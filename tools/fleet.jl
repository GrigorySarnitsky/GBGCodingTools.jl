# tools/fleet.jl — run every rule over several packages at once, and say what crashed.
#
#     julia --project tools/fleet.jl <package> [<package> …]
#
# WHY THIS EXISTS, and why it is not a test. Two defects of 2026-09-18 were invisible from any single
# consumer and obvious across four:
#
#   - a rule read the files a docs build GENERATES, which do not exist in a fresh clone and do exist in
#     a tree somebody has built once;
#   - `Texts.line_range` sliced source at the parser's BYTE offsets, so a node boundary landing inside a
#     multi-byte name threw out of the rule — on the two consumers whose prose carries the most Greek,
#     and on neither of the two I had been measuring.
#
# It cannot be a test. The packages live outside this repository at paths that differ by machine, and a
# test that reads them would answer differently on a fresh clone and on CI — the one thing a check here
# may never do. So it is a tool a session runs deliberately, and what it reports is a reason to look,
# never a gate.
#
# A rule that THROWS is the finding here. A count that moves is information; a stack trace is a defect,
# because a rule that cannot read a package's source reports nothing about it and says so to nobody.
using GBGCodingTools
const G = GBGCodingTools

"""
    sweep(roots) -> Bool

Runs every rule of the rulebook over each package in `roots` and prints what each found and what threw.
The argument is `roots`, the package directories. Returns whether every rule ran on every package.

Each package is read with the DEFAULT file sets rather than its own config, so that one rule change is
compared across packages on the same terms; a package's own switches and file sets are what `gbg check`
applies, and this is not that.
"""
function sweep(roots)
    clean = true
    for root in roots
        isdir(root) || (println("  ", root, " — not a directory"); clean = false; continue)
        cfg = G.Model.Config(package = basename(rstrip(root, '/')), tool = :dev)
        total = 0
        crashed = String[]
        for rule in G.Catalogue.RULES
            try
                total += length(G.Engine.Checks.run_rule(rule, cfg, root))
            catch err
                push!(crashed, String(rule.id) * ": " * first(sprint(showerror, err), 90))
            end
        end
        println(rpad(basename(rstrip(root, '/')), 26), lpad(total, 5), " finding(s)",
                isempty(crashed) ? "" : "   " * string(length(crashed)) * " RULE(S) THREW")
        for c in crashed; println("      ", c); clean = false; end
    end
    return clean
end

if abspath(PROGRAM_FILE) == @__FILE__
    isempty(ARGS) && (println(stderr, "usage: julia --project tools/fleet.jl <package> [<package> …]"); exit(2))
    exit(sweep(ARGS) ? 0 : 1)
end
