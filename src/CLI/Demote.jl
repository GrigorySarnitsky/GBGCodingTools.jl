# Demote.jl — the mechanical demotion of the act verdict (ARCHITECTURE D10, §6.3).

"""
    demote(verdict) -> (verdict′, demoted::Bool)

The one demotion rule: an act verdict `HONORED` whose `class_surfaces` is empty becomes `LINE-ONLY`
(a fix graded honoured without the class enumerated from the finding's own text is a line fix by
construction); every other verdict is returned unchanged. Returns the verdict and whether it moved.
"""
function demote(v::AbstractDict)
    if get(v, "verdict", "") == "HONORED" && isempty(get(v, "class_surfaces", Any[]))
        w = copy(v); w["verdict"] = "LINE-ONLY"; w["demoted_from"] = "HONORED"
        return (w, true)
    end
    return (v, false)
end
