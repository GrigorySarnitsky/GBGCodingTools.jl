# TestHarness.jl — the Julia test engines a consumer's suite calls. Sources: PF test/allocations.jl
# (@alloc_below, the derived completeness check), PF test/pass_audit.jl (CountingArray/Traffic/audit),
# PF test/method_parity.jl (the enumerated and derived baselines), PF test/oracle_registry.jl, PF
# test/display.jl + IT test/display.jl (the UnionAll clause), PF test/threading.jl (the cross-`-t`
# subprocess digest), PF test/runtests.jl (run_regressions). Frozen tables stay in the consumer as TOML.

"""
    TestHarness

The engines behind a consumer's `test/`: the allocation audit ([`@alloc_below`](@ref),
[`TestHarness.allocation_completeness`](@ref) and the operations it covers,
[`TestHarness.AUDITED_ALLOCATION_OPS`](@ref)), the element-traffic audit
([`TestHarness.counting`](@ref), [`TestHarness.CountingArray`](@ref), [`TestHarness.Traffic`](@ref),
[`TestHarness.audit`](@ref), [`TestHarness.traffic_completeness`](@ref) and the operations it covers,
[`TestHarness.AUDITED_TRAFFIC_OPS`](@ref)), the
method-parity baselines ([`TestHarness.method_parity`](@ref)), the oracle registry
([`TestHarness.oracle_registry`](@ref)), the display gate ([`TestHarness.display_gate`](@ref)), the
cross-thread-count digest ([`TestHarness.thread_digest`](@ref)), seed parity across backends
([`TestHarness.seed_parity`](@ref)), the promoted-witness loop
([`TestHarness.run_regressions`](@ref)). The tables a package freezes live in the consumer as TOML.
"""
module TestHarness

using Test, TOML
import ..GBGCodingTools

export @alloc_below, CountingArray, Traffic, counting, audit, run_regressions

# ────────────────────────────────────────────── the public surface, derived from the loaded package

"""
    package_operations(pkg, modules) -> Set{Symbol}

The derived public surface: every exported function of the umbrella `pkg` and of its owned `modules`,
plus every external generic a package module extends (found by walking the loaded modules and asking
each function whether a package module owns one of its methods — a method defined under a qualified
name creates no binding, so a namespace scan cannot see it). Internal helpers and closures never
enter it. The arguments are `pkg`, the umbrella module, and `modules`, the owned modules. Returns the
names. Harvested from `Reflection.jl` in Phase 5; the completeness checks below derive their
required sets from it, so a new operation fails them until it is audited.
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
    # (`Base.show(io, ::T) = …`) creates no binding in the package, so the loaded modules are walked —
    # their submodules too, since `Base.Broadcast.broadcasted` is as much a generic as `Base.show` and
    # was missed (found in review, 2026-09-26) — and each function asked whether a package module owns
    # one of its methods
    for mod in with_submodules(Base.loaded_modules_array())
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

# The modules and every module defined inside one of them, each once; a module reached by a binding
# whose parent is another is that other's and is not walked twice.
function with_submodules(roots)
    out = Module[]; seen = Set{Module}()
    visit(m) = begin
        m in seen && return
        push!(seen, m); push!(out, m)
        for n in names(m; all = true)
            isdefined(m, n) || continue
            v = try getfield(m, n) catch; continue end
            v isa Module && v !== m && parentmodule(v) === m && visit(v)
        end
    end
    foreach(visit, roots)
    return out
end

"""
    all_package_functions(pkg, modules) -> Set{Symbol}

Every function name a package module owns methods of, the umbrella's own and internal helpers included
— the wider set a guard's own bookkeeping may name. Returns the set.
"""
function all_package_functions(pkg::Module, modules::AbstractVector{Module})
    owned = Set(vcat(modules, [pkg]))
    found = Set{Symbol}()
    for mod in owned, name in names(mod; all = true, imported = true)
        # A compiler-generated binding (`#809#val`, a closure's or a keyword sorter's) is no function
        # of the package's. Julia 1.13 lists far more of them than 1.12, and they own methods in the
        # module, so a count frozen on one version was wrong on the other: GBGPeriodicFields' `Fields`
        # module read 189 methods on 1.12 and 313 on 1.13 (reported by PF, 2026-09-28).
        startswith(String(name), "#") && continue
        isdefined(mod, name) || continue
        f = getfield(mod, name)
        f isa Function || continue
        any(m -> m.module in owned, methods(f)) && push!(found, name)
    end
    return union(found, package_operations(pkg, modules))
end

# ─────────────────────────────────────────────────────────────────────── allocation audit

"""
    AUDITED_ALLOCATION_OPS

