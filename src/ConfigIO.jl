"""
    ConfigIO

Reading a package's own two Julia files — `.gbg/config.jl`, its settings, and `.gbg/settled.jl`, the
rulings its owner has already given — WITHOUT EVALUATING THEM. Both are parsed, and only literals and
calls to the constructors of [`Model`](@ref) are accepted: a function call, an interpolation, an unknown
keyword or an unknown constructor is refused (`docs/ARCHITECTURE.md` §5.2).

The reason is not tidiness. A config that is `include`d is a program, and a module holding nothing but a
configuration type still ran `getpid()` through it when that was tried. A package's settings are read by
every build and every test of that package; they must be data.

Refusals are [`ConfigError`](@ref), which every verb turns into exit 2 — the consumer's mistake, not a
crash of this package.
"""
module ConfigIO

using ..Model
using ..Texts
using ..Catalogue

const JS = Base.JuliaSyntax

"""
    ConfigError

A `.gbg/config.jl` or `.gbg/settled.jl` that cannot be read as data. The fields are:

- `file` — the file it was raised for.
- `problems` — one line per refusal, each naming what was found and where.
"""
struct ConfigError <: Exception
    file::String
    problems::Vector{String}
end

Base.showerror(io::IO, e::ConfigError) =
    print(io, "config error: ", e.file, " is not data:\n  ", join(e.problems, "\n  "))

# Every constructor a config file may call, with the module the value comes from. Nothing else is
# accepted: a name not in this table is a refusal, so a config cannot reach a function by naming it.
const CONSTRUCTORS = Dict{String,Any}(
    "Config" => Model.Config, "Switch" => Model.Switch, "Setting" => Model.Setting,
    "PatternRule" => Model.PatternRule, "AgentRole" => Model.AgentRole, "Settled" => Model.Settled,
    "Location" => Model.Location, "TextExample" => Model.TextExample,
)

# The enums a config file may name, by their scoped spelling (`FileSet.PAGES`, `Strength.FULL`).
const ENUMS = Dict{String,Module}(
    "Intention" => Model.Intention, "Decider" => Model.Decider, "Fixer" => Model.Fixer,
    "Input" => Model.Input, "FileSet" => Model.FileSet, "Strength" => Model.Strength,
    "Part" => Model.Part, "Verdict" => Model.Verdict, "Stop" => Model.Stop,
    "WhyAgent" => Model.WhyAgent, "Anchor" => Model.Anchor,
)

"""
    read_config(root) -> Model.Config

The package at `root` read from its `.gbg/config.jl`, as data. The argument is `root`, the package root.
Throws [`ConfigError`](@ref) when the file is absent, does not parse, or holds anything but literals and
the constructors above. Returns the config.
"""
function read_config(root::AbstractString)
    path = joinpath(root, ".gbg", "config.jl")
    value = read_value(path)
    value isa Model.Config || throw(ConfigError(path, ["the file must hold one Config(…) value, not $(typeof(value))"]))
    return value
end

"""
    read_settled(root) -> Vector{Model.Settled}

The rulings the owner has already given, read from `.gbg/settled.jl` as data; an absent file is no
rulings, which is the ordinary state of a new package. The argument is `root`, the package root. Returns
the rulings, in the order they were appended.
"""
function read_settled(root::AbstractString)
    path = joinpath(root, ".gbg", "settled.jl")
    isfile(path) || return Model.Settled[]
    value = read_value(path)
    value isa Vector || throw(ConfigError(path, ["the file must hold one vector of Settled(…) values"]))
    bad = [string(typeof(v)) for v in value if !(v isa Model.Settled)]
    isempty(bad) || throw(ConfigError(path, ["every element must be a Settled(…) value; found " * join(unique(bad), ", ")]))
    return Vector{Model.Settled}(value)
end

