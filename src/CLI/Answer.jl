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
    isempty(qs) && (println(io, "Nothing is waiting for an answer."); return 0)
    open_ones = 0
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
    why = Engine.Questions.answer!(root, id, option; item, direction)
    of_run = why !== nothing && Orchestration.Runs.question_of(root, id) !== nothing
    of_run && (why = Orchestration.Runs.answer!(root, id, option; item, direction))
    why === nothing || (println(io, "answer: ", why); return 2)
    println(io, "answer: ", id, isempty(item) ? "" : " / " * item, " answered `", option, "`.")
    where_ = of_run ? settled_locations(root, id) : Model.Location[]
    if settled || (of_run && option == NOT_A_DEFECT)
        path = ConfigIO.append_settled(root, Model.Settled(question = id,
                                                           text = isempty(direction) ? option : direction,
                                                           date = string(Dates.today()),
                                                           locations = where_))
        println(io, "answer: recorded in ", relpath(path, root), " — agents are told not to report it again.")
    end
    return 0
end

"The option of a run's question that says the reader was wrong; answering it settles the matter."
const NOT_A_DEFECT = "not a defect"

# What a settled ruling covers: the locations of the finding the question was raised over. The question's
# id carries the finding's, so the run's record has them without the report being parsed.
function settled_locations(root::AbstractString, id::AbstractString)
    found = Orchestration.Runs.question_of(root, id)
    found === nothing && return Model.Location[]
    _, run, _ = found
    k = findfirst(f -> occursin("-" * f.id * "-", id), run.findings)
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
