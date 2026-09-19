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

A failing question is rewritten once and then shown with the failed rule NAMED, so the owner can see
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

end # module Questions
