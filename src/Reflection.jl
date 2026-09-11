# Reflection.jl — the four reflection scans and the public-surface derivation. Sources: PF
# check-docs/argcov.jl (the exemption classes, the semicolon-first splitter), IT check-docs/argcov.jl
# (the Greek identifier class, the `arg = default` form), IT signature_fidelity.jl, IT xlink.jl,
# IT dupref.jl, PF test/public_surface.jl (`package_operations`, the ownership-derived route).

"""
    Reflection

The engines of `/check-docs` that reason about a package's docstrings against its code: argument
coverage ([`Reflection.argcov`](@ref)), the displayed-versus-defined signature table
([`Reflection.signature_fidelity`](@ref)), unlinked cross-module first mentions
([`Reflection.xlink`](@ref)), a target linked twice in one docstring ([`Reflection.dupref`](@ref)),
and the ownership-derived public surface ([`Reflection.package_operations`](@ref)) every
completeness guard covers. The text scans need no loaded package; the two reflective ones load it.
"""
module Reflection

import ..GBGCodingTools
import ..GBGCodingTools: Config

export argcov, signature_fidelity, xlink, dupref, package_operations

"""
    ARGS_THRESHOLD

The docstring rubric's constant (the `RULE.DOC.*` rules of the shared policy): a docstring with this
many arguments or more, or any keyword, documents them in
the bulleted `The arguments are:` form; fewer are bound in prose. Not a config key.
"""
const ARGS_THRESHOLD = 3

"""
    WRAPPER_PHRASE

The rubric's spelling of a thin allocating wrapper — a docstring carrying it documents no arguments,
`@ref`-linking its home instead — which is what makes the exemption detectable rather than a judgement.
"""
const WRAPPER_PHRASE = "Allocating form of"

"""
    Docstring

One docstring found in a source file.

The fields are:

- `file` — the path relative to the consumer root.
- `line` — the 1-based line of the opening `\"\"\"`.
- `body` — the text between the quotes.
- `signature` — the first line of the body, stripped (the displayed signature when there is one).
- `offset` — the byte offset of the body's first character in the file.
"""
struct Docstring
    file::String
    line::Int
    body::String
    signature::String
    offset::Int
end


"""
    docstrings(root, files) -> Vector{Docstring}

Every `\"\"\"`-delimited docstring in `files` (relative to `root`), in file then source order — the
house form, opening quotes on their own line. Returns the list.
"""
function docstrings(root::AbstractString, files::AbstractVector{<:AbstractString})
    out = Docstring[]
    for f in files
        text = read(joinpath(root, f), String)
        lines = split(text, '\n')
        offset = 1; i = 1; n = length(lines)
        # the engine's rule: a docstring opens at a line holding the three quotes alone; a triple-quoted
        # code literal opens mid-line and is skipped to its close, so a closer at line start pairs with nothing
        while i <= n
            l = lines[i]; c = count("\"\"\"", l)
            if strip(l) == "\"\"\""
                j = i + 1
                while j <= n && count("\"\"\"", lines[j]) == 0; j += 1; end
                if j <= n
                    body = join(lines[i+1:j-1], "\n")
                    push!(out, Docstring(String(f), i, body, String(strip(first(split(body, '\n')))), offset + ncodeunits(l) + 1))
                    for k in i:j; offset += ncodeunits(lines[k]) + 1; end
                    i = j + 1; continue
                end
            elseif isodd(c)
                j = i + 1
                while j <= n && count("\"\"\"", lines[j]) == 0; j += 1; end
                for k in i:min(j, n); offset += ncodeunits(lines[k]) + 1; end
                i = j + 1; continue
            end
            offset += ncodeunits(l) + 1; i += 1
        end
    end
    return out
end

const IDENT = r"^[A-Za-zα-ωΑ-Ω_][A-Za-z0-9_!α-ωΑ-Ω̂]*$"

