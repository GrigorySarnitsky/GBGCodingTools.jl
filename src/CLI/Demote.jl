# Demote.jl — the mechanical demotion of the act verdict (ARCHITECTURE D10, §6.3).

"""
    demote(verdict) -> (verdict′, demoted::Bool)

The one demotion rule over an act verdict — the act verifier's grade of what the fix pass DID to one
finding, from the diff (the state verifier grades, blind to the diff, whether the defect is still
there). `class_surfaces` is the list the verifier fills from the finding's own text: every surface
carrying the same class and whether the diff swept it. An act verdict `HONORED` whose `class_surfaces`
is empty becomes `LINE-ONLY` (a fix graded honoured without the class enumerated is a line fix by
construction); every other verdict is returned unchanged. Returns the verdict and whether it moved.
"""
function demote(verdict::AbstractDict)
    if get(verdict, "verdict", "") == "HONORED" && isempty(get(verdict, "class_surfaces", Any[]))
        demoted = copy(verdict); demoted["verdict"] = "LINE-ONLY"; demoted["demoted_from"] = "HONORED"
        return (demoted, true)
    end
    return (verdict, false)
end
