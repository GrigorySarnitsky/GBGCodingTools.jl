# The design's §5.2 and §7; the coordinates live here rather than in a docstring, which must read
# complete at the REPL.
"""
    Rules.Modules

The rules that need the package LOADED: what a docstring shows against what the module actually holds.
A cross-module name mentioned bare where a reader cannot follow it, and a displayed signature that no
longer matches the method table, are both invisible in the source of any one file.

A check here is handed the loaded package and the package root together, since what it compares is the
module against the source that documents it. Where nothing loaded the package the rule does not run, and
the caller is told so rather than the run reporting clean.
"""
module Modules

using ...Model
using ...Texts

"""
    owners(pkg, cfg) -> Dict{String,Symbol}

Which module of the package owns each name it exports. The arguments are `pkg`, the loaded package, and
`cfg`, the package's config. Returns the map from name to owning module.
"""
function owners(pkg::Module, cfg)
    mods = Module[pkg]
    for n in names(pkg; all = true)
        isdefined(pkg, n) || continue
        v = getfield(pkg, n)
        v isa Module && v !== pkg && push!(mods, v)
    end
    modnames = Set(nameof.(mods))
    out = Dict{String,Symbol}()
    for mod in mods, n in names(mod)
        s = String(n)
        s == String(nameof(mod)) && continue
        isdefined(mod, n) || continue
        v = getfield(mod, n)
        parent = (v isa Function || v isa Type) ? nameof(parentmodule(v)) : nameof(mod)
        # A generic of Base or a standard library that a package module extends and re-exports — `norm`,
        # `dot`, `mul!` — is owned by no module of the package: a reader meeting it knows it already, and
        # crediting it to the extending module reported every mention of `norm` in a sibling as foreign
        # (found upgrading GBGPeriodicFields, 2026-09-27).
        (v isa Function || v isa Type) && !(parent in modnames) && continue
        out[s] = parent in modnames ? parent : nameof(mod)
    end
    return out
end

"""
    xlink(loaded, cfg) -> Vector{Model.Location}

Every cross-module name mentioned bare in a docstring where a reader would need a link to reach it. The
arguments are `loaded`, the loaded package with the package root, and `cfg`, the package's config, which
names the files. Returns one location per first bare mention.

A name the same module owns needs no link — the reader is already there. A name in the docstring's own
signature, or already linked earlier in the same docstring, is not a mention to be linked either.
"""
function xlink(loaded, cfg)
    own_of = owners(loaded.pkg, cfg)
    out = Model.Location[]
    # Through the same resolver every other rule uses. Read as a list of FILES, the config's code set is
    # a list of globs — empty by default — and both rules here visited nothing and reported clean in
    # every real package (found in review, 2026-09-26).
    for f in Texts.files(cfg, loaded.root, Model.FileSet.CODE)
        path = joinpath(loaded.root, f)
        src = read(path, String)
        # The declaration line holds the name and nothing after it but a comment: matched loosely, a
        # docstring's prose line "module for what the point layer provides" named the module `for`, and
        # every function of that module was reported as foreign to it (found upgrading PF, 2026-09-27).
        m = match(r"^(?:bare)?module\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:#.*)?$"m, src)
        m === nothing && continue
        me = Symbol(m.captures[1])
        for d in Texts.docstrings_of(src)
            lines = split(d.text, '\n')
            first_prose = something(findfirst(l -> !startswith(l, "    ") && !isempty(strip(l)), lines), 1)
            signature = join(lines[1:first_prose-1], "\n")
            prose = join(lines[first_prose:end], "\n")
            in_signature = Set(String.(x.captures[1] for x in eachmatch(Regex("(" * Texts.NAME * ")\\("), signature)))
            for am in eachmatch(r"\(([^)]*)\)", signature)
                for raw in split(am.captures[1], ",")
                    a = strip(split(split(split(raw, "::")[1], "=")[1], ";")[end])
                    isempty(a) || push!(in_signature, String(a))
                end
            end
            # A name heading a bullet is the docstring's own field or argument, not a mention: a field
            # called `audit` is not the function of that name elsewhere.
            for b in eachmatch(r"(?m)^\s*[-*]\s+`([^`:\s]+)", prose); push!(in_signature, String(b.captures[1])); end
            linked = Set(String.(x.captures[1] for x in eachmatch(r"\[`([^`]+)`\]\(@", prose)))
            seen = Set{String}()
            for x in eachmatch(Regex("`(" * Texts.NAME * ")`"), prose)
                name = String(x.captures[1])
                (haskey(own_of, name) && !(name in in_signature) && !(name in linked) && !(name in seen)) || continue
                push!(seen, name)
                own_of[name] === me && continue
                push!(out, Model.Location(; file = f, line = d.line, node = d.node,
                    text = "`$name` is owned by $(own_of[name]) and mentioned here without a link"))
            end
        end
    end
    return out
