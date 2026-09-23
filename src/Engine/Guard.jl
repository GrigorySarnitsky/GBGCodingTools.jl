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
using Markdown

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

Every mathematical expression a text spells, found by PATTERN, in order and with repetition: a
double-backtick span (the spelling the rulebook requires), a fenced math block, a display between
doubled dollar signs, a span between single dollar signs, and a bracketed display or inline span in the
LaTeX spelling. The argument is
`text`. Returns the expressions, whitespace flattened so that a re-wrapped line is the same expression.

This is half of what clause 6 reads. The other half is [`parsed_math`](@ref), what Julia's Markdown
parser — the one Documenter uses — reads as mathematics; a change either half sees is refused, so a
formula one of them misses is caught by the other.
"""
function math_spans(text::AbstractString)
    t = String(text)
    out = String[]
    flat(x) = strip(replace(x, r"\s+" => " "))
    for rx in (r"^[ \t>]*(?:[-*+][ \t]+)?(?:#[ \t]?)?(```+|~~~+)[ \t]*math[ \t]*\n(.*?)^[ \t>]*(?:#[ \t]?)?\1[ \t]*$"ms,)
        for m in eachmatch(rx, t); push!(out, flat(m.captures[2])); end
        t = replace(t, rx => "")
    end
    for rx in (r"\$\$(.+?)\$\$"s, r"(?<!`)``(?!`)(.+?)(?<!`)``(?!`)"s, r"\\\[(.+?)\\\]"s, r"\\\((.+?)\\\)"s,
               r"(?<![\$\\])\$([^\$]+?)\$(?!\$)"s)
        for m in eachmatch(rx, t); push!(out, flat(m.captures[1])); end
        t = replace(t, rx => "")
    end
    return out
end

"""
    parsed_math(src; jl = false) -> (math, code)

What Julia's Markdown parser reads as mathematics in a text, and the inline code spans beside it. The
arguments are:

- `src` — the file's content.
- `jl` — whether it is a Julia file, whose Markdown is the value of each string literal and, for
  Literate, each comment with its `# ` taken off.

Returns the formulas in order, and the contents of the inline code spans.

A blockquote, a list item, a formula wrapped across a line, a stray pair of backticks before a formula:
the parser reads each as Documenter will, which no pattern over the text did.
"""
function parsed_math(src::AbstractString; jl::Bool = false)
    math = String[]; code = String[]
    for text in markdown_texts(src; jl)
        md = try Markdown.parse(text) catch; nothing end
        md === nothing || md_walk(md) do x
            if x isa Markdown.LaTeX
                push!(math, strip(replace(x.formula, r"\s+" => " ")))
            elseif x isa Markdown.Code && isempty(x.language)
                push!(code, strip(replace(x.code, r"\s+" => " ")))
            end
        end
    end
    return math, code
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

# The Markdown a file holds: a page is Markdown; a Julia file's is each string literal's VALUE, and the
# comments, which Literate renders as Markdown once their `# ` is taken off.
function markdown_texts(src::AbstractString; jl::Bool = false)
    jl || return [String(src)]
    out = string_values(src)
    comments = [replace(l, r"^[ \t]*#[ \t]?" => "") for l in split(String(src), '\n') if occursin(r"^[ \t]*#(?!=)", l)]
    isempty(comments) || push!(out, join(comments, '\n'))
    return out
end

function string_values(src::AbstractString)
    ex = try Meta.parseall(String(src)) catch; return String[] end
    out = String[]
    walk(x) = x isa String ? push!(out, x) : x isa Expr ? foreach(walk, x.args) : nothing
    walk(ex)
    return out
end

"""
    math_changed(before, after; jl = false) -> Vector{String}

The mathematics this change adds, alters, removes or reorders. The arguments are:

- `before` and `after` — the file's text on each side.
- `jl` — whether it is a Julia file.

Returns the expressions that differ — those added, then those removed — and, where the same expressions
now stand in a different order, all of them; empty when the mathematics is untouched.

CLAUSE 6, and the owner's ruling of 2026-09-21: **no edit inside a math span is made automatically**.
A program has no oracle for whether a formula is true — only the code it documents has that, and code
that is itself wrong then certifies prose that matches it — so a changed symbol, number or sign is put
to the owner as a question rather than committed. Deleting a formula and swapping two are edits too.