The operations [`@alloc_below`](@ref) has exercised in this process, recorded from the callee of each
audited call so [`allocation_completeness`](@ref) can be DERIVED from the export list rather than
trusted to memory.
"""
const AUDITED_ALLOCATION_OPS = Set{Symbol}()

"""
    @alloc_below bound expr

Warms `expr` up once (compilation, plans, first touch), then asserts a single call allocates strictly
fewer than `bound` bytes. A thrown error becomes a failed test rather than aborting the testset, so one
bad line cannot mask every check after it. The callee of `expr` (when it is a plain call) is recorded
in [`AUDITED_ALLOCATION_OPS`](@ref). Splice a NAMED function rather than an anonymous closure: the
expression is evaluated twice and an anonymous closure would get two types, the second read as a
compile allocation.
"""
macro alloc_below(bound, expr)
    callee = (expr isa Expr && expr.head === :call && expr.args[1] isa Symbol) ? expr.args[1] : nothing
    record = callee === nothing ? :() : :(push!($TestHarness.AUDITED_ALLOCATION_OPS, $(QuoteNode(callee))))
    quote
        $record
        local limit = $(esc(bound))
        try
            $(esc(expr))
            @test (@allocated $(esc(expr))) < limit
        catch err
            @error "alloc check threw (likely a test-side signature error, not an allocation)" exception = (err, catch_backtrace())
            @test false
        end
    end
end

"""
    field_threshold(field_bytes; fraction = 16, per_thread = 4096,
                    components = 1) -> Int

The allocation bound for a field-destination operation.

# Arguments

- `field_bytes` — the size of one field in bytes.
- `fraction` — the bound admits `field_bytes ÷ fraction` bytes of small temporaries (any field-sized
  temporary fails).
- `per_thread` — the size-independent per-task bookkeeping a threaded path pays, per Julia thread.
- `components` — the number of contiguous components an operation transforms (FFTW's worker callback
  allocates task state per plan execution, one execution per component).

Returns the bound in bytes.
"""
field_threshold(field_bytes::Integer; fraction::Integer = 16, per_thread::Integer = 4096, components::Integer = 1) =
    field_bytes ÷ fraction + per_thread * Threads.nthreads() * components

"""
    allocation_completeness(pkg, modules; exempt = Dict{Symbol,String}())

The derived completeness check of the allocation audit.

# Arguments

- `pkg` — the package module.
- `modules` — its owned modules (the public surface is derived from them).
- `exempt` — operation name to reason, for the operations deliberately not audited.

Every exported in-place operation (a name ending in `!` on the ownership-derived public surface) was
exercised by [`@alloc_below`](@ref), or is named in `exempt` with a reason; no exemption names a
vanished operation; every recorded callee is a real package function. Runs as a `@testset`. Returns
`nothing`.
"""
function allocation_completeness(pkg::Module, modules::AbstractVector{Module}; exempt::AbstractDict = Dict{Symbol,String}())
    @testset "every exported in-place operation has an allocation row" begin
        required = Set(n for n in package_operations(pkg, modules) if endswith(String(n), "!"))
        uncovered = setdiff(required, AUDITED_ALLOCATION_OPS, keys(exempt))
        isempty(uncovered) || @error "in-place operations with no allocation row — add one, or exempt it with a reason" uncovered
        @test isempty(uncovered)
        @test isempty(setdiff(keys(exempt), required))
        phantoms = setdiff(AUDITED_ALLOCATION_OPS, all_package_functions(pkg, modules))
        isempty(phantoms) || @error "audited names that match no real function" phantoms
        @test isempty(phantoms)
    end
    return nothing
end

# ─────────────────────────────────────────────────────────────────────── element-traffic audit

"""
    CountingArray{T,N} <: AbstractArray{T,N}

A plain `Array` wrapper counting every `getindex` and `setindex!` with atomic counters, so an
operation's element traffic can be measured through generic `AbstractArray` storage. A consumer using
KernelAbstractions defines `KernelAbstractions.get_backend(a::CountingArray) = get_backend(a.data)`
itself (the tool does not depend on it).

# Fields