end

const XLINK = Model.Rule(
    id = Symbol("RULE.DOC.XLINK"),
    statement = "A name another module owns is linked at its first mention in a docstring, qualified so the link resolves.",
    why = "A reader meeting a name from elsewhere has nowhere to go: the docstring in front of him does not define it.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.LOADED_MODULE, xlink, false),
    examples = [
        Model.ModuleExample("""
            module Example
            module Inner
                export helper
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
            end
            using .Inner
            \"\"\"
                caller(x)

            Calls `helper` on its argument.
            \"\"\"
            caller(x) = Inner.helper(x)
            end
            """, [Model.Location(; file = "src/Example.jl", line = 12)], "linked at its first mention"),
        Model.ModuleExample("""
            module Example
            module Inner
                export helper
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
            end
            using .Inner
            \"\"\"
                caller(x)

            Calls [`helper`](@ref Example.Inner.helper) on its argument.
            \"\"\"
            caller(x) = Inner.helper(x)
            end
            """, Model.Location[], "linked at its first mention"),
        # A field that shares a name with another module's function is the docstring's own field.
        Model.ModuleExample("""
            module Example
            module Inner
                export helper
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
            end
            using .Inner
            \"\"\"
                Holder

            A holder. The fields are:

            - `helper` — what it holds.
            \"\"\"
            struct Holder
                helper::Int
            end
            end
            """, Model.Location[], "linked at its first mention"),
    ])

# ────────────────────────────────────────── what a docstring shows against what the module defines

dehat(a::Symbol) = Symbol(replace(String(a), "̂" => ""))

"""
    displayed_signatures(root, cfg) -> Tuple

Every signature a docstring displays, as the positional and keyword names it shows, keyed by binding
and file, with the keys whose signature elides arguments behind a splat. The arguments are `root`, the
package root, and `cfg`, the package's config. Returns `(positional, keyword, elided, shown_in,
arg_in)`: each key's first docstring line, and the first line showing each `(name, file, argument)`.
"""
function displayed_signatures(root::AbstractString, cfg)
    Key = Tuple{Symbol,String}
    positional = Dict{Key,Set{Symbol}}(); keyword = Dict{Key,Set{Symbol}}()
    elided = Set{Key}(); shown_in = Dict{Key,Int}(); arg_in = Dict{Tuple{Symbol,String,Symbol},Int}()
    note!(d, key, args) = union!(get!(d, key, Set{Symbol}()), args)
    function harvest!(ex, file, line)
        ex isa Expr && ex.head === :where && return harvest!(ex.args[1], file, line)
        (ex isa Expr && ex.head === :call) || return
        name = ex.args[1]; name isa Symbol || return
        key = (name, file)
        pos, kw = Symbol[], Symbol[]
        for a in ex.args[2:end]
            if a isa Expr && a.head === :parameters
                for k in a.args
                    k isa Expr && k.head === :(...) && (push!(elided, key); continue)
                    k isa Expr && k.head === :kw && (k = k.args[1])
                    k isa Expr && k.head === :(::) && (k = k.args[1])
                    k isa Symbol && push!(kw, k)
                end
            else
                a isa Expr && a.head === :(...) && (push!(elided, key); continue)
                a isa Expr && a.head === :kw && (a = a.args[1])
                a isa Expr && a.head === :(::) && (a = a.args[1])
                a isa Symbol && push!(pos, a)
            end
        end
        note!(positional, key, dehat.(pos)); note!(keyword, key, kw)
        get!(shown_in, key, line)
        for a in [dehat.(pos); kw]
            get!(arg_in, (name, file, a), line)
        end
    end
    for f in Texts.files(cfg, root, Model.FileSet.CODE)
        path = joinpath(root, f)
        for d in Texts.docstrings_of(read(path, String))
            header = collect(Iterators.takewhile(l -> startswith(l, "    "), split(d.text, '\n')))
            isempty(header) && continue
            joined = String[]; current = ""
            for line in header
                current *= strip(line) * " "
                if count('(', current) == count(')', current) && !isempty(strip(current))
                    push!(joined, strip(current)); current = ""
                end
            end
            for signature in joined
                # The `-> T` a signature ends in is not part of the call. Written `\$` inside the
                # pattern it was a literal dollar, nothing was cut, and every signature with a return
                # annotation parsed as a lambda and was dropped (found in review, 2026-09-26).
                ex = try Meta.parse(replace(signature, r"\s*->.*$" => "")) catch; nothing end
                ex === nothing || harvest!(ex, f, d.line)
            end
        end
    end
    return (positional, keyword, elided, shown_in, arg_in)
