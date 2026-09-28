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
and with the text inside the docstrings and comments it already has taken out, THE FILE MUST BE
IDENTICAL BYTE FOR BYTE — the simple rule of 2026-09-23 that [`regions`](@ref) states. A docstring or a
comment is never added, removed or moved by the fixer, and the literal pieces of an interpolated
docstring are its prose while the interpolations are code.

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
using Markdown

using JuliaSyntax: JuliaSyntax
const JS = JuliaSyntax   # the registered parser, pinned: its trees do not change when Julia does

"""
    Ruling

What the guard decided about one changed file, and why.

# Fields

- `path` — the file it is about.
- `documentation` — whether the change may be committed by the documentation fixer.
- `reason` — the clause that decided it, in one line a person can act on.
"""
struct Ruling
    path::String
    documentation::Bool
    reason::String
end

const LITERATE_MARKS = ("#src", "#md", "#jl", "#nb", "#!md", "#!jl", "#!nb")

# What Julia's Markdown parser reads in one text, in document order: every formula, and the sequence of
# spans — inline code, inline mathematics, or a DISPLAY formula — with their text, which is what a
# respelling is judged on. A formula is inline when it stands inside a paragraph, a heading or a table
# cell (a cell holds inline content only), and display anywhere else; the two were one kind, so a display formula made a plain code fence with the
# same text passed as a respelling (found in review, 2026-09-26).
function parsed_math(text::AbstractString)
    math = String[]; spans = Tuple{Symbol,String}[]
    md = try Markdown.parse(String(text)) catch; return math, spans end
    math_walk!(md, false) do x, inline
        if x isa Markdown.LaTeX
            f = strip(replace(x.formula, r"\s+" => " ")); push!(math, f); push!(spans, (inline ? :math : :display, f))
        elseif x isa Markdown.Code && isempty(x.language)
            push!(spans, (:code, strip(replace(x.code, r"\s+" => " "))))
        end
    end
    return math, spans
end

# `md_walk` with the one thing it does not carry: whether the node stands inside a paragraph, heading or
# table cell.
function math_walk!(f, x, inline::Bool)
    f(x, inline)
    inline |= x isa Markdown.Paragraph || x isa Markdown.Header || x isa Markdown.Table
    if x isa AbstractVector
        foreach(y -> math_walk!(f, y, inline), x)
    elseif !(x isa AbstractString || x isa Symbol || x isa Number || x === nothing)
        for n in fieldnames(typeof(x))
            v = getfield(x, n)
            (v isa AbstractVector || parentmodule(typeof(v)) === Markdown) && math_walk!(f, v, inline)
        end
    end
end

# Every node of a parsed Markdown tree, depth first, in document order.
function md_walk(f, x)
    f(x)
    if x isa AbstractVector
        foreach(y -> md_walk(f, y), x)
    elseif !(x isa AbstractString || x isa Symbol || x isa Number || x === nothing)
        for n in fieldnames(typeof(x))
            v = getfield(x, n)
            (v isa AbstractVector || parentmodule(typeof(v)) === Markdown) && md_walk(f, v)
        end
    end
end

"""
    math_changed(before, after; jl = false, literate = false) -> Vector{String}

The mathematics this change adds, alters, removes or reorders.

# Arguments

- `before` and `after` — the file's text on each side.
- `jl` — whether it is a Julia file, whose mathematics is read in its docstrings, never in its code.
- `literate` — whether it is a Literate example, whose comments render and are read too.

Returns the expressions that differ — those added, then those removed — and, where the same expressions
now stand in a different order, all of them; empty when the mathematics is untouched.

CLAUSE 6, and the owner's ruling of 2026-09-21: **no edit inside a math span is made automatically**.
A program has no oracle for whether a formula is true — only the code it documents has that, and code
that is itself wrong then certifies prose that matches it — so a changed symbol, number or sign is put
to the owner as a question rather than committed. Deleting a formula and swapping two are edits too.

One change is spelling and not mathematics: an inline code span made a math span with the same text,
or back, in the same place — the fix the LaTeX rules ask for. Judged position by position, so swapping
the texts of a code span and a math span is a change. Whitespace alone is not, nor a year in a citation.
"""
function math_changed(before::AbstractString, after::AbstractString; jl::Bool = false, literate::Bool = false)
    tb = jl ? something(texts_of(before; literate), String[String(before)]) : String[String(before)]
    ta = jl ? something(texts_of(after; literate), String[String(after)]) : String[String(after)]
    return math_diff_texts(tb, ta)
