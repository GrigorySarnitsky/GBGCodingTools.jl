# The design's §8; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.Questions

The language a question to the owner is written in: one decision, short, in his words rather than the
tool's, with every identifier moved out of the sentence and into the exhibit.

These are batch e of the conversion, and the only rules in the rulebook with no ancestor — nothing in
the old tree checked how a person was addressed. They read a [`Model.Question`](@ref) rather than a file,
so they run when a question is PUT and never when a record is read: a question already answered was
written under whatever rules stood then, and re-judging it would fail to load an old record.
"""
module Questions

using ...Model

# A location inside a question names the field, not a line: there is no file to point at.
at(field::AbstractString, text::AbstractString) = Model.Location(; file = "", node = field, text = text)

"""
    one_decision(q, cfg) -> Vector{Model.Location}

Whether the decision is one sentence that asks something. The arguments are `q`, the question, and
`cfg`, the package's config, which this rule does not read. Returns one location when it is not.

Two sentences in the decision is two decisions, and the owner answers with one option: whichever he
means, the other is recorded as answered and was not.
"""
function one_decision(q::Model.Question, cfg)
    d = strip(q.decision)
    isempty(d) && return [at("decision", "the decision is empty")]
    out = Model.Location[]
    endswith(d, "?") || push!(out, at("decision", "does not end in a question mark: " * String(d)))
    # A sentence end INSIDE the decision, not the one closing it. `e.g.` and `i.e.` are not ends.
    body = replace(String(d[1:prevind(d, lastindex(d))]), r"\b(e\.g|i\.e|cf|vs|no)\.\s" => " ")
    occursin(r"[.!?]\s+\p{Lu}", body) && push!(out, at("decision", "more than one sentence: " * String(d)))
    return out
end

"""
    DECISION_WORDS

How many words a decision may be. A decision longer than this is a paragraph with a question mark on it.
"""
const DECISION_WORDS = Model.Parameter(:decision_words, 40)

"""
    CONTEXT_WORDS

How many words the context may be. What does not fit belongs in the exhibit, which no rule measures.
"""
const CONTEXT_WORDS = Model.Parameter(:context_words, 150)

words(s::AbstractString) = length(split(s))

"""
    short(q, cfg) -> Vector{Model.Location}

Whether the decision and the context are short enough to read in one pass. The arguments are `q`, the
question, and `cfg`, the package's config, which may set either limit. Returns one location per field
that is too long.

The exhibit is not measured. Commits, diffs and definitions are what the owner reads to decide, and a
limit on them would push the evidence out of the question rather than shortening it.
"""
function short(q::Model.Question, cfg)
    dmax = DECISION_WORDS.default; cmax = CONTEXT_WORDS.default
    for s in cfg.settings
        s.rule === SHORT.id || continue                 # the rule's own settings, as `Checks.reading` asks
        s.name === :decision_words && s.value isa Int && (dmax = s.value)
        s.name === :context_words  && s.value isa Int && (cmax = s.value)
    end
    out = Model.Location[]
    words(q.decision) > dmax && push!(out, at("decision", "$(words(q.decision)) words, and $dmax is the limit"))
    words(q.context)  > cmax && push!(out, at("context",  "$(words(q.context)) words, and $cmax is the limit"))
    return out
end

# What reads as a coordinate rather than as a sentence: a rule id, a finding id, a path, a code name.
# A word in backticks is exempt — quoting a name is how a question says "this exact name", and the
# owner asked for that in the very first question the design's own machinery put to him.
const COORDINATE = [
    r"\bRULE\.[A-Z]+\.[A-Z_]+" => "a rule id",
    r"\b[A-Za-z0-9_]+/[A-Za-z0-9_./-]+\.(jl|md|toml|json|ya?ml|sh)\b" => "a file path",
    r"\b[a-z][A-Za-z0-9_]*\(\)" => "a function call",
    # Any `a.b` is a qualified name — `io.write` as much as `Config.read` — except the English
    # abbreviations listed here: `e.g.` and `i.e.` are how a sentence gives an example, which
    # `one_decision` already allows for. The list is the only exception.
    r"\b(?!(?i:e\.g|i\.e|etc|vs|cf)\b)[A-Za-z_][A-Za-z0-9_]*\.[a-z][A-Za-z0-9_]*\b" => "a qualified name",
]

"""
    no_coordinates(q, cfg) -> Vector{Model.Location}

Whether the decision or the context names a rule, a file, or a piece of code. The arguments are `q`, the
question, and `cfg`, the package's config, which this rule does not read. Returns one location per
coordinate found.