- `data` — the wrapped array.
- `reads` — the atomic read counter.
- `writes` — the atomic write counter.
"""
struct CountingArray{T,N} <: AbstractArray{T,N}
    data::Array{T,N}
    reads::Threads.Atomic{Int}
    writes::Threads.Atomic{Int}
end

"""
    counting(data) -> CountingArray

Wraps `data` with zeroed counters. Returns the wrapper.
"""
counting(data::Array) = CountingArray(data, Threads.Atomic{Int}(0), Threads.Atomic{Int}(0))

Base.size(a::CountingArray) = size(a.data)
Base.IndexStyle(::Type{<:CountingArray}) = IndexLinear()
Base.parent(a::CountingArray) = a.data
Base.@propagate_inbounds function Base.getindex(a::CountingArray, i::Int)
    Threads.atomic_add!(a.reads, 1)
    return a.data[i]
end
Base.@propagate_inbounds function Base.setindex!(a::CountingArray, value, i::Int)
    Threads.atomic_add!(a.writes, 1)
    a.data[i] = value
    return a
end

"""
    Traffic

One array's row in an audited call.

# Fields

- `role` — the array's role in the call (`"source"`, `"dest"`, `"kernel"`).
- `array` — the [`CountingArray`](@ref) measured.
- `frozen` — the `(reads, writes)` asserted exactly.
- `ideal` — the fused ideal documented beside it (each needed input element read once, each output
  written once).
- `holder` — the named holder REQUIRED when the two differ.
"""
struct Traffic
    role::String
    array::CountingArray
    frozen::NTuple{2,Int}
    ideal::NTuple{2,Int}
    holder::String
end
Traffic(role, array, frozen) = Traffic(role, array, frozen, frozen, "")

"""
    AUDITED_TRAFFIC_OPS

The operations [`audit`](@ref) has measured, taken from the leading token of each row name.
"""
const AUDITED_TRAFFIC_OPS = Set{Symbol}()

"""
    audit(operation!, name, rows...; print = false)

One row of the traffic audit (the per-operation table of array reads and writes).

# Arguments

- `operation!` — a zero-argument closure running the operation once over the counting arrays.
- `name` — the row's name; its leading token, up to whitespace, `(` or `∘`, is the operation recorded
  in [`AUDITED_TRAFFIC_OPS`](@ref).
- `rows` — one [`Traffic`](@ref) per array with its frozen `(reads, writes)`.
- `print` — print every measured count for re-baselining.

It zeroes the counters of every row, runs the operation, and asserts for every row that the measured
pair equals the frozen pair exactly; a frozen count differing from its ideal must carry a named holder. Returns
`nothing`.
"""
function audit(operation!, name::AbstractString, rows::Traffic...; print::Bool = false)
    token = match(r"^[^\s(∘]+", name)
    token === nothing && error("the row name $(repr(name)) opens with no operation token")
    push!(AUDITED_TRAFFIC_OPS, Symbol(token.match))
    foreach(r -> (r.array.reads[] = 0; r.array.writes[] = 0), rows)
    operation!()
    @testset "$name" begin
        for r in rows
            measured = (r.array.reads[], r.array.writes[])
            print && println(rpad(name, 52), rpad(r.role, 14), "measured ", measured, "  frozen ", r.frozen, "  ideal ", r.ideal)
            @test measured == r.frozen
            r.frozen != r.ideal && @test !isempty(r.holder)
        end
    end
    return nothing
end

"""
    traffic_completeness(pkg, modules; exempt = Dict{Symbol,String}())

The derived completeness check of the traffic audit, the twin of [`allocation_completeness`](@ref)
over [`AUDITED_TRAFFIC_OPS`](@ref).

# Arguments

- `pkg` — the package module.
- `modules` — its owned modules.
- `exempt` — operation name to reason, for the operations deliberately not audited.

Runs as a `@testset`. Returns `nothing`.
"""
function traffic_completeness(pkg::Module, modules::AbstractVector{Module}; exempt::AbstractDict = Dict{Symbol,String}())
    @testset "every exported in-place operation has a traffic row" begin
        required = Set(n for n in package_operations(pkg, modules) if endswith(String(n), "!"))
        uncovered = setdiff(required, AUDITED_TRAFFIC_OPS, keys(exempt))
        isempty(uncovered) || @error "in-place operations with no traffic row — add one, or exempt it with a reason" uncovered
        @test isempty(uncovered)
        @test isempty(setdiff(keys(exempt), required))
        phantoms = setdiff(AUDITED_TRAFFIC_OPS, all_package_functions(pkg, modules))
        isempty(phantoms) || @error "row labels that parse to no real operation — fix the label" phantoms
        @test isempty(phantoms)
    end
    return nothing
end

"""
    count_expression(text, symbols) -> Int

