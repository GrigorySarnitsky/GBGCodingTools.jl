# The design's §4.2; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Guard

The change guard: the program that decides whether one changed file is a DOCUMENTATION change, which the
documentation fixer may commit on its own, or a CODE change, which waits for the owner
. It is the gate the whole automatic half rests on, so it answers `CODE`
whenever it is unsure.

Documentation is exactly: docstrings and comments in `.jl` files under `src/` and `ext/`; hand-written
Markdown under `docs/src/`; the package's `README.md`; and the rationale documents the config names.
Everything else is code — other `.jl` files whole, the config, stored data, generated files, CI and hook
files, `CLAUDE.md`, and any document the config declares normative.

For a `.jl` file that is on the documentation list, being on it is not enough: both versions must parse,
and with the docstrings and the standalone string literals removed, THE CODE MUST BE IDENTICAL. A
docstring whose target is a call rather than a definition is not documentation at all — Julia then
documents the call instead of running it — and neither is one built by interpolation.

Clause 0, a generated file equal to its generator's output, needs the generators, and the caller passes
their output in rather than this module reaching for them, since `Engine` may not name `Render`. Clause
3 — in GBGCodingTools only, a change confined to the plain string literals given to `statement` or `why`
of a `Rule(…)` call is documentation — is decided by comparing the two versions' shapes with those
literals elided; any other difference, a moved argument, a changed check or tag or an interpolated
statement among them, is code.
"""
module Guard

using ..Model
using ..Texts

const JS = Base.JuliaSyntax

"""
    Ruling

What the guard decided about one changed file, and why. The fields are:

- `path` — the file it is about.
- `documentation` — whether the change may be committed by the documentation fixer.
- `reason` — the clause that decided it, in one line a person can act on.
"""
struct Ruling
    path::String
    documentation::Bool
    reason::String
end

const LITERATE_MARKS = ("#src", "#md", "#jl", "#nb")

"""
    math_spans(text) -> Vector{String}

Every mathematical expression a text writes between single dollars, in order and with repetition. The
argument is `text`. Returns the expressions, whitespace flattened so that a re-wrapped line is the same
expression it was.
"""
math_spans(text::AbstractString) =
    [strip(replace(m.captures[1], r"\s+" => " ")) for m in eachmatch(r"(?<!\$)\$([^\$\n]+)\$(?!\$)", String(text))]

"""
    math_changed(before, after) -> Vector{String}

The mathematics this change adds or alters. The arguments are `before` and `after`, the file's text on
each side. Returns the expressions that are in `after` and were not in `before`, empty when the
mathematics is untouched.

CLAUSE 6, and the owner's ruling of 2026-09-21: **no edit inside a math span is made automatically**.
A program has no oracle for whether a formula is true — only the code it documents has that, and code
that is itself wrong then certifies prose that matches it — so a changed symbol, number or sign is put
to the owner as a question rather than committed. Whitespace alone is not a change, and a year in a
citation is not mathematics: it is not inside a math span to begin with.
"""
function math_changed(before::AbstractString, after::AbstractString)
    was = math_spans(before)
    now = math_spans(after)
    left = copy(was)
    out = String[]
    for span in now
        i = findfirst(==(span), left)
        i === nothing ? push!(out, String(span)) : deleteat!(left, i)
    end
    return out
end

"""
    on_documentation_list(cfg, path) -> Bool

Whether the path is one where documentation can live at all: a `.jl` file under `src/` or `ext/`,
hand-written Markdown under `docs/src/`, the package's `README.md`, or a rationale document the config
names. A document the config declares normative is never on the list, whatever else it looks like — a fix
that aligned a specification with the code would be authorising that code.

