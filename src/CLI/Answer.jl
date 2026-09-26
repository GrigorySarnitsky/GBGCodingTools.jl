# The design's §8; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Answer

`gbg ask` and `gbg answer`: the two ends of putting a decision to the owner.

`gbg ask` with a decision puts a question and with nothing lists what is waiting for him;
`gbg answer <question> <option>` records what he said. A question of a run is answered in that run's
record; these are the rest, kept in `.gbg/questions.json`. Which store an id came from is not his to
know, so `answer` tries both.

An answered question never returns. Recording an answer twice is refused rather than overwritten: the
second would replace a ruling with a later reading of the same words, and the first is the one he gave.
"""
module Answer

using Dates
using ..GBGCodingTools: GBGCodingTools, ConfigIO, Engine, Model, Orchestration, parse_options, VERBS

"""
    ask(root; io = stdout) -> Int

Prints the questions waiting for the owner in the package at `root`, unanswered first. The arguments
are:

- `root` — the package root.
- `io` — where the list goes.

Exit 0 when none is open, 1 when one is.

The exit code is the contract: a session that must not end with a decision outstanding reads it rather
than the text.
"""
function ask(root::AbstractString; io::IO = stdout)
    qs = Engine.Questions.open_questions(root)
    # The questions RUNS put, which live in their records: until 2026-09-23 this read only the standalone
    # store and said nothing was waiting while a run's question stood.
    runs_q = Orchestration.Runs.open_questions(root)
    isempty(qs) && isempty(runs_q) && (println(io, "Nothing is waiting for an answer."); return 0)
    open_ones = 0
    for (run_id, q) in runs_q
        open_ones += 1
        println(io, "\n", q.id, "  ", q.decision, "   (from run ", run_id, ")")
        isempty(q.context) || println(io, "  ", q.context)
        for o in q.options
            println(io, "    - ", o.label, o.recommended ? "  (recommended)" : "", "  — ", o.consequence)
        end
    end
    for q in qs
        items = get(q, "items", [])
        answered = isempty(items) ? q["answer"] !== nothing :
                   all(i -> i["answer"] !== nothing, items)
        answered && continue
        open_ones += 1
        println(io, "\n", q["id"], "  ", q["decision"])
        isempty(get(q, "context", "")) || println(io, "  ", q["context"])
        for o in get(q, "options", [])
            println(io, "    - ", o["label"], o["recommended"] ? "  (recommended)" : "", "  — ", o["consequence"])
        end
        for i in items
            i["answer"] === nothing || continue
            println(io, "    * ", i["text"], isempty(i["recommended"]) ? "" : "  (recommended: " * i["recommended"] * ")")
        end
    end
    open_ones == 0 && (println(io, "Every question here is answered."); return 0)
    println(io, "\n", open_ones, " waiting. Answer one with: gbg answer <id> \"<option>\" [--item \"…\"] [--direction \"…\"]")
    return 1
end

"""
    answer(root, id, option; item, direction, settled, io) -> Int

Records the owner's answer to one question. The arguments are:

- `root` — the package root.
- `id` — the question's id.
- `option` — the label he chose.
- `item` — the item it answers, empty for a question with none.
- `direction` — how he wants it done, where his answer carried that.
- `settled` — also record it as a ruling agents are told not to report again.
- `io` — where the result goes.

Exit 0 when it was recorded, 2 when it was refused.

The `settled` flag is "not a defect, do not ask again": it appends a [`Model.Settled`](@ref) to
`.gbg/settled.jl`, holding his words and the locations the ruling covers. Nothing a build, a test or a
check runs reads that file — only the agents of a later run, which is the point of it.

TWO STORES, one command. A question a run put is kept in that run's record and nowhere else; every
other question is in `.gbg/questions.json`. The owner reads an id off a report and types it, and which
store it came from is not his to know, so this tries the standalone one and then the runs. Until
2026-09-21 it tried only the first, and the report of every run that parked a finding printed an
instruction that answered `no question here is called …`.

