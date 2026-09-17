"""
    Harness

What a package's `test/runtests.jl` calls: the code half of the always-on checks, run inside the suite so
that a broken contract is a failing test rather than a report nobody reads (`docs/ARCHITECTURE.md` §3,
§11).

It runs only programs — the code rules of the rulebook, and the frozen contracts a package pins — and
reads no review state, starts no child process and never touches the network, because CI and a fresh
clone must give the same answer.

It does NOT reach the wiring check, though a test suite runs that too. `Render` is above `Engine` in the
order and the harness reaches no further than its own layer (§5.1), so the wiring check is handed IN, by
whoever calls this. That is what `checks` is for, and it is how a consumer's suite gets both without this
module knowing what a generator is.

The contract engines still live in `TestHarness`, the module of the tree being replaced; a package passes
its own contract runner as `contracts` until those are harvested (`IMPLEMENTATION.md` batch f).
"""
module Harness

using ..Model
using ..Catalogue
using ..ConfigIO
using ..Checks

"""
    test(root; rules = Catalogue.RULES, checks = (), contracts = nothing)

Runs the code half of the always-on checks over the package at `root` and throws on anything found, so a
red suite means a broken contract and a green one means every program that can check this package has.
The arguments are:

- `root` — the package root; the directory holding `.gbg/config.jl`.
- `rules` — the rules to run, the whole rulebook by default; only those whose intention is code.
- `checks` — further checks to run, each `(cfg, root) -> Vector{Model.Location}`. The wiring check is
  passed in this way, because it lives in a module above this one.
- `contracts` — the function that runs the package's frozen contracts, or `nothing` to run none. It is
  passed the package root and is expected to throw on a broken contract, as a test does.

Prints one banner line naming the version that ran, which a consumer's CI reads to know the suite was
this package's and not a bare `Pkg.test()`. Returns `nothing`.
"""
function test(root::AbstractString; rules = Catalogue.RULES, checks = (), contracts = nothing)
    cfg = ConfigIO.read_config(root)
    println("GBGCodingTools ", tool_name(cfg), " checks")

    problems = ConfigIO.validate(cfg, root)
    isempty(problems) || error("the config describes a package this is not:\n  " * join(problems, "\n  "))

    found = Model.Location[]
    for rule in rules
        rule.intention === Model.Intention.CODE || continue
        append!(found, Checks.run_rule(rule, cfg, root))
    end
    others = Model.Location[]
    for check in checks
        append!(others, check(cfg, root))
    end

    if !(isempty(found) && isempty(others))
        lines = vcat(["  RULE   $(l.file):$(l.line)  $(l.text)" for l in found],
                     ["  CHECK  $(l.file)  $(l.text)" for l in others])
        error("GBGCodingTools found " * string(length(found) + length(others)) * ":\n" * join(lines, "\n"))
    end
    contracts === nothing || contracts(root)
    return nothing
end

tool_name(cfg::Model.Config) = cfg.tool isa VersionNumber ? "v" * string(cfg.tool) : "vdev"

end # module Harness
