# The design's §5.2; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    ConfigIO

Reading a package's own two Julia files — `.gbg/config.jl`, its settings, and `.gbg/settled.jl`, the
rulings its owner has already given — WITHOUT EVALUATING THEM. Both are parsed, and only literals and
keyword calls to the constructors of [`Model`](@ref) are accepted: a function call, an interpolation, an unknown
keyword or an unknown constructor is refused.

The reason is not tidiness. A config that is `include`d is a program, and a module holding nothing but a
configuration type still ran `getpid()` through it when that was tried. A package's settings are read by
every build and every test of that package; they must be data.

Refusals are [`ConfigError`](@ref), which every verb turns into exit 2 — the consumer's mistake, not a
crash of this package.
"""
module ConfigIO

using TOML

using ..Model
using ..Texts
using ..Catalogue

using JuliaSyntax: JuliaSyntax
const JS = JuliaSyntax   # the registered parser, pinned: its trees do not change when Julia does

"""
    require_root(verb) -> Union{String,Nothing}

The package root for a verb that needs one, or `nothing` with a named refusal on `stderr`. The argument
is `verb`, the verb's name, which the message opens with. Returns the root.

A verb run outside a package is exit 2, not a `MethodError` on `nothing` — which is what every new verb
did until 2026-09-18, because each passed `find_root()` straight into a function typed `AbstractString`.
"""
function require_root end

"""
    find_root(start = pwd()) -> Union{String,Nothing}

The package root at or above `start`: the nearest directory holding `.gbg/config.jl`. The argument is
`start`, where to begin. Returns the root, or `nothing` where no package encloses it.

Every verb finds its package this way. The old reader looked for `.gbg/config.toml` instead, and a
package wired by `gbg init` has never had one — which made every new verb fail with a `MethodError` on
`nothing` when run from a real consumer, though each worked when handed a root.
"""
function require_root(verb::AbstractString)
    root = find_root()
    root === nothing && println(stderr, "$verb: no .gbg/config.jl here or above — run `gbg init` in the package")
    return root
end

function find_root(start::AbstractString = pwd())
    d = abspath(start)
    while true
        isfile(joinpath(d, ".gbg", "config.jl")) && return d
        p = dirname(d)
        p == d && return nothing
        d = p
    end
end

"""
    narrow(v) -> AbstractVector

The vector retyped to its elements where they share a concrete type, and left alone otherwise. The
argument is `v`, a freshly built list. Returns it, possibly retyped.

A list literal builds as `Vector{Any}`, which a field typed as a union of vectors — `Setting.value` —
refuses, since there is no one element type to convert it to.
"""
narrow(v::AbstractVector) = isempty(v) ? v : (T = typeof(first(v)); all(x -> x isa T, v) ? T[x for x in v] : v)

"""
    ConfigError

A `.gbg/config.jl` or `.gbg/settled.jl` that cannot be read as data.

# Fields

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
    "Config" => Model.Config, "Switch" => Model.Switch, "Exclusion" => Model.Exclusion, "Deferral" => Model.Deferral, "Setting" => Model.Setting,
    "PatternRule" => Model.PatternRule, "Settled" => Model.Settled,
    "Location" => Model.Location, "TextExample" => Model.TextExample,
    "RetiredClaim" => Model.RetiredClaim,
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
    append_settled(root, s) -> String

Adds one ruling to `.gbg/settled.jl`, creating the file where there is none. The arguments are `root`,
the package root, and `s`, the ruling. Returns the path written.

