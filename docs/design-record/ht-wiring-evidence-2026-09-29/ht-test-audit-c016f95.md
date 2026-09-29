# HT's test-side audits against the four harness contracts

Checked against: HT real tree `c016f95`, the clone's `.gbg/policy/testing-protocol.md`, and the tool's
`src/TestHarness.jl` and `src/Render.jl` at `v2.0.0-rc.31`, which is the dev checkout's HEAD `6e85c5a`
(`git diff v2.0.0-rc.31 HEAD` on those files is empty). PF's pattern comes from `git show` of `d139bafb`,
`cee1ad73`, `c0125ece` and `708161cf`.

**Measured, not read.** I loaded the real HT tree, read-only, with the tool stacked on the load path
(`JULIA_LOAD_PATH="$HT:$TOOL:@stdlib" julia --project=$HT`; scripts in `scratchpad/htaud/probe*.jl`).
Then I asked the tool's own engines for HT's derived surface. Nothing in either tree was written. The
modules are taken as `filter(m -> m !== HT, TestHarness.with_submodules([HT]))`, which gives 13 modules:
Cache, Forcing, Generator, Observables, Particles, Phenomenology, Phenomenology.{Scalings, Spectra,
StructureFunctions}, Propagator, SimulationDomain, SimulationRun and State.

- `package_operations`, in-place (`!`) operations, **23**: add_forcing_source! advance! advect! deposit!
  fields_modified! finalize! interpolate_at_particles! particles_modified! prepare! prepare_forcing!
  project_forcing! random_scalar_spectral! random_solenoidal_velocity_spectral! rebuild_traversal!
  restart! run! scalar_rhs! set_forcing_rate! step! truncate_to_band! velocity_rhs! vorticity_physical!
  warmup!
- value-returning operations, **62**. The only external generic on the surface is `show` (Base).
- `module_method_count`, with `externals = (Base,)`: umbrella 0, Cache 24, Forcing 73, Generator 34,
  Observables 12, Particles 28, Phenomenology 7, Scalings 6, Spectra 33, StructureFunctions 19,
  Propagator 26, SimulationDomain 29, SimulationRun 45, State 8. No surface name fails to resolve.
- `detect_ambiguities(HT; recursive = true)`: **0**. `struct_types`: **38** types.

**Today HT declares none of the four contracts.** No file under `test/` names `GBGCodingTools`, and
`test/runtests.jl` in the clone is byte-identical to the real one (`diff` is empty).

---

## 1. `test/memory_audit.jl` (743 lines)

**What it checks.** The header says it has "Three instruments":

- "THE WORKING-SET LEDGER — a reflective walk over every resident field-sized buffer a run EVOLVES,
  counted per shape class" (:5-6). It is frozen as `const BASE = Dict(` with 24 cells (:94-125), plus
  the forcing deltas in `_forcing_delta` (:142-150) and `TRACER_DELTA = ZERO` (:169). The compositional
  sweep is tested at :429-444.
- "THE FRAME LEDGER" (:17), `const FRAME` (:204) and `DEVICE_FRAME` (:321), and the check "no
  field-scale storage escapes both ledgers" (:494).
- "THE LIVENESS AUDIT … The gap register records achieved − bound per class with a NAMED HOLDER for
  every nonzero gap" (:29-34). This is `GAP_HOLDERS` (:373), tested at :641-668.
- Allocation checks:
  - The episode ledger `EPISODE_UNITS` (:405-412). Each episode is measured with
    `measured[name] = (@allocated f()) / unit; @test abs(measured[name] - expected) <= tolerance`
    (:711-712). The episodes are two seeders, `random_solenoidal_velocity_spectral!` and
    `random_scalar_spectral!`, and four value functions (:697-706).
  - The hot loop: `@test (@allocated advance!(sim; dt = 1e-3)) < 0.2 * unit` (:719).
  - "the hot loop is allocation-free on EVERY dealiasing strategy":
    `@test (@allocated advance!(sim; dt = 1e-3)) < 0.5 * unit` (:722, :740).

**Which contract.**
- The working-set, frame and liveness ledgers are **none — HT's own**. They count resident buffers
  per shape class. No rule and no TestHarness engine counts residency.