They go in the items and the exhibit, which is where the owner looks when he wants them. A decision
carrying an identifier asks him to hold a coordinate in his head to reach the question, and the question
is the part he is being asked about.
"""
function no_coordinates(q::Model.Question, cfg)
    out = Model.Location[]
    for (field, text) in (("decision", q.decision), ("context", q.context))
        masked = replace(text, r"`[^`]*`" => " ")     # a quoted name is deliberate, not a leak
        for (re, what) in COORDINATE
            m = match(re, masked)
            m === nothing && continue
            push!(out, at(field, what * " in the $field: " * m.match))
            # Consumed before the next pattern looks: `src/Rules/shape.jl` is a file path AND reads as a
            # qualified name, and one coordinate reported twice tells a reader there are two things
            # wrong with a sentence that has one.
            masked = replace(masked, re => " ")
        end
    end
    return out
end

"""
    HOUSE_TERMS

The tooling package's own words, which mean nothing to a reader who does not work on it. A package adds
to the list; it never shortens it, since a term is on it because the owner did not recognise it.
"""
const HOUSE_TERMS = Model.Parameter(:house_terms,
    ["fileset", "file set", "ratchet", "anchor", "wiring check", "managed block", "pin", "switch",
     "rulebook", "instrument", "lane", "hat", "round", "harness", "consumer"])

"""
    no_house_terms(q, cfg) -> Vector{Model.Location}

Whether the decision or the context uses a word that belongs to this package rather than to the owner.
The arguments are `q`, the question, and `cfg`, the package's config, which may add terms. Returns one
location per term found.

