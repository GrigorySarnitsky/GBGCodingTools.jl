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

The rubric's constant: a docstring with this many arguments or more, or any keyword, documents them in
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
"""
struct Docstring
    file::String
    line::Int
    body::String
    signature::String
end

const DOC_RE = r"\"\"\"\n(.*?)\n\"\"\""s

"""
    docstrings(root, files) -> Vector{Docstring}

Every `\"\"\"`-delimited docstring in `files` (relative to `root`), in file then source order — the
house form, opening quotes on their own line. Returns the list.
"""
function docstrings(root::AbstractString, files::AbstractVector{<:AbstractString})
    out = Docstring[]
    for f in files
        text = read(joinpath(root, f), String)
        for m in eachmatch(DOC_RE, text)
            body = m.captures[1]
            line = count(==('\n'), SubString(text, 1, prevind(text, m.offset))) + 1
            push!(out, Docstring(String(f), line, String(body), String(strip(first(split(body, '\n'))))))
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

One undocumented argument: `file`, `line`, `signature`, `binding` (the function's name), `parameter`,
and `declared_type` (the annotation text, or `""`).
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

The argument-coverage sweep over the `src` surface, driven FROM THE SIGNATURE: every positional and
keyword parameter of a docstring's displayed signature must appear in its body as a code span, bare or
carrying its default (`` `n` `` or `` `n = 2` ``). The rubric's exemptions are applied, and counted
rather than silently dropped: an internal `_`-prefixed helper; a thin allocating wrapper (the body
carries [`WRAPPER_PHRASE`](@ref)); a docstring with fewer than [`ARGS_THRESHOLD`](@ref) arguments and no
keyword (the prose form, a human read). `exempt(hit)` is the ledger's `[exemption.match]` predicate,
applied per trigger; the trigger population is returned so the doctor can dry-run it. Returns the
hits, the number of parameters examined, and a named tuple of the skipped counts.
"""
function argcov(cfg::AbstractDict; exempt = (hit -> false))
    files = Config.surface_files(cfg, "src")
    hits = ArgcovHit[]; population = 0
    internal = wrappers = prose = 0
    for d in docstrings(cfg["root"], files)
        sig = d.signature
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

The `@ref` targets linked more than once inside one docstring of the `src` surface (the rubric caps a
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

The package's true public surface, derived from OWNERSHIP: every function a module in `modules` owns
at least one method of — a generic the package declares and an extension of an external generic
(`Base.map!`, `Statistics.mean`) alike — plus the umbrella's exported functions. `names()` cannot see
an extension the package does not re-export, and three consumer guards built on it were each blind to
nine public operations. Returns the set of names.
"""
function package_operations(pkg::Module, modules::AbstractVector{Module})
    owned = Set(modules)
    found = Set{Symbol}(n for n in names(pkg) if isdefined(pkg, n) && getfield(pkg, n) isa Function)
    for mod in Base.loaded_modules_array()
        for name in names(mod; all = true, imported = true)
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
    signature_fidelity(cfg; pkg = load_package(cfg)) -> Vector{String}

The displayed signature set of every exported binding against its defined method table: a displayed
keyword no method has (a stale signature), a defined keyword no displayed signature shows
(unadvertised), a displayed positional matching no argument name. The spectral-pair forms
(`f(u)` / `f(û)`) are accent-normalised; a `kwargs...` display suppresses the hidden-keyword direction;
an unnamed dispatch slot suppresses the positional one; a generic whose methods live in an unloaded
extension is reported once as extension-homed. A triage scan: count first, read all. Returns the
messages.
"""
function signature_fidelity(cfg::AbstractDict; pkg::Module = load_package(cfg))
    displayed = Dict{Symbol,Set{Symbol}}(); displayed_kw = Dict{Symbol,Set{Symbol}}(); elided = Set{Symbol}()
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
    end
    for f in Config.surface_files(cfg, "src")
        src = read(joinpath(cfg["root"], f), String)
        for m in eachmatch(r"\"\"\"\n((?:    [^\n]*\n)+)"s, src)
            lines = split(m.captures[1], '\n'; keepempty = false)
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
    function defined_sets(name)
        f = nothing
        for mod in mods
            isdefined(mod, name) && (f = getfield(mod, name); break)
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
    out = String[]
    for name in sort!(collect(keys(displayed)))
        name in exported || continue
        def = defined_sets(name)
        def === nothing && continue
        if def === :extension
            push!(out, "$name: EXTENSION-HOMED (no methods loaded) — skipped"); continue
        end
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

Every docstring's FIRST mention of a name whose DEFINING module differs from the docstring's own,
cited in plain backticks and never `@ref`-linked anywhere in that docstring — the class that is
invisible because an unqualified cross-module `@ref` does not resolve and the author downgrades it to a
bare span. The docstring's own binding names and its own signature arguments are off limits (this
sweep once re-linked two arguments a manual fix had just unlinked). Dry run by default; with
`apply = true` it rewrites each site as `` [`name`](@ref Pkg.Owner.name) ``, back to front. Returns
the sites as `(file, line, name, owner)`.
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
        for dm in eachmatch(DOC_RE, src)
            body = dm.captures[1]; base = dm.offsets[1]
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
