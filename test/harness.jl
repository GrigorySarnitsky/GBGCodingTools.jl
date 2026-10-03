# test/harness.jl — the seed-parity contract's engine, on the CPU alone: two "backends" here are two
# copies of one array, so the comparison, its bound and its planted case are tested where CI can run
# them. Whether a GPU agrees is the declaring package's GPU leg to show (HT's, on CUDA, 2026-10-01).
using Test, GBGCodingTools
const TH = GBGCodingTools.TestHarness

# The draws of one seed: an exact one, used as drawn, and a transformed one. A backend is a symbol
# naming how its copy is made, the first two equal, the rest each one way to break the contract.
function draws(seed, backend)
    exact = (positions = collect(1.0:8.0) .* seed,)
    field = sin.(seed .* (1:16)) .+ 2.0
    rounded = (field = copy(field),)
    if backend === :noisy2
        rounded.field[3] += 2 * eps(Float64) * maximum(abs, field)
    elseif backend === :noisy100
        rounded.field[3] += 100 * eps(Float64) * maximum(abs, field)
    elseif backend === :moved
        exact.positions[1] = nextfloat(exact.positions[1])
    elseif backend === :single
        exact = (positions = Float32.(exact.positions),)
    elseif backend === :seedless                       # its own generator ignores the seed
        return draws(1, :cpu)
    elseif backend === :extra
        exact = (positions = exact.positions, more = [seed])
    end
    return (exact = exact, rounded = rounded)
end
# A package whose draws ignore the seed: every backend agrees, which proves nothing.
seedless(seed, backend) = draws(1, backend)
# A transformed draw that the seed moves, with an exact one beside it.
fixed_rounded(f) = (seed, backend) -> (exact = (s = [seed],), rounded = (f = seed == 1 ? f : f .+ 1,))

@testset "seed parity" begin
    @test TH.seed_measure(draws, [:cpu, :same]).ok
    near = TH.seed_measure(draws, [:cpu, :noisy2])
    @test near.ok && 1.5 < near.rounded[:noisy2][:field] <= 2.5          # measured, in epsilon
    @test !TH.seed_measure(draws, [:cpu, :noisy100]).ok                  # beyond the bound
    moved = TH.seed_measure(draws, [:cpu, :moved])
    @test !moved.ok && moved.exact[:moved] == [:positions]               # an exact draw is bitwise
    blind = TH.seed_measure(seedless, [:cpu, :same])
    @test !blind.ok && Set(blind.planted[:same]) == Set([:positions, :field])   # the planted run must differ
    @test TH.seed_difference([1.0, 2.0], [1.0]) == Inf
    @test TH.seed_difference(zeros(3), zeros(3)) == 0.0

    # Found in review, 2026-10-02, each on the first version.
    # A third backend whose generator ignores the seed: the planted run is tried on every backend.
    third = TH.seed_measure(draws, [:cpu, :same, :seedless])
    @test !third.ok && !isempty(third.planted[:seedless])
    # Bitwise is bits: the sign of a zero, the element type.
    @test !TH.seed_identical([-0.0], [0.0])
    @test !TH.seed_identical(Float64[1, 2], Float32[1, 2])
    @test !TH.seed_identical(Int64[1], Int32[1])
    @test !TH.seed_measure(draws, [:cpu, :single]).ok
    # A NaN equals itself bitwise, and a non-finite value matching its place is no difference.
    @test TH.seed_identical([NaN, 1.0], [NaN, 1.0])
    @test TH.seed_difference([NaN, 1.0], [NaN, 1.0]) == 0.0
    @test TH.seed_difference([Inf, 1.0], [Inf, 1.0]) == 0.0
    @test TH.seed_difference([Inf, 1.0], [1.0, 1.0]) == Inf
    @test TH.seed_measure(fixed_rounded([NaN, 2.0]), [:cpu, :same]).ok
    # A planted run that lacks a draw is told apart, not an error.
    gone = (seed, backend) -> seed == 1 ? (exact = (x = [1.0],), rounded = NamedTuple()) :
                                          (exact = NamedTuple(), rounded = NamedTuple())
    @test TH.seed_measure(gone, [:cpu, :same]).ok
    # One backend is never a pass, and no draws at all is refused.
    @test !TH.seed_measure(draws, [:cpu]).ok
    @test_throws ArgumentError TH.seed_measure((s, b) -> (exact = NamedTuple(), rounded = NamedTuple()), [:cpu, :same])
    # A draw one backend makes and the reference does not breaks "the same draws".
    extra = TH.seed_measure(draws, [:cpu, :extra])
    @test !extra.ok && extra.exact[:extra] == [:more]
    # An integer transformed draw is refused with its reason; a scalar draw is a 0-d array.
    @test_throws ArgumentError TH.seed_difference([1, 2], [1, 2])
    @test TH.seed_identical(1.5, 1.5) && !TH.seed_identical(1.5, 2.5)

    # Through the testset: two backends pass and return the measure; one is skipped, never passed.
    @test TH.seed_parity(draws, [:cpu, :same]).ok
    @test (@test_logs (:warn, r"skipped, not passed") match_mode = :any TH.seed_parity(draws, [:cpu])) === nothing
end

# The device-cost contract's engine, on the CPU: a copy gives the bandwidth, a plain read of a vector
# costs about its bytes, and the same read with a sine per element costs more — computation a traffic
# count cannot see, which is what the contract exists to find (PF's request, 2026-10-03).
@testset "device cost" begin
    n = 2^20
    src = rand(n); dst = similar(src); sink = Ref(0.0)
    copy = (run = () -> copyto!(dst, src), bytes = 2 * sizeof(src))
    plain = (name = :plain, run = () -> (sink[] = sum(src)), bytes = sizeof(src))
    heavy = (name = :heavy, run = () -> (sink[] = sum(sin, src)), bytes = sizeof(src))
    sync = () -> nothing
    t, m = TH.fastest(plain.run, sync; reps = 5)
    @test 0 < t <= m
    r = TH.device_measure([plain, heavy], copy, sync; reps = 10)
    @test r.bandwidth > 0
    ratio(name) = only(x.ratio for x in r.rows if x.name === name)
    @test ratio(:heavy) > 2 * ratio(:plain)                      # the computation shows in the ratio
    # through the testset: an operation with a generous frozen bound passes; none given is a skip
    @test TH.device_cost([plain], copy, sync; bounds = Dict(:plain => 1e6), reps = 5) !== nothing
    @test (@test_logs (:warn, r"skipped, not passed") match_mode = :any TH.device_cost(NamedTuple[], copy, sync)) === nothing
end
