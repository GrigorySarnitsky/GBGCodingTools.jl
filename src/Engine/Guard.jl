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

Every mathematical expression a text spells, found by PATTERN, in order and with repetition: a
double-backtick span (the spelling the rulebook requires), a fenced math block, a display between
doubled dollar signs, a span between single dollar signs, and a bracketed display or inline span in the
LaTeX spelling. The argument is `text`, a page or ONE docstring's value — never a whole Julia file,
where a dollar sign in one error message pairs with the next and every docstring between reads as a
formula (a third of the prose fixes of [GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/)
were refused that way). Returns the expressions,
whitespace flattened so that a re-wrapped line is the same expression.

This is half of what clause 6 reads; the other half is what Julia's Markdown parser — the one
Documenter uses — reads as mathematics. A change either half sees is refused.
"""
function math_spans(text::AbstractString)
    t = String(text)
    out = String[]
    flat(x) = strip(replace(x, r"\s+" => " "))
    rx = r"^[ \t>]*(?:(?:[-*+]|\d+[.)])[ \t]+)?(```+|~~~+)[ \t]*math[ \t]*\n(.*?)^[ \t>]*\1[ \t]*$"ms
    for m in eachmatch(rx, t); push!(out, flat(m.captures[2])); end
    t = replace(t, rx => "")
    for r in (r"\$\$(.+?)\$\$"s, r"(?<!`)``(?!`)(.+?)(?<!`)``(?!`)"s, r"\\\[(.+?)\\\]"s, r"\\\((.+?)\\\)"s,
              r"(?<![\$\\])\$([^\$]+?)\$(?!\$)"s)
        for m in eachmatch(r, t); push!(out, flat(m.captures[1])); end
        t = replace(t, r => "")
    end
    return out
end

# What Julia's Markdown parser reads in one text, in document order: every formula, and the sequence of
# inline spans — code or mathematics — with their text, which is what a respelling is judged on.
function parsed_math(text::AbstractString)
    math = String[]; spans = Tuple{Symbol,String}[]
    md = try Markdown.parse(String(text)) catch; return math, spans end
    md_walk(md) do x
        if x isa Markdown.LaTeX
            f = strip(replace(x.formula, r"\s+" => " ")); push!(math, f); push!(spans, (:math, f))
        elseif x isa Markdown.Code && isempty(x.language)
            push!(spans, (:code, strip(replace(x.code, r"\s+" => " "))))
        end
    end
    return math, spans
end

# The same inline sequence found by pattern.
pattern_spans(text) = [(startswith(m.match, "``") || startswith(m.match, "\$") ? :math : :code,
                        strip(replace(something(m.captures[1], m.captures[2], m.captures[3], m.captures[4]), r"\s+" => " ")))
                       for m in eachmatch(r"(?<!`)``(?!`)(.+?)(?<!`)``(?!`)|(?<!`)`(?!`)([^`]+?)(?<!`)`(?!`)|\$\$(.+?)\$\$|(?<![\$\\])\$([^\$]+?)\$(?!\$)"s, String(text))]

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
    math_changed(before, after; jl = false) -> Vector{String}

The mathematics this change adds, alters, removes or reorders. The arguments are:

- `before` and `after` — the file's text on each side.
- `jl` — whether it is a Julia file, whose mathematics is read in its docstrings and in the comments
  Literate renders, never in its code.

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
function math_changed(before::AbstractString, after::AbstractString; jl::Bool = false)
    tb = jl ? something(texts_of(before), String[String(before)]) : String[String(before)]
    ta = jl ? something(texts_of(after), String[String(after)]) : String[String(after)]
    return math_diff_texts(tb, ta)
end

function math_diff_texts(tb::Vector{String}, ta::Vector{String})
    pb = [parsed_math(t) for t in tb]; pa = [parsed_math(t) for t in ta]
    mb = reduce(vcat, first.(pb); init = String[]); ma = reduce(vcat, first.(pa); init = String[])
    qb = reduce(vcat, math_spans.(tb); init = String[]); qa = reduce(vcat, math_spans.(ta); init = String[])
    mb == ma && qb == qa && return String[]
    # a respelling: the same inline texts in the same order, kinds flipped, and nothing else
    sb = reduce(vcat, last.(pb); init = Tuple{Symbol,String}[]); sa = reduce(vcat, last.(pa); init = Tuple{Symbol,String}[])
    rb = reduce(vcat, pattern_spans.(tb); init = Tuple{Symbol,String}[]); ra = reduce(vcat, pattern_spans.(ta); init = Tuple{Symbol,String}[])
    respelled = last.(sb) == last.(sa) && last.(rb) == last.(ra) &&
                [m for (k, m) in sb if k === :math] != [m for (k, m) in sa if k === :math] &&
                multiset_minus(mb, [m for (k, m) in sb if k === :math]) == multiset_minus(ma, [m for (k, m) in sa if k === :math])
    respelled && return String[]
    out = String[]
    for (was, now) in ((mb, ma), (qb, qa))
        was == now && continue
        d = vcat(multiset_minus(now, was), multiset_minus(was, now))
        append!(out, isempty(d) ? now : d)
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

A Julia file split into what the documentation fixer may change and everything else. The arguments are:

- `src` — the file's content.
- `literate` — whether it is a Literate example, whose comments are Markdown and whose comment lines
  divide what runs.
- `rule_prose` — whether the plain strings given as a `Rule(…)` call's own `statement` and `why`
  keywords count as prose too (clause 3, GBGCodingTools only).

Returns `(outer, texts)` — the file with every changeable region taken out, and the text of each region
— or `nothing` when the source does not parse.

INVERTED, 2026-09-23. Three review passes found thirty-five ways past a guard that decided which parts
of a changed file were CODE; each fix exposed a form it had not anticipated. This decides the opposite
question: what may change.

Exactly three things. The text of a docstring the parser attached, at top level or directly in a
module, on a function, a struct, an abstract or primitive type, a macro, a module, a `const`, a bare
name that is not the block's last statement, or a Base annotation or `@kwdef`/`@enum` around one of
those. A field docstring directly in the body of such a struct. And comments.

Everything else must be byte for byte the same — whitespace included, since `[1 - 1]` is not `[1 -1]`
— apart from blank lines and trailing spaces outside strings. In a Literate example a run of prose
comment lines may be rewritten but not moved, split or joined to code, and a line carrying a Literate
mark, a chunk separator or a `#=` block is code.

Line numbers move when a docstring grows, and a program can read them; that is accepted, as it is for
every edit, except in a file that names `@__LINE__` or `__source__`, where a moved line is code.
"""
function regions(src::AbstractString; literate::Bool = false, rule_prose::Bool = false)
    s = String(src)
    tree = try JS.parseall(JS.SyntaxNode, s; filename = "regions.jl") catch; return nothing end
    any_error(tree) && return nothing
    cut = UnitRange{Int}[]; texts = String[]
    walk_regions!(cut, texts, s, tree, :top, false; rule_prose)
    toks = collect(JS.tokenize(s))
    instr = falses(ncodeunits(s))                          # bytes inside a string literal's text
    for t in toks
        JS.kind(t) in (JS.K"String", JS.K"CmdString") || continue
        r = Int(first(t.range)):Int(last(t.range)); isempty(r) || (instr[r] .= true)
    end
    comments = [(Int(first(t.range)):Int(last(t.range))) for t in toks if JS.kind(t) === JS.K"Comment"]
    if literate
        literate_comments!(cut, texts, s, comments)
    else
        for r in comments
            push!(cut, r)
        end
    end
    lines_matter = occursin("@__LINE__", s) || occursin("__source__", s)
    return (outer = assemble(s, cut, instr; keep_blank = literate || lines_matter, keep_lines = lines_matter), texts = texts)