The owner is being asked about his own work, in his own words. A question written in the tool's
vocabulary is answerable only by someone who has read the tool, which makes the answer the tool's.
"""
function no_house_terms(q::Model.Question, cfg)
    terms = copy(HOUSE_TERMS.default)
    for s in cfg.settings
        s.rule === NO_HOUSE_TERMS.id && s.name === :house_terms && s.value isa Vector{String} && append!(terms, s.value)
    end
    out = Model.Location[]
    for (field, text) in (("decision", q.decision), ("context", q.context))
        masked = replace(text, r"`[^`]*`" => " ")
        for t in terms
            # LITERAL, word by word, as `retired_claims` does: a term a package writes — `C++`, `f(x)` —
            # is never compiled as a pattern.
            words = [replace(w, r"([\\^$.|?*+()\[\]{}])" => s"\\\1") for w in split(strip(t))]
            isempty(words) && continue
            occursin(Regex("(?<![A-Za-z])" * join(words, "\\s+") * "(?![A-Za-z])", "i"), masked) &&
                push!(out, at(field, "a word of this package's own: " * t))
        end
    end
    return out
end

# ──────────────────────────────────────────────────────────────────────────────────── the five rules

const ASK = Model.Question(id = "q-example", decision = "Should the tolerance stay at its present value?",
                           context = "The current value was chosen once and has not been revisited.")

const ONE_DECISION = Model.Rule(
    id = Symbol("RULE.ASK.ONE_DECISION"),
    statement = "A question's decision is one sentence, and it ends in a question mark.",
    why = "Two sentences in a decision are two decisions, and the owner answers with one option: whichever he meant, the other is recorded as answered and was not.",
    intention = Model.Intention.DOCUMENTATION,
    check = Model.ProgramCheck(Model.Input.QUESTION, one_decision, false),
    examples = [
        Model.QuestionExample(ASK, Model.Location[], "one sentence ending in a question mark"),
        Model.QuestionExample(Model.Question(id = "q", decision = "The tolerance is old. Should it change?"),
            [Model.Location(; file = "", node = "decision")], "one sentence ending in a question mark"),
        Model.QuestionExample(Model.Question(id = "q", decision = "Decide whether the tolerance stays."),
            [Model.Location(; file = "", node = "decision")], "one sentence ending in a question mark"),
    ])

const SHORT = Model.Rule(
    id = Symbol("RULE.ASK.SHORT"),
    statement = "A question's decision and its context are short enough to read in one pass; its exhibit is not measured.",
    why = "What does not fit belongs in the exhibit, which holds the commits, the diffs and the definitions the owner reads to decide. A limit on the exhibit would push the evidence out of the question instead of shortening the question.",
    intention = Model.Intention.DOCUMENTATION,
    check = Model.ProgramCheck(Model.Input.QUESTION, short, false),
    parameters = [DECISION_WORDS, CONTEXT_WORDS],
    examples = [
        Model.QuestionExample(ASK, Model.Location[], "short enough to read in one pass"),
        Model.QuestionExample(Model.Question(id = "q", decision = join(fill("word", 60), " ") * "?"),
            [Model.Location(; file = "", node = "decision")], "short enough to read in one pass"),
        # The exhibit is long and is not measured, which is the second clause.
        Model.QuestionExample(Model.Question(id = "q", decision = "Should it stay?",
                                             exhibit = join(fill("commit", 400), " ")),
            Model.Location[], "short enough to read in one pass"),
    ])

const NO_COORDINATES = Model.Rule(
    id = Symbol("RULE.ASK.NO_COORDINATES"),
    statement = "A question's decision and context name no rule, file or piece of code; those go in its items and its exhibit.",
    why = "A decision carrying an identifier asks the owner to hold a coordinate in his head before he can reach the question, and the question is the part he is being asked about. A name in backticks is exempt: quoting one is how a question says which exact name it means.",
    intention = Model.Intention.DOCUMENTATION,
    check = Model.ProgramCheck(Model.Input.QUESTION, no_coordinates, false),
    examples = [
        Model.QuestionExample(ASK, Model.Location[], "names no rule, file or code"),
        Model.QuestionExample(Model.Question(id = "q", decision = "Should RULE.DOC.SHAPE stay on here?"),
            [Model.Location(; file = "", node = "decision")], "names no rule, file or code"),
        Model.QuestionExample(Model.Question(id = "q", decision = "Should it stay?",
                                             context = "It was added in src/Rules/shape.jl last week."),
            [Model.Location(; file = "", node = "context")], "names no rule, file or code"),
        # Backticked, the name is the question's subject rather than a coordinate the reader must resolve.
        Model.QuestionExample(Model.Question(id = "q", decision = "Should the option named `spectral` stay?"),
            Model.Location[], "names no rule, file or code"),
        # An English abbreviation is not a qualified name; a qualified name is.
        Model.QuestionExample(Model.Question(id = "q", decision = "Should the cap stay, e.g. at 120 words, i.e. as now, etc.?",
                                             context = "Pages vs. docstrings, cf. the last run."),
            Model.Location[], "names no rule, file or code"),
        Model.QuestionExample(Model.Question(id = "q", decision = "Should Shape.allowance stay at ten words?"),
            [Model.Location(; file = "", node = "decision")], "names no rule, file or code"),
        Model.QuestionExample(Model.Question(id = "q", decision = "Should io.write stay?", context = "Config.read is the other."),
            [Model.Location(; file = "", node = "decision"), Model.Location(; file = "", node = "context")],
            "names no rule, file or code"),
    ])

const NO_HOUSE_TERMS = Model.Rule(
    id = Symbol("RULE.ASK.NO_HOUSE_TERMS"),
    statement = "A question is written in the owner's words, not in this package's.",
    why = "He is being asked about his own work. A question written in the tool's vocabulary is answerable only by someone who has read the tool, which makes the answer the tool's rather than his.",
    intention = Model.Intention.DOCUMENTATION,
    check = Model.ProgramCheck(Model.Input.QUESTION, no_house_terms, false),
    parameters = [HOUSE_TERMS],
    examples = [
        Model.QuestionExample(ASK, Model.Location[], "written in the owner's words"),
        Model.QuestionExample(Model.Question(id = "q", decision = "Should this ratchet stay where it is?"),
            [Model.Location(; file = "", node = "decision")], "written in the owner's words"),
        Model.QuestionExample(Model.Question(id = "q", decision = "Should it stay?",
                                             context = "Every consumer would have to be told."),
            [Model.Location(; file = "", node = "context")], "written in the owner's words"),
    ])

const PLAIN = Model.Rule(
    id = Symbol("RULE.ASK.PLAIN"),
    statement = "A question reads plainly, stands on its own, and invents no word for something that already has one.",
    why = "A question is read once, by someone who was doing something else. Whether it can be answered without opening anything is a matter of meaning, which no program decides.",
    intention = Model.Intention.DOCUMENTATION,
    check = Model.AgentCheck(
        "Read this question as the owner will: once, having been interrupted. Can he answer it without opening a file, without asking what a word means, and without being told anything the question does not already say? Report the word or the sentence that fails, and nothing else.",
        Model.WhyAgent.MEANING))

const RULES = Model.Rule[ONE_DECISION, SHORT, NO_COORDINATES, NO_HOUSE_TERMS, PLAIN]

end # module Questions