The arguments are `cfg`, the package's config, and `path`, the file's path relative to the package root.
Returns whether documentation may live there.
"""
function on_documentation_list(cfg::Model.Config, path::AbstractString)
    p = replace(path, '\\' => '/')
    # THREE refusals come first, before any path rule can admit the file. A normative document, a declared
    # build-time copy and a GENERATED page all LOOK like ordinary prose and none of them is. A copy's text
    # belongs to the source it is copied from and a fix landing in it is overwritten by the next build;
    # the same is true of a generated page, which is written from this package's own values, and which is
    # additionally full of text that breaks the rules it states — the rulebook page quotes every banned
    # spelling in order to ban it. Generated was missing here until 2026-09-22, when a reader launched
    # against three such pages on GBGPeriodicFields's first real run and the guard would have let their
    # fixes through.
    any(n -> replace(n, '\\' => '/') == p, cfg.normative) && return false
    any(f -> replace(first(f), '\\' => '/') == p, cfg.copies) && return false
    any(g -> replace(g, '\\' => '/') == p, cfg.generated) && return false
    endswith(p, ".jl") && (startswith(p, "src/") || startswith(p, "ext/")) && return true
    p == "README.md" && return true
    startswith(p, "docs/src/") && endswith(p, ".md") && return true
    literate(cfg, p) && return true
    return rationale(cfg, p)
end

# A LITERATE example is a `.jl` file that both runs and renders, and it was readable and unfixable until
# 2026-09-22: two rules judge it, and no path here admitted it, so every finding on one could only park
# on the owner's queue. Reported by GBGPeriodicFields on its first real run — and the hole was not its
# alone, since the DEFAULT pattern is `examples/**/*.jl`, so every package with an examples directory had
# it whether or not it declared the set.
#
# Nothing downstream needed changing, which is why this is one line. A Literate file is not a third kind
# of thing beside documentation and code: it is a `.jl` file, and the clauses after this one already
# decide per CHANGE rather than per file. Clause 2 parses both versions and refuses any change to the
# code itself, so a comment may be edited and a statement may not; clause 4 refuses a change that moves a
# Literate mark, which is what makes a comment render as prose; clause 5 refuses an executed block.
literate(cfg::Model.Config, p) =
    any(pat -> glob_matches(pat, p), get(cfg.filesets, Model.FileSet.LITERATE,
                                         Texts.DEFAULT_PATTERNS[Model.FileSet.LITERATE]))

# `**` spans directories, `*` stays within one name — the same two wildcards `Texts.expand` resolves,
# matched here against ONE path rather than walked over a tree, because the guard is given a path and no
# root and has no business touching disk to classify a change.
function glob_matches(pattern::AbstractString, path::AbstractString)
    pat = replace(pattern, '\\' => '/')
    rx = "^" * replace(replace(replace(replace(pat, "." => "\\."), "**/" => "\0ANY\0"),
                               "*" => "[^/]*"), "\0ANY\0" => "(?:.*/)?") * "\$"
    return occursin(Regex(rx), path)
end

rationale(cfg::Model.Config, p) = any(r -> replace(r, '\\' => '/') == p, get(cfg.filesets, Model.FileSet.RATIONALE, String[]))

"""
    classify(cfg, path, before, after; generated = nothing) -> Ruling

What one changed file is: documentation, which the documentation fixer may commit, or code, which waits
for the owner. The arguments are:

- `cfg` — the package's config, which names the rationale documents, the declared copies and the
  normative documents.
- `path` — the file's path relative to the package root.
- `before` and `after` — its content on each side of the change; `nothing` for a file that was added or
  removed, which is always code.
- `generated` — what this path's generator produces now, for clause 0; `nothing` where no generator
  writes it. Passed in by the caller, because the generators live above this module.

