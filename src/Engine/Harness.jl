# The design's §3, §11, §5.1; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Harness

What a package's `test/runtests.jl` calls: the code half of the always-on checks, run inside the suite so
that a broken contract is a failing test rather than a report nobody reads.

It runs only programs — the code rules of the rulebook, and the frozen contracts a package pins — and
reads no review state, starts no child process and never touches the network, because CI and a fresh
clone must give the same answer.

It does NOT reach the wiring check, though a test suite runs that too. `Render` is above `Engine` in the
order and the harness reaches no further than its own layer, so the wiring check is handed IN, by
whoever calls this. That is what `checks` is for, and it is how a consumer's suite gets both without this
module knowing what a generator is.

The contract engines live in `TestHarness`, which a consumer's suite calls directly; a package passes
its own contract runner as `contracts` until those are harvested.
"""
module Harness

using ..Model
using ..Catalogue
using ..ConfigIO
using ..Checks

"""
    test(root; extra = Model.Rule[], rules = nothing, checks = (), contracts = nothing)

Runs the code half of the always-on checks over the package at `root` and throws on anything found, so a
red suite means a broken contract and a green one means every program that can check this package has.
The arguments are:

- `root` — the package root; the directory holding `.gbg/config.jl`.
- `extra` — the package's own rules, run AFTER the whole rulebook and never instead of it; only those
  whose intention is code. `rules` is accepted as the same thing.
- `checks` — further checks to run, each `(cfg, root) -> Vector{Model.Location}`. The wiring check is
  passed in this way, because it lives in a module above this one.
- `contracts` — the function that runs the package's frozen contracts, or `nothing` to run none. It is
  passed the package root and is expected to throw on a broken contract, as a test does.

Prints one banner line naming the version that ran — and the pin beside it where the two differ — which
a consumer's CI reads to know the suite was this package's and not a bare `Pkg.test()`. Returns `nothing`.
"""
function test(root::AbstractString; extra = Model.Rule[], rules = nothing, checks = (), contracts = nothing)
    cfg = ConfigIO.read_config(root)
    println("GBGCodingTools ", banner(cfg))

    problems = ConfigIO.validate(cfg, root)
    isempty(problems) || error("the config describes a package this is not:\n  " * join(problems, "\n  "))

    # Each finding with the id of the rule that found it: a line saying only `RULE file:line` left the
    # reader to guess which rule, and a package's own rule was the hardest to guess (found verifying the
    # review, 2026-09-27).
    found = Tuple{Symbol,Model.Location}[]
    # The rulebook always, and the package's own after it: a consumer passing its one extra rule had
    # silently replaced every code rule of the rulebook with it (found in review, 2026-09-26).
    for rule in vcat(Catalogue.RULES, extra, something(rules, Model.Rule[]))
        rule.intention === Model.Intention.CODE || continue
        append!(found, [(rule.id, l) for l in Checks.run_rule(rule, cfg, root)])
    end
    append!(found, Checks.run_patterns(cfg, root; intention = Model.Intention.CODE))
    others = Model.Location[]
    for check in checks
        append!(others, check(cfg, root))
    end

    if !(isempty(found) && isempty(others))
        lines = vcat(["  $(rpad(String(id), 30)) $(l.file):$(l.line)  $(l.text)" for (id, l) in found],
                     ["  CHECK  $(l.file)  $(l.text)" for l in others])
        error("GBGCodingTools found " * string(length(found) + length(others)) * ":\n" * join(lines, "\n"))
    end
    contracts === nothing || contracts(root)
    return nothing
end

tool_name(cfg::Model.Config) = cfg.tool isa VersionNumber ? "v" * string(cfg.tool) : "vdev"

# The banner names the version that RAN, not the pin: a test manifest resolved to an older release than
# the config names printed the pin, and CI read the wrong version as having run (found in review,
# 2026-09-26). Where the two agree, or the pin is `:dev`, it is the pin's spelling, which the workflows grep.
function banner(cfg::Model.Config)
    ran = pkgversion(@__MODULE__)
    (ran === nothing || !(cfg.tool isa VersionNumber) || ran == cfg.tool) && return tool_name(cfg) * " checks"
    return "v" * string(ran) * " checks — the config pins " * tool_name(cfg)
end

end # module Harness
