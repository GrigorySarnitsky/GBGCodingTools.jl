# The design's §8; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Questions

Applying the language rules to a question, at the moment it is put.

It selects the rules itself, out of `Catalogue.RULES`, rather than holding a list: a rule whose input is
a question is one of these, and nothing else has to be told when one is added. No rule text is copied
here, so a reworded rule applies to the next question without an edit in this file.

**Never when a record is read.** A question already answered was written under whatever rules stood
then, and judging it again under today's would fail to load an old run.
"""
module Questions

using ..Model
using ..Catalogue
using ..Engine.Checks
using ..Engine
using JSON3

"""
    rules() -> Vector{Model.Rule}

The language rules: every rule of the rulebook whose program check reads a question. Returns them in
catalogue order.
"""
rules() = filter(r -> r.check isa Model.ProgramCheck && r.check.input === Model.Input.QUESTION,
                 Catalogue.RULES)

"""
    check(q, cfg) -> Vector{Tuple{Symbol,Model.Location}}

Everything the language rules find wrong with one question. The arguments are `q`, the question about to
be put, and `cfg`, the package's config, which may switch a rule off or set a limit. Returns the rule id
and the location for each, in the order the rules are declared; empty means the question may be shown.

A rule this package has switched off is not applied, the same as anywhere else: a package that does not
want a limit on how it addresses its own owner is entitled to say so, with a reason, on its own site.
The agent-decided language rules are not here — an agent judges those before a question is shown, and
this is the program half.
"""
function check(q::Model.Question, cfg::Model.Config)
    out = Tuple{Symbol,Model.Location}[]
    for rule in rules()
        Checks.applies(cfg, rule.id) || continue
        for loc in rule.check.run(q, cfg)
            push!(out, (rule.id, loc))
        end
    end
    return out
end

"""
    report(q, cfg) -> String

What the language rules find wrong with one question, as lines a session can read. The arguments are
`q`, the question, and `cfg`, the package's config. Returns an empty string when nothing is wrong.

A failing question is rewritten once and then shown with the failed rule named, so the owner can see
that the tool knew and asked anyway, rather than wondering whether anything checked it at all.
"""
function report(q::Model.Question, cfg::Model.Config)
    found = check(q, cfg)
    isempty(found) && return ""
    io = IOBuffer()
    for (id, loc) in found
        println(io, "  ", rpad(String(id), 30), isempty(loc.node) ? "" : loc.node * ": ", loc.text)
    end
    return String(take!(io))
end


# ─────────────────────────────────────────────────────── where a question waits for an answer

"""
    store(root) -> String

Where questions put outside a run wait for their answers. The argument is `root`, the package root.
Returns the path.

A run's own questions live in its run record; these are the rest — the wiring check that could not read
a config, a rule counterexample, a proposed program check. They are JSON rather than Julia because a
verb writes them and nothing hand-edits them, which is the opposite of `config.jl`.
"""
store(root::AbstractString) = joinpath(root, ".gbg", "questions.json")

"""
    open_questions(root) -> Vector{Dict{String,Any}}

Every question put outside a run in this package, answered or not. The argument is `root`, the package
root. Returns them in the order they were put; an absent file is no questions.
"""
function open_questions(root::AbstractString)
    path = store(root)
    isfile(path) || return Dict{String,Any}[]
    return Vector{Dict{String,Any}}(JSON3.read(read(path, String), Vector{Dict{String,Any}}))
end

"""
    put(q, root, cfg; io = stdout) -> Bool

Records a question so the owner can answer it, after the language rules have judged it.

# Arguments

- `q` — the question.
- `root` — the package root.
- `cfg` — the package's config.
- `io` — where a refusal is reported.

Returns whether it was recorded.

A question that fails a language rule is recorded anyway, with the failed rules printed. The design has
a failing question rewritten once and then shown with the rule named: a question withheld because the
tool disliked its wording is a question the owner never gets to answer, and the rule was written to
improve questions, not to suppress them.
"""
function put(q::Model.Question, root::AbstractString, cfg::Model.Config; io::IO = stdout)
    failed = report(q, cfg)
    isempty(failed) || (println(io, "question ", q.id, " does not read as it should:"); print(io, failed))
    qs = open_questions(root)
    any(x -> get(x, "id", "") == q.id, qs) && return false      # a question is put once
    push!(qs, Dict{String,Any}("id" => q.id, "decision" => q.decision, "context" => q.context,
                               "exhibit" => q.exhibit, "answer" => nothing, "direction" => "",
                               "options" => [Dict("label" => o.label, "consequence" => o.consequence,
                                                  "recommended" => o.recommended) for o in q.options],
                               "items" => [Dict{String,Any}("text" => i.text, "recommended" => i.recommended,
                                                            "answer" => nothing, "direction" => "") for i in q.items]))
    mkpath(dirname(store(root)))
    Engine.Guard.refuse_publication(JSON3.write(qs), ".gbg/questions.json")
    open(store(root), "w") do f; JSON3.pretty(f, JSON3.write(qs)); end
    return true
end

"""
    answer!(root, id, option; item = "", direction = "") -> Union{String,Nothing}

Records the owner's answer on a question put outside a run, or the reason it could not be.

# Arguments

- `root` — the package root.
- `id` — the question's id.
- `option` — the label he chose.
- `item` — the item it answers, empty for a question with none.
- `direction` — how he wants it done, where his answer carried that.

Returns the refusal in words, or `nothing` when the answer was recorded.

An answered question never returns, so recording one twice would overwrite a ruling with a later
reading of the same words: answering an answered question is refused and the first answer stands.
"""
function answer!(root::AbstractString, id::AbstractString, option::AbstractString;
                 item::AbstractString = "", direction::AbstractString = "")
    qs = open_questions(root)
    i = findfirst(x -> get(x, "id", "") == id, qs)
    i === nothing && return "no question here is called $id"
    q = qs[i]
    labels = [get(o, "label", "") for o in get(q, "options", [])]
    isempty(labels) || option in labels ||
        return "$option is not one of its options: " * join(labels, ", ")
    if isempty(item)
        isempty(get(q, "items", [])) || return "it is asked per item; name the item"
        q["answer"] === nothing || return "it was already answered: " * string(q["answer"])
        q["answer"] = option; q["direction"] = direction
    else
        j = findfirst(x -> get(x, "text", "") == item, q["items"])
        j === nothing && return "no item of $id reads: $item"
        q["items"][j]["answer"] === nothing || return "that item was already answered"
        q["items"][j]["answer"] = option; q["items"][j]["direction"] = direction
    end
    Engine.Guard.refuse_publication(JSON3.write(qs), ".gbg/questions.json")
    open(store(root), "w") do f; JSON3.pretty(f, JSON3.write(qs)); end
    return nothing
end

end # module Questions