A run's question is answered ON its own terms. Where the answer is that the reader was wrong — the
option a `HIDES_CODE_DEFECT` question offers as "not a defect" — the ruling is recorded as settled
without the flag, with the finding's own locations, because the next run derives its readers from the
same rulebook and would otherwise raise it again and spend another pass on it.
"""
function answer(root::AbstractString, id::AbstractString, option::AbstractString;
                item::AbstractString = "", direction::AbstractString = "",
                settled::Bool = false, io::IO = stdout)
    R = Orchestration.Runs
    found = R.question_of(root, id)
    of_run = found !== nothing && !any(q -> get(q, "id", "") == id, Engine.Questions.open_questions(root))
    # The settled list is a tracked file, and one changed while a run is open blocks that run's collect
    # and every fix it commits (found in review, 2026-09-24). The open run's own question is recorded now
    # and settled when it closes; any other that would write the list waits for the close.
    open_here = open_run_here(root)
    deferred = false
    remade = false
    if open_here !== nothing && (settled || (of_run && option == NOT_A_DEFECT))
        # with or without the flag: on this option the flag adds nothing, and refusing the spelling the
        # usage line offers was only a trap (found in review, 2026-09-26)
        if of_run && first(found) == open_here && option == NOT_A_DEFECT
            deferred = true
        else
            println(io, "answer: refused — a run is open, and this answer writes the settled list, which would block it; answer it once the run has closed")
            return 2
        end
    end
    if of_run
        run_id, run, q = found
        # refused on its own terms first, so nothing is re-made for an answer that is then refused
        q.answer === nothing || (println(io, "answer: it was already answered: ", q.answer); return 2)
        isempty(q.options) || option in [o.label for o in q.options] ||
            (println(io, "answer: ", option, " is not one of its options: ", join([o.label for o in q.options], ", ")); return 2)
        fid = replace(id, r"-code$" => "")
        # "do not report it again" is a ruling that the READER was wrong; it is refused on an answer that
        # wants the code or the documentation changed (review, 2026-09-23)
        settled && option != NOT_A_DEFECT &&
            (println(io, "answer: refused — --settled means the reader was wrong, which `", option, "` does not say"); return 2)
        if option == R.DOCS_ANSWER
            # the edit is made again BEFORE the answer is recorded, so an edit that cannot be made leaves
            # the question standing; and never while a run is open, whose collect the commit would block
            open_run_here(root) === nothing ||
                (println(io, "answer: refused — a run is open; answer this once it has closed, since re-making the edit commits"); return 2)
            undone = R.reverts_of(root, run.first_commit, fid)
            # All or none: a revert made before one that failed is taken back, or the answer that said
            # nothing was recorded left HEAD moved and every retry failing (found in review, 2026-09-24).
            saved = R.head_commit(root)
            ok = all(r -> R.revert!(root, r; why = "the owner: fix the documentation instead"), undone)
            if !ok
                back = R.head_commit(root) == saved || GBGCodingTools.Git.run(root, "reset", "--keep", saved) !== nothing
                println(io, "answer: the reverted edit of ", fid, " could NOT be made again (the page has moved, or something is staged);",
                        back ? " nothing was recorded, and the question stands" :
                               " the part already made could not be taken back — `git reset --keep $(saved)` does it; nothing was recorded")
                return 2
            end
            remade = !isempty(undone)
        end
    end
    why = Engine.Questions.answer!(root, id, option; item, direction)
    of_run && (why = R.answer!(root, id, option; item, direction))
    why === nothing || (println(io, "answer: ", why); return 2)
    println(io, "answer: ", id, isempty(item) ? "" : " / " * item, " answered `", option, "`.")
    if of_run && option == R.DOCS_ANSWER
        println(io, remade ? "answer: the reverted edit is made again and stands; the finding is closed." :
                             "answer: no reverted edit of it was found to make again; the finding is closed.")
    elseif of_run && option == R.RULED_ANSWER
        println(io, "answer: the finding is the fixer's again, to be made as you say; commit it with `gbg docfix commit --finding ", fid, "`, and a verifier closes it.")
    elseif of_run && option in (R.CODE_ANSWER, R.OWNER_ANSWER)
        # onto the OWNER's list, which no close rewrites: the finding lives only in its run's record, and
        # a line on the tool's section was erased at the next close (review, 2026-09-23)
        _, run, _ = found
        f = run.findings[findfirst(x -> R.code_question_id(run, x.id) == id, run.findings)]
        owner_line!(root, "- [ ] " * f.id * " " * one_line(f.draft.claim) * (isempty(direction) ? "" : " — " * one_line(direction)))
        println(io, "answer: the finding is on the owner's list in .claude/WORK_QUEUE.md, under \"", OWNER_HEADING, "\".")
    end
    if deferred
        println(io, "answer: it goes into the settled list when the run closes — agents are then told not to report it again.")
    elseif settled || (of_run && option == NOT_A_DEFECT)
        path = settle!(root, id, isempty(direction) ? option : direction)
        println(io, "answer: recorded in ", relpath(path, root), " — agents are told not to report it again.")
    end
    return 0
end

"""
    settle!(root, id, text) -> String