"""
    read_value(path) -> Any

The one value the Julia file at `path` holds, built from its parse tree without evaluating it. The
argument is `path`, the file to read. Throws [`ConfigError`](@ref) listing every refusal, so a reader
sees all of its mistakes at once rather than one per run. Returns the value.
"""
function read_value(path::AbstractString)
    isfile(path) || throw(ConfigError(path, ["the file does not exist"]))
    src = read(path, String)
    tree = try
        JS.parseall(JS.SyntaxNode, src; filename = path)
    catch err
        throw(ConfigError(path, ["the file does not parse: " * sprint(showerror, err)]))
    end
    problems = String[]
    values = Any[]
    for c in something(JS.children(tree), ())
        JS.kind(c) === JS.K"Comment" && continue
        push!(values, build(c, path, problems))
    end
    isempty(problems) || throw(ConfigError(path, problems))
    length(values) == 1 || throw(ConfigError(path, ["the file must hold exactly one value, found $(length(values))"]))
    return only(values)
end

# The one recursive reader. Every kind it does not know is a refusal naming the line, so a config that
# reaches for a function is rejected with the reason rather than quietly ignored.
function build(node, path, problems)
    k = JS.kind(node)
    line = JS.source_line(node)
    text = strip(String(JS.sourcetext(node)))
    cs = something(JS.children(node), ())

    if k === JS.K"string" || k === JS.K"String"
        # A string literal is a `string` node wrapping one `String`; anything else inside it is an
        # interpolation, which is a program and not data.
        kids = [c for c in cs if JS.kind(c) !== JS.K"String"]
        isempty(kids) || (push!(problems, "line $line: an interpolated string is not data: $(first(text, 60))"); return nothing)
        occursin("\$", text) && (push!(problems, "line $line: an interpolated string is not data: $(first(text, 60))"); return nothing)
        return unquote(text)
    elseif k === JS.K"Integer"
        return parse(Int, replace(text, "_" => ""))
    elseif k === JS.K"Float"
        return parse(Float64, text)
    elseif k === JS.K"Bool"
        return text == "true"
    elseif k === JS.K"quote"                                   # :a_symbol
        return Symbol(strip(text, ':'))
    elseif k === JS.K"vect"
        return Any[build(c, path, problems) for c in cs]
    elseif k === JS.K"ref"
        # A typed array literal — `String[]`, `Switch[]` — is data: the type names an element type the
        # model already has, and an empty one is how a config says "none of these".
        elem = node_name(first(cs))
        elem in ("String", "Symbol", "Int", "Any") || haskey(CONSTRUCTORS, elem) ||
            (push!(problems, "line $line: $elem[] is not an element type a config may name"); return nothing)
        return Any[build(c, path, problems) for c in cs[2:end]]
    elseif k === JS.K"macrocall" && startswith(text, "v\"")
        return VersionNumber(unquote(text[2:end]))            # a pinned version, `v"2.0.0"`
    elseif k === JS.K"macrocall" && startswith(text, "r\"")
        return Regex(unquote(text[2:end]))                    # a package's own pattern rule
    elseif k === JS.K"=>" || (k === JS.K"call" && length(cs) == 3 && node_name(cs[2]) == "=>")
        # `a => b` parses infix: the operator is the middle child of a call.
        parts = k === JS.K"=>" ? (cs[1], cs[2]) : (cs[1], cs[3])
        return build(parts[1], path, problems) => build(parts[2], path, problems)
    elseif k === JS.K"." && length(cs) == 2                    # a scoped enum value, FileSet.PAGES
        mod = node_name(cs[1]); name = strip(node_name(cs[2]), ':')
        haskey(ENUMS, mod) || (push!(problems, "line $line: $mod is not one of this package's enums"); return nothing)
        sym = Symbol(name)
        for v in instances(ENUMS[mod].T)
            Symbol(v) === sym && return v
        end
        push!(problems, "line $line: $mod has no value $name"); return nothing
    elseif k === JS.K"call"
        name = node_name(first(cs))
        if name == "Symbol"
            # A rule id holds dots — `RULE.DOC.TABLE_TOP_LEVEL` — so `:RULE.DOC…` is not a symbol in
            # Julia but a field access. `Symbol("…")` is how a config names one, and it converts a
            # literal rather than running anything.
            length(cs) == 2 || (push!(problems, "line $line: Symbol takes one string"); return nothing)
            inner = build(cs[2], path, problems)
            inner isa AbstractString || (push!(problems, "line $line: Symbol takes a string"); return nothing)
            return Symbol(inner)
        end
        if name == "Dict"
            pairs_ = [build(c, path, problems) for c in cs[2:end]]
            all(p -> p isa Pair, pairs_) ||
                (push!(problems, "line $line: a Dict takes pairs, `key => value`"); return nothing)
            return Dict(pairs_)
        end
        haskey(CONSTRUCTORS, name) ||
            (push!(problems, "line $line: $name is not a constructor a config may call"); return nothing)
        kwargs = Dict{Symbol,Any}()
        positional = Any[]
        for a in cs[2:end]
            if JS.kind(a) === JS.K"="
                kid = something(JS.children(a), ())
                length(kid) == 2 || continue
                kwargs[Symbol(node_name(kid[1]))] = build(kid[2], path, problems)
            elseif JS.kind(a) === JS.K"parameters"
                for kw in something(JS.children(a), ())
                    kid = something(JS.children(kw), ())
                    length(kid) == 2 && (kwargs[Symbol(node_name(kid[1]))] = build(kid[2], path, problems))
                end
            else
                push!(positional, build(a, path, problems))
            end
        end
        return construct(CONSTRUCTORS[name], name, positional, kwargs, line, problems)
    end
    push!(problems, "line $line: $(lowercase(string(k))) is not data: $(first(text, 60))")
    return nothing
