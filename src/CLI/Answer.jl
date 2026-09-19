# The design's §8; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Answer

`gbg ask` and `gbg answer`: the two ends of putting a decision to the owner.

`gbg ask` lists what is waiting for him, and `gbg answer <question> <option>` records what he said. A
question of a run is answered in that run's record; these are the rest, kept in `.gbg/questions.json`.

An answered question never returns. Recording an answer twice is refused rather than overwritten: the
second would replace a ruling with a later reading of the same words, and the first is the one he gave.
"""
module Answer

using Dates
using ..GBGCodingTools: GBGCodingTools, ConfigIO, Engine, Model, parse_options, VERBS

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
"""
function answer(root::AbstractString, id::AbstractString, option::AbstractString;
                item::AbstractString = "", direction::AbstractString = "",
                settled::Bool = false, io::IO = stdout)
    why = Engine.Questions.answer!(root, id, option; item, direction)
    why === nothing || (println(io, "answer: ", why); return 2)
    println(io, "answer: ", id, isempty(item) ? "" : " / " * item, " answered `", option, "`.")
    if settled
        path = ConfigIO.append_settled(root, Model.Settled(question = id,
                                                           text = isempty(direction) ? option : direction,
                                                           date = string(Dates.today())))
        println(io, "answer: recorded in ", relpath(path, root), " — agents are told not to report it again.")
    end
    return 0
end

function cmd_ask(args)
    root = ConfigIO.require_root("ask")
    root === nothing && return 2
    return ask(root)
end

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