- The `@allocated` lines are the ground of **RULE.TEST.ALLOC_ZERO**: "every in-place ! operator is
  allocation-free and in the audit; a deliberate materializer gets a bounded guard".

**Does HT meet ALLOC_ZERO today?** No, in three ways:

1. **Coverage.** Across the whole suite, only 7 of the 23 in-place operations are measured with
   `@allocated` (see §6). Here that is `advance!` and the two seeders.
2. **Bounds are not zero.** The advance! guards are ceilings of 0.2 and 0.5 of a field (`unit = 8 *
   N^3`, :691 and :734). The comment says this "separates 'allocation-free' from 'one field per stage'
   by a wide margin" (:731-732). That is a bound, not the zero the rule states.
3. **Nothing derives completeness.** There is no completeness check tied to the export list.

**What declaring would take, on PF's pattern (d139bafb).**
- PF replaced its own macro with `using GBGCodingTools.TestHarness: @alloc_below` / `import
  GBGCodingTools`. It ended the file with
  `GBGCodingTools.TestHarness.allocation_completeness(GBGPeriodicFields, filter(m -> m !== GBGPeriodicFields, collect(PACKAGE_MODULES)); exempt = Dict(...))`.
- HT's equivalent is `allocation_completeness(GBGHomogeneousTurbulence, <the 13 modules>; exempt = Dict(...))`.
  HT has no `PACKAGE_MODULES`. The nearest list is `display.jl`'s `const MODULES` (display.jl:22-24),
  which is 13 modules plus the umbrella, in a different wrapper module.
- Each `@test (@allocated advance!(sim; dt = 1e-3)) < c * unit` becomes
  `@alloc_below c * unit advance!(sim; dt = 1e-3)`. The callee is recorded because `expr.args[1]` is the
  Symbol `:advance!` (TestHarness.jl:128).
- **Blockers in this file:**
  - The episodes are closures (`f = episodes[name]`, :709). `@alloc_below … f()` would record `:f`,
    which `allocation_completeness` reports as a phantom (TestHarness.jl:182-184). Each seeder would need
    its own row with a named call, as the tool's docstring asks: "Splice a NAMED function rather than an
    anonymous closure" (TestHarness.jl:123-125).
  - The seeders allocate by design ("seeding (velocity) ≈ 6.1", :385), so each is a "deliberate
    materializer" and gets a bounded row.
  - `@alloc_below` asserts only an upper bound (`< limit`, TestHarness.jl:135). HT's two-sided band,
    `abs(measured - expected) <= tolerance`, would stay HT's own.
- **Warm-up differs.** HT warms `advance!` twice before measuring (:718, :739). `@alloc_below` runs the
  expression once as the warm-up (TestHarness.jl:134). Whether one warm-up gives the same number for
  `advance!` was not measured.

## 2. `test/compute_audit.jl` (388 lines)

**What it checks.**
- "THE TRANSFORM LEDGER — scalar-equivalent FFT counts (c2r, r2c) per step, frozen per scheme ×
  dealiasing × scalar cell" (:5-6). This is `TRANSFORMS_BASE` (:55-84), `TRANSFORM_BOUND` (:103) and
  `TRANSFORM_GAP_HOLDERS` (:106).
- "THE PASS LEDGER — full-field memory passes per shape class … Achieved − bound per class carries a
  NAMED HOLDER … an unclaimed gap fails the suite" (:15-24). This is `PASSES_BASE` (:124-156) and
  `FUSION_GAP_HOLDERS` (:170-173). The gap test is
  `if a - b > 0; @test haskey(FUSION_GAP_HOLDERS, class)` (:318-320).
- "every op is priced" (:267-273).
- Regeneration: "`AUDIT_PRINT=1 julia --project=. test/compute_audit.jl`" (:33, :243).
- Its measurement is stated in the file: "Both ledgers are STATIC projections of the op lists" (:26).
  The ops are transcribed by hand into `audit_ops.jl` (audit_ops.jl:16-21).

**Which contract.** It is closest to **RULE.TEST.PASS_AUDIT**: "every audited operation has a frozen
per-array traffic row with a named holder for any gap … the frozen values are refrozen in the same
commit as the change, with the reason". The frozen-plus-named-holder discipline and the
refreeze-with-reason practice (:32-35) match the statement's shape. The mechanism does not match:

| | The tool's engine | HT's pass ledger |
|---|---|---|
| Unit | Per exported `!` operation, per array | Per step schedule (scheme × dealiasing × scalar cell), per shape class |
| How counted | Measured at runtime through `CountingArray` (TestHarness.jl:205-229) | Computed from the hand-written op model |
| Completeness | Every exported `!` operation has an `audit(...)` row or an exemption (TestHarness.jl:305-317) | "every op is priced" means every op-list entry has an `OP_COST` entry, not every exported operation |

**Does HT meet PASS_AUDIT today?** No, not as the tool checks it. HT has no `CountingArray`, no per-array
rows, and nothing ties its completeness to the export list.

**What declaring would take, on PF's pattern (cee1ad73).**
- PF imported `CountingArray, Traffic, counting` and wrapped `audit(...; print = PRINT_COUNTS)`. It
  defined `KernelAbstractions.get_backend(a::CountingArray) = …` itself, and closed with
  `TestHarness.traffic_completeness(GBGPeriodicFields, <modules>; exempt = Dict(...))`, which carries 9
  exemptions.
- For HT this means a new file, or a new section. It would build HT's fields over `counting(...)`
  storage and write one `audit(op!, "<op> …", Traffic(role, array, frozen[, ideal, holder])...)` row
  per audited `!` operation, ending with `traffic_completeness(GBGHomogeneousTurbulence, <13 modules>;
  exempt = Dict(...))`. Every one of the 23 in-place operations needs a row or a reasoned exemption.
- **Why it cannot yet be said whether this is feasible.**
  - Nothing in HT's suite shows that an HT `Simulation` or `FixedDomain` accepts wrapped storage. Every
    audit builds with `array_type = Array` (memory_audit.jl:416-419).
  - PF's own exemptions say FFT plans reject wrapped storage: `:to_physical! => "the transform interior
    is FFTW's, and FFT plans reject wrapped storage"`. HT's step runs through PF transforms.
  - HT's test environment has no `KernelAbstractions` (test/Project.toml: GBGCodingTools,
    GBGPeriodicFields, HDF5, Logging, Random, Test). PF needed it for `get_backend`.
  - Settling this needs a trial build, which I did not run.
- The existing static pass ledger would stay HT's own either way. The tool has no engine for a
  schedule-level projection.

## 3. `test/audit_ops.jl` (612 lines)

**What it checks.** Nothing on its own; it has no `@testset`. It is "the single source of truth two
audits project" (:1). It holds the shape-class walk `collect_field_arrays!`/`_counts` (:58-86), the op
lists `rk3_ops … rk2_ops` (:268-414), `peak_liveness` (:415) and the cost model `OP_COST`,
`_transforms`, `_passes` and `_fusion_bound` (:456-597). The three audits include it: "All three audits
share the file by `include`" (:23).

**Which contract.** **none — HT's own**. It is the model behind the §1, §2 and §4 ledgers. No
TestHarness engine takes an op model.

**To declare:** nothing. It is unaffected by any of the four.

## 4. `test/optimality_audit.jl` (462 lines)

**What it checks.**
- "Every quantity it audits is held against a FLOOR … and every unit of residual distance must be
  CLAIMED by a named holder" (:6-8).
- It is bidirectional: "no unclaimed gap" and "no stale holder — a holder that no longer names a live
  gap ALSO fails" (:10-15).
- Instruments: the pass floor (:277-295), the symbol tier (:297-308), the frame floor (:310-351), and
  the synchronization ledger `SYNC_LEDGER` (:239, :409-420). Holders carry a disposition
  `:FIX`/`:PF_RAISE`/`:DESIGN` (:447-461).
- "both instruments are STATIC projections" (:48).

**Which contract.** **none — HT's own**. Its named-holder idea echoes PASS_AUDIT's "a named holder for
any gap". But it audits floors and host–device synchronization over the static op model, and neither
the rule nor `traffic_completeness` covers that.

**To declare:** nothing applies.

## 5. `test/display.jl` (323 lines)

**What it checks.**
- "every package struct type displays, or is exempt with a reason" (:77-100). This is a derived
  enumeration, `package_struct_types()` (:48-68), with `NO_DISPLAY` holding 8 exemptions (:35-44).