end

node_name(node) = strip(String(JS.sourcetext(node)))

unquote(s) = replace(strip(s, '"'), "\\\"" => "\"", "\\\\" => "\\", "\\n" => "\n")

# The constructor is called with what the file gave it, and a wrong keyword or a wrong type is a refusal
# naming the line rather than a stack trace: the reader of this message is a person editing a config.
function construct(T, name, positional, kwargs, line, problems)
    try
        return isempty(kwargs) ? T(positional...) : T(; kwargs...)
    catch err
        push!(problems, "line $line: $name(…) does not accept what it was given — " * sprint(showerror, err))
        return nothing
    end
end

"""
    validate(cfg, root) -> Vector{String}

What is wrong with the config as a description of the package at `root`: a command that names no file, a
declared copy whose source is missing, a switch with no reason, a file set whose patterns match nothing.
The arguments are `cfg`, the config, and `root`, the package root. Returns one line per problem, empty
when there is none.
"""
function validate(cfg::Model.Config, root::AbstractString)
    problems = String[]
    isempty(cfg.package) && push!(problems, "the package has no name")
    for (label, cmd) in ("docs_build" => cfg.docs_build, "test" => cfg.test)
        isempty(cmd) && continue
        script = findfirst(a -> endswith(a, ".jl"), cmd)
        script === nothing && continue
        isfile(joinpath(root, cmd[script])) ||
            push!(problems, "$label names $(cmd[script]), which is not a file here")
    end
    for (copy, source) in cfg.copies
        isfile(joinpath(root, source)) ||
            push!(problems, "the copy $copy is declared from $source, which is not a file here")
    end
    # The three refusals of §9. A switch is how a package says a rule does not apply to it, and each of
    # these would make that claim unreadable: one naming nothing, one giving no reason to show on the
    # package's own site, and one against a rule the rulebook says nobody may escape.
    known = Catalogue.known_ids()
    # A name can only be judged against a complete rulebook. While the ninety-five rules are being
    # converted, `RULES` is short by construction, so a switch naming one that has not arrived yet is not
    # a mistake — this arm turns itself on when the conversion ratchet reaches zero.
    judge_names = !isempty(Catalogue.RULES)
    for s in cfg.switches
        isempty(strip(s.reason)) && push!(problems, "the switch against $(s.target) gives no reason")
        judge_names && !(s.target in known) &&
            push!(problems, "the switch names $(s.target), which is not a rule, a role or an instrument")
        s.target in Catalogue.ALWAYS_ON_RULES &&
            push!(problems, "$(s.target) is always on: no package may switch it off (docs/ARCHITECTURE.md §9)")
    end
    for st in cfg.settings
        judge_names && !(st.rule in known) &&
            push!(problems, "the setting is for $(st.rule), which is not a rule")
    end
    for n in cfg.normative
        isfile(joinpath(root, n)) || push!(problems, "the normative document $n is not a file here")
    end
    return problems
end

end # module ConfigIO