"""
    signature_parameters(inside) -> (positional, keyword)

Splits the text between a signature's parentheses into parameter names: the `;` is split FIRST, once,
and each side then on commas (splitting on commas first discarded the last positional of every
keyword-carrying signature, silently, in both consumers). Type annotations and defaults are dropped;
Greek and hatted identifiers count. Returns the two name lists.
"""
function signature_parameters(inside::AbstractString)
    semi = findfirst(';', inside)
    positional = semi === nothing ? inside : inside[1:prevind(inside, semi)]
    keywords = semi === nothing ? "" : inside[nextind(inside, semi):end]
    clean(raw) = String(strip(split(split(raw, "::")[1], "=")[1]))
    pos = [clean(r) for r in split(positional, ',') if occursin(IDENT, clean(r))]
    kw = [clean(r) for r in split(keywords, ',') if occursin(IDENT, clean(r))]
    return (pos, kw)
end

"""
    signature_types(inside) -> Dict{String,String}

The declared type text of every parameter that carries one (`n::Integer` → `"n" => "Integer"`).
Returns the map.
"""
function signature_types(inside::AbstractString)
    types = Dict{String,String}()
    for raw in split(replace(inside, ';' => ','), ',')
        parts = split(split(raw, "=")[1], "::")
        length(parts) == 2 && (types[String(strip(parts[1]))] = String(strip(parts[2])))
    end
    return types
end

"""
    ArgcovHit

One undocumented argument found by [`argcov`](@ref). The fields are:

- `file` — the source file, relative to the root.
- `line` — the docstring's opening line.
- `signature` — the docstring's signature line.
- `binding` — the documented binding's name.
- `parameter` — the undocumented parameter.
- `declared_type` — its declared type in the signature, or empty.
"""
struct ArgcovHit
    file::String
    line::Int
    signature::String
    binding::String
    parameter::String
    declared_type::String
end

"""
    argcov(cfg; exempt = (hit -> false)) -> (hits, population, skipped)

The argument-coverage sweep over the `src` surface of the config `cfg`, driven FROM THE SIGNATURE:
every positional and keyword parameter of a docstring's displayed signature must appear in its body as
a code span, bare (`n`) or carrying its default (`n = 2`).

The arguments are:

- `cfg` — the validated config, whose `src` surface names the files swept.
- `exempt` — the [`GBGCodingTools.Ledger`](@ref)'s `[exemption.match]` predicate, called per trigger as
  `exempt(hit)`; the trigger population is returned so the doctor can dry-run it.

The rubric's exemptions are applied, and counted rather than silently dropped: an internal `_`-prefixed
helper; a thin allocating wrapper (the body carries [`WRAPPER_PHRASE`](@ref)); a docstring with fewer
than [`ARGS_THRESHOLD`](@ref) arguments and no keyword (the prose form, a human read).

Returns the hits, the number of parameters examined, and a named tuple of the skipped counts.
"""
function argcov(cfg::AbstractDict; exempt = (hit -> false))
    files = Config.surface_files(cfg, "src")
    hits = ArgcovHit[]; population = 0
    internal = wrappers = prose = 0
    for d in docstrings(cfg["root"], files)
        sig = replace(d.signature, r"\s*->.*$" => "")          # the return annotation is not a parameter list
        (occursin('(', sig) && occursin(')', sig)) || continue
        o = findfirst('(', sig); c = findlast(')', sig)
        inside = sig[nextind(sig, o):prevind(sig, c)]
        binding = String(strip(sig[1:prevind(sig, o)]))
        if startswith(binding, "_")
            internal += 1; continue
        elseif occursin(WRAPPER_PHRASE, d.body)
            wrappers += 1; continue
        end
        pos, kw = signature_parameters(inside)
        if length(pos) + length(kw) < ARGS_THRESHOLD && isempty(kw)
            prose += 1; continue
        end
        types = signature_types(inside)
        for p in vcat(pos, kw)
            population += 1
            q = "\\Q" * p * "\\E"
            documented = occursin(Regex("`" * q * "`"), d.body) || occursin(Regex("`" * q * "\\s*=[^`]*`"), d.body)
            documented && continue
            hit = ArgcovHit(d.file, d.line, sig, binding, p, get(types, p, ""))
            exempt(hit) || push!(hits, hit)
        end
    end
    return (hits, population, (internal = internal, wrappers = wrappers, prose = prose))
end