- It has a floor, `@test length(types) ≥ 30` (:79), and plants a falsifier:
  `@eval Particles struct _PlantedOrderTag{K} end` (:97-99).
- Other testsets: no flood (`length(repr(sample)) ≤ 300`, :132), self-delimiting, refused pairs,
  round-trip, REPL form, and "nothing reads an element" (:295-321), which uses
  `@test (@allocated show(IOBuffer(), sample)) < floor` (:317, :319).

**Which contract.** **none of the four.** The tool has an engine for the gate,
`TestHarness.display_gate` (TestHarness.jl:570). Its header names "IT test/display.jl (the UnionAll
clause)" as a source (:4). But no rule in the clone's rulebook names it: a grep of `.gbg/policy/*.md`
and `src/Rules/` for `display_gate` or "display gate" finds nothing. The `@allocated show` lines measure
`show`, a value operation, so they sit outside ALLOC_ZERO's `!` set.

**Does HT meet what the engine checks?** Yes. HT's gate is the same algorithm:
- The same UnionAll unwrap, abstract skip and empty-non-parametric skip (display.jl:56-64 against
  TestHarness.jl:534-539).
- The same two directions (:83, :91).
- The same planted parametric struct (:97-99).

**To adopt the engine (optional, and binding nothing):** replace the testset at :77-100 with
`GBGCodingTools.TestHarness.display_gate(collect(MODULES); no_display = NO_DISPLAY, min_types = 30)`.
Two differences:
- The engine plants its struct in `first(modules)` (TestHarness.jl:586). `collect` of HT's `Set`
  gives no fixed first element, whereas HT plants in `Particles`. Passing a `Vector` that starts with
  `Particles` would keep HT's behaviour.
- The engine also `@error`s on a missing display.

## 6. Other files with `@allocated`, method counts or oracles

**Allocation guards on in-place operations (ALLOC_ZERO ground):**

| File:line | What it measures | Bound |
|---|---|---|
| integrators.jl:106-108 | `step!` and `deposit!` | `@test bytes + deposit_bytes < field_bytes` |
| velocity_slice.jl:61-63 | `step!` and `deposit!` | the same, `< field_bytes` |
| particles.jl:135-137 | `deposit!` and `advect!` in one block, "allocation-free advection step — both verbs of the push" | `@test bytes < 4096` |
| particles.jl:246-250 | `advance!` at two tracer counts | `@test large <= small + 512`, a scaling check rather than a bound |
| regressions/02-gpu-and-hot-loop-02.jl:31 | `prepare_forcing!` | half a field |
| regressions/02-gpu-and-hot-loop-02.jl:41 | `advance!` | `step_bytes < 0.5 * unit` |
| regressions/05-test-critic-05.jl:45-46 | `step!` and `deposit!` | — |
| regressions/r5-gpu-and-hot-loop-01.jl:34 | `step!` | — |
| regressions/gpu-and-hot-loop-03.jl:20-57 | `allocations_of(advect!, …)` with `@test ab_bytes == 0` (:49), plus `IT.Particles._adams_bashforth_weights` | a true zero |

**All `@allocated` measurements of in-place operations suite-wide:** advance!, step!, deposit!, advect!,
prepare_forcing!, random_solenoidal_velocity_spectral! and random_scalar_spectral!. That is 7 of the 23.

**Never measured (16):** add_forcing_source! fields_modified! finalize! interpolate_at_particles!
particles_modified! prepare! project_forcing! rebuild_traversal! restart! run! scalar_rhs!
set_forcing_rate! truncate_to_band! velocity_rhs! vorticity_physical! warmup!

**A stated non-zero.** regressions/gpu-and-hot-loop-03.jl:7-9 reads: "the tracer path is not
allocation-free as a whole — `GBGPeriodicFields`' `interpolate!` allocates 912 bytes per call, so
`Heun`'s `advect!` and the particle `deposit!` each cost that much per step". That is a measured
non-zero in two in-place operations, attributed to PF.

**If the rows were converted to `@alloc_below`:**
- The `(deposit!(…); advect!(…))` block (particles.jl:135) is not a plain call, so nothing is recorded.
  It would have to become two rows.