The file is written whole, from the rulings it already holds — read back as data first, so a file that
cannot be read is a [`ConfigError`](@ref) and nothing is written into it — with the new one last. Text
appended to the owner's file put a ruling inside a trailing comment and left the record unreadable
(found in review, 2026-09-26); what is written here is exactly what `read_settled` reads. The comment
block above the vector is kept byte for byte; a comment between or after the rulings is not kept.
"""
function append_settled(root::AbstractString, s::Model.Settled)
    path = joinpath(root, ".gbg", "settled.jl")
    rulings = vcat(read_settled(root), [s])      # a file that cannot be read throws before anything is written
    io = IOBuffer()
    if isfile(path)
        # every blank or line comment before the line that opens the vector, as the owner left them; a
        # `#=` block ends the run, since half of one kept would not parse
        print(io, match(r"\A(?:[ \t]*(?:#(?!=)[^\n]*)?\r?\n)*", read(path, String)).match)
    else
        println(io, "# .gbg/settled.jl — what the owner has already decided, and agents are told not to report.")
        println(io, "#")
        println(io, "# Read as data by ConfigIO, which evaluates nothing. Written by `gbg answer`; no build, test")
        println(io, "# or check reads it, and only the agents of a run are shown it.")
    end
    println(io, "[")
    for r in rulings
        println(io, "    Settled(question = ", repr(r.question), ",")
        println(io, "            text = ", repr(r.text), ",")
        println(io, "            date = ", repr(r.date), ",")
        println(io, "            locations = [")
        for l in r.locations
            println(io, "                Location(file = ", repr(l.file), ", node = ", repr(l.node),
                    ", text = ", repr(l.text), ", line = ", l.line, "),")
        end
        println(io, "            ]),")
    end
    println(io, "]")
    mkpath(dirname(path))
    write(path, String(take!(io)))
    return path
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
        # Decided by the parser's children alone: an escaped `\$` is a dollar in the value, and a scan of
        # the source text for one refused the owner's own rulings (found in review, 2026-09-26).
        kids = [c for c in cs if JS.kind(c) !== JS.K"String"]
        isempty(kids) || (push!(problems, "line $line: an interpolated string is not data: $(first(text, 60))"); return nothing)
        # The value the PARSER gives each piece, joined: a `\`-newline continuation, a triple-quoted
        # string's indent and every escape come out as Julia evaluates them. Unquoting the source text
        # kept the continuations, and a switch's reason reached a consumer's public page with a `\` and
        # a run of spaces at every line end (found upgrading GBGPeriodicFields, 2026-09-24).
        return k === JS.K"String" ? String(node.val) : join(String(c.val) for c in cs)
    elseif k === JS.K"Integer"
        n = tryparse(Int, replace(text, "_" => ""))
        n === nothing && (push!(problems, "line $line: $text is not an integer this package can hold"); return nothing)
        return n
    elseif k === JS.K"Float"
        return parse(Float64, text)
    elseif k === JS.K"Bool"
        return text == "true"
    elseif k === JS.K"quote"
        # `:a_symbol` and nothing else: `:(expr)` and `quote … end` are programs, and were read as a
        # symbol of their source text (found in review, 2026-09-26)
        (length(cs) == 1 && JS.kind(cs[1]) === JS.K"Identifier") ||
            (push!(problems, "line $line: a quoted expression is not data: $(first(text, 60))"); return nothing)
        return Symbol(node_name(cs[1]))
    elseif k === JS.K"vect"
        # NARROWED to the element type where every element shares one. A `Vector{Any}` is refused by
        # every field typed `Vector{String}` — `Setting.value` among them — so the one documented way to
        # declare a package's admitted `\mathbf` strings could not be written at all.
        return narrow(Any[build(c, path, problems) for c in cs])
    elseif k === JS.K"ref"
        # A typed array literal — `String[]`, `Switch[]` — is data: the type names an element type the
        # model already has, and an empty one is how a config says "none of these". It is built AS that
        # type: an `Any[]` was refused by every union-typed field, so `value = String[]` could not be
        # written at all (found in review, 2026-09-26).
        elem = node_name(first(cs))
        T = elem == "String" ? String : elem == "Symbol" ? Symbol : elem == "Int" ? Int : elem == "Any" ? Any :
            get(CONSTRUCTORS, elem, nothing)
        T === nothing && (push!(problems, "line $line: $elem[] is not an element type a config may name"); return nothing)
        items = Any[build(c, path, problems) for c in cs[2:end]]
        any(x -> x === nothing, items) && return nothing        # already refused, one line each
        all(x -> x isa T, items) || (push!(problems, "line $line: not every element of $elem[…] is a $elem"); return nothing)
        return T[x for x in items]
    elseif k === JS.K"macrocall" && !isempty(cs) && Texts.string_macro(cs[1]) && Texts.macro_name(cs[1]) in ("v", "r")
        # `v"2.0.0"` is a pinned version and `r"…"` a package's own pattern; each is read from the
        # parser's string child — a raw string takes no escapes, so unquoting the source text turned
        # `r"\\d"` into `r"\d"` and dropped the flags of `r"x"i` — and a mistake in either is a refusal
        # naming the line, not a backtrace (found in review, 2026-09-26).
        lit = length(cs) >= 2 && JS.kind(cs[2]) === JS.K"string" ? join(String(c.val) for c in something(JS.children(cs[2]), ())) : ""
        if Texts.macro_name(cs[1]) == "v"
            v = tryparse(VersionNumber, lit)
            v === nothing && (push!(problems, "line $line: $text is not a version"); return nothing)
            return v
        end
        flags = length(cs) >= 3 ? String(cs[3].val) : ""
        return try
            Regex(lit, flags)
        catch err
            push!(problems, "line $line: $text is not a pattern — " * sprint(showerror, err)); nothing
        end
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
        # Each keyword once, and never a positional argument: §5.2 admits keyword calls only. A positional
        # beside keywords vanished without a word, a repeated keyword took the last value where Julia
        # refuses it, and a call positional throughout bound its values by field order, which a new field
        # silently re-binds (found in review, 2026-09-26). No config of the fleet writes one.
        kwargs = Dict{Symbol,Any}()
        positional = Any[]
        refused = length(problems)
        keyword!(kw) = begin
            kid = something(JS.children(kw), ())
            length(kid) == 2 || return
            key = Symbol(node_name(kid[1]))
            haskey(kwargs, key) && push!(problems, "line $line: $name(…) is given `$key` twice")
            kwargs[key] = build(kid[2], path, problems)
        end
        for a in cs[2:end]
            if JS.kind(a) === JS.K"="
                keyword!(a)
            elseif JS.kind(a) === JS.K"parameters"
                foreach(keyword!, something(JS.children(a), ()))
            else
                push!(positional, build(a, path, problems))
            end
        end
        isempty(positional) ||
            (push!(problems, "line $line: $name(…) is given a positional argument; name every one, `field = value`"); return nothing)
        # an argument already refused was said once, on its own line; the call around it says nothing more
        length(problems) > refused && return nothing
        return construct(CONSTRUCTORS[name], name, kwargs, line, problems)
    end
    push!(problems, "line $line: $(lowercase(string(k))) is not data: $(first(text, 60))")
    return nothing
end

node_name(node) = strip(String(JS.sourcetext(node)))

# The constructor is called with what the file gave it, and a wrong keyword or a wrong type is a refusal
# naming the line rather than a stack trace: the reader of this message is a person editing a config. One
# line: a `MethodError` prints its candidate list beneath, and a bare `[]` given to a list-valued setting
# dumped that whole list where the fix is to name the element type (found in review, 2026-09-26).
function construct(T, name, kwargs, line, problems)
    try
        return T(; kwargs...)
    catch err
        bare = [k for (k, v) in kwargs if v isa Vector{Any} && isempty(v)]
        msg = isempty(bare) ? first(split(sprint(showerror, err), '\n')) :
              "`$(first(bare)) = []` has no element type; an empty list is written `String[]`"
        push!(problems, "line $line: $name(…) does not accept what it was given — " * msg)
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
    # The name is what every rule about a package's own name reads — which of its mentions is a sibling's
    # and which is its own. A config that names the DIRECTORY rather than the package passes every other
    # check and then reports a package's every mention of itself as an unlinked sibling.
    let proj = joinpath(root, "Project.toml")
        if isfile(proj)
            declared = get(TOML.parsefile(proj), "name", "")
            isempty(declared) || declared == cfg.package ||
                push!(problems, "the config names the package `$(cfg.package)`, and Project.toml names it `$declared`")
        end
    end
    for (label, cmd) in ("docs_build" => cfg.docs_build, "test" => cfg.test)
        isempty(cmd) && continue
        script = findfirst(a -> endswith(a, ".jl"), cmd)
        script === nothing && continue
        isfile(joinpath(root, cmd[script])) ||
            push!(problems, "$label names $(cmd[script]), which is not a file here")
    end
    # A section named as documentation must be one the file has: a heading misspelt here would admit
    # nothing and say nothing, and the owner would believe a section fixable that is not.
    if !isempty(cfg.claude_documentation)
        cm = joinpath(root, "CLAUDE.md")
        heads = isfile(cm) ? Set(strip(m.captures[1]) for m in eachmatch(r"(?m)^#{1,6}\s+(.*?)\s*$", read(cm, String))) : Set{String}()
        for h in cfg.claude_documentation
            h in heads || push!(problems, "claude_documentation names the section \"$h\", which CLAUDE.md does not have")
        end
    end
    for (copy, source) in cfg.copies
        isfile(joinpath(root, source)) ||
            push!(problems, "the copy $copy is declared from $source, which is not a file here")
    end
    # A pattern matching nothing is a surface handed to no reader and read by no rule, silently: the
    # fixture carried two such for a week and every rule over them reported clean.
    for (fs, patterns) in cfg.filesets, pat in patterns
        isempty(Texts.expand(root, pat)) &&
            push!(problems, "the $(lowercase(String(Symbol(fs)))) file set names $pat, which matches nothing here")
    end
    # The two refusals of §9. A switch is how a package says a rule does not apply to it, and each of
    # these would make that claim unreadable: one naming nothing, and one giving no reason to show on the
    # package's own site. There is no third: every rule is switchable, and the rulebook is the default
    # rather than a set a package may not escape (ruled 2026-09-17).
    # A package's own pattern rules are rules too: `run_patterns` honours a switch against one, and
    # refusing that switch here left a package no way to turn off a rule of its own making.
    own = Set(r.id for r in cfg.rules)
    known = union(Catalogue.known_ids(), own)
    for s in cfg.switches
        isempty(strip(s.reason)) && push!(problems, "the switch against $(s.target) gives no reason")
        s.target in known ||
            push!(problems, "the switch names $(s.target), which is not a rule, a role or an instrument")
    end
    # An exclusion takes files out of every rule, so it must say why and must name something: one matching
    # no file would claim, on the package's site, an exemption that covers nothing.
    for e in cfg.exclusions
        isempty(strip(e.reason)) && push!(problems, "an exclusion gives no reason")
        isempty(e.files) && push!(problems, "an exclusion names no files")
        for pat in e.files
            isempty(Texts.expand(root, pat)) && push!(problems, "the exclusion names $pat, which matches nothing here")
        end
    end
    # A deferral is a question with a condition on it: one naming no rule, or no condition, is not one.
    # And a rule cannot be both switched off and deferred, for the whole package or for some of its files.
    for d in cfg.deferrals
        isempty(strip(d.until)) && push!(problems, "the deferral of $(d.rule) says nothing of what would close it")
        (d.rule in own || any(r -> r.id === d.rule, Catalogue.RULES)) ||
            push!(problems, "the deferral names $(d.rule), which is not a rule")
        any(s -> s.target === d.rule, cfg.switches) &&
            push!(problems, "$(d.rule) is both switched off and deferred; it is one or the other")
    end
    # A setting is read by the one rule it names, by the parameter's name: one on a retired rule, or
    # naming a parameter the rule does not have, was read by nobody and reported by nobody (found in
    # review, 2026-09-26).
    for st in cfg.settings
        rule = Catalogue.rule(st.rule)
        if rule === nothing
            push!(problems, "the setting is for $(st.rule), which is not a rule of the rulebook")
        elseif !any(p -> p.name === st.name, rule.parameters)
            push!(problems, "$(st.rule) has no parameter `$(st.name)`" *
                            (isempty(rule.parameters) ? "" : "; it has " * join(("`$(p.name)`" for p in rule.parameters), ", ")))
        end
    end
    for d in cfg.disciplines
        any(x -> x.id === d, Catalogue.DISCIPLINES) ||
            push!(problems, "the discipline $d is not in the catalogue; one the tool lacks is requested from its session, not written here")
    end
    for n in cfg.normative
        isfile(joinpath(root, n)) || push!(problems, "the normative document $n is not a file here")
    end
    return problems
end

end # module ConfigIO