end

function math_diff_texts(tb::Vector{String}, ta::Vector{String})
    # text by text where the texts correspond — the same docstrings in the same order — so a formula
    # moved from one function's docstring to another's is a change; pooled where docstrings came or went
    pairs = length(tb) == length(ta) ? collect(zip(tb, ta)) : [(join(tb, "\n\n"), join(ta, "\n\n"))]
    out = String[]
    for (b, a) in pairs
        (mb, sb) = parsed_math(b); (ma, sa) = parsed_math(a)
        mb == ma && continue
        # a respelling: the same span texts in the same order, inline kinds flipped, and every display
        # formula still a display formula where it stood
        displays(sq) = [k === :display for (k, _) in sq]
        respelled = last.(sb) == last.(sa) && displays(sb) == displays(sa)
        respelled && continue
        d = vcat(multiset_minus(ma, mb), multiset_minus(mb, ma))
        append!(out, isempty(d) ? ma : d)
    end
    return unique(String.(out))
end

function multiset_minus(xs, ys)
    left = collect(ys); out = String[]
    for x in xs
        i = findfirst(==(x), left)
        i === nothing ? push!(out, String(x)) : deleteat!(left, i)
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
    any(pat -> Texts.glob_matches(pat, p), get(cfg.filesets, Model.FileSet.LITERATE,
                                               Texts.DEFAULT_PATTERNS[Model.FileSet.LITERATE]))

# The rationale set by its PATTERNS and with its default, as every other file set is read: comparing the
# raw entries, with no default, refused a fix to `docs/ARCHITECTURE.md` in every package that declared no
# set, although that document is a target of the review (found 2026-09-24).
rationale(cfg::Model.Config, p) =
    any(pat -> Texts.glob_matches(pat, p), get(cfg.filesets, Model.FileSet.RATIONALE,
                                               Texts.DEFAULT_PATTERNS[Model.FileSet.RATIONALE]))

"""
    classify(cfg, path, before, after; generated = nothing) -> Ruling

What one changed file is: documentation, which the documentation fixer may commit, or code, which waits
for the owner.

# Arguments

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
    jl = endswith(path, ".jl")
    if jl
        lit = literate(cfg, replace(path, '\\' => '/'))
        rb = regions(before; literate = lit); ra = regions(after; literate = lit)
        rb === nothing && return Ruling(path, false, "the file did not parse before the change (clause 2)")
        ra === nothing && return Ruling(path, false, "the file does not parse after the change (clause 2)")
        if rb.outer != ra.outer
            # Clause 3, in the tooling package alone: the statement and why of a rule are its prose, and a
            # change confined to those literals is documentation. Everything else about a rule is code.
            if cfg.package == "GBGCodingTools"
                rb = regions(before; literate = lit, rule_prose = true)
                ra = regions(after; literate = lit, rule_prose = true)
                rule_prose = rb.outer == ra.outer
            end
            rule_prose || return Ruling(path, false, "the code changed, not only its docstrings and comments (clause 2)")
        end
        tb, ta = rb.texts, ra.texts
    else
        tb, ta = String[String(before)], String[String(after)]
    end

    fenced_kept(tb, ta) ||
        return Ruling(path, false, "a doctest or an `@` block changed: those are run, not read (clause 5)")
    changed = math_diff_texts(tb, ta)
    isempty(changed) ||
        return Ruling(path, false, "mathematics changed, which is the owner's to answer (clause 6): " *
                                   join("`" .* first.(changed, 60) .* "`", ", "))
    rule_prose && return Ruling(path, true, "the prose of a rule — its statement or why — and nothing else (clause 3)")
    return Ruling(path, true, "docstrings, comments or prose only")
end

# ────────────────────────────────────────────────────────────────────── clause 2: the code itself

"""
    regions(src; literate = false, rule_prose = false) -> Union{NamedTuple,Nothing}

A Julia file split into what the documentation fixer may change and everything else.

# Arguments

- `src` — the file's content.
- `literate` — whether it is a Literate example, whose comments are Markdown and decide what runs.
- `rule_prose` — whether the plain strings given as a top-level `Rule(…)` constant's own `statement`
  and `why` keywords count as prose too (clause 3, GBGCodingTools only).

Returns `(outer, texts)` — the file with the changeable TEXT taken out, and each docstring's value and
each Literate prose run — or `nothing` when the source does not parse.