Evaluates a frozen count written symbolically in a baseline TOML — `"3P"`, `"2M"`, `"0"`,
`"3 * stencil * number_of_points"` — over the integer `symbols` the test defines (`P`, `M`, …). A
coefficient glued to a symbol (`3P`) is a product. Returns the integer; an unknown symbol is an error.
"""
function count_expression(text::AbstractString, symbols::AbstractDict{String,Int})
    s = replace(strip(text), r"(\d)([A-Za-z_])" => s"\1*\2")
    ex = Meta.parse(s)
    return Int(_eval_count(ex, symbols))
end
_eval_count(x::Integer, _) = x
_eval_count(s::Symbol, symbols) = haskey(symbols, String(s)) ? symbols[String(s)] : error("unknown count symbol `$s`")
function _eval_count(ex::Expr, symbols)
    ex.head === :call || error("unsupported count expression $ex")
    op = ex.args[1]; vals = [_eval_count(a, symbols) for a in ex.args[2:end]]
    op === :* && return prod(vals)
    op === :+ && return sum(vals)
    op === :- && return length(vals) == 1 ? -vals[1] : vals[1] - vals[2]
    op === :÷ && return vals[1] ÷ vals[2]
    error("unsupported operator `$op` in a count expression")
end

"""
    traffic_rows(baseline, name, symbols) -> Vector

One row of a frozen traffic table, evaluated.

# Arguments

- `baseline` — the parsed `test/pass_audit_baseline.toml`.
- `name` — the `[[row]]` entry's name.
- `symbols` — the values of the count symbols (`P`, `M`) for the fixture at hand.

The row's `arrays = [{label, reads, writes, ideal_reads?, ideal_writes?, holder?}]` counts are
evaluated over `symbols`. Returns named tuples `(label, frozen, ideal, holder)`; a missing row is an
error naming it.
"""
function traffic_rows(baseline::AbstractDict, name::AbstractString, symbols::AbstractDict{String,Int})
    rows = get(baseline, "row", Any[])
    i = findfirst(r -> r["name"] == name, rows)
    i === nothing && error("pass_audit_baseline.toml has no row named $(repr(name))")
    out = NamedTuple[]
    for a in rows[i]["arrays"]
        frozen = (count_expression(string(a["reads"]), symbols), count_expression(string(a["writes"]), symbols))
        ideal = (count_expression(string(get(a, "ideal_reads", a["reads"])), symbols), count_expression(string(get(a, "ideal_writes", a["writes"])), symbols))
        push!(out, (label = String(a["label"]), frozen = frozen, ideal = ideal, holder = String(get(a, "holder", ""))))
    end
    return out
end

# ─────────────────────────────────────────────────────────────────────── method parity

"""
    resolve_function(name, pkg, modules; externals = (Base,)) -> Union{Function,Nothing}

The function object a surface name denotes.

# Arguments

- `name` — the symbol.
- `pkg` — the umbrella module.
- `modules` — the package modules.
- `externals` — the external modules whose generics the package extends, searched last.

A package module that OWNS the name is searched before anything else, so `run` and `diff` denote
`Git.run` and `Git.diff` and not the `Base` exports they collide with — the first owning module in
`modules` wins when two own a name; ordering the externals last does not achieve that on its own,
because `isdefined(pkg, :run)` is already true through the implicit `using Base`.

Returns the function, or `nothing`.
"""
function resolve_function(name::Symbol, pkg::Module, modules::AbstractVector{Module}; externals = (Base,))
    # `pkg` first would decide every colliding name before `modules` is reached: `isdefined(pkg, :read)`
    # is true through the implicit `using Base`, so ordering `externals` last alone changed nothing (421
    # names, zero moved). A package module that OWNS the name wins; `pkg` and the externals follow.
    owned = [m for m in modules if isdefined(m, name) && getfield(m, name) isa Function && parentmodule(getfield(m, name)) === m]
    for mod in Iterators.flatten((owned, (pkg,), modules, externals))
        isdefined(mod, name) || continue
        c = getfield(mod, name)
        c isa Function && return c
    end
    return nothing
end

"""
    module_method_count(mod, pkg, modules; externals = (Base,)) -> Int

