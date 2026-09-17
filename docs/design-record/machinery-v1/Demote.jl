# Demote.jl — the mechanical demotion of the act verdict (ARCHITECTURE D10, §6.3).

"""
    demote(verdict) -> (verdict′, demoted::Bool)

The one demotion rule over an act verdict — the act verifier's grade of what the fix pass DID to one
finding, from the diff (the state verifier grades, blind to the diff, whether the defect is still
there; [`GBGCodingTools.Passes`](@ref) binds both verifiers and their verdict vocabularies).
`class_surfaces` is the list the act verifier fills: every surface carrying the finding's class of
defect, its own site included, each marked `swept` when the fix pass's diff fixed the class there.

An act verdict `HONORED` becomes `LINE-ONLY` when that list is empty, a fix graded honoured without the
class enumerated being a line fix by construction, OR when any entry is `swept: false` — a verdict that
says "the fix landed" while its own evidence says "and here is where the class still lives" is a line
fix that has said so.

Emptiness alone fired 0 times in the 571 act verdicts of `2026-09-09-check-docs-02`, which never handed
in an empty list, while admitting 21 closures whose own list named an unswept surface — `templates#3`
five times, and that contradiction shipped. The design record weighed the two rules, content against
emptiness; the data settled it. Every other verdict is returned unchanged. Returns the verdict and whether it moved.
"""
function demote(verdict::AbstractDict)
    cs = get(verdict, "class_surfaces", Any[])
    if get(verdict, "verdict", "") == "HONORED" && (isempty(cs) || any(c -> !get(c, "swept", false), cs))
        demoted = copy(verdict); demoted["verdict"] = "LINE-ONLY"; demoted["demoted_from"] = "HONORED"
        return (demoted, true)
    end
    return (verdict, false)
end