THE SIMPLE RULE [ruled 2026-09-23]. A Julia file must be the same byte for byte, whitespace included,
except the text INSIDE docstrings it already has and the text of comments it already has. A docstring
or a comment cannot be added, removed or moved by the fixer — that is the owner's to approve — because
every hole the review passes found in earlier guards came from judging when a docstring's presence, or
a comment's place, changes what loads: attaching a loose string to a call, a docstring above `@enum`,
on a bare name or a `baremodule`, a comment line splitting a Literate chunk. With structure fixed, none
of that can happen, and nothing needs judging.

What counts as a docstring's text: the string tokens of a string the parser attached as a docstring,
anywhere except inside a `quote` or a macro call's arguments, where a string is data — `Base.@kwdef`,
written out, excepted — and never a string inside an interpolation.

Line numbers move when a docstring grows by a line, and a log location, a stack trace or `functionloc`
reports them: that is accepted, as it is for every edit, except in a file that names `@__LINE__` or
`__source__`, where every line break is kept. In a Literate example a Markdown line (`# `) and a code
comment (`## `) may be turned into each other [ruled 2026-09-24] — which decides only whether the
comment shows on the page — while a mark stays exactly as it is and a prose run may not leave a fence
open.
"""
function regions(src::AbstractString; literate::Bool = false, rule_prose::Bool = false)
    s = String(src)
    tree = try JS.parseall(JS.SyntaxNode, s; filename = "regions.jl") catch; return nothing end
    any_error(tree) && return nothing
    toks = collect(JS.tokenize(s))
    cut = UnitRange{Int}[]; texts = String[]; sig = String[]
    walk_docs!(cut, texts, s, tree; rule_prose, top = true)
    for t in toks
        JS.kind(t) === JS.K"Comment" || continue
        r = Int(first(t.range)):Int(last(t.range)); c = sub(s, r)
        if !literate && startswith(c, "#=")
            push!(cut, (first(r) + 2):(last(r) - 2))            # the delimiters stay, the text may change
        elseif !literate
            push!(cut, (first(r) + 1):last(r))                  # the `#` stays, the text may change
        elseif occursin(r"^##?( |$)", c) && !has_mark(c)
            # A Markdown line (`# `) or a code comment (`## `): the first `#` stays, so the comment can be
            # neither removed nor turned into a mark; the rest may change, the second `#` included — which
            # is the fix RULE.DOC.LITERATE asks for, a comment inside a loop made `##` [ruled 2026-09-24].
            push!(cut, (first(r) + 1):last(r))
        elseif (m = match(r"^(#!?(?:md|jl|nb) #)( |$)", c)) !== nothing
            # A filtered Markdown line, `#md # prose`: the mark and its `#` stay exactly, and the prose
            # after them may change as any Markdown line's may. It was kept whole as a mark, so a fix to an
            # example's `#md` block could not be committed at all (found by PF, 2026-09-24).
            push!(cut, (first(r) + length(m.captures[1]) + 1):last(r))
        end                                                      # any other mark: exactly as it is
    end
    if literate
        # a prose run that leaves a fence open swallows the next code chunk into it
        for run in prose_runs(s)
            open_fence(run) && push!(sig, "open-fence")
        end
        md = literate_markdown(s); push!(texts, md)
        any(has_mark, split(md, '\n')) && push!(sig, "mark-in-prose")
    end
    # a file that reads its own line numbers keeps every line break, the ones inside docstrings included
    keep_lines = occursin("@__LINE__", s) || occursin("__source__", s)
    return (outer = without(s, cut; keep_lines) * "\0" * join(sig, ","), texts = texts)
end

any_error(node) = JS.kind(node) === JS.K"error" || any(any_error, something(JS.children(node), ()))
brange(n) = Int(first(JS.byte_range(n))):Int(last(JS.byte_range(n)))

function walk_docs!(cut, texts, s, n; rule_prose::Bool, top::Bool)
    k = JS.kind(n); cs = something(JS.children(n), ())
    # quoted code and a macro's arguments are data — a string there is read by whatever receives it
    k === JS.K"quote" && return
    if k === JS.K"macrocall"
        # only Base's own, written out: a bare `@kwdef` may be a package's, defined in another file this
        # guard never reads, that takes a field's string as its default (review, 2026-09-23)
        (!isempty(cs) && strip(String(JS.sourcetext(cs[1]))) == "Base.@kwdef") || return
    end
    if k === JS.K"doc" && !isempty(cs) && JS.kind(cs[1]) === JS.K"string"
        cut_text!(cut, cs[1]); push!(texts, value(s, cs[1]))
    end
    # clause 3: the statement and why of a Rule(…) that IS a top-level constant's value
    if rule_prose && top && k in (JS.K"const", JS.K"=")
        asg = k === JS.K"const" ? (isempty(cs) ? nothing : cs[1]) : n
        ac = asg === nothing ? () : something(JS.children(asg), ())
        if asg !== nothing && JS.kind(asg) === JS.K"=" && length(ac) == 2 && JS.kind(ac[2]) === JS.K"call" &&
           !isempty(something(JS.children(ac[2]), ())) && is_rule_callee(JS.children(ac[2])[1])
            for c in JS.children(ac[2])[2:end]
                for kwn in (JS.kind(c) === JS.K"parameters" ? something(JS.children(c), ()) : (c,))
                    kc = something(JS.children(kwn), ())
                    # a PLAIN string only: an interpolated statement is code, and its literal pieces
                    # were being cut as prose (found in review, 2026-09-26)
                    if JS.kind(kwn) === JS.K"=" && length(kc) == 2 && JS.kind(kc[1]) === JS.K"Identifier" &&
                       strip(String(JS.sourcetext(kc[1]))) in ("statement", "why") && JS.kind(kc[2]) === JS.K"string" &&
                       all(c -> JS.kind(c) === JS.K"String", something(JS.children(kc[2]), ()))
                        cut_text!(cut, kc[2]); push!(texts, value(s, kc[2]))
                    end
                end
            end
        end
    end
    inner = k === JS.K"toplevel" || (k === JS.K"block" && top)
    for c in cs
        walk_docs!(cut, texts, s, c; rule_prose, top = inner || k === JS.K"module")
    end
end

# The literal text pieces of one string: its OWN String children, never its delimiters and never a
# string inside an interpolation — `$(parse(Int, "1"))` runs at load, and cutting its "1" as text let a
# changed argument through (found in review, 2026-09-23).
cut_text!(cut, n) = append!(cut, (brange(c) for c in something(JS.children(n), ()) if JS.kind(c) === JS.K"String"))

# A string's value as Markdown: the whole value when it is plain, and its literal pieces when it
# interpolates — so a doctest in a docstring that opens with `$(SIGNATURES)` is still compared.
function value(s, n)
    v = try Meta.parse(sub(s, brange(n))) catch; nothing end
    v isa AbstractString && return String(v)
    v isa Expr && v.head === :string && return join((a for a in v.args if a isa AbstractString), "")
    return ""
end

# A byte range of `s` as a string: the tokenizer's ranges end on a byte, which in a multi-byte character
# is not a valid string index.
sub(s, r) = String(codeunits(s)[max(first(r), 1):min(last(r), ncodeunits(s))])

function macro_name(n)
    t = strip(String(JS.sourcetext(n)))
    t = split(t, '.')[end]
    return Symbol(startswith(t, "@") ? t : "@" * t)
end
is_rule_callee(n) = (t = strip(String(JS.sourcetext(n))); t == "Rule" || endswith(t, ".Rule"))

# The file with the cut ranges removed, every other byte kept.
function without(s, cut; keep_lines::Bool = false)
    drop = falses(ncodeunits(s))
    for r in cut
        r2 = max(first(r), 1):min(last(r), ncodeunits(s)); isempty(r2) || (drop[r2] .= true)
    end
    bytes = codeunits(s)
    keep_lines && (drop .&= bytes .!= UInt8('\n'))
    return String(bytes[.!drop])
end

# The Literate prose runs: consecutive lines the page renders as Markdown, `#md` lines among them, each
# run's text with its marks and `# ` off. Formed from raw `# ` lines alone, a fence opened inside a
# `#md` block was never seen (found in review, 2026-09-26).
function prose_runs(s)
    out = String[]; cur = String[]
    for l in literate_lines(s)
        if l !== nothing
            push!(cur, l)
        else
            isempty(cur) || push!(out, join(cur, '\n')); empty!(cur)
        end
    end
    isempty(cur) || push!(out, join(cur, '\n'))
    return out
end

# Whether a comment carries a Literate mark where Literate reads one: at its start, or at its end. A
# mention of `#md` in the middle of a prose line is prose (found in review, 2026-09-26).
has_mark(c) = occursin(r"^#!?(?:md|jl|nb|src)(?:\s|$)", c) || occursin(r"(?:^|\s)#!?(?:md|jl|nb|src)$", c)

# Whether a Markdown text leaves a fence open at its end: an opening ``` or ~~~ line with no closing one.
function open_fence(t)
    fence = nothing
    for l in split(t, '\n')
        m = match(r"^\s*(```+|~~~+)\s*(.*?)\s*$", l)
        m === nothing && continue
        if fence === nothing
            fence = String(m.captures[1])
        elseif first(m.captures[1]) == first(fence) && length(m.captures[1]) >= length(fence) && isempty(m.captures[2])
            fence = nothing
        end
    end
    return fence !== nothing
end

# The Markdown Literate writes from an example, whole, as far as mathematics and run blocks go: prose
# lines and `#md` lines with their marks taken off, code as blank lines. A block that spans a mark line
# is seen here whole, where each half of it was not.
literate_markdown(s) = join((something(l, "") for l in literate_lines(s)), '\n')

# Each line of an example as the page sees it: its prose, or `nothing` for a line of code.
function literate_lines(s)
    out = Union{Nothing,String}[]
    for l in split(s, '\n')
        t = replace(l, r"^[ \t]*#md[ \t]?" => "")
        m = match(r"^[ \t]*#(?:[ \t](.*))?$", t)
        push!(out, m !== nothing && !startswith(lstrip(t), "##") ? something(m.captures[1], "") : nothing)
    end
    return out
end

"""
    texts_of(src; literate = false) -> Union{Vector{String},Nothing}