Every method module `mod` OWNS, summed over the package's whole function surface (internals included,
not `names(mod)` — a method defined under a qualified name creates no binding).

# Arguments

- `mod` — the module counted.
- `pkg` — the umbrella.
- `modules` — the package modules.
- `externals` — the external modules whose generics are included.

Returns the count.
"""
function module_method_count(mod::Module, pkg::Module, modules::AbstractVector{Module}; externals = (Base,))
    total = 0
    for name in all_package_functions(pkg, modules)
        f = resolve_function(name, pkg, modules; externals)
        f === nothing && continue
        total += count(m -> m.module === mod, methods(f))
    end
    return total
end

"""
    method_parity(pkg, modules, baseline; externals = (Base,))

The method-parity engine.

# Arguments

- `pkg` — the umbrella module.
- `modules` — the package modules.
- `baseline` — the parsed `test/method_parity_baseline.toml`.
- `externals` — the external modules whose generics the package extends.

Every `[[generic]]` entry `{set, name, count, module}` asserts the number of methods the named module
defines for that generic, each set's total is asserted where the baseline states `[set_total]`, the
`[module]` table asserts the derived per-module counts, and `detect_ambiguities` over `pkg` must be
empty. A moved number is reported with the instruction to refreeze deliberately, with the reason.
Runs as a `@testset`. Returns `nothing`.
"""
function method_parity(pkg::Module, modules::AbstractVector{Module}, baseline::AbstractDict; externals = (Base,))
    byname = Dict(String(nameof(m)) => m for m in modules); byname[String(nameof(pkg))] = pkg
    @testset "method parity" begin
        sets = Dict{String,Int}()
        for g in get(baseline, "generic", Any[])
            f = resolve_function(Symbol(g["name"]), pkg, modules; externals)
            mod = byname[g["module"]]
            n = f === nothing ? -1 : count(m -> m.module === mod, methods(f))
            n == g["count"] || @info "method count moved — refreeze deliberately, with the reason" set = g["set"] name = g["name"] expected = g["count"] measured = n
            @test n == g["count"]
            sets[g["set"]] = get(sets, g["set"], 0) + max(n, 0)
        end
        for (set, total) in get(baseline, "set_total", Dict())
            @test sets[set] == total
        end
        for (name, expected) in get(baseline, "module", Dict())
            measured = module_method_count(byname[name], pkg, modules; externals)
            measured == expected || @info "module method count moved — refreeze deliberately, with the reason" target = name expected measured
            @test measured == expected
        end
        @test isempty(Test.detect_ambiguities(pkg; recursive = true))
    end
    return nothing
end

# ─────────────────────────────────────────────────────────────────────── oracle registry

const ORACLE_CLASSES = ("analytic", "independent", "property", "relational", "structural")

"""
    oracle_registry(pkg, modules, registry, testdir)

The oracle-provenance engine.

# Arguments

- `pkg` — the umbrella module.
- `modules` — the package modules.
- `registry` — the parsed `test/oracle_registry.toml` (`[[operation]] name, class, evidence`).
- `testdir` — the directory the cited test files live in.

Every public value-returning operation (the derived surface minus the `!` names) is classified; no
classification names a vanished operation; every class is one of `analytic | independent | property |
relational | structural`; no operation rests on `relational` alone; and every non-structural citation
names a test file under `testdir` that exists and mentions the operation. Runs as a `@testset`.
Returns `nothing`.
"""
function oracle_registry(pkg::Module, modules::AbstractVector{Module}, registry::AbstractDict, testdir::AbstractString)
    entries = Dict(Symbol(e["name"]) => (String(e["class"]), String(e["evidence"])) for e in get(registry, "operation", Any[]))
    @testset "oracle provenance is classified for every public operation" begin
        public_ops = Set(n for n in package_operations(pkg, modules) if !endswith(String(n), "!"))
        unclassified = setdiff(public_ops, keys(entries))
        isempty(unclassified) || @error "a public operation has no recorded oracle provenance — classify it; if the honest answer is relational, that is the finding" unclassified
        @test isempty(unclassified)
        @test isempty(setdiff(keys(entries), public_ops))
        @test all(v -> v[1] in ORACLE_CLASSES, values(entries))
        relational_only = sort([String(k) for (k, v) in entries if v[1] == "relational"])
        isempty(relational_only) || @error "operations whose only oracle is other package operations" relational_only
        @test isempty(relational_only)
    end
    @testset "every oracle citation names a file that exists and mentions the operation" begin
        missing_file = Tuple{String,String}[]; unmentioned = Tuple{String,String}[]
        for (op, (class, where)) in entries
            class == "structural" && continue
            for token in eachmatch(r"[A-Za-z_0-9]+\.jl", where)
                path = joinpath(testdir, token.match)
                isfile(path) || (push!(missing_file, (String(op), token.match)); continue)
                occursin(String(op), read(path, String)) || push!(unmentioned, (String(op), token.match))
            end
            @test occursin(".jl", where)
        end
        isempty(missing_file) || @error "oracle citations naming a file that does not exist" missing_file
        @test isempty(missing_file)
        isempty(unmentioned) || @error "oracle citations whose file never mentions the operation" unmentioned
        @test isempty(unmentioned)
    end
    return nothing
end

# ─────────────────────────────────────────────────────────────────────── display gate

"""
    struct_types(modules) -> Dict{Symbol,Any}

