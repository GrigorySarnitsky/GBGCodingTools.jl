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
    for f in get(cfg.filesets, Model.FileSet.CODE, String[])
        path = joinpath(loaded.root, f)
        isfile(path) || continue
        src = read(path, String)
        m = match(r"^\s*(?:bare)?module\s+([A-Za-z_][A-Za-z0-9_]*)"m, src)
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
    ])

# ────────────────────────────────────────── what a docstring shows against what the module defines

dehat(a::Symbol) = Symbol(replace(String(a), "̂" => ""))

"""
    displayed_signatures(root, cfg) -> Tuple

Every signature a docstring displays, as the positional and keyword names it shows per binding, with the
bindings whose signature elides arguments behind a splat. The arguments are `root`, the package root, and
`cfg`, the package's config, which names the files. Returns `(positional, keyword, elided, owners_shown)`.
"""
function displayed_signatures(root::AbstractString, cfg)
    positional = Dict{Symbol,Set{Symbol}}(); keyword = Dict{Symbol,Set{Symbol}}()
    elided = Set{Symbol}(); shown_in = Dict{Symbol,Set{String}}()
    note!(d, name, args) = union!(get!(d, name, Set{Symbol}()), args)
    function harvest!(ex, file)
        ex isa Expr && ex.head === :where && return harvest!(ex.args[1], file)
        (ex isa Expr && ex.head === :call) || return
        name = ex.args[1]; name isa Symbol || return
        pos, kw = Symbol[], Symbol[]
        for a in ex.args[2:end]
            if a isa Expr && a.head === :parameters
                for k in a.args
                    k isa Expr && k.head === :(...) && (push!(elided, name); continue)
                    k isa Expr && k.head === :kw && (k = k.args[1])
                    k isa Expr && k.head === :(::) && (k = k.args[1])
                    k isa Symbol && push!(kw, k)
                end
            else
                a isa Expr && a.head === :(...) && (push!(elided, name); continue)
                a isa Expr && a.head === :kw && (a = a.args[1])
                a isa Expr && a.head === :(::) && (a = a.args[1])
                a isa Symbol && push!(pos, a)
            end
        end
        note!(positional, name, dehat.(pos)); note!(keyword, name, kw)
        push!(get!(shown_in, name, Set{String}()), file)
    end
    for f in get(cfg.filesets, Model.FileSet.CODE, String[])
        path = joinpath(root, f)
        isfile(path) || continue
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
                ex = try Meta.parse(replace(signature, r"\s*->.*\$" => "")) catch; nothing end
                ex === nothing || harvest!(ex, f)
            end
        end
    end
    return (positional, keyword, elided, shown_in)
end

"""
    signature_fidelity(loaded, cfg) -> Vector{Model.Location}

Every displayed signature that no longer matches the method table: a keyword shown that no method takes,
a keyword taken that no signature shows, and a positional name shown that matches no defined argument.
The arguments are `loaded`, the loaded package with the package root, and `cfg`, the package's config.
Returns one location per disagreement.

A name two modules own is skipped rather than compared: the union of two functions' signatures is
nobody's. A binding whose methods live in an extension that is not loaded is skipped too, and said to be.
"""
function signature_fidelity(loaded, cfg)
    pkg, root = loaded.pkg, loaded.root
    shown, shown_kw, elided, _ = displayed_signatures(root, cfg)
    mods = Module[pkg]
    for n in names(pkg; all = true)
        isdefined(pkg, n) || continue
        v = getfield(pkg, n)
        v isa Module && v !== pkg && push!(mods, v)
    end
    # A module with no package directory — one an example loaded into memory — has methods whose file is
    # not a path at all, so the filter that keeps a package's own methods would reject every one of them.
    home = pkgdir(pkg)
    pkgroot = something(home, root)
    every_method = home === nothing
    owners_of(name) = [m for m in mods if isdefined(m, name) && Base.which(m, name) === m]
    function defined_sets(name)
        f = nothing
        for m in mods
            isdefined(m, name) && Base.which(m, name) === m && (f = getfield(m, name); break)
        end
        f === nothing && for m in mods
            isdefined(m, name) && (f = getfield(m, name); break)
        end
        (f isa Function || f isa Type) || return nothing
        f isa Function && isempty(methods(f)) && return :extension
        pos, kw = Set{Symbol}(), Set{Symbol}(); unnamed = false
        for m in methods(f)
            file = String(m.file)
            (every_method || startswith(file, pkgroot) || occursin(cfg.package, file)) || continue
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
    out = Model.Location[]
    for name in sort!(collect(keys(shown)))
        (!by_export || name in exported) || continue
        length(owners_of(name)) > 1 && continue
        def = defined_sets(name)
        def === nothing && continue
        def === :extension && continue
        for a in setdiff(shown_kw[name], def.kw)
            push!(out, Model.Location(; file = "", line = 0,
                text = "$name: the displayed keyword `$a` matches no defined method"))
        end
        for a in (name in elided ? Symbol[] : collect(setdiff(def.kw, shown_kw[name])))
            push!(out, Model.Location(; file = "", line = 0,
                text = "$name: the defined keyword `$a` appears in no displayed signature"))
        end
        for a in (def.unnamed ? Symbol[] : collect(setdiff(shown[name], def.pos, def.kw)))
            push!(out, Model.Location(; file = "", line = 0,
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
            # taken one no signature shows — and the rule reports what it found, not one summary of it.
            [Model.Location(; file = "", line = 0), Model.Location(; file = "", line = 0)],
            "argument for argument"),
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