end

# Every module of the package, nested ones included: a module two levels down is as much the package's as a
# module directly under it, and a search one level deep judged its docstrings against another module's
# function of the same name.
function modules_of(pkg::Module)
    out = Module[pkg]; i = 1
    while i <= length(out)
        m = out[i]; i += 1
        for n in names(m; all = true)
            isdefined(m, n) || continue
            v = getfield(m, n)
            v isa Module && v !== m && parentmodule(v) === m && !(v in out) && push!(out, v)
        end
    end
    return out
end

"""
    signature_fidelity(loaded, cfg) -> Vector{Model.Location}

Every displayed signature that no longer matches the method table: a keyword shown that no method takes,
a keyword taken that no signature shows, and a positional name shown that matches no defined argument.
The arguments are `loaded`, the loaded package with the package root, and `cfg`, the package's config.
Returns one location per disagreement, at the docstring.

A docstring is held to the function of its name whose methods are defined in its own file; where none
is, to the one function of that name the package owns, and where several are, it is skipped rather
than compared with a namesake. A binding whose methods live in an extension that is not loaded is
skipped too.
"""
function signature_fidelity(loaded, cfg)
    pkg, root = loaded.pkg, loaded.root
    shown, shown_kw, elided, shown_in, arg_in = displayed_signatures(root, cfg)
    mods = modules_of(pkg)
    # A module with no package directory — one an example loaded into memory — has methods whose file is
    # not a path at all, so the filter that keeps a package's own methods would reject every one of them.
    home = pkgdir(pkg)
    pkgroot = something(home, root)
    every_method = home === nothing
    ours(m) = every_method || startswith(String(m.file), pkgroot) || occursin(cfg.package, String(m.file))
    owned(name) = unique!([getfield(m, name) for m in mods if isdefined(m, name) && Base.which(m, name) === m])
    in_file(f, file) = f isa Function &&
        any(m -> endswith(replace(String(m.file), '\\' => '/'), "/" * file) || String(m.file) == file, methods(f))
    function resolve(name, file)
        cands = filter(f -> f isa Function || f isa Type, owned(name))
        here = filter(f -> in_file(f, file), cands)
        length(here) == 1 && return here[1]
        length(cands) == 1 && return cands[1]
        return nothing
    end
    function defined_sets(f)
        f isa Function && isempty(methods(f)) && return :extension
        pos, kw = Set{Symbol}(), Set{Symbol}(); unnamed = false
        for m in methods(f)
            ours(m) || continue
            for a in Base.method_argnames(m)[2:end]
                (a === Symbol("#unused#") || a === Symbol("")) ? (unnamed = true) : push!(pos, dehat(a))
            end
            for k in Base.kwarg_decl(m)
                endswith(String(k), "...") || push!(kw, k)
            end
        end
        return (pos = pos, kw = kw, unnamed = unnamed)
    end

    exported = Set(names(pkg))
    by_export = length(exported) > 1      # a package that exports nothing publishes through its docstrings
    # Every docstring held to one function is read together: a function whose methods are documented in
    # two files shows its keywords across both, and one file's docstring compared alone reported the
    # other file's keywords as shown nowhere. Grouping by the RESOLVED function, not by name, still
    # keeps two modules' namesakes apart.
    groups = Dict{Any,Vector{Tuple{Symbol,String}}}()
    for key in sort!(collect(keys(shown)))
        name, file = key
        (!by_export || name in exported) || continue
        f = resolve(name, file)
        f === nothing && continue
        push!(get!(groups, f, Tuple{Symbol,String}[]), key)
    end
    out = Model.Location[]
    for keys_ in sort!(collect(values(groups)); by = first)
        def = defined_sets(resolve(keys_[1]...))
        def === :extension && continue
        name = keys_[1][1]; node = String(name)
        all_kw = union((shown_kw[k] for k in keys_)...)
        all_pos = union((shown[k] for k in keys_)...)
        # At the docstring that displays the disagreeing argument; a keyword no signature displays is
        # reported at the first docstring of the name. A finding with no file could be neither switched
        # off for that file nor anchored, and sent a fixer nowhere.
        function at(a)
            for (n, file) in keys_
                haskey(arg_in, (n, file, a)) && return (file, arg_in[(n, file, a)])
            end
            return (keys_[1][2], shown_in[keys_[1]])
        end
        for a in sort!(collect(setdiff(all_kw, def.kw)))
            file, line = at(a)
            push!(out, Model.Location(; file, line, node,
                text = "$name: the displayed keyword `$a` matches no defined method"))
        end
        for a in (any(in(elided), keys_) ? Symbol[] : sort!(collect(setdiff(def.kw, all_kw))))
            file, line = keys_[1][2], shown_in[keys_[1]]
            push!(out, Model.Location(; file, line, node,
                text = "$name: the defined keyword `$a` appears in no displayed signature"))
        end
        for a in (def.unnamed ? Symbol[] : sort!(collect(setdiff(all_pos, def.pos, def.kw))))
            file, line = at(a)
            push!(out, Model.Location(; file, line, node,
                text = "$name: the displayed positional `$a` matches no defined argument name"))
        end
    end
    return out
