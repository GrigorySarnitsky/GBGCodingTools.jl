# The design's §12; the coordinates live here rather than in a docstring, which must read complete at
# the REPL.
"""
    Study

Whether a rule's text says what deciding it requires — MEASURED, and not argued.

Three readers are given a rule's text and nothing else, and answer the same questions about it: what
must be read to decide it, whether deciding it needs a discipline, and whether the wording left them
guessing. Their AGREEMENT is the result. A rule they answer differently about is a rule whose text says
two things, and that is a fact about the wording, which no amount of discussion can move.

**It converges on nothing, and there is nothing to converge.** This was called an attack on the rules
until 2026-09-21, and the name was wrong twice over: an attack collects objections until they stop,
which rewards a text that claims less, and the narrowing that produced is a measured failure of this
project rather than a worry [`docs/design-record/08-discipline-attack.md`]. Here nobody objects. Three
readers answer, the answers agree or they do not, and rewording is what the disagreement is FOR.

**What it does with a disagreement.** Nothing, by itself. A rule the readers split on is reported, and a
rule whose majority answer differs from the tag the rulebook actually carries becomes a PROPOSAL, which
becomes a question to the owner. A tag is code: it changes on his answer and never on a measurement.
"""
module Study

using ..Model
using ..Catalogue

"""
    Tag

One reader's answer about one rule. The fields are:

- `rule` — the rule's id, as the vote file spells it.
- `reader` — which of the three answered.
- `needs` — what must be read to decide it, as a set of access names; empty is "the text alone".
- `discipline` — whether deciding it needs a field of expertise: `true` for a discipline's, `false` for
  a generalist's.
- `flagged` — whether the wording left this reader guessing.
"""
Base.@kwdef struct Tag
    rule::String
    reader::String
    needs::Set{String} = Set{String}()
    discipline::Bool = false
    flagged::Bool = false
end

"""
    Round

One round of the study, and what its arithmetic says. The fields are:

- `tags` — every answer, three per rule.
- `rules` — the rules answered about, in the file's order.
- `needs_kappa` — agreement on what must be read, as Fleiss' kappa.
- `discipline_kappa` — agreement on whether a discipline is needed.
- `splits` — the rules the three did not answer alike about what must be read.
- `flagged` — the rules at least one reader flagged as leaving them guessing.
"""
Base.@kwdef struct Round
    tags::Vector{Tag} = Tag[]
    rules::Vector{String} = String[]
    needs_kappa::Float64 = 0.0
    discipline_kappa::Float64 = 0.0
    splits::Vector{String} = String[]
    flagged::Vector{String} = String[]
end

"The shorthand a vote may be written in, against the access name the rulebook uses."
const SPELLING = Dict("OTHER" => "OTHER_DOCUMENTS", "OTHER_DOCS" => "OTHER_DOCUMENTS",
                      "CITED" => "CITED_WORK", "CODE" => "SOURCE", "SITE" => "RENDERED")

spelled(token::AbstractString) = get(SPELLING, String(token), String(token))

"""
    read_round(path) -> Round

Reads a round's votes from a tab-separated file and measures it. The argument is `path`, the file.
Returns the round.

The columns are `rule` and then three per reader: `<R>_w`, what must be read, `+`-joined and `NOTHING`
for the text alone; `<R>_c`, `G` for a generalist's rule and `D` for a discipline's; and, where a round
recorded it, `<R>_f`, `1` where the wording left that reader guessing. A round without the flag columns
is read as a round where nobody flagged anything, which is what round 0 was.

A vote is written in the SHORTHAND the readers were offered and read back in the rulebook's own access
names, so `OTHER` and `CITED_WORK` are the same answer written twice. Without that, every rule needing
another document drifts from the rulebook by spelling alone, and ten questions are put to the owner
about nothing.
"""
function read_round(path::AbstractString)
    lines = [l for l in split(read(path, String), '\n') if !isempty(strip(l))]
    isempty(lines) && return Round()
    head = split(strip(lines[1]), '\t')
    col = Dict(String(h) => i for (i, h) in enumerate(head))
    readers = sort([String(h[1:end-2]) for h in head if endswith(String(h), "_w")])
    tags, rules = Tag[], String[]
    for l in lines[2:end]
        cells = split(strip(l, '\n'), '\t')
        length(cells) < length(head) && continue
        rule = String(cells[col["rule"]])
        push!(rules, rule)
        for r in readers
            needs = Set(spelled(p) for p in split(String(cells[col[r * "_w"]]), '+') if p != "NOTHING" && !isempty(p))
            flag = haskey(col, r * "_f") && strip(String(cells[col[r * "_f"]])) == "1"
            push!(tags, Tag(rule = rule, reader = r, needs = needs,
                            discipline = strip(String(cells[col[r * "_c"]])) == "D", flagged = flag))
        end
    end
    return measure(tags, rules)