end

any_error(node) = JS.kind(node) === JS.K"error" || any(any_error, something(JS.children(node), ()))
brange(n) = Int(first(JS.byte_range(n))):Int(last(JS.byte_range(n)))

function walk_regions!(cut, texts, s, n, level::Symbol, last_stmt::Bool; rule_prose::Bool)
    k = JS.kind(n); cs = something(JS.children(n), ())
    if k === JS.K"doc" && level === :top && length(cs) == 2 && plain(cs[1]) && attachable(cs[2], last_stmt)
        push!(cut, first(brange(cs[1])):(first(brange(cs[2])) - 1))    # the docstring and the gap after it
        push!(texts, value(s, cs[1]))
        walk_regions!(cut, texts, s, cs[2], :top, last_stmt; rule_prose)
        return
    end
    if level === :top && (k === JS.K"struct" || (k === JS.K"macrocall" && kwdef(n)))
        st = k === JS.K"struct" ? n : something(findfirst(c -> JS.kind(c) === JS.K"struct", cs) |> i -> i === nothing ? nothing : cs[i], nothing)
        if st !== nothing
            body = something(findfirst(c -> JS.kind(c) === JS.K"block", something(JS.children(st), ())) |> i -> i === nothing ? nothing : JS.children(st)[i], nothing)
            if body !== nothing
                for f in something(JS.children(body), ())
                    fc = something(JS.children(f), ())
                    if JS.kind(f) === JS.K"doc" && length(fc) == 2 && plain(fc[1])
                        push!(cut, first(brange(fc[1])):(first(brange(fc[2])) - 1)); push!(texts, value(s, fc[1]))
                    end
                end
            end
        end
        return
    end
    if rule_prose && k === JS.K"call" && !isempty(cs) && is_rule_callee(cs[1])
        for c in cs[2:end]
            for kwn in (JS.kind(c) === JS.K"parameters" ? something(JS.children(c), ()) : (c,))
                kc = something(JS.children(kwn), ())
                if JS.kind(kwn) === JS.K"=" && length(kc) == 2 && JS.kind(kc[1]) === JS.K"Identifier" &&
                   strip(String(JS.sourcetext(kc[1]))) in ("statement", "why") && plain(kc[2])
                    r = brange(kc[2]); push!(cut, (first(r) + 1):(last(r) - 1)); push!(texts, value(s, kc[2]))
                end
            end
        end
    end
    inner = k === JS.K"toplevel" || (k === JS.K"block" && level === :module)
    for (i, c) in enumerate(cs)
        # a function's SIGNATURE is not a call: `Rule(; statement = "…") = …` defines a method
        sig = (k === JS.K"function" || k === JS.K"macro") && i == 1
        next = inner ? :top : (k === JS.K"module" ? :module : :other)
        walk_regions!(cut, texts, s, c, next, inner && i == length(cs); rule_prose = rule_prose && !sig)
    end