- A qualified callee such as `IT.Particles.deposit!` (gpu-and-hot-loop-03.jl:35) is not recorded
  either, because `expr.args[1] isa Symbol` fails (TestHarness.jl:128).
- The regression files are witnesses "moved here unchanged" (test/regressions/README.md in the clone).
  Converting their rows would edit a witness. If the rows stay as they are, they count for nothing
  toward completeness.

**Method counts (METHOD_PARITY ground):**
- regressions/01-free-hot-path-01.jl:19: `@test length(methods(particles_modified!)) == 2`
- regressions/audit-03-fields-modified-sim.jl:17: `@test length(methods(fields_modified!)) >= 2`
- These two per-generic checks are the only method counts in the suite. There is no per-module
  baseline and no ambiguity test.

**Oracles (ORACLE_INDEPENDENT ground):**
- below_scale.jl: "Two oracles, each independent of the fused kernel path under test" (:2),
  `spectral_oracle` (:15) and `physical_oracle` (:44).
- dealiasing.jl:69, "PhaseShift de-aliases exactly (vs a zero-padded oracle)".
- regressions/r6-inclusive-ball-exact.jl:11, 62.
- These are per-test oracles. No file classifies operations.

**Frozen tables:** covered in §1 to §4. There are none elsewhere. The `forcing.jl:56` "frozen" match is
prose about the integrating factor.

---

## The contracts, one by one

### RULE.TEST.ALLOC_ZERO — `allocation_completeness`

- **Meets today:** no. 7 of 23 operations are measured, the bounds are fractions of a field rather than
  zero, and nothing checks completeness.
- **To declare:**
  1. Put `using GBGCodingTools.TestHarness: @alloc_below` and `import GBGCodingTools` in the file or
     files that hold the rows.
  2. Convert each `@test (@allocated X) < b` on an in-place operation to `@alloc_below b X`, with X a
     plain unqualified call.
  3. Add rows, or exemptions with reasons, for the 16 unmeasured operations. The two seeders become
     bounded rows.
  4. Call `GBGCodingTools.TestHarness.allocation_completeness(GBGHomogeneousTurbulence, <13 modules>;
     exempt = Dict(:op! => "reason", …))`.
- **Order constraint.** `AUDITED_ALLOCATION_OPS` is one set per process (TestHarness.jl:115). The
  completeness call must therefore run after every row. PF has all its rows in one file,
  `test/allocations.jl`, with the call at its foot. HT's rows are spread over memory_audit, integrators,
  velocity_slice and particles, in that order in runtests.jl (:9-16). So HT would either gather the rows
  into one file or place the call after the last row-bearing file.