Records one answered question in the package's settled list, with the locations of the finding it was
about, so no agent reports it again. The arguments are:

- `root` — the package root.
- `id` — the question's id.
- `text` — what is settled, in the owner's words or the option chosen.

Returns the path written. A question already in the list is not written twice.
"""
function settle!(root::AbstractString, id::AbstractString, text::AbstractString)
    any(s -> s.question == id, ConfigIO.read_settled(root)) && return joinpath(root, ".gbg", "settled.jl")
    return ConfigIO.append_settled(root, Model.Settled(question = id, text = text, date = string(Dates.today()),
                                                       locations = settled_locations(root, id)))
end

"The heading of the owner's own list on the work queue: code he asked for, which no close rewrites and the end-of-turn hook does not count."
const OWNER_HEADING = "## Code the owner asked for"

one_line(t) = replace(strip(String(t)), r"\s*[\r\n]+\s*" => " ")

function owner_line!(root::AbstractString, line::AbstractString)
    path = joinpath(root, ".claude", "WORK_QUEUE.md")
    text = isfile(path) ? read(path, String) : "# Work queue\n"
    ls = split(text, '\n')
    i = findfirst(l -> rstrip(l) == OWNER_HEADING, ls)
    if i === nothing
        text = rstrip(text) * "\n\n" * OWNER_HEADING * "\n\n" * line * "\n"
    else
        j = something(findnext(l -> startswith(l, "#"), ls, i + 1), length(ls) + 1)
        k = j - 1; while k > i && isempty(strip(ls[k])); k -= 1; end
        text = join(vcat(ls[1:k], k == i ? [""] : String[], [line], ls[k+1:end]), '\n')
    end
    mkpath(dirname(path)); write(path, text)
end

function open_run_here(root)
    d = joinpath(root, ".gbg", "runs")
    isdir(d) || return nothing
    for x in sort(readdir(d); rev = true)
        isfile(joinpath(d, x, "stage")) && !isfile(joinpath(d, x, "run.json")) && return x
    end
    return nothing
end

"The option of a run's question that says the reader was wrong; answering it settles the matter."
const NOT_A_DEFECT = "not a defect"

# What a settled ruling covers: the locations of the finding the question was raised over. The question's
# id carries the finding's, so the run's record has them without the report being parsed.
function settled_locations(root::AbstractString, id::AbstractString)
    found = Orchestration.Runs.question_of(root, id)
    found === nothing && return Model.Location[]
    _, run, _ = found
    k = findfirst(f -> Orchestration.Runs.code_question_id(run, f.id) == id, run.findings)
    return k === nothing ? Model.Location[] : run.findings[k].draft.locations
end

"""
    put(root, decision; context, options, exhibit, io) -> Int