One change is spelling and not mathematics: an inline code span made a math span with the same text,
or back — the fix the LaTeX rules ask for. Whitespace alone is not a change, and a year in a citation
is not mathematics.
"""
function math_changed(before::AbstractString, after::AbstractString; jl::Bool = false)
    pm_b, pc_b = parsed_math(before; jl); pm_a, pc_a = parsed_math(after; jl)
    code_spans(t) = [strip(replace(m.captures[1], r"\s+" => " ")) for m in eachmatch(r"(?<!`)`(?!`)([^`]+?)(?<!`)`(?!`)", String(t))]
    one = math_diff(pm_b, pm_a, pc_b, pc_a)
    two = math_diff(math_spans(before), math_spans(after), code_spans(before), code_spans(after))
    return unique(vcat(one, two))
end

function math_diff(was, now, code_was, code_now)
    was == now && return String[]
    added = multiset_minus(now, was); removed = multiset_minus(was, now)
    # respelled, not changed: what appeared as mathematics left the code spans, and what left the
    # mathematics appeared among them
    isempty(multiset_minus(added, multiset_minus(code_was, code_now))) &&
        isempty(multiset_minus(removed, multiset_minus(code_now, code_was))) &&
        (!isempty(added) || !isempty(removed)) && return String[]
    out = vcat(added, removed)
    return isempty(out) ? String.(now) : String.(out)     # the same expressions, in another order
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

    fenced_kept(before, after; jl = endswith(path, ".jl")) ||
        return Ruling(path, false, "a doctest or an `@` block changed: those are run, not read (clause 5)")
    changed = math_changed(before, after; jl = endswith(path, ".jl"))
    isempty(changed) ||
        return Ruling(path, false, "mathematics changed, which is the owner's to answer (clause 6): " *
                                   join("`" .* first.(changed, 60) .* "`", ", "))
    rule_prose && return Ruling(path, true, "the prose of a rule — its statement or why — and nothing else (clause 3)")
    return Ruling(path, true, "docstrings, comments or prose only")
end

# ────────────────────────────────────────────────────────────────────── clause 2: the code itself

"""
    code_shape(src; rule_prose = false) -> Union{Expr,Nothing}

The Julia source as Julia's own parser reads it, with exactly what Julia treats as documentation taken
out, and nothing else. The arguments are:

- `src` — the file's content.
- `rule_prose` — whether the plain strings given as a `Rule(…)` call's own `statement` and `why`
  keywords are elided too (clause 3).

Returns the parsed tree, or `nothing` when the source does not parse.

What comes out is decided by the parser, not by patterns over the text [rebuilt 2026-09-23: two review
passes found twenty-six ways past a guard that recognised documentation by its shape in the source,
each fix exposing the next shape it had not anticipated]:

- a docstring the parser ATTACHED — a `Core.@doc` node — at top level or directly in a module, whose
  text is a plain string or a `raw"…"` literal, on a definition, an assignment or a bare name. Inside
  any other block a docstring changes the block's value, and on a call or a non-defining macro it
  replaces what runs, so both stay;
- a plain string standing directly in a struct's body: a field docstring.