Every concrete struct type the modules define, keyed by name: parametric types unwrapped first (a
`UnionAll` is not a `DataType`, and asking silently drops most of a package); abstract types skipped;
an empty NON-parametric struct skipped as a singleton whose default display is its constructor, while
an empty PARAMETRIC one is kept (its content lives in the type parameter). Returns the map.
"""
function struct_types(modules::AbstractVector{Module})
    owned = Set(modules)
    found = Dict{Symbol,Any}()
    for m in modules, name in names(m; all = true)
        isdefined(m, name) || continue
        object = getfield(m, name)
        object isa Type || continue
        base = Base.unwrap_unionall(object)
        base isa DataType || continue
        base.name.module in owned || continue
        isabstracttype(base) && continue
        isempty(fieldnames(base)) && !(object isa UnionAll) && continue
        startswith(string(nameof(base)), "#") && continue
        found[nameof(base)] = object
    end
    return found
end

"""
    has_display(type, modules) -> Bool

Whether a module in `modules` owns a `Base.show(::IO, ::type)` method. Returns the answer.
"""
has_display(type, modules::AbstractVector{Module}) = any(m -> m.module in modules, methods(Base.show, Tuple{IO,type}))

"""
    display_gate(modules; no_display = Dict{Symbol,String}, min_types = 1,
                 falsify = true)

The display gate, DERIVED rather than listed: every concrete struct type has a package-owned `show`
or an exemption with a reason.

# Arguments

- `modules` — the modules whose concrete struct types are enumerated.
- `no_display` — type name to reason, for the types deliberately without a display; an exemption whose
  type has a `show` after all is stale (a widened blind spot), and one naming a type no longer defined
  is stale.
- `min_types` — the least number of types the enumeration must find, so a parser that stops matching
  fails rather than reporting a clean sweep.
- `falsify` — with `true`, an empty parametric struct is planted in the first module and must be
  enumerated without a display.

Runs as a `@testset`. Returns `nothing`.
"""
function display_gate(modules::AbstractVector{Module}; no_display::AbstractDict = Dict{Symbol,String}(), min_types::Integer = 1, falsify::Bool = true)
    @testset "every package struct type displays, or is exempt with a reason" begin
        types = struct_types(modules)
        @test length(types) >= min_types
        for (name, type) in sort!(collect(types); by = first)
            if haskey(no_display, name)
                @test !has_display(type, modules)
            else
                has_display(type, modules) || @error "a package struct type has no display and no exemption" name
                @test has_display(type, modules)
            end
        end
        for name in keys(no_display)
            @test haskey(types, name)
        end
        if falsify
            m = first(modules)
            Core.eval(m, :(struct _GBGPlantedOrderTag{K} end))
            @test haskey(struct_types(modules), :_GBGPlantedOrderTag)
            @test !has_display(getfield(m, :_GBGPlantedOrderTag), modules)
        end
    end
    return nothing
end

# ─────────────────────────────────────────────────────────────────────── cross-thread digest

"""
    DIGEST_SOURCE

The source of `fnv_digest`, embedded textually in a subprocess probe so the two cannot drift.
"""
const DIGEST_SOURCE = """
function fnv_digest(a)
  h = 0xcbf29ce484222325
  for byte in reinterpret(UInt8, vec(collect(a)))
    h = (h ⊻ byte) * 0x100000001b3
  end
  return h
end
"""
eval(Meta.parse(DIGEST_SOURCE))

"""
    thread_digest(probe_source; threads, project = Base.active_project()) -> String

