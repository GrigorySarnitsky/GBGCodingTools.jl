# SCAN.SENTENCE_OPENER — RULE.DOC.SENTENCE_OPENER (triage). Source: PF sentence_openers.py: a sentence
# start is COMPUTED, not pattern-matched — at the start of a line whose previous line ended a sentence or
# was blank, and after `. ` within a line — and an opener is a lowercase code span, a math span, or
# either wrapped in a link. Exemptions are the rule's own: bullets and their wrapped continuations,
# `#` lines, headings, fenced code, indented lines (signatures, continuations), the abbreviations
# e.g./i.e./cf./vs./incl., and the ``\checkmark`` marker. Zero surfaces ⇒ DEAD.
const SO_LEADER = r"^\s*([-*+>|]|\d+[.)])\s"
const SO_OPENER = r"^(\[?`[a-z_][\w!]*`|``[^`])"
const SO_ENDS = r"[.!?]\*{0,2}[\"')]?$"
const SO_ABBREV = r"(e\.g|i\.e|cf|vs|incl)\.\s*$"i
const SO_INLINE = r"(?<!\.)\.\s+(\[?`[a-z_][\w!]*`|``[^`])"

register_scan!("SCAN.SENTENCE_OPENER", function (cfg, files)
    hits = Hit[]
    for f in files
        previous = ""; inlist = false; lastdoc = false
        for p in prose_lines(cfg, f)
            line = p.text
            p.indocstring != lastdoc && (previous = ""; inlist = false; lastdoc = p.indocstring)
            if occursin(SO_LEADER, line)
                inlist = true
            elseif isempty(strip(line)) || !startswith(line, (' ', '\t'))
                inlist = false
            end
            if occursin(r"^\s*#", line) || occursin(SO_LEADER, line) || inlist
                previous = line; continue
            end
            stripped = rstrip(line)
            if !startswith(line, (' ', '\t')) && occursin(SO_OPENER, line) && !startswith(line, "``\\checkmark``")
                if isempty(strip(previous)) || (occursin(SO_ENDS, rstrip(previous)) && !occursin(SO_ABBREV, rstrip(previous)))
                    push!(hits, Hit(f, p.n, first(stripped, 100))); previous = line; continue
                end
            end
            for m in eachmatch(SO_INLINE, line)
                before = rstrip(line[1:m.offset])
                (occursin(SO_ABBREV, before) || occursin("checkmark", line)) && continue
                push!(hits, Hit(f, p.n, first(stripped, 100))); break
            end
            previous = line
        end
    end
    return (hits, length(files))
end)