Puts one question to the owner. The arguments are:

- `root` — the package root.
- `decision` — the one decision it asks, in his words.
- `context` — what he needs to know to decide, in one sentence or none.
- `options` — the answers he may give, the first recommended.
- `exhibit` — what the question is about, quoted, where quoting it helps.
- `io` — where the result goes.

Exit 0 when it was recorded, 2 when it was refused.

Refused when the decision is empty or fewer than two options are given: a question with one answer is
a notification, and this is not how a session tells the owner something.

Its id is the date and a number, so two questions put on one day do not collide and an id sorts by
when it was asked. The `RULE.ASK.*` rules judge the wording, and a question that fails one is recorded
ANYWAY with the rule named: a question withheld because the tool disliked its phrasing is a question
the owner never gets to answer.

Until 2026-09-21 nothing in this package called [`Engine.Questions.put`](@ref) at all. `.gbg/questions.json`
was written by no verb and no instrument, so [`ask`](@ref) always answered that nothing was waiting,
[`answer`](@ref) had nothing to answer, and the skill of every instrument told a session to put a
question with `gbg ask`, which lists them.
"""
function put(root::AbstractString, decision::AbstractString; context::AbstractString = "",
             options::Vector{String} = String[], exhibit::AbstractString = "", io::IO = stdout)
    isempty(strip(decision)) && (println(io, "ask: the decision is empty"); return 2)
    length(options) >= 2 ||
        (println(io, "ask: a question needs at least two options; one answer is a notification"); return 2)
    cfg = ConfigIO.read_config(root)
    q = Model.Question(id = next_id(root), decision = strip(decision), context = strip(context),
                       exhibit = exhibit,
                       options = [Model.Option(o, "", i == 1) for (i, o) in enumerate(options)])
    Engine.Questions.put(q, root, cfg; io) ||
        (println(io, "ask: ", q.id, " is already here"); return 2)
    println(io, "ask: ", q.id, " is waiting for him.")
    return 0
end

# `<date>-<n>`: the date so an id says when it was asked, the number so a day takes more than one.
function next_id(root::AbstractString)
    today = string(Dates.today())
    taken = [get(q, "id", "") for q in Engine.Questions.open_questions(root)]
    n = 1
    while string(today, "-", n) in taken; n += 1; end
    return string(today, "-", n)
end

function cmd_ask(args)
    o = parse_options(args; valued = ["context", "options", "exhibit"])
    root = ConfigIO.require_root("ask")
    root === nothing && return 2
    isempty(o.positional) && isempty(o.values) && return ask(root)
    isempty(o.positional) &&
        (println(stderr, "usage: gbg ask | gbg ask \"<decision>\" --options \"<one> | <another>\" [--context \"…\"] [--exhibit \"…\"]"); return 2)
    return put(root, o.positional[1]; context = get(o.values, "context", ""),
               options = split_options(get(o.values, "options", "")), exhibit = get(o.values, "exhibit", ""))
end

# The options arrive as one value cut on `|`, rather than as a repeated flag: `parse_options` keeps one
# value per name and is shared by every verb, and widening it for this one would change all of them.
split_options(s::AbstractString) =
    [String(strip(p)) for p in split(s, '|') if !isempty(strip(p))]

function cmd_answer(args)
    o = parse_options(args; valued = ["item", "direction"])
    length(o.positional) >= 2 ||
        (println(stderr, "usage: gbg answer <question> \"<option>\" [--item \"…\"] [--direction \"…\"] [--settled]"); return 2)
    root = ConfigIO.require_root("answer")
    root === nothing && return 2
    return answer(root, o.positional[1], o.positional[2];
                  item = get(o.values, "item", ""), direction = get(o.values, "direction", ""),
                  settled = "settled" in o.flags)
end

VERBS["ask"] = cmd_ask
VERBS["answer"] = cmd_answer

end # module Answer