No other string is ever removed. A string separated from what follows by a blank line is not attached,
so it is a statement like any other, and one ending a Literate chunk is that chunk's displayed output.
Line numbers are dropped, except in a file that reads its own with `@__LINE__` or `__source__`, where
they are kept and a moved line is code.
"""
function code_shape(src::AbstractString; rule_prose::Bool = false)
    ex = try
        Meta.parseall(String(src); filename = "shape.jl")
    catch
        return nothing
    end
    broken(ex) && return nothing
    lines = occursin("@__LINE__", src) || occursin("__source__", src)
    return shape(ex, :top; rule_prose, lines)
end

broken(x) = x isa Expr && (x.head in (:error, :incomplete) || any(broken, x.args))

function shape(x, level::Symbol; rule_prose::Bool, lines::Bool)
    x isa LineNumberNode && return lines ? x : nothing
    x isa Expr || return x
    kw = (; rule_prose, lines)
    if level === :top && is_doc(x) && removable_text(x.args[3]) && removable_target(x.args[4])
        return shape(x.args[4], :top; kw...)                 # the docstring goes; what it documents stays
    end
    if x.head === :toplevel
        return Expr(:toplevel, keep(shape(a, :top; kw...) for a in x.args)...)
    end
    if x.head === :module
        body = x.args[3]
        return Expr(:module, x.args[1], x.args[2],
                    Expr(:block, keep(shape(a, :top; kw...) for a in body.args)...))
    end
    if x.head === :struct
        body = x.args[3]
        return Expr(:struct, x.args[1], shape(x.args[2], :other; kw...),
                    Expr(:block, keep(shape(a, :other; kw...) for a in body.args if !(a isa String))...))
    end
    # A signature is not a call: `Rule(; statement = "…") = …` defines a method, and its defaults are code.
    if x.head in (:function, :(=), :macro) && length(x.args) == 2
        return Expr(x.head, shape(x.args[1], :sig; kw...), shape(x.args[2], :other; kw...))
    end
    if rule_prose && level !== :sig && x.head === :call && is_rule_callee(x.args[1])
        return Expr(:call, (prose_elided(a, kw) for a in x.args)...)
    end
    return Expr(x.head, keep(shape(a, :other; kw...) for a in x.args)...)
end

keep(xs) = Any[y for y in xs if y !== nothing]

is_doc(x) = x isa Expr && x.head === :macrocall && length(x.args) == 4 &&
            (x.args[1] == GlobalRef(Core, Symbol("@doc")) || x.args[1] === Symbol("@doc"))

removable_text(t) = t isa String ||
    (t isa Expr && t.head === :macrocall && t.args[1] === Symbol("@raw_str") && count(a -> a isa String, t.args) == 1)

# A definition, an assignment or a name: removing the docstring from one of these leaves the same thing
# evaluated. A call, an indexing or a non-defining macro call does not.
function removable_target(t)
    t isa Symbol && return true
    t isa Expr || return false
    t.head === :. && return all(a -> a isa Symbol || a isa QuoteNode, t.args)
    t.head in (:function, :(=), :struct, :abstract, :primitive, :module, :const, :macro, :global) && return true
    if t.head === :macrocall
        m = t.args[1]
        name = m isa Symbol ? m : (m isa Expr && m.head === :. ? m.args[end] : nothing)
        name isa QuoteNode && (name = name.value)
        name in (Symbol("@kwdef"), Symbol("@enum")) &&
            return any(a -> a isa Expr && a.head in (:struct, :block) || a isa Symbol, t.args[3:end])
        # Base's macros that only ANNOTATE a definition — the form fast code documents most — around a
        # definition. A named list, not any macro: a package's own macro may rewrite what it wraps into a
        # call, and a docstring on it then stops the call from running.
        name in ANNOTATING && return removable_target(t.args[end])
    end
    return false
end

const ANNOTATING = Symbol.(["@inline", "@noinline", "@generated", "@propagate_inbounds", "@constprop",
                            "@assume_effects", "@nospecialize", "@specialize", "@deprecate"])

# `Rule` or `Model.Rule`: the one constructor whose statement and why are prose (clause 3).
is_rule_callee(f) = f === :Rule || (f isa Expr && f.head === :. && f.args[end] == QuoteNode(:Rule))

function prose_elided(a, kw)
    if a isa Expr && a.head === :kw && a.args[1] in (:statement, :why) && a.args[2] isa String
        return Expr(:kw, a.args[1], "<prose>")
    end
    if a isa Expr && a.head === :parameters
        return Expr(:parameters, (prose_elided(p, kw) for p in a.args)...)
    end
    return shape(a, :other; kw...)
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

The arguments are the two versions and `jl`, whether it is a Julia file. Returns whether they all
survived unchanged.
"""
function fenced_kept(before::AbstractString, after::AbstractString; jl::Bool = false)
    return run_blocks(before; jl) == run_blocks(after; jl)
end

function run_blocks(src::AbstractString; jl::Bool = false)
    out = Tuple{String,String}[]
    # What the parser reads as a run block, wherever it stands — in a blockquote, on a list bullet, in a
    # docstring's value, in a Literate comment — and, beside it, every fence found by pattern in the text
    # as it stands and with comment marks taken off.
    for text in markdown_texts(src; jl)
        md = try Markdown.parse(text) catch; nothing end
        md === nothing || md_walk(md) do x
            x isa Markdown.Code && (startswith(x.language, "jldoctest") || startswith(x.language, "@")) &&
                push!(out, (x.language, x.code))
        end
    end
    for text in (String(src), uncommented(src))
        append!(out, blocks_of(text))
    end
    return out
end

uncommented(src) = join((replace(l, r"^([ \t]*)#[ \t]?" => s"\1") for l in split(String(src), '\n')), '\n')

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