- **Standalone runs.** A file run alone (runtests.jl:5 promises "Every file is also runnable on its
  own") would then see only its own rows.
- **Unresolved zeros.** Whether `step!`, `advance!`, `advect!` and `deposit!` reach a true zero on the
  CPU is not established. gpu-and-hot-loop-03.jl:7-9 states 912 B per `interpolate!` from PF.

### RULE.TEST.PASS_AUDIT — `traffic_completeness`

- **Meets today:** no, as the engine checks it. HT's pass ledger is static and schedule-level (§2).
- **To declare:** follow PF's cee1ad73. Use `import GBGCodingTools` and
  `using GBGCodingTools.TestHarness: CountingArray, Traffic, counting`, then write one `audit(...)` row
  per in-place operation. Close with `GBGCodingTools.TestHarness.traffic_completeness(GBGHomogeneousTurbulence,
  <13 modules>; exempt = Dict(...))`.
- **Cannot yet be said:** whether HT's types run over `CountingArray` storage. No test builds them over
  anything but `Array`, PF exempts its transforms because "FFT plans reject wrapped storage", and
  `KernelAbstractions` is absent from HT's test environment.

### RULE.TEST.ORACLE_INDEPENDENT — `oracle_registry`

- **Meets today:** no. There is no registry, and none of the 62 value operations is classified.
- **To declare:** follow PF's 708161cf. Write a table, for example `const ORACLE_PROVENANCE =
  Dict{Symbol,Tuple{Symbol,String}}(…)` in a new `test/oracle_registry.jl`, or a TOML file with
  `[[operation]] name, class, evidence`.
  - It needs one entry for each of the 62 operations listed at the top, `show` included. PF's entry for
    `show` was `(:property, "display.jl — …")`.
  - Each non-structural `evidence` must name an existing `test/*.jl` whose text mentions the operation
    (TestHarness.jl:498-513).
  - No entry may be `relational` (TestHarness.jl:494-496).
  - Then call `GBGCodingTools.TestHarness.oracle_registry(GBGHomogeneousTurbulence, <13 modules>,
    Dict("operation" => [Dict("name"=>…, "class"=>…, "evidence"=>…) …]), @__DIR__)`, and add
    `module OracleRegistryTests; include("oracle_registry.jl"); end` to runtests.jl.
- The classification of each operation is the owner's.

### RULE.TEST.METHOD_PARITY — `method_parity`

- **Meets today:** no. There are two per-generic checks in regressions and no per-module baseline.
- **To declare:** follow PF's c0125ece.
  1. Add `TOML = "fa267f1f-6049-4f14-aa54-33bafae1ed76"` to test/Project.toml.
  2. Write `test/method_parity_baseline.toml` with a `[module]` table: `"Cache" = 24`,
     `"Forcing" = 73`, `"Generator" = 34`, `"Observables" = 12`, `"Particles" = 28`,
     `"Phenomenology" = 7`, `"Scalings" = 6`, `"Spectra" = 33`, `"StructureFunctions" = 19`,
     `"Propagator" = 26`, `"SimulationDomain" = 29`, `"SimulationRun" = 45`, `"State" = 8`. These are
     measured at c016f95. `[[generic]]` entries (`set, name, count, module`) and `[set_total]` are
     optional.
  3. Write `test/method_parity.jl` calling `GBGCodingTools.TestHarness.method_parity(GBGHomogeneousTurbulence,
     <13 modules>, TOML.parsefile(joinpath(@__DIR__, "method_parity_baseline.toml")))`, and include it
     from runtests.jl.
- `externals = (Base,)` suffices on today's surface. The only external generic is `Base.show`, and no
  name fails to resolve.
- **Two caveats:**
  - `method_parity` keys `[module]` by `String(nameof(m))` (TestHarness.jl:441). The three
    Phenomenology submodules are therefore keyed by their bare names. No two of HT's modules share a
    bare name today.
  - Ambiguities are 0 today, so the engine's `@test isempty(detect_ambiguities(...))` (:460) would pass.

---

## `test/runtests.jl`: the harness call and the regressions loop

**`Engine.Harness.test(...)` is needed, whatever the contracts.**
- The wiring check requires `test/runtests.jl` to call it: `CALLS` pairs `test/runtests.jl` with
  "Harness.test" and the reason "the test suite runs no rule of the rulebook" (Render.jl:550-552).
  `call_drift` reports a file that does not.
- HT's runtests.jl (all 33 lines) has no such call, and the clone's copy is identical.
- The line the tool expects is `Render.runtests_call()`:
  `GBGCodingTools.Engine.Harness.test(dirname(@__DIR__); checks = (GBGCodingTools.Render.wiring,))`
  (Render.jl:467), preceded by `using GBGCodingTools`, as in PF runtests.jl:59-60. It is independent of
  the four contracts.
- `Harness.test` also takes `contracts = nothing`, called as `contracts(root)` after the rules
  (Engine/Harness.jl:45, :73). This is a second place a contract call could go; PF does not use it.

**`TestHarness.run_regressions` is not required.**
- No rule and no wiring check names it: grep of the rulebook and of `src/Render.jl` finds none.
- PF did not adopt it either. PF's runtests.jl keeps its own `for regression_file in sort(filter(…
  readdir(joinpath(@__DIR__, "regressions")…)))` loop.
- HT's loop (runtests.jl:29-33) does the same work as `run_regressions(@__DIR__)`: sorted `*.jl`,
  non-recursive (so it never descends into an `escalated/`), one `Regression_<name>` module each. Two
  differences:
  - HT replaces only `-` in the module name. The tool replaces `-` and `.` (TestHarness.jl:659).
  - HT's `include` evaluates in the runtests module, where the tool uses `Core.eval(parent, …)` with
    `parent = Main`.
- Swapping it would be the single line `GBGCodingTools.TestHarness.run_regressions(@__DIR__)`, and is
  optional. Today there are 125 witness files.