Returns the [`Ruling`](@ref), whose reason names the clause that decided it.
"""
function classify(cfg::Model.Config, path::AbstractString, before, after; generated = nothing)
    if generated !== nothing && after == generated
        return Ruling(path, true, "a generated file equal to what its generator produces now (clause 0)")
    end
    before === nothing && return Ruling(path, false, "the file is new: a file nobody has reviewed is code")
    after === nothing && return Ruling(path, false, "the file was removed, which no documentation fix does")
    before == after && return Ruling(path, true, "unchanged")
    on_documentation_list(cfg, path) ||
        return Ruling(path, false, "not a path where documentation lives (clause 1)")

    rule_prose = false
    if endswith(path, ".jl")
        shape_before = code_shape(before)
        shape_after = code_shape(after)
        shape_before === nothing && return Ruling(path, false, "the file did not parse before the change (clause 2)")
        shape_after === nothing && return Ruling(path, false, "the file does not parse after the change (clause 2)")
        if shape_before != shape_after
            # Clause 3, in the tooling package alone: the statement and why of a rule are its prose, and a
            # change confined to those literals is documentation. Everything else about a rule is code.
            rule_prose = cfg.package == "GBGCodingTools" &&
                         code_shape(before; rule_prose = true) == code_shape(after; rule_prose = true)
            rule_prose || return Ruling(path, false, "the code changed, not only its docstrings and comments (clause 2)")
        end
        literate_changed(before, after) &&
            return Ruling(path, false, "a comment carrying a Literate mark changed, which moves what runs (clause 4)")
    end

    fenced_kept(before, after) ||
        return Ruling(path, false, "a doctest or an `@` block changed: those are run, not read (clause 5)")
    changed = math_changed(before, after)
    isempty(changed) ||
        return Ruling(path, false, "mathematics changed, which is the owner's to answer (clause 6): " *
                                   join("`" .* first.(changed, 60) .* "`", ", "))
    rule_prose && return Ruling(path, true, "the prose of a rule — its statement or why — and nothing else (clause 3)")
    return Ruling(path, true, "docstrings, comments or prose only")
end

# ────────────────────────────────────────────────────────────────────── clause 2: the code itself

"""
    code_shape(src) -> Union{String,Nothing}

The Julia source with everything that is documentation taken out of it: docstrings whose text is a plain
literal and whose target is a definition, and string literals standing alone at top level or in a struct
body. What is left is written out in a canonical form that holds no line numbers, so two versions differing
only in their prose have the same shape and any other difference shows.

A docstring whose target is a CALL, or a macro call that does not define anything, is left in: Julia then
documents the call instead of running it, so removing it would hide a change in what the file does. So is
one built by interpolation, whose text is a program.