end

const SIGNATURE_FIDELITY = Model.Rule(
    id = Symbol("RULE.DOC.SIGNATURE_FIDELITY"),
    statement = "The signature a docstring displays and the methods the module defines agree, argument for argument.",
    why = "A displayed signature is what a reader calls; one the method table has moved past is a call that fails.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.LOADED_MODULE, signature_fidelity, false),
    examples = [
        Model.ModuleExample("""
            module Example
            export measure
            \"\"\"
                measure(u; tol = 1e-6)

            The mean of `u`, to within `tol`.
            \"\"\"
            measure(u; atol = 1e-6) = sum(u) / length(u)
            end
            """,
            # A renamed keyword disagrees in both directions at once — the shown one no method takes, the
            # taken one no signature shows — and the rule reports what it found, not one summary of it,
            # each at the docstring that displays the signature.
            [Model.Location(; file = "src/Example.jl", line = 3), Model.Location(; file = "src/Example.jl", line = 3)],
            "argument for argument"),
        # The standard form carries a return annotation, and the rule reads through it: a signature
        # written `-> T` is not a lambda to be dropped.
        Model.ModuleExample("""
            module Example
            export measure
            \"\"\"
                measure(u; tol = 1e-6) -> Float64

            The mean of `u`, to within `tol`.
            \"\"\"
            measure(u; atol = 1e-6) = sum(u) / length(u)
            end
            """,
            [Model.Location(; file = "src/Example.jl", line = 3), Model.Location(; file = "src/Example.jl", line = 3)],
            "argument for argument"),
        Model.ModuleExample("""
            module Example
            export measure
            \"\"\"
                measure(u; atol = 1e-6) -> Float64

            The mean of `u`, to within `atol`.
            \"\"\"
            measure(u; atol = 1e-6) = sum(u) / length(u)
            end
            """, Model.Location[], "argument for argument"),
        Model.ModuleExample("""
            module Example
            export measure
            \"\"\"
                measure(u; atol = 1e-6)

            The mean of `u`, to within `atol`.
            \"\"\"
            measure(u; atol = 1e-6) = sum(u) / length(u)
            end
            """, Model.Location[], "argument for argument"),
    ])

"""
    RULES

The rules of this batch.
"""
const RULES = Model.Rule[XLINK, SIGNATURE_FIDELITY]

end # module Modules