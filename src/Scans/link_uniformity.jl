# SCAN.LINK_UNIFORMITY — RULE.DOC.LINKS (clause: sibling names in one list are all linked or all plain).
# Source: PF link_uniformity.py: the unit is an ADJACENT RUN of items separated only by `,`, `and`,
# `or`, `/`; a run mixing an @ref-linked public name with a bare public name is a hit. Operators and the
# docstring's own binding are bare by rule and excluded. The public surface is read from the `export`
# lists; none parsed ⇒ population 0 (DEAD).
const LU_ITEM = raw"(?:\[`[A-Za-z_]\w*!?`\]\(@ref[^)]*\)|`[A-Za-z_!*/+\-]\w*!?`)"
const LU_SEP = raw"(?:,\s+|\s+and\s+|\s+or\s+|\s*/\s*)"
const LU_RUN = Regex(LU_ITEM * "(?:" * LU_SEP * LU_ITEM * ")+")
const LU_LINKED = r"\[`([A-Za-z_]\w*!?)`\]\(@ref"
const LU_BARE = r"(?<!\[)`([A-Za-z_]\w*!?)`(?!\]\()"

function exported_names(cfg, files)
    names = Set{String}()
    for f in files
        surface_kind(cfg, f) == :julia || continue
        text = read(joinpath(cfg["root"], f), String)
        for block in eachmatch(r"^export\s+(.+?)(?=^\s*$|^\w)"ms, text)
            for t in eachmatch(r"[A-Za-z_]\w*!?", block.captures[1]); push!(names, t.match); end
        end
    end
    return names
end

register_scan!("SCAN.LINK_UNIFORMITY", function (cfg, files)
    public = exported_names(cfg, files)
    hits = Hit[]
    for d in docstring_blocks(cfg, files)
        doc = join(split(d.body), " ")
        own = d.binding
        for run in eachmatch(LU_RUN, doc)
            text = run.match
            linked = [m.captures[1] for m in eachmatch(LU_LINKED, text)]
            bare = [m.captures[1] for m in eachmatch(LU_BARE, text) if m.captures[1] in public && m.captures[1] != own]
            (isempty(linked) || isempty(bare)) && continue
            push!(hits, Hit(d.file, d.line, "in `$(first(d.signature, 44))`: linked $(linked), bare $(bare) — " * first(text, 104); symbol = own))
        end
    end
    return (hits, length(public))
end)