"""
    dupref(cfg) -> Vector

The `@ref` targets linked more than once inside one docstring of the `src` surface (the docstring rubric caps a
target at its first genuine mention; invisible in the rendered text). Returns named tuples
`(file, line, target, count, signature)`.
"""
function dupref(cfg::AbstractDict)
    out = NamedTuple[]
    for d in docstrings(cfg["root"], Config.surface_files(cfg, "src"))
        targets = [String(m.captures[1]) for m in eachmatch(r"\[`([^`]+)`\]\(@ref[^)]*\)", d.body)]
        for t in unique(targets)
            n = count(==(t), targets)
            n > 1 && push!(out, (file = d.file, line = d.line, target = t, count = n, signature = first(d.signature, 46)))
        end
    end
    return out
end

"""
    load_package(cfg) -> Module

Loads the consumer package named in the config into the running session (`Base.require`), as the
reflection scans need it. Returns the module; throws when the active environment cannot load it — the
caller reports exit 2, cannot evaluate.
"""
function load_package(cfg::AbstractDict)
    name = Symbol(cfg["package"]["name"])
    return Base.require(Main, name)
end

"""
    package_modules(pkg, cfg) -> Vector{Module}

The submodules the config names under `package.modules`, resolved inside `pkg` (a name that does not
resolve to a module is skipped — `CFG.SURFACES` reports it). Returns the list, the umbrella first.
"""
function package_modules(pkg::Module, cfg::AbstractDict)
    mods = Module[pkg]
    for m in cfg["package"]["modules"]
        s = Symbol(m)
        if isdefined(pkg, s)
            v = getfield(pkg, s)
            v isa Module && v !== pkg && push!(mods, v)
        end
    end
    return mods
end

"""
    package_operations(pkg, modules) -> Set{Symbol}

The derived public surface: every exported function of the umbrella `pkg` and of its owned `modules`,
plus every external generic a package module extends (found by walking the loaded modules and asking
each function whether a package module owns one of its methods — a method defined under a qualified
name creates no binding, so a namespace scan cannot see it). Internal helpers and closures never
enter it. The arguments are `pkg`, the umbrella module, and `modules`, the owned modules. Returns the
names.
"""
function package_operations(pkg::Module, modules::AbstractVector{Module})
    owned = Set(vcat(modules, [pkg]))
    found = Set{Symbol}()
    # the package's own public surface: the exported (public) names of the umbrella and of every owned
    # module that are functions — internals and closures never enter it
    for mod in owned, n in names(mod)
        isdefined(mod, n) || continue
        f = try getfield(mod, n) catch; continue end
        f isa Function && !startswith(String(n), "#") && push!(found, n)
    end
    # plus every EXTERNAL generic the package extends: a method defined under a qualified name
    # (`Base.show(io, ::T) = …`) creates no binding in the package, so the loaded modules are walked and
    # each function asked whether a package module owns one of its methods
    for mod in Base.loaded_modules_array()
        mod in owned && continue
        for name in names(mod; all = true, imported = true)
            startswith(String(name), "#") && continue
            isdefined(mod, name) || continue
            f = try getfield(mod, name) catch; continue end
            f isa Function || continue
            nameof(f) === :kwcall && continue
            any(m -> m.module in owned, methods(f)) && push!(found, nameof(f))
        end
    end
    return found
end

"""
    all_package_functions(pkg, modules) -> Set{Symbol}

Every function name a package module owns methods of, internal helpers included — the wider set a
guard's own bookkeeping may name. Returns the set.
"""
function all_package_functions(pkg::Module, modules::AbstractVector{Module})
    owned = Set(modules)
    found = Set{Symbol}()
    for mod in modules, name in names(mod; all = true, imported = true)
        isdefined(mod, name) || continue
        f = getfield(mod, name)
        f isa Function || continue
        any(m -> m.module in owned, methods(f)) && push!(found, name)
    end
    return union(found, package_operations(pkg, modules))
end

dehat(s::Symbol) = Symbol(replace(Base.Unicode.normalize(String(s), :NFD), r"[̂̄̇]" => ""))

