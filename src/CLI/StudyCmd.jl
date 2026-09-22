# The design's §12; the coordinates live here rather than in a docstring, which must read complete at
# the REPL.
"""
    StudyCmd

`gbg study rules`: how well the rulebook is written, measured.

It reports a round of the wording study and says what follows: the agreement between three readers given
only a rule's text, the rules they answered differently about, the rules whose wording left one of them
guessing, and the rules whose majority answer differs from the tag the rulebook carries. The last become
questions the owner answers; nothing here edits a rule.

The verb reads a round that has already been ANSWERED — a tab-separated file of votes. Launching the
three readers is a run's work and a session's: Julia cannot launch an agent, and this verb is the half
that can be a program. A round is a file so that a measurement is repeatable: the four numbers of
2026-09-19 are `test/tagging/`, and they come out the same today.
"""
module StudyCmd

using ..GBGCodingTools: GBGCodingTools, Catalogue, ConfigIO, Engine, Model, Study, parse_options, VERBS

"""
    rules(root, path; io = stdout) -> Int

Reports the round of votes in `path`. The arguments are:

- `root` — the package root.
- `path` — the votes, tab-separated.
- `io` — where the report goes.

Exit 0 when the readers agreed with the rulebook everywhere, 1 when anything is open — a split, a
flagged wording, or a tag the readers would move. The exit code is the contract: a session that must
not leave a measurement unread reads it rather than the text.
"""
function rules(root::AbstractString, path::AbstractString; io::IO = stdout)
    isfile(path) || (println(io, "study: no such file: ", path); return 2)
    round = Study.read_round(path)
    isempty(round.rules) && (println(io, "study: ", path, " holds no votes"); return 2)
    println(io, "study: ", length(round.rules), " rule(s), three readers each.")
    println(io, "  agreement on what must be read : ", round_2(round.needs_kappa))
    println(io, "  agreement on whether a discipline is needed : ", round_2(round.discipline_kappa))
    report(io, "answered differently by the three", round.splits)
    report(io, "wording that left a reader guessing", round.flagged)
    drifts = Study.drift(round, Catalogue.RULES)
    if isempty(drifts)
        println(io, "  no tag the readers would move.")
    else
        println(io, "  ", length(drifts), " tag(s) the readers would move, each a question for the owner:")
        for d in drifts
            println(io, "    ", d.rule, ": the rulebook says ", d.rulebook, ", the readers said ", d.readers)
        end
    end
    return isempty(round.splits) && isempty(round.flagged) && isempty(drifts) ? 0 : 1
end

# Two places, so two rounds are comparable at a glance; `round` is taken by the type above.
round_2(x::Float64) = string(round(x; digits = 2))

function report(io::IO, what::AbstractString, ids::AbstractVector{<:AbstractString})
    isempty(ids) && (println(io, "  none ", what, "."); return)
    println(io, "  ", length(ids), " ", what, ":")
    for id in ids; println(io, "    ", id); end
end

function cmd_study(args)
    o = parse_options(args; valued = ["votes"])
    isempty(o.positional) || o.positional[1] != "rules" ?
        (println(stderr, "usage: gbg study rules --votes <file.tsv>"); return 2) : nothing
    root = ConfigIO.require_root("study")
    root === nothing && return 2
    votes = get(o.values, "votes", "")
    isempty(votes) && (println(stderr, "usage: gbg study rules --votes <file.tsv>"); return 2)
    return rules(root, votes)
end
VERBS["study"] = cmd_study

end # module StudyCmd