end

plain(n) = JS.kind(n) === JS.K"string" && all(c -> JS.kind(c) === JS.K"String", something(JS.children(n), ()))
value(s, n) = (v = try Meta.parse(s[brange(n)]) catch; nothing end; v isa AbstractString ? String(v) : "")
kwdef(n) = (cs = something(JS.children(n), ()); !isempty(cs) && macro_name(cs[1]) === Symbol("@kwdef"))
function macro_name(n)
    t = strip(String(JS.sourcetext(n)))
    t = split(t, '.')[end]
    return Symbol(startswith(t, "@") ? t : "@" * t)
end
is_rule_callee(n) = (t = strip(String(JS.sourcetext(n))); t == "Rule" || endswith(t, ".Rule"))

# A docstring on this target may be edited, added or removed without changing what the file does.
function attachable(t, last_stmt::Bool)
    k = JS.kind(t)
    k in (JS.K"function", JS.K"struct", JS.K"abstract", JS.K"primitive", JS.K"macro", JS.K"module", JS.K"const") &&
        return !(k === JS.K"const" && last_stmt)
    k === JS.K"Identifier" && return !last_stmt
    if k === JS.K"macrocall"
        cs = something(JS.children(t), ()); isempty(cs) && return false
        name = macro_name(cs[1])
        name in (Symbol("@kwdef"), Symbol("@enum")) && return true
        name in ANNOTATING && return JS.kind(cs[end]) in (JS.K"function", JS.K"macrocall") && attachable(cs[end], true)
    end
    return false