"""
    signature_fidelity(cfg; pkg = load_package(cfg), examined = nothing) -> Vector{String}

Per exported binding, the displayed docstring signatures against the defined method table (positional
names accent-normalised, keywords by name): a displayed keyword no method defines (a stale
signature), a defined keyword no signature advertises, a displayed positional matching no argument
name. The arguments are:

- `cfg` — the validated config.
- `pkg` — the loaded package, loaded from the config when not given.
- `examined` — an optional counter the caller passes to learn how many bindings were actually
  compared, which is the scan's population: a package that exports nothing compares nothing, and a
  scan that measured nothing must say so rather than print clean.

Returns one message per discrepancy; an extension-homed binding with no methods loaded is reported as
skipped.
"""
function signature_fidelity(cfg::AbstractDict; pkg::Module = load_package(cfg), examined::Union{Nothing,Base.RefValue{Int}} = nothing)
    displayed = Dict{Symbol,Set{Symbol}}(); displayed_kw = Dict{Symbol,Set{Symbol}}(); elided = Set{Symbol}()
    shown_in = Dict{Symbol,Set{String}}(); curfile = Ref("")     # which file displayed each name
    note!(dict, name, args) = union!(get!(dict, name, Set{Symbol}()), args)
    function harvest!(ex)
        ex isa Expr && ex.head === :where && return harvest!(ex.args[1])
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
        note!(displayed, name, dehat.(pos)); note!(displayed_kw, name, kw)
        push!(get!(shown_in, name, Set{String}()), curfile[])
    end
    for f in Config.surface_files(cfg, "src")
        curfile[] = f
        for d in docstrings(cfg["root"], [f])
            header = collect(Iterators.takewhile(l -> startswith(l, "    "), split(d.body, '\n')))
            isempty(header) && continue
            lines = header
            joined, cur = String[], ""
            for ln in lines
                cur *= strip(ln) * " "
                if count('(', cur) == count(')', cur) && !isempty(strip(cur))
                    push!(joined, strip(cur)); cur = ""
                end
            end
            for sig in joined
                sig = replace(sig, r"\s*->.*$" => "")
                ex = try Meta.parse(sig) catch; nothing end
                ex === nothing || harvest!(ex)
            end
        end
    end
    mods = package_modules(pkg, cfg)
    pkgroot = pkgdir(pkg)
    owners_of(name) = [mod for mod in mods if isdefined(mod, name) && Base.which(mod, name) === mod]
    function defined_sets(name)
        f = nothing
        # the module that OWNS the binding, not merely the first that can see it: every module can see
        # `Base.close`, and taking that one made every `close` argument look undefined (2026-09-09)
        for mod in mods
            isdefined(mod, name) && Base.which(mod, name) === mod && (f = getfield(mod, name); break)
        end
        if f === nothing
            for mod in mods
                isdefined(mod, name) && (f = getfield(mod, name); break)
            end
        end
        (f isa Function || f isa Type) || return nothing
        if f isa Function && isempty(methods(f))
            return :extension
        end
        pos, kw = Set{Symbol}(), Set{Symbol}(); unnamed = false
        for m in methods(f)
            file = String(m.file)
            (startswith(file, pkgroot) || occursin(cfg["package"]["name"], file)) || continue
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
    # A package that exports nothing at top level publishes through its DOCUMENTED surface instead (the
    # tool is such a package: explicit `@docs` blocks, no `export`). Filtering on `names(pkg)` then leaves
    # nothing to compare, and the scan printed clean over 74 files having examined zero bindings.
    by_export = length(exported) > 1
    out = String[]
    for name in sort!(collect(keys(displayed)))
        (!by_export || name in exported) || continue
        # a name OWNED by two modules is two different functions sharing a bare name (`render` in Sync and
        # in Rounds): the union of their displayed signatures is nobody's, so it is skipped, not compared.
        # One owner documented in two files is one function documented twice, which is what this compares.
        length(owners_of(name)) > 1 && continue
        def = defined_sets(name)
        def === nothing && continue
        if def === :extension
            push!(out, "$name: EXTENSION-HOMED (no methods loaded) — skipped"); continue
        end
        examined === nothing || (examined[] += 1)                 # what was COMPARED: the scan's population
        for a in setdiff(displayed_kw[name], def.kw)
            push!(out, "$name: displayed keyword `$a` matches NO defined method (stale signature?)")
        end
        for a in (name in elided ? Symbol[] : collect(setdiff(def.kw, displayed_kw[name])))
            push!(out, "$name: defined keyword `$a` appears in NO displayed signature (unadvertised)")
        end
        for a in (def.unnamed ? Symbol[] : collect(setdiff(displayed[name], def.pos, def.kw)))
            push!(out, "$name: displayed positional `$a` matches no defined argument name")
        end
    end
    return out