Runs a probe in a fresh Julia process with a given thread count and returns its output — the
cross-thread-count half of a bitwise-invariance check the in-process toggle cannot make.

# Arguments

- `probe_source` — Julia source that prints digests with `fnv_digest` (which is prepended).
- `threads` — the `-t` value.
- `project` — the `--project` it runs under.

Returns the trimmed stdout.
"""
function thread_digest(probe_source::AbstractString; threads::Integer, project::AbstractString = Base.active_project())
    src = DIGEST_SOURCE * "\n" * probe_source
    return readchomp(`$(Base.julia_cmd()) --startup-file=no --project=$project -t$threads -e $src`)
end

"""
    other_thread_count() -> Int

The thread count a cross-`-t` probe runs at: 4 when this process has one thread, 1 otherwise. Returns it.
"""
other_thread_count() = Threads.nthreads() == 1 ? 4 : 1

# ───────────────────────────────────────────────────────────────────────────────── seed parity

# A draw on the host, from any device; a scalar draw is a 0-dimensional array.
host(x) = x isa AbstractArray ? Array(x) : fill(x)

"""
    seed_identical(a, b) -> Bool

Whether two copies of one exact draw are the same bits: the same element type, the same shape, and
the same bytes — so `-0.0` is not `0.0`, a `NaN` equals itself, and a `Float32` copy of a `Float64` draw
differs. The arguments are the two draws, on any device. Returns the answer.
"""
function seed_identical(a, b)
    A, B = host(a), host(b)
    eltype(A) === eltype(B) && size(A) == size(B) || return false
    isbitstype(eltype(A)) || return isequal(A, B)
    return reinterpret(UInt8, vec(A)) == reinterpret(UInt8, vec(B))
end

"""
    seed_difference(reference, other) -> Float64

How far two copies of one transformed draw are apart: the largest difference over the finite values,
relative to the largest finite magnitude of `reference`, in machine epsilon of its element type. The
arguments are the two draws, on any device, of one floating-point element type. Returns `Inf` where
the types or shapes differ, or a non-finite value of one is not the same in the other.
"""
function seed_difference(reference, other)
    a, b = host(reference), host(other)
    eltype(a) <: Union{AbstractFloat,Complex{<:AbstractFloat}} ||
        throw(ArgumentError("a transformed draw is floating-point; put an integer draw under `exact`"))
    eltype(a) === eltype(b) && size(a) == size(b) || return Inf
    finite = isfinite.(a)
    all(i -> finite[i] == isfinite(b[i]) && (finite[i] || isequal(a[i], b[i])), eachindex(a)) || return Inf
    unit = eps(real(eltype(a)))
    scale = maximum(abs, a[finite]; init = zero(real(eltype(a))))
    gap = maximum(abs, a[finite] .- b[finite]; init = zero(real(eltype(a))))
    return iszero(scale) ? (iszero(gap) ? 0.0 : Inf) : Float64(gap / scale / unit)
end

"""
    seed_measure(draws, backends; seed = 1, other_seed = seed + 1, bound = 8) -> NamedTuple

What [`seed_parity`](@ref) tests, measured without testing it.

# Arguments