end

"""
    measure(tags, rules) -> Round

The arithmetic over a round's answers. The arguments are `tags`, every answer, and `rules`, the rules in
the order to report them. Returns the round with its four measurements filled in.
"""
function measure(tags::AbstractVector{Tag}, rules::AbstractVector{<:AbstractString})
    by = Dict{String,Vector{Tag}}()
    for t in tags; push!(get!(by, t.rule, Tag[]), t); end
    kept = [r for r in rules if haskey(by, r)]
    needs = [[join(sort(collect(t.needs)), "+") for t in by[r]] for r in kept]
    disc = [[string(t.discipline) for t in by[r]] for r in kept]
    return Round(tags = collect(tags), rules = collect(kept),
                 needs_kappa = fleiss(needs), discipline_kappa = fleiss(disc),
                 splits = [r for r in kept if length(Set(t.needs for t in by[r])) > 1],
                 flagged = [r for r in kept if any(t.flagged for t in by[r])])
end

"""
    fleiss(per_item) -> Float64

Fleiss' kappa over `per_item`, one vector of labels per item, each the same length. The argument is
`per_item`. Returns the coefficient, and `1.0` where every reader gave every item the same label, which
the formula leaves undefined by dividing by zero.

Chosen over a bare agreement rate because three readers who all answer "the source" about every rule
agree perfectly by accident: kappa asks how much of the agreement is more than the labels' own
frequencies would give.
"""
function fleiss(per_item::AbstractVector)
    isempty(per_item) && return 0.0
    n = length(first(per_item))
    n < 2 && return 1.0
    counts = Dict{String,Int}()
    agree = Float64[]
    for labels in per_item
        here = Dict{String,Int}()
        for l in labels
            here[l] = get(here, l, 0) + 1
            counts[l] = get(counts, l, 0) + 1
        end
        push!(agree, (sum(v * v for v in values(here)) - n) / (n * (n - 1)))
    end
    N = length(per_item)
    observed = sum(agree) / N
    expected = sum((v / (N * n))^2 for v in values(counts))
    return expected < 1 ? (observed - expected) / (1 - expected) : 1.0
end

"""
    drift(round, rules) -> Vector{NamedTuple}

Where the readers' majority answer differs from the tag a rule actually carries. The arguments are
`round`, a measured round, and `rules`, the rulebook. Returns one entry per disagreement, each with the
rule's id, what the rulebook says, and what the readers said.

A rule the readers SPLIT on is left out: they did not agree on an answer, so there is no majority to
hold the rulebook to, and the finding about it is the split itself.
"""
function drift(round::Round, rules::AbstractVector{Model.Rule})
    by = Dict{String,Vector{Tag}}()
    for t in round.tags; push!(get!(by, t.rule, Tag[]), t); end
    out = NamedTuple{(:rule, :rulebook, :readers),Tuple{String,String,String}}[]
    for id in round.rules
        id in round.splits && continue
        r = findfirst(x -> endswith(String(x.id), id) || String(x.id) == id, rules)
        r === nothing && continue
        said = join(sort(collect(first(by[id]).needs)), "+")
        said = isempty(said) ? "NOTHING" : said
        held = join(sort([String(Symbol(a)) for a in rules[r].access]), "+")
        held = isempty(held) ? "NOTHING" : held
        said == held || push!(out, (rule = id, rulebook = held, readers = said))
    end
    return out
end

"""
    question_of(entry) -> Model.Question

The question one drift becomes. The argument is `entry`, one of [`drift`](@ref)'s entries. Returns the
question, whose options are the only two answers there are: the rulebook is right, or the readers are.

A measurement never edits a tag. A tag is code, it decides which reader judges a rule, and a rule that
moved to a reader nobody chose is a rule judged by somebody the owner did not pick.
"""
question_of(entry) = Model.Question(
    id = string("tag-", lowercase(replace(entry.rule, "." => "-"))),
    decision = "Which is right about what deciding this rule needs?",
    context = string("Three readers given only the rule's text agreed on ", entry.readers,
                     "; the rulebook says ", entry.rulebook, "."),
    options = [Model.Option(string("keep ", entry.rulebook), "the rulebook stands and the wording is what moved the readers", true),
               Model.Option(string("change to ", entry.readers), "the tag changes, and with it which reader judges this rule", false)],
    exhibit = entry.rule)

end # module Study