end

"""
    xlink(cfg; pkg = load_package(cfg), apply = false) -> Vector

Every bare mention of a public name owned by ANOTHER package module inside a docstring (the first
mention, outside the signature and the arguments), as `(file, line, name, owner)`. The arguments are:

- `cfg` — the validated config.
- `pkg` — the loaded package (loaded from the config when not given).
- `apply` — rewrite each site to a qualified `@ref` link in place; default false, a dry run.

Returns the sites.
"""
function xlink(cfg::AbstractDict; pkg::Module = load_package(cfg), apply::Bool = false)
    mods = package_modules(pkg, cfg)
    modnames = Set(nameof.(mods))
    owners = Dict{String,Symbol}()
    for mod in mods, n in names(mod)
        s = String(n)
        s == String(nameof(mod)) && continue
        isdefined(mod, n) || continue
        v = getfield(mod, n)
        pm = (v isa Function || v isa Type) ? nameof(parentmodule(v)) : nameof(mod)
        owners[s] = pm in modnames ? pm : nameof(mod)
    end
    # which module each source file is: the file whose text declares `module <Name>`
    sites = NamedTuple[]
    for f in Config.surface_files(cfg, "src")
        path = joinpath(cfg["root"], f)
        src = read(path, String)
        mm = match(r"^\s*(?:bare)?module\s+([A-Za-z_][A-Za-z0-9_]*)"m, src)
        mm === nothing && continue
        me = Symbol(mm.captures[1])
        edits = Tuple{Int,Int,String,Symbol}[]
        for d in docstrings(cfg["root"], [f])
            body = d.body; base = d.offset
            lines = split(body, "\n")
            se = something(findfirst(l -> !startswith(l, "    ") && !isempty(strip(l)), lines), 1)
            sighead = join(lines[1:se-1], "\n")
            prose_start = base + (isempty(sighead) ? 0 : ncodeunits(sighead) + 1)
            prose = join(lines[se:end], "\n")
            own = Set(String.(x.captures[1] for x in eachmatch(r"([A-Za-z_][A-Za-z0-9_!]*)\(", sighead)))
            for am in eachmatch(r"\(([^)]*)\)", sighead)
                for raw in split(am.captures[1], ",")
                    a = strip(split(split(split(raw, "::")[1], "=")[1], ";")[end])
                    isempty(a) || push!(own, String(a))
                end
            end
            linked = Set(String.(x.captures[1] for x in eachmatch(r"\[`([^`]+)`\]\(@", prose)))
            seen = Set{String}()
            for x in eachmatch(r"`([A-Za-z_][A-Za-z0-9_!]*)`", prose)
                p = String(x.captures[1])
                (haskey(owners, p) && !(p in own) && !(p in linked) && !(p in seen)) || continue
                push!(seen, p)
                owners[p] == me && continue
                s0 = prose_start + x.offset - 1
                push!(edits, (s0, s0 + ncodeunits(p) + 1, p, owners[p]))
                line = count(==('\n'), SubString(src, 1, prevind(src, s0))) + 1
                push!(sites, (file = f, line = line, name = p, owner = owners[p]))
            end
        end
        if apply && !isempty(edits)
            sort!(edits; by = first, rev = true)
            for (s0, s1, p, ow) in edits
                src = src[1:prevind(src, s0)] * "[`" * p * "`](@ref " * cfg["package"]["name"] * "." * String(ow) * "." * p * ")" * src[nextind(src, s1):end]
            end
            write(path, src)
        end
    end
    return sites
end

end # module Reflection