The prose of a Julia file: the value of every docstring the fixer may edit, and, in a Literate example,
each run of comment lines.

# Arguments

- `src` — the file's content.
- `literate` — whether it is a Literate example.

Returns them in order, or `nothing` when the file does not parse. Clauses 5 and 6 read these, and never
the code.
"""
function texts_of(src::AbstractString; literate::Bool = false)
    r = regions(src; literate)
    return r === nothing ? nothing : r.texts
end

# ─────────────────────────────────────────────────────────── clauses 4 and 5: marks and fenced blocks

"""
    fenced_kept(before, after) -> Bool

Whether every fenced block that is RUN rather than read is identical in both, in the same order and
with the same info string: a doctest (` ```jldoctest `) and every Documenter block whose info string
starts with `@`. Their content is executed or collected at build time, so an edit to one is a code
change however much it looks like prose.

The arguments are the two lists of texts — a page, or a Julia file's docstrings and Literate comments.
Returns whether every such block survived unchanged. Each text is read by Julia's Markdown parser, so a
block in a blockquote or a list item is seen, and by pattern, fenced with backticks or tildes.
"""
fenced_kept(before::Vector{String}, after::Vector{String}) = run_blocks(before) == run_blocks(after)

function run_blocks(texts::Vector{String})
    out = Tuple{String,String}[]
    for text in texts
        md = try Markdown.parse(text) catch; nothing end
        md === nothing || md_walk(md) do x
            x isa Markdown.Code && (startswith(x.language, "jldoctest") || startswith(x.language, "@")) &&
                push!(out, (x.language, x.code))
        end
        append!(out, blocks_of(text))
        append!(out, blocks_of(join((replace(l, r"^[ \t]*>[ \t]?" => "") for l in split(text, '\n')), '\n')))
    end
    return out
end

# ``` and ~~~ fences alike, as Julia's Markdown parser reads them: a fence closes on the same character.
function blocks_of(text::AbstractString)
    out = Tuple{String,String}[]
    fence = nothing; info = nothing
    buf = IOBuffer()
    for line in split(text, '\n')
        m = match(r"^\s*(```+|~~~+)\s*(.*?)\s*$", line)
        if m !== nothing && (fence === nothing || (first(m.captures[1]) == first(fence) &&
                                                   length(m.captures[1]) >= length(fence) && isempty(m.captures[2])))
            if fence === nothing
                fence = String(m.captures[1]); tag = String(m.captures[2])
                info = startswith(tag, "jldoctest") || startswith(tag, "@") ? tag : ""
            else
                info == "" || push!(out, (info, String(take!(buf))))
                take!(buf); fence = nothing; info = nothing
            end
            continue
        end
        info === nothing || info == "" || println(buf, line)
    end
    return out
end

end # module Guard