end

# Base's macros that only ANNOTATE a function definition. A named list: a package's own macro may
# rewrite what it wraps, and `@deprecate` or `@nospecialize` do not wrap a definition at all.
const ANNOTATING = Symbol.(["@inline", "@noinline", "@generated", "@propagate_inbounds", "@constprop",
                            "@assume_effects"])

# In a Literate example a comment line is Markdown, and where comment lines stand decides what runs. A
# run of prose comment lines is one region; its line count may change, its place may not. A line with a
# mark — `#src` `#md` `#jl` `#nb`, their `#!` negations, a `#-` or `#+` separator — and a `#=` block
# stay in the outer text, so a change to one is code.
function literate_comments!(cut, texts, s, comments)
    run = UnitRange{Int}[]
    flush!() = (isempty(run) && return;
                push!(cut, first(run[1]):last(run[end])); push!(texts, join((strip_hash(s[r]) for r in run), '\n'));
                empty!(run))
    for r in comments
        c = s[r]
        whole = line_only(s, r)
        mark = startswith(c, "#=") || occursin(r"^#\s*[-+]", c) || startswith(c, "#!") ||
               any(m -> occursin(m, c), LITERATE_MARKS)
        if mark
            flush!()
        elseif whole
            if !isempty(run) && only_space(s, (last(run[end]) + 1):(first(r) - 1))
                push!(run, r)
            else
                flush!(); push!(run, r)
            end
        else
            flush!(); push!(cut, r)                         # a trailing comment on a code line
        end
    end
    flush!()
end

strip_hash(c) = replace(c, r"^#[ \t]?" => "")
only_space(s, r) = isempty(r) || all(isspace, s[r])
function line_only(s, r)
    a = first(r); while a > 1 && s[prevind(s, a)] in (' ', '\t'); a = prevind(s, a); end
    return a == 1 || s[prevind(s, a)] == '\n'
end

# The file with the cut ranges removed; outside strings, trailing spaces go and blank lines go too
# unless they carry meaning (a Literate example, a file reading its own line numbers).
function assemble(s, cut, instr; keep_blank::Bool, keep_lines::Bool = false)
    drop = falses(ncodeunits(s))
    for r in cut
        r2 = max(first(r), 1):min(last(r), ncodeunits(s)); isempty(r2) || (drop[r2] .= true)
    end
    bytes = codeunits(s)
    out = IOBuffer(); line = UInt8[]; line_str = Bool[]
    function emit()
        # trailing whitespace outside strings
        while !isempty(line) && (line[end] == UInt8(' ') || line[end] == UInt8('\t')) && !line_str[end]
            pop!(line); pop!(line_str)
        end
        blank = isempty(line)
        (blank && !keep_blank) || (write(out, line); write(out, UInt8('\n')))
        empty!(line); empty!(line_str)
    end
    for i in eachindex(bytes)
        # in a file that reads its own line numbers, a cut region keeps its line breaks, so a docstring
        # that grew by a line moves every line below it in the outer text too
        drop[i] && (keep_lines && bytes[i] == UInt8('\n') && emit(); continue)
        if bytes[i] == UInt8('\n') && !instr[i]
            emit()
        else
            push!(line, bytes[i]); push!(line_str, instr[i])
        end
    end
    isempty(line) || emit()
    return String(take!(out))
end

"""
    texts_of(src; literate = false) -> Union{Vector{String},Nothing}

The prose of a Julia file: the value of every docstring the fixer may edit, and, in a Literate example,
each run of comment lines. The arguments are:

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