The arguments are `src`, the file's content, and `rule_prose`, whether the plain string literals given to
`statement` or `why` inside a `Rule(…)` call are elided too (clause 3). Returns the shape, or `nothing`
when the source does not parse.
"""
function code_shape(src::AbstractString; rule_prose::Bool = false)
    tree = try
        JS.parseall(JS.SyntaxNode, src; filename = "shape.jl")
    catch
        return nothing
    end
    any_error(tree) && return nothing
    io = IOBuffer()
    shape!(io, tree, false; rule_prose, in_rule = false)
    return String(take!(io))
end

any_error(node) = JS.kind(node) === JS.K"error" ||
                  any(any_error, something(JS.children(node), ()))

# `in_struct` says whether a bare string here is a field docstring, which is documentation like any other.
# `in_rule` says whether this node sits inside a `Rule(…)` call, where — with `rule_prose` — the plain
# string literal of a `statement = "…"` or `why = "…"` keyword is elided as that rule's prose.
function shape!(io, node, in_struct; rule_prose::Bool = false, in_rule::Bool = false)
    k = JS.kind(node)
    cs = something(JS.children(node), ())

    if k === JS.K"doc" && length(cs) >= 2 && removable_doc(cs[1], cs[2])
        shape!(io, cs[2], in_struct; rule_prose, in_rule)    # the docstring goes; what it documents stays
        return
    end
    if rule_prose && in_rule && k === JS.K"=" && length(cs) == 2 && is_prose_keyword(cs[1]) && plain_string(cs[2])
        print(io, "(= ", strip(String(JS.sourcetext(cs[1]))), " <prose>)")
        return
    end
    if (k === JS.K"string" || k === JS.K"String") && in_struct
        return                                              # a field docstring
    end
    if isempty(cs)
        print(io, "(", k, " ", strip(String(JS.sourcetext(node))), ")")
        return
    end
    print(io, "(", k)
    nested = in_struct || k === JS.K"struct" || is_kwdef_struct(node)
    inside = in_rule || (k === JS.K"call" && !isempty(cs) && is_rule_callee(cs[1]))
    for c in cs
        # a bare string standing alone in a block is an unattached docstring, not code
        if JS.kind(c) === JS.K"string" && (k === JS.K"toplevel" || k === JS.K"block" || k === JS.K"module")
            continue
        end
        print(io, " ")
        shape!(io, c, nested && k !== JS.K"toplevel"; rule_prose, in_rule = inside)
    end
    print(io, ")")
end

# `Rule(` or `Model.Rule(`: the one constructor whose statement and why are prose (clause 3).
is_rule_callee(node) = (t = strip(String(JS.sourcetext(node))); t == "Rule" || endswith(t, ".Rule"))
is_prose_keyword(node) = JS.kind(node) === JS.K"Identifier" && strip(String(JS.sourcetext(node))) in ("statement", "why")
plain_string(node) = JS.kind(node) === JS.K"string" &&
                     all(c -> JS.kind(c) === JS.K"String", something(JS.children(node), ()))

is_kwdef_struct(node) = JS.kind(node) === JS.K"macrocall" &&
                        occursin(r"@kwdef\b", String(JS.sourcetext(node))) &&
                        occursin(r"\bstruct\b", String(JS.sourcetext(node)))

# A docstring may be dropped only when it is a plain literal AND documents something Julia would define.
function removable_doc(text_node, target)
    JS.kind(text_node) in (JS.K"string", JS.K"String") || return false
    kids = [c for c in something(JS.children(text_node), ()) if JS.kind(c) !== JS.K"String"]
    isempty(kids) || return false                           # interpolation: the text is a program
    return defining(target)
end

const DEFINING_KINDS = (JS.K"function", JS.K"macro", JS.K"struct", JS.K"abstract", JS.K"primitive",
                        JS.K"const", JS.K"module", JS.K"=")

function defining(node)
    k = JS.kind(node)
    k in DEFINING_KINDS && return true
    if k === JS.K"macrocall"
        # `@kwdef`, `@enum` and their kind define; any other macro call is a call, and documenting a call
        # replaces it rather than running it.
        t = String(JS.sourcetext(node))
        return occursin(r"@(?:Base\.)?kwdef\b", t) || occursin(r"@enum\b", t) ||
               any(defining, something(JS.children(node), ()))
    end
    return false
end

# ─────────────────────────────────────────────────────────── clauses 4 and 5: marks and fenced blocks

"""
    literate_changed(before, after) -> Bool

Whether any comment carrying a Literate mark — `#src`, `#md`, `#jl`, `#nb` — differs between the two
versions. Those marks decide which lines of a script are executed, rendered or dropped, so a change to one
changes what runs. The arguments are the two versions. Returns whether such a comment moved.
"""
function literate_changed(before::AbstractString, after::AbstractString)
    marked(s) = [strip(l) for l in split(s, '\n') if any(m -> occursin(m, l), LITERATE_MARKS)]
    return marked(before) != marked(after)
end

"""
    fenced_kept(before, after) -> Bool

Whether every fenced block that is RUN rather than read is identical in both versions, in the same order
and with the same info string: a doctest (` ```jldoctest `) and every Documenter block whose info string
starts with `@` (`@example`, `@eval`, `@setup`, `@meta`, `@raw`, `@docs`, `@autodocs`, `@index`,
`@contents`). Their content is executed or collected at build time, so an edit to one is a code change
however much it looks like prose.

The arguments are the two versions. Returns whether they all survived unchanged.
"""
function fenced_kept(before::AbstractString, after::AbstractString)
    return run_blocks(before) == run_blocks(after)
end

function run_blocks(src::AbstractString)
    out = Tuple{String,String}[]
    info = nothing
    buf = IOBuffer()
    for line in split(src, '\n')
        m = match(r"^\s*```+\s*(.*?)\s*$", line)
        if m !== nothing
            if info === nothing
                tag = String(m.captures[1])
                info = startswith(tag, "jldoctest") || startswith(tag, "@") ? tag : ""
            else
                info == "" || push!(out, (info, String(take!(buf))))
                take!(buf); info = nothing
            end
            continue
        end
        info === nothing || info == "" || println(buf, line)
    end
    return out
end

end # module Guard