- `draws` — the package's function `draws(seed, backend)`, returning `(exact = (; name => draw, …),
  rounded = (; name => draw, …))`: the draws a run uses as drawn, and those it sees through a transform.
- `backends` — the backends to compare, the reference first.
- `seed`, `other_seed` — the seed, and the one the planted run draws from.
- `bound` — how far a transformed draw may differ, in machine epsilon.

Returns `(exact, rounded, planted, ok)`, per backend after the first: the exact draws not bitwise equal
or not drawn by both, each transformed draw's distance, and, for every backend, the draws a run from
`other_seed` failed to tell apart. The last, `ok`, holds when all is as the contract asks and two
backends ran.
"""
function seed_measure(draws, backends; seed::Integer = 1, other_seed::Integer = seed + 1, bound::Real = 8)
    reference = draws(seed, first(backends))
    isempty(keys(reference.exact)) && isempty(keys(reference.rounded)) &&
        throw(ArgumentError("seed parity: `draws` returned no draws, so nothing would be compared"))
    exact = Dict{Any,Vector{Symbol}}(); rounded = Dict{Any,Dict{Symbol,Float64}}()
    planted = Dict{Any,Vector{Symbol}}()
    for backend in backends[2:end]
        got = draws(seed, backend)
        exact[backend] = [k for k in union(keys(reference.exact), keys(got.exact))
                          if !(haskey(reference.exact, k) && haskey(got.exact, k) &&
                               seed_identical(reference.exact[k], got.exact[k]))]
        rounded[backend] = Dict(k => (haskey(reference.rounded, k) && haskey(got.rounded, k) ?
                                      seed_difference(reference.rounded[k], got.rounded[k]) : Inf)
                                for k in union(keys(reference.rounded), keys(got.rounded)))
    end
    # A run from another seed is told apart on every draw and every backend, each having its own
    # generator; a draw it lacks is told apart.
    for backend in backends
        wrong = draws(other_seed, backend)
        planted[backend] = vcat(
            [k for k in keys(reference.exact) if haskey(wrong.exact, k) && seed_identical(reference.exact[k], wrong.exact[k])],
            [k for k in keys(reference.rounded) if haskey(wrong.rounded, k) && seed_difference(reference.rounded[k], wrong.rounded[k]) <= bound])
    end
    ok = length(backends) >= 2 && all(isempty, values(exact)) &&
         all(d -> all(<=(bound), values(d)), values(rounded)) && all(isempty, values(planted))
    return (exact = exact, rounded = rounded, planted = planted, ok = ok)
end

"""
    seed_parity(draws, backends; seed = 1, other_seed = seed + 1, bound = 8)

The seed-parity contract, `RULE.TEST.SEED_PARITY`: one seed gives the same draws on every backend.

# Arguments

- `draws` — the package's function `draws(seed, backend)`, as [`seed_measure`](@ref) reads it.
- `backends` — the backends this machine can run, the CPU first; the package decides which work.
- `seed`, `other_seed` — the seed, and the one a planted wrong run draws from.
- `bound` — how far a transformed draw may differ, in machine epsilon.

An exact draw is bitwise equal on every backend, a transformed one within `bound`, and a run from
`other_seed` is told apart on every draw. With one backend it records `@test_skip` and a warning:
skipped, never passed, as on a runner with no GPU. Runs as a `@testset`. Returns what
`seed_measure` measured, or `nothing` when skipped.
"""
function seed_parity(draws, backends; seed::Integer = 1, other_seed::Integer = seed + 1, bound::Real = 8)
    result = nothing
    @testset "one seed gives the same draws on every backend" begin
        if length(backends) < 2
            @warn "seed parity: one backend only, so nothing is compared; skipped, not passed" backends
            @test_skip false
        else
            result = seed_measure(draws, backends; seed, other_seed, bound)
            for (backend, names) in result.exact
                isempty(names) || @error "exact draws not bitwise equal, or not drawn on both" backend names
                @test isempty(names)
            end
            for (backend, distance) in result.rounded, (name, d) in distance
                d <= bound || @error "a transformed draw differs beyond the bound" backend name d bound
                @test d <= bound
            end
            for (backend, names) in result.planted
                isempty(names) || @error "a run from another seed was not told apart" backend names
                @test isempty(names)
            end
        end
    end
    return result
end

# ───────────────────────────────────────────────────────────────────────────────── regressions

"""
    run_regressions(dir; parent = Main) -> Vector{String}

The one include loop of the promoted witnesses.

# Arguments

- `dir` — the consumer's test directory (`@__DIR__` of `runtests.jl`); its `regressions/`
  subdirectory is read, or `dir` itself when it is that directory.
- `parent` — the module the wrapper modules are evaluated in.

Every `*.jl` directly under the regressions directory (sorted) is included into its own wrapper
module `Regression_<name>`, so top-level helpers cannot collide across files. An empty directory is an
honest state and runs nothing. Returns the list of files run.
"""
function run_regressions(dir::AbstractString; parent::Module = Main)
    # the wiring passes the TEST directory (`@__DIR__` of runtests.jl); the witnesses live in its
    # `regressions/` subdirectory — passing that directory itself is accepted too
    basename(dir) == "regressions" || (dir = joinpath(dir, "regressions"))
    files = isdir(dir) ? sort!(filter(f -> endswith(f, ".jl"), readdir(dir))) : String[]
    for f in files
        modname = Symbol("Regression_", replace(f[1:end-3], '-' => '_', '.' => '_'))
        path = joinpath(dir, f)
        Core.eval(parent, :(module $modname; Base.include($modname, $path); end))
    end
    return files
end

end # module TestHarness
