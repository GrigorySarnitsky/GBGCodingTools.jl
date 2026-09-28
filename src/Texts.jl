# The design's §4.5; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Texts

Reading the texts a rule is about, and finding a place in them again after they have moved: the
docstrings of Julia source, the headings of Markdown pages, and the re-anchoring both exist for.

A line number is not a place. A fix earlier in a file moves every line below it, four fix passes compound
that, and a finding carried from an earlier run had its lines read at an older commit — so a stale number
points at whatever now sits there, which is how a fix lands in the wrong paragraph.

A [`Model.Location`](@ref) is therefore the file, the NODE (for Julia the binding, method or field of a
constant documented; for Markdown the heading path), the QUOTE as it read then, and the line as a hint
only. The function [`reanchor`](@ref) finds the node, then the quote inside it; failing that the quote, nearest
the old line; failing that it says `OUTDATED` rather than guessing.

This module is the second of the order and may name only [`Model`](@ref). It parses Julia with the
compiler's own parser, so what it calls a definition is what Julia calls one.
"""
module Texts

using ..Model
using Gumbo: parsehtml, HTMLDocument, HTMLElement, HTMLText, children
using AbstractTrees: PreOrderDFS

const JS = Base.JuliaSyntax

# A directory that disappears while a walk is running is SKIPPED, not thrown over. Every walk here is
# over a working tree, and a working tree has git in it: git packs and removes its own object
# directories while it commits, and a walk that started before a commit and finished after one died
# with ENOENT on `.git/objects/81` — on CI, where the tests commit far faster than a person does.
const SKIP_VANISHED = _ -> nothing

"""
    DEFAULT_PATTERNS

Where each file set lives in a package that says nothing about it. A package's own config overrides any of
these, which is how a package whose examples are elsewhere, or whose rationale is one document, says so.
"""
const DEFAULT_PATTERNS = Dict{Model.FileSet.T,Vector{String}}(
    Model.FileSet.DOCSTRINGS => ["src/**/*.jl", "ext/**/*.jl"],
    Model.FileSet.CODE       => ["src/**/*.jl", "ext/**/*.jl"],
    Model.FileSet.PAGES      => ["docs/src/**/*.md"],
    # Every design document a package keeps directly under `docs/` — the site's pages live in `docs/src/`
    # and history deeper down. Deterministic checks are cheap and carry no risk of an agent's misreading,
    # so they read these by default [ruled 2026-09-24]; which of them a READER is given is a separate
    # question, answered by `architecture_doc` and `material`.
    Model.FileSet.RATIONALE  => ["docs/*.md"],
    Model.FileSet.LITERATE   => ["examples/**/*.jl"],
    Model.FileSet.TESTS      => ["test/**/*.jl"],
)

"""
    files(cfg, root, fileset) -> Vector{String}

The files of one file set in the package at `root`, as paths relative to it, sorted and without
duplicates. The arguments are:

- `cfg` — the package's config.
- `root` — the package root.
- `fileset` — the set to resolve.

A package's own patterns replace the defaults for that set rather than adding to them, so a package that
says where its pages are is believed. Returns the paths.
"""
function files(cfg::Model.Config, root::AbstractString, fileset::Model.FileSet.T)
    patterns = get(cfg.filesets, fileset, DEFAULT_PATTERNS[fileset])
    out = String[]
    for pattern in patterns
        append!(out, expand(root, pattern))
    end
    # A page written at build time is nobody's to fix: the rules page is by construction full of text
    # that breaks the rules it lists, and a reader would spend its whole budget reporting it
    # (docs/ARCHITECTURE.md §5.2). Same for a declared copy, whose text belongs to its source.
    written = Set(vcat(cfg.generated, first.(cfg.copies)))
    skip = Texts.ignored(root)
    return sort!(unique!(filter(f -> !(f in written) && !skip(f), out)))
end


"""
    glob_matches(pattern, path) -> Bool

Whether one path matches one file-set pattern, without touching disk. The arguments are `pattern`, with
`**` spanning directories and `*` staying within one name — the same two wildcards [`expand`](@ref)
walks — and `path`, relative to the package root. Returns the answer.

The change guard is given a path and no root and has no business reading disk to classify a change, and
the question "is this path a target of the review" is asked of paths the walk never produced, such as
the file a reader names. Both ask this.
"""
glob_matches(pattern::AbstractString, path::AbstractString) =
    occursin(Regex("^" * wildcard_source(pattern; classes = false) * "\$"), replace(path, '\\' => '/'))

# ONE grammar for every pattern this module matches. A file-set pattern and a `.gitignore` line share
# git's wildcards, and the walk, the guard's test and the ignore predicate each had a rewrite of their
# own: only the dot was escaped in two of them, so `docs/a+b.md` matched `docs/ab.md`, `foo(1).txt`
# ignored `foo1.txt`, and a line holding `)` threw out of every check (found in review, 2026-09-23 and
# 2026-09-26). Every regex metacharacter is literal here unless it is a wildcard: `*` within one name,
# `?` one character, `[…]` a class (`[!…]` negated, as git writes it), and `**` any run of directories —
# `**/` at the start or `/**/` in the middle matching none as well, a trailing `/**` everything below.
# A backslash makes the character after it literal, which is how a name holding a space, a `#` or a
# `!` is written in a `.gitignore`. A FILE-SET pattern (`classes = false`) has the two wildcards `*` and
# `**` alone: a `?` or a `[` there is literal, as it was on 2026-09-23, because a path may hold them
# (found verifying the review's fixes, 2026-09-27).
function wildcard_source(pattern::AbstractString; classes::Bool = true)
    s = String(pattern)
    io = IOBuffer()
    literal(c) = c in ".^\$|()[]{}+?*\\" ? "\\" * c : string(c)
    i = firstindex(s); n = lastindex(s)
    while i <= n
        c = s[i]
        if c == '\\' && i < n
            i = nextind(s, i)
            write(io, literal(s[i]))
        elseif c == '*' && i < n && s[nextind(s, i)] == '*'
            after = nextind(s, i, 2)                                # the index past the `**`
            at_edge = i == firstindex(s) || s[prevind(s, i)] == '/'
            if at_edge && after <= n && s[after] == '/'
                write(io, "(?:.*/)?"); i = nextind(s, after)       # `**/`: zero or more directories
            elseif at_edge && after > n
                write(io, ".+"); i = after                          # a trailing `/**`, or `**` alone
            else
                write(io, "[^/]*"); i = after                       # git: other doubled stars are stars
            end
            continue
        elseif c == '*'
            write(io, "[^/]*")
        elseif c == '?' && classes
            write(io, "[^/]")
        elseif c == '[' && classes
            close_ = findnext(']', s, min(nextind(s, i, 2), n))    # a `]` right after the `[` is literal
            if close_ === nothing
                write(io, "\\[")
            else
                inner = s[nextind(s, i):prevind(s, close_)]
                negated = startswith(inner, "!") || startswith(inner, "^")
                negated && (inner = inner[2:end])
                write(io, negated ? "[^" : "[", replace(inner, "\\" => "\\\\", "[" => "\\["), "]")
                i = close_
            end
        else
            write(io, literal(c))
        end
        i = nextind(s, i)
    end
    return String(take!(io))
end

# Every file under `root` the pattern matches, walked rather than globbed: the patterns are few and the
# walk is over a source tree, not a corpus.
function expand(root::AbstractString, pattern::AbstractString)
    isfile(joinpath(root, pattern)) && return [String(pattern)]
    rx = Regex("^" * wildcard_source(pattern; classes = false) * "\$")
    out = String[]
    for (dir, _, fs) in walkdir(root; onerror = SKIP_VANISHED)
        rel = relpath(dir, root)
        for f in fs
            p = rel == "." ? f : joinpath(rel, f)
            p = replace(p, '\\' => '/')
            startswith(p, ".git/") && continue
            occursin(rx, p) && push!(out, p)
        end
    end
    return out
end

"""
    unwrapped(text) -> Vector{Tuple{Int,String}}

The text as logical lines, each with the number of the line it starts on: a line whose brackets do not
close absorbs the lines after it until they do. The argument is `text`, the text to read. Returns the
pairs, in order.

Prose is hard-wrapped, and almost nothing in a docstring can be assumed to fit one line. A citation
whose title crosses a wrap reads, line by line, as `[*Computer Simulation Using` — an opening bracket
with no link — so a rule matching a bracketed construct line by line reports a correct reference as
having no DOI. The same assumption cost `RULE.DOC.ARGS_FORM` a wrapped signature.

Two bounds on the joining, both from one false positive
[[GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/), 2026-09-22]. A BLANK LINE
ends a logical line whatever the brackets say: a paragraph break is a break, and a bracket left open
before one is unmatched, not wrapped. And brackets inside a code or math span do not count: the `[`
of a half-open interval written ``[a, b)`` has no `]` and never will. Without either bound, that one
`[` absorbed eighteen lines, across two paragraphs, up to the `]` of the next reference, and the rule
reported a correct DOI as resolving to the wrong title.
"""
function unwrapped(text::AbstractString)
    out = Tuple{Int,String}[]
    current = ""; start = 0
    for (i, raw) in pairs(split(text, '\n'))
        line = String(raw)
        if isempty(strip(line))
            isempty(current) || (push!(out, (start, current)); current = "")
            continue
        end
        isempty(current) ? (current = line; start = i) : (current *= " " * strip(line))
        seen = mask_math_spans(mask_code_spans(current))
        balanced = count(==('['), seen) == count(==(']'), seen) &&
                   count(==('('), seen) == count(==(')'), seen)
        balanced && (push!(out, (start, current)); current = "")
    end
    isempty(current) || push!(out, (start, current))
    return out
end

"""
    wrapped_lines(text) -> Vector{Tuple{Int,String}}

The text as logical lines, each with the number of the line it starts on: a continuation of the line
above is joined to it. A blank line, a heading, and a bullet or numbered item each START a line.

The argument is `text`. Returns the pairs, in order.

This is for a rule about ADJACENCY, where [`unwrapped`](@ref) is not enough: `unwrapped` joins only when
brackets are open, and a line ending in a cross-reference has balanced brackets while the formula naming
that reference sits on the next line. A bullet has to start a new logical line, or the end of one item and the start
of the next read as adjacent when they are two entries of a list.
"""
function wrapped_lines(text::AbstractString)
    out = Tuple{Int,String}[]
    current = ""; start = 0
    flush!() = (isempty(strip(current)) || push!(out, (start, current)); current = "")
    for (i, raw) in pairs(split(text, '\n'))
        line = String(raw); body = strip(line)
        if isempty(body) || occursin(r"^#", body) || occursin(r"^([-*+]|\d+\.)\s", body)
            flush!(); current = line; start = i
        elseif isempty(current)
            current = line; start = i
        else
            current *= " " * body
        end
    end
    flush!()
    return out
end

"""
    NAME

What a Julia name looks like, as regex source for a rule to build a larger pattern around.

It is NOT `[A-Za-z_][A-Za-z0-9_!]*`, and it is not that list with Greek appended either. Julia admits
any Unicode letter in an identifier, and the packages this rulebook serves are full of them — `φ`, `ν`
and `σ` are ordinary field and argument names in a physics package. An incomplete pattern does not
merely miss such a name: it REPORTS it. A struct field the pattern cannot see is a field the type does
not have, so the docstring documenting it is reported as documenting a ghost — which is exactly what
happened to `_MapValues(φ, orders)` when this was spelled out by hand in four places.
"""
const NAME = "[\\p{L}_][\\p{L}\\p{N}_!′]*"

"""
    NodeSpan

One named node of a file, with where it is. The fields are:

- `name` — the node's name: a binding for Julia source, a heading path for Markdown.
- `line` — the line it starts on.
- `bytes` — the byte range it spans, empty for a Markdown heading, whose span is by line.
- `lines` — the line range it spans.
"""
struct NodeSpan
    name::String
    line::Int
    bytes::UnitRange{Int}
    lines::UnitRange{Int}
end

"""
    DocBlock

One docstring of a Julia file, with the node it documents. The fields are:

- `node` — the name of what it documents.
- `text` — the docstring itself.
- `line` — the line the docstring starts on.
"""
struct DocBlock
    node::String
    text::String
    line::Int
end

# ─────────────────────────────────────────────────────────────────────────────────── Julia source

# The name a definition binds, or nothing where the node binds none. Written against the parser's own
# kinds rather than against source text, so `function f end`, `f(x) = x` and `struct S` are one case each
# and a macro call that only looks like a definition is not mistaken for one.
function bound_name(node)
    k = JS.kind(node)
    cs = JS.children(node)
    cs === nothing && return nothing
    if k in (JS.K"function", JS.K"macro")
        isempty(cs) && return nothing
        sig = signature(first(cs))
        return JS.kind(sig) === JS.K"call" && !isempty(JS.children(sig)) ? callee_name(first(JS.children(sig))) : node_text(sig)
    elseif k in (JS.K"struct", JS.K"abstract", JS.K"primitive")
        isempty(cs) && return nothing
        return first_name(first(cs))
    elseif k === JS.K"const" || k === JS.K"global"
        isempty(cs) && return nothing
        return first_name(first(cs))
    elseif k === JS.K"="
        isempty(cs) && return nothing
        lhs = signature(first(cs))
        JS.kind(lhs) === JS.K"call" && !isempty(JS.children(lhs)) && return callee_name(first(JS.children(lhs)))
        return nothing
    elseif k === JS.K"macrocall"
        # `@enum E a b` binds E, and no child of the call is a definition: the first identifier after
        # the macro's name is the one it makes.
        if !isempty(cs) && macro_name(first(cs)) == "enum"
            for c in cs[2:end]
                JS.kind(c) in (JS.K"Identifier", JS.K"::") && return first_name(c)
            end
            return nothing
        end
        # A defining macro call binds what it wraps: `Base.@kwdef struct S` is a struct named S, and
        # treating it as anonymous sent every keyword-default type down the weaker anchoring path.
        for c in cs
            n = bound_name(c)
            n === nothing || return n
        end
        return nothing
    elseif k === JS.K"module"
        for c in cs                                          # the name is the first identifier, not the body
            JS.kind(c) === JS.K"Identifier" && return node_text(c)
        end
        return nothing
    end
    return nothing
end

node_text(node) = strip(String(JS.sourcetext(node)))

# The name a documented thing goes by, where the docstring sits on something that is not a definition:
# a bare `f`, a signature `g(::Int)` with no body, a plain `k = 1`. Each of those is documented in the
# packages this serves, and each anchored to no node at all (found in review, 2026-09-26).
function doc_target(node)
    n = bound_name(node)
    n === nothing || return n
    k = JS.kind(node)
    k === JS.K"Identifier" && return node_text(node)
    cs = something(JS.children(node), ())
    isempty(cs) && return nothing
    k === JS.K"call" && return callee_name(first(cs))
    k === JS.K"=" && return first_name(first(cs))
    return nothing
end

# The first name a left-hand side or a type head binds: `x::Int = 1`, `P, Q = 1, 2`, `A{T} <: B`.
function first_name(node)
    while JS.kind(node) in (JS.K"=", JS.K"::", JS.K"tuple", JS.K"curly", JS.K"<:", JS.K"parens") &&
          !isempty(something(JS.children(node), ()))
        node = first(JS.children(node))
    end
    return node_text(node)
end

# What a call's callee is named: `f`, `Base.show`, and for a callable struct's method `(c::C)(x)` the
# type `C`, which is the name a location can carry and `c::C` is not.
function callee_name(node)
    cs = something(JS.children(node), ())
    if JS.kind(node) === JS.K"::" && !isempty(cs)
        return first_name(last(cs))
    elseif JS.kind(node) === JS.K"parens" && !isempty(cs)
        return callee_name(first(cs))
    end
    return node_text(node)
end

# A macro's name without its `@`, or `""` for a node that is not one; `Base.@doc` names `doc` too.
function macro_name(node)
    k = JS.kind(node)
    k === JS.K"MacroName" && return lstrip(node_text(node), '@')
    cs = something(JS.children(node), ())
    k === JS.K"." && !isempty(cs) && return macro_name(last(cs))
    return ""
end

# A docstring and the thing it documents, as a pair, or `nothing` for a node that is not one. Two
# spellings make one: the parser's own `doc` node, and a call of `@doc` on a string and a definition —
# `@doc raw"""…""" f(x) = x`, the idiom for a docstring full of backslashes, which read as no docstring
# at all (found in review, 2026-09-26).
function doc_parts(node)
    k = JS.kind(node)
    cs = something(JS.children(node), ())
    if k === JS.K"doc"
        return length(cs) >= 2 ? (cs[1], cs[2]) : nothing
    elseif k === JS.K"macrocall" && length(cs) >= 3 && macro_name(cs[1]) == "doc"
        s = cs[2]
        is_string = JS.kind(s) === JS.K"string" ||
                    (JS.kind(s) === JS.K"macrocall" && JS.kind(first(something(JS.children(s), (s,)))) === JS.K"StringMacroName")
        return is_string ? (s, cs[3]) : nothing
    end
    return nothing
end

# The call inside a signature: `f(x::T) where {T}` and `f(x)::Int` name `f`, not their whole text, which
# no reader writes and no lookup by name can match (found in review, 2026-09-23: 63 of a real package's
# node names were whole signatures).
function signature(sig)
    while JS.kind(sig) in (JS.K"where", JS.K"::") && !isempty(something(JS.children(sig), ()))
        sig = first(JS.children(sig))
    end
    return sig
end

"""
    definitions(path) -> Vector{NodeSpan}

Every named node of the Julia file at `path`, in source order: each function, macro, struct, module and
constant, and each keyword field of a constant that is written as a keyword call, which is how a
generated docstring such as `ARGS_FORM.statement` has a node of its own.

The argument is `path`, the file to read. A file that does not parse yields what parsed rather than an
error, since a caller asking where something is must not be stopped by a file that is temporarily broken.
Returns the spans.

A name is BARE, `g` and not `Inner.g`, inside a submodule as at the top: a location's node is looked up
by the name a reader writes, and no reader writes the qualified one.
"""
function definitions(path::AbstractString)
    out = NodeSpan[]
    isfile(path) || return out
    src = read(path, String)
    tree = try
        JS.parseall(JS.SyntaxNode, src; filename = path, ignore_errors = true)
    catch
        return out
    end
    walk!(out, tree, src)
    return out
end

function walk!(out, node, src)
    cs = JS.children(node)
    cs === nothing && return
    for c in cs
        k = JS.kind(c)
        parts = doc_parts(c)
        if parts !== nothing
            # A docstring and what it documents are ONE node here: the parser wraps them together, and a
            # finding is nearly always in the docstring, which sits above the definition and so outside
            # its own byte range. Anchoring to the definition alone would send every such finding down the
            # weaker path, the quote searched over the whole file.
            documented = last(parts)
            name = doc_target(documented)
            if name !== nothing
                r = JS.byte_range(c)
                span = NodeSpan(name, JS.source_line(c), r, line_range(src, r))
                push!(out, span)
                JS.kind(documented) === JS.K"const" && keyword_fields!(out, documented, src, span.name)
                JS.kind(documented) === JS.K"module" && walk!(out, documented, src)
                continue
            end
            walk!(out, c, src)
            continue
        end
        name = bound_name(c)
        if name !== nothing
            r = JS.byte_range(c)
            span = NodeSpan(name, JS.source_line(c), r, line_range(src, r))
            push!(out, span)
            if k === JS.K"const"                             # the keyword fields of a constant value
                keyword_fields!(out, c, src, span.name)
            elseif k === JS.K"module"
                walk!(out, c, src)
            end
            continue
        end
        walk!(out, c, src)
    end
end

# A constant built by a keyword call — `const ARGS_FORM = Rule(id = :x, statement = "…")` — gives each
# keyword a node of its own, so a finding inside one of those strings anchors to `ARGS_FORM.statement`
# rather than to a line of a text no file holds whole. A keyword written after a semicolon sits under a
# `parameters` child of the call and is the same keyword.
function keyword_fields!(out, node, src, owner)
    for c in something(JS.children(node), ())
        if JS.kind(c) === JS.K"call"                          # only a call's keywords, never the binding itself
            args = [x for a in something(JS.children(c), ())
                      for x in (JS.kind(a) === JS.K"parameters" ? something(JS.children(a), ()) : (a,))]
            for a in args
                JS.kind(a) === JS.K"=" || continue
                kids = something(JS.children(a), ())
                length(kids) >= 2 && JS.kind(first(kids)) === JS.K"Identifier" || continue
                r = JS.byte_range(a)
                push!(out, NodeSpan(owner * "." * node_text(first(kids)), JS.source_line(a), r, line_range(src, r)))
            end
        end
        keyword_fields!(out, c, src, owner)
    end
end

function line_range(src::AbstractString, bytes::UnitRange{Int})
    isempty(bytes) && return 1:0
    # The parser reports BYTE offsets and `SubString` wants character indices. A package whose source
    # holds `π`, `Δ` or any other multi-byte name eventually has a node boundary land inside one, and
    # slicing there throws `StringIndexError` out of a rule — which is what happened on a real package.
    at(i) = thisind(src, clamp(i, 1, lastindex(src)))
    first_line = count(==('\n'), SubString(src, 1, at(first(bytes)))) + 1
    last_line = count(==('\n'), SubString(src, 1, at(last(bytes)))) + 1
    return first_line:last_line
end

"""
    docstrings(path) -> Vector{DocBlock}

Every docstring of the Julia file at `path`, in source order, each with the name of what it documents.
A docstring whose text is interpolated is returned as written, since what a rule reads is the source.

The argument is `path`, the file to read. Returns the blocks; a file that does not parse yields those
of what parsed.
"""
function docstrings(path::AbstractString)
    isfile(path) || return DocBlock[]
    return docstrings_of(read(path, String); filename = path)
end

"""
    docstrings_of(src; filename = "source.jl") -> Vector{DocBlock}

The docstrings of Julia source held in memory, for a rule handed the text rather than the path. The
arguments are:

- `src` — the source.
- `filename` — the name to parse it under.

Returns the blocks.
"""
function docstrings_of(src::AbstractString; filename::AbstractString = "source.jl")
    out = DocBlock[]
    tree = try
        JS.parseall(JS.SyntaxNode, src; filename, ignore_errors = true)
    catch
        return out
    end
    docs!(out, tree)
    return out
end

function docs!(out, node)
    cs = JS.children(node)
    cs === nothing && return
    for c in cs
        parts = doc_parts(c)
        if parts !== nothing
            # The INDENTATION is kept: a docstring opens with its signature, indented, and stripping
            # the text of leading space hides that line from any rule that reads it. Only the quotes
            # and the blank lines around the body come off.
            raw = String(JS.sourcetext(first(parts)))
            body = strip(replace(raw, r"^(?:raw)?\"{1,3}" => "", r"\"{1,3}$" => ""), '\n')
            target = something(doc_target(last(parts)), "")
            push!(out, DocBlock(target, body, JS.source_line(c)))
        end
        docs!(out, c)
    end
end

"""
    prose_text(path; comments = true) -> String

The file's PROSE alone, with every other line left empty so that line numbers are unchanged. The
arguments are:

- `path` — the Julia file to read.
- `comments` — whether ordinary comments count as prose here.

Returns the masked text.

The distinction matters to a rule about RENDERING: a docstring is published and a comment is not, so a
rule that exists because a reader would see the wrong thing on the page reads docstrings alone, while a
rule about what the text says reads both.

A documentation rule reads this rather than the source. Julia code is full of text that looks like prose
markup — a regular expression holding double backticks, a string holding a pipe table — and a rule handed
the whole file reports the code as though it were the prose about it. Keeping the line numbering is what
lets a finding still say where it is.
"""
function prose_text(path::AbstractString; comments::Bool = true)
    isfile(path) || return ""
    src = read(path, String)
    lines = split(src, '\n')
    keep = falses(length(lines))
    for d in docstrings(path)                        # the docstring blocks, by their own line ranges
        span = doc_span(lines, d.line)
        for i in span; keep[i] = true; end
    end
    if comments
        for (i, line) in pairs(lines)
            occursin(r"^\s*#(?!=)", line) && (keep[i] = true)  # a comment line, never a `#=` block opener
        end
    end
    return join((keep[i] ? lines[i] : "" for i in eachindex(lines)), '\n')
end

# A docstring runs from its opening triple quote to the closing one; a one-line docstring, written
# with single quotes, is that line alone. (The marker is not written out here: the docstring reader of
# the tree being replaced pairs on it literally, and a comment holding one shifts every pairing after it.)
function doc_span(lines, start)
    start <= length(lines) || return start:start-1
    opener = lines[start]
    count(==("\"\"\""), [m.match for m in eachmatch(r"\"\"\"", opener)]) >= 2 && return start:start
    occursin("\"\"\"", opener) || return start:start
    for i in (start+1):length(lines)
        occursin("\"\"\"", lines[i]) && return start:i
    end
    return start:length(lines)
end

"""
    mask_code_spans(line) -> String

The line with every single-backtick code span blanked to spaces of the same length, so that a pattern
about MATHEMATICS does not match a code span that merely looks like it. The argument is `line`, the line
to mask. Returns the masked line, whose length and column positions are unchanged.
"""
mask_code_spans(line::AbstractString) = replace(String(line), r"(?<!`)`[^`\n]+`(?!`)" => m -> " "^length(m))

"""
    mask_math_spans(line) -> String

The line with every double-backtick span blanked to spaces of the same length, so a bracket inside a
math span is not read as prose. The argument is `line`. Returns it, length preserved.

Kept APART from [`mask_code_spans`](@ref) on purpose: the LaTeX rules read their mathematics inside
exactly these spans, and masking them everywhere blinded eleven rules at once. Only what counts
brackets or scans for links wants them gone — the `[` of a half-open interval written ``[a, b)`` has
no `]` and never will.
"""
mask_math_spans(line::AbstractString) = replace(String(line), r"``[^`\n]+?``" => m -> " "^length(m))

"""
    single_escapes(line) -> String

The line with every doubled LaTeX backslash written singly, so that a rule about LaTeX reads the same
text whether it came from a Markdown page or from a Julia docstring. The argument is `line`, the line to
read. Returns it rewritten; its length is NOT preserved, so a rule using this reports the whole line.

The doubling is not a mistake to be reported — `RULE.TEX.SWALLOWED_ESCAPE` REQUIRES it, because Julia
eats a single backslash in a docstring before LaTeX ever sees it. So a page carries `\\int f \\, g` and the
docstring saying the same thing carries `\\\\int f \\\\, g`, and a pattern written for one of them silently
misreads the other. `RULE.TEX.SPACING` reported every correct `\\\\,\\\\mathrm{d}x` in a consumer's
docstrings because its exception for the differential was written in the page's spelling.
"""
single_escapes(line::AbstractString) = replace(String(line), "\\\\" => "\\")

"""
    ignored(root) -> Function

A predicate saying whether a path, relative to `root`, is one the package's own `.gitignore` excludes.
The argument is `root`, the package root. Returns the predicate; it is `false` everywhere when there is
no `.gitignore`.

**Why a rule never reads an ignored file.** Such a file is not source — the package has said so. It is
build output, and a finding in it names a line that will not exist after the next build, sends whoever
fixes it into an artefact, and cannot be fixed there at all. A consumer copies four rationale
documents into `docs/src/` as lowercase siblings and renders a Literate example beside them; all five
are ignored, all five are rewritten every build, and the default pages pattern `docs/src/**/*.md` globs
them. On a built tree that was 264 findings against 108 real ones, and once its `docs/make.jl` called
this package the build would have been linting its own output.

It is read from the FILES rather than from `git check-ignore`, because the harness that runs these
checks starts no child process: a rule must give the same answer on a machine with no git on its path.
Checked against `git check-ignore` over 3,203 files in four repositories, it disagrees on two, both
deliberate and both the same name:

- a file that a pattern matches but the repository TRACKS. Git never ignores a tracked file; knowing
  which are tracked needs git, so this skips it. The difference is conservative — a file the package
  told git to ignore goes unread — and it is a file the package asked not to have around.
- a file ignored by the user's GLOBAL excludes (`~/.config/git/ignore`). Those are per-machine, and
  reading them would make a rule answer differently on two machines from the same commit, which is the
  one thing this may not do.
"""
function ignored(root::AbstractString)
    # Every `.gitignore` under the root, not only the one at it: a package may ignore build output from
    # the directory that holds it, and GBGHomogeneousTurbulence — then called GBGIsotropicTurbulence —
    # ignores 129 files that way. A deeper file overrides a shallower one, and within one file the last
    # matching line wins, as git decides it.
    levels = Tuple{String,Vector{Tuple{Regex,Bool}}}[]
    for (dir, _, fs) in walkdir(root; onerror = SKIP_VANISHED)
        rel = replace(relpath(dir, root), '\\' => '/')
        (rel == ".git" || startswith(rel, ".git/")) && continue   # git's own directory, not `.github/`
        ".gitignore" in fs || continue
        prefix = rel == "." ? "" : rel * "/"
        push!(levels, (prefix, gitignore_rules(joinpath(dir, ".gitignore"))))
    end
    isempty(levels) && return _ -> false
    sort!(levels; by = first)
    decide(f) = begin
        hit = false
        for (prefix, rules) in levels
            startswith(f, prefix) || continue
            rest = f[nextind(f, 0, length(prefix) + 1):end]
            # A `.gitignore` applies strictly below its directory, never to the directory itself: read
            # against an empty path its `*` excluded the directory whole, re-inclusions and all.
            isempty(rest) && continue
            for (rx, negated) in rules
                occursin(rx, rest) && (hit = !negated)
            end
        end
        hit
    end
    # A file under an excluded directory is excluded whatever a deeper file says: git never re-includes
    # a file whose parent directory is ignored. Found when `inspiration/` — ignored here, holding a
    # clone whose own `.gitignore` re-includes its root manifest — surfaced a manifest of another
    # package as this one's (RULE.GIT.MANIFEST_TRACKED, 2026-09-26).
    return function (f::AbstractString)
        parts = split(f, '/')
        for k in 1:length(parts)-1
            decide(join(parts[1:k], '/') * "/") && return true
        end
        return decide(f)
    end
end

"""
    gitignore_rules(path) -> Vector{Tuple{Regex,Bool}}

The lines of one `.gitignore` as patterns, each with whether it re-includes rather than excludes. The
argument is `path`, the file to read. Returns them in file order, since the last match decides.
"""
gitignore_rules(path::AbstractString) = gitignore_rules_of(isfile(path) ? read(path, String) : "")

"""
    gitignore_rules_of(text) -> Vector{Tuple{Regex,Bool}}

The same, from the text of a `.gitignore` rather than its path, so the pattern grammar can be tested
without a directory. The argument is `text`, the file's content. Returns the rules in file order.
"""
function gitignore_rules_of(text::AbstractString)
    rules = Tuple{Regex,Bool}[]
    for raw in split(text, '\n')
        # Trailing whitespace is not part of a pattern unless a backslash keeps it, as git reads it.
        line = replace(lstrip(raw), r"(?<!\\)\s+$" => "")
        (isempty(line) || startswith(line, "#")) && continue
        negated = startswith(line, "!")
        negated && (line = line[2:end])
        isdir_only = endswith(line, "/")
        # Anchoring is decided BEFORE the leading slash is stripped. `!/Manifest.toml` anchors to the
        # root; read after stripping it looks unanchored, and the negation then re-includes the file at
        # every depth — which is exactly what GBGHomogeneousTurbulence's `Manifest.toml` / `!/Manifest.toml`
        # pair is written to prevent.
        anchored = startswith(line, "/") || occursin('/', strip(line, '/'))
        line = strip(line, '/')
        isempty(line) && continue
        # A directory matches everything under it; an unanchored pattern matches at any depth.
        tail = isdir_only ? "/.*" : "(?:/.*)?"
        push!(rules, (Regex("^" * (anchored ? "" : "(?:.*/)?") * wildcard_source(line) * tail * "\$"), negated))
    end
    return rules
end

# ─────────────────────────────────────────────────────────────────────────── a docstring's signature

# One name for a whole string, built from the one pattern above so the two cannot disagree. A combining
# mark is admitted at the end: `û` is written as `u` plus U+0302 in some sources.
const IDENTIFIER = Regex("^" * NAME * "[\\p{M}]*\$")

"""
    signature_line(doc) -> String

The signature a docstring opens with — the indented call on its first non-empty line — or an empty string
where it opens with prose instead. The argument is `doc`, the docstring's text. Returns the line, stripped.
"""
function signature_line(doc::AbstractString)
    for line in split(doc, '\n')
        isempty(strip(line)) && continue
        startswith(line, (' ', '\t')) || return ""
        return String(strip(line))
    end
    return ""
end

"""
    signature_lines(doc) -> Vector{String}

Every signature a docstring displays: the indented lines it opens with, blank lines between them
included, up to its first line of prose. The argument is `doc`, the docstring's text. Returns them stripped, in order, empty where it
opens with prose.

A docstring may display several arities — `weighted_inner(f, w)`, `weighted_inner(f, g, w)` — and a
rule about how many arguments something takes must see all of them. Reading only the first reported
`weighted_inner` as taking two, and asked for the prose form on a binding whose three-argument form
needs bullets. Only the LEADING block counts: an indented line further down is a code example.
"""
function signature_lines(doc::AbstractString)
    out = String[]
    current = ""
    for line in split(doc, '\n')
        # A blank line separates two signatures of the block and does not end it; the first line that is
        # neither blank nor indented does (GBGPeriodicFields' request of 2026-09-27: every signature after a
        # blank line went unread, so its keywords were reported missing and its stale names passed).
        isempty(strip(line)) && continue
        startswith(line, (' ', '\t')) || break
        # A signature too wide for the column is wrapped, and its continuation is indented too. Lines are
        # joined until the parentheses balance, or the second of a wrapped pair reads as its own call
        # with the arguments left on the first line lost.
        current = isempty(current) ? String(strip(line)) : current * " " * strip(line)
        if count(==('('), current) == count(==(')'), current)
            push!(out, current); current = ""
        end
    end
    isempty(current) || push!(out, current)
    return out
end

"""
    argument_list(signature) -> Union{String,Nothing}

What sits between the parentheses of a call: the FIRST opening parenthesis and the one that closes it,
matched by depth. The argument is `signature`, the signature line. Returns the text inside, or `nothing`
where the line holds no balanced call.

Depth matching is what makes it right. Cutting a `-> …` return annotation off first is unsound, because a
default holding an arrow — `exempt = (hit -> false)` — is then cut in half and the signature parses as
nothing at all.
"""
function argument_list(signature::AbstractString)
    o = findfirst('(', signature)
    o === nothing && return nothing
    depth = 0
    i = o
    while i <= lastindex(signature)
        signature[i] == '(' && (depth += 1)
        if signature[i] == ')'
            depth -= 1
            depth == 0 && return signature[nextind(signature, o):prevind(signature, i)]
        end
        i = nextind(signature, i)
    end
    return nothing
end

"""
    parameters(inside) -> Tuple{Vector{String},Vector{String}}

The positional and keyword parameter NAMES of an argument list, with their types and defaults taken off.
The argument is `inside`, the text between the parentheses. Returns the two lists, positional first.

A bare splat — `kwargs...` — counts as a parameter although it is not an identifier: a docstring for
`f(cfg; kwargs...)` documents a keyword argument, and dropping the splat would read it as taking none.
A typed splat is already its own name and is not counted twice.
"""
function parameters(inside::AbstractString)
    semi = findfirst(';', inside)
    positional_text = semi === nothing ? inside : inside[1:prevind(inside, semi)]
    keyword_text = semi === nothing ? "" : inside[nextind(inside, semi):end]
    bare(raw) = String(strip(split(split(raw, "::")[1], "=")[1]))
    named(text) = [bare(r) for r in slots(text) if occursin(IDENTIFIER, bare(r))]
    splats(text) = [x for x in bare.(slots(text)) if occursin(Regex("^" * NAME * "\\.\\.\\.\$"), x)]
    return (vcat(named(positional_text), splats(positional_text)),
            vcat(named(keyword_text), splats(keyword_text)))
end

"""
    slots(text) -> Vector{String}

One argument per entry, splitting only at the commas that separate arguments. The argument is `text`,
part of an argument list. Returns the entries, stripped, with empty ones dropped.

A comma inside a type is not a separator: `offset::NTuple{3, Real}` is ONE argument, and splitting on
every comma makes it two — the second of which, `Real}`, carries no name, so a count came out right by
luck wherever names were what mattered and wrong wherever the count was.
"""
function slots(text::AbstractString)
    out = String[]; depth = 0; start = firstindex(text)
    for (i, c) in pairs(text)
        c in ('{', '(', '[') && (depth += 1)
        c in ('}', ')', ']') && (depth -= 1)
        if c == ',' && depth == 0
            push!(out, String(strip(text[start:prevind(text, i)]))); start = nextind(text, i)
        end
    end
    start <= lastindex(text) && push!(out, String(strip(text[start:end])))
    return filter(!isempty, out)
end

"""
    arity(inside) -> Tuple{Int,Int}

How many positional and keyword arguments a signature's argument list holds, counting a slot that has
no NAME. The argument is `inside`, what sits between the parentheses. Returns the two counts.

`field_spectral_shape(grid, fourier_layout, ::Val{R})` takes three; [`parameters`](@ref) returns two,
because the third slot is typed and unnamed and there is no name to return. A rule about how many
arguments a reader meets must count it: the caller passes it, and the docstring documents it.
"""
function arity(inside::AbstractString)
    semi = findfirst(';', inside)
    pos = semi === nothing ? inside : inside[1:prevind(inside, semi)]
    kw = semi === nothing ? "" : inside[nextind(inside, semi):end]
    return (length(slots(pos)), length(slots(kw)))
end

# ───────────────────────────────────────────────────────────────────────────────────────── Markdown

"""
    headings(path) -> Vector{NodeSpan}

Every heading of the Markdown file at `path`, each named by its HEADING PATH — the headings above it and
itself, joined by `" / "` — so a section keeps its name when a sibling is renamed. A heading inside a
fenced code block is not a heading.

The argument is `path`, the file to read. Returns the spans, each spanning from its own line to the line
before the next heading of the same level or higher.
"""
function headings(path::AbstractString)
    out = NodeSpan[]
    isfile(path) || return out
    lines = readlines(path)
    stack = String[]
    open_ = Tuple{Int,Int,Int}[]          # (index into out, level, start line)
    fence = nothing                       # the open fence's character and length, as CommonMark closes it
    for (i, line) in pairs(lines)
        if fence === nothing
            f = fence_of(line)
            f === nothing || (fence = f; continue)
        else
            # A fence closes only on a line of its own character at least as long, so a four-backtick
            # fence holds a three-backtick one and its headings, and `~~~` is a fence too.
            s = strip(line)
            !isempty(s) && all(==(first(fence)), s) && length(s) >= last(fence) && (fence = nothing)
            continue
        end
        m = match(r"^(#{1,6})\s+(.*?)\s*$", line)
        m === nothing && continue
        level = length(m.captures[1])
        while length(stack) >= level; pop!(stack); end
        while !isempty(open_) && last(open_)[2] >= level
            idx, _, start = pop!(open_)
            out[idx] = NodeSpan(out[idx].name, out[idx].line, 1:0, start:(i - 1))
        end
        push!(stack, String(m.captures[2]))
        push!(out, NodeSpan(join(stack, " / "), i, 1:0, i:length(lines)))
        push!(open_, (length(out), level, i))
    end
    return out
end

# A line that opens a fenced code block: three or more backticks or tildes, indented at most three
# spaces. Returns the character and how many of it, or `nothing`.
function fence_of(line::AbstractString)
    m = match(r"^ {0,3}(`{3,}|~{3,})", line)
    return m === nothing ? nothing : (m.captures[1][1], length(m.captures[1]))
end

"""
    heading_path(path, line) -> String

The heading path of the section the line `line` of the Markdown file at `path` falls in, empty above the
first heading. The arguments are `path`, the file, and `line`, the line in it. Returns the path.
"""
heading_path(path::AbstractString, line::Integer) = heading_in(headings(path), line)

function heading_in(spans::Vector{NodeSpan}, line::Integer)
    best = ""
    for h in spans
        h.line <= line && (best = h.name)
        h.line > line && break
    end
    return best
end

# ───────────────────────────────────────────────────────────────────────────────────── re-anchoring

"""
    find_node(root, file, node) -> UnitRange{Int}

The lines the named node spans in the file, or an empty range when the file holds no such node. Julia
nodes are named by binding (`f`, `S`, `ARGS_FORM.statement`) and Markdown nodes by heading path.

The arguments are:

- `root` — the package root.
- `file` — the path relative to it.
- `node` — the name to find.

Returns the line range.
"""
function find_node(root::AbstractString, file::AbstractString, node::AbstractString)
    spans = find_nodes(root, file, node)
    return isempty(spans) ? (1:0) : first(spans)
end

# Every span the name has: a generic's methods each carry a docstring, and a heading may repeat, so a
# quote is looked for in all of them before it is looked for in the whole file.
find_nodes(root::AbstractString, file::AbstractString, node::AbstractString) =
    spans_named(nodes_of(joinpath(root, file)), node)

spans_named(spans::Vector{NodeSpan}, node::AbstractString) =
    isempty(node) ? UnitRange{Int}[] : [s.lines for s in spans if s.name == node]

# Every named node of one file, parsed ONCE: a caller with several lines to place in one file asks
# this and then `node_in`, since parsing the file again for each of 235 hits cost two seconds where the
# search itself cost a fifth of one (found in review, 2026-09-26).
nodes_of(path::AbstractString) = endswith(path, ".jl") ? definitions(path) : headings(path)

function node_in(path::AbstractString, spans::Vector{NodeSpan}, line::Integer)
    endswith(path, ".jl") || return heading_in(spans, line)
    best = ""
    width = typemax(Int)
    for s in spans
        if line in s.lines && length(s.lines) < width
            best = s.name; width = length(s.lines)
        end
    end
    return best
end

"""
    reanchor(root, loc; loose = true) -> Model.Location

The location as it stands now: the same file, the same node and quote, with the line found again and
`found` saying how. The node is looked for first and the quote inside it (`BY_NODE`); failing that the
quote alone, the occurrence nearest the old line (`BY_QUOTE`); failing that the location is `OUTDATED`
and its line is left as it was, never pointed at whatever now sits there.

A node that survives does not anchor a finding whose quote is gone: the finding was about that text, and
a fixer sent to a paragraph it was not written about is the failure this exists to prevent. A location
with a node and no quote is about the node itself and anchors to it.

The arguments are:

- `root` — the package root.
- `loc` — the location to find again.
- `loose` — whether a quote may, as a last resort, be matched as the built page reads it.

A location with neither node nor quote is the file itself and comes back unchanged while the file exists. Returns the
located copy.
"""
function reanchor(root::AbstractString, loc::Model.Location; loose::Bool = true)
    path = joinpath(root, loc.file)
    isfile(path) || return outdated(loc)
    isempty(loc.node) && isempty(loc.text) && return loc
    lines = readlines(path)

    nodes = nodes_of(path)
    spans = spans_named(nodes, loc.node)
    if !isempty(spans)
        isempty(loc.text) && return Model.Location(; file = loc.file, node = loc.node, text = loc.text,
                                                    line = first(first(spans)), found = Model.Anchor.BY_NODE, at = loc.at)
    end
    isempty(loc.text) && return outdated(loc)

    # The quote as written on one line; as written, across the lines the source wraps it over; and, only
    # where both fail, as it READS on the built page, whose quote lost the source's markup. The reading
    # comes last because it erases differences: tried first, it lost 1769 quotes spelled as the source
    # spells them and found text the finding was not about (both found in review, 2026-09-24).
    exact = [i for (i, l) in pairs(lines) if occursin(loc.text, l)]
    hits = !isempty(exact) ? exact : flattened_lines(path, loc.text; form = :written)
    loose && isempty(hits) && (hits = flattened_lines(path, loc.text; form = :read))
    isempty(hits) && return outdated(loc)
    inside = [i for i in hits if any(sp -> i in sp, spans)]
    if !isempty(inside)
        return Model.Location(; file = loc.file, node = loc.node, text = loc.text,
                               line = nearest(inside, loc.line), found = Model.Anchor.BY_NODE, at = loc.at)
    end
    i = nearest(hits, loc.line)
    return Model.Location(; file = loc.file, node = node_in(path, nodes, i), text = loc.text,
                           line = i, found = Model.Anchor.BY_QUOTE, at = loc.at)
end

nearest(hits, line) = hits[argmin(abs.(hits .- line))]

"""
    place(cfg, root, text) -> Union{Model.Location,Nothing}

Where a quote is written, searched across the package's documentation. The arguments are:

- `cfg` — the package's config, which says where its documentation is.
- `root` — the package root.
- `text` — the quote, as it was read.

Returns the one location that holds it, or `nothing` when no file holds it or more than one does.

This is for a quote read somewhere that is not a file: a reader given one BUILT page quotes the page,
and the words may have been rendered from a docstring in the source rather than written on the page.
Searching the documentation for them is what puts the finding in the file a fixer can edit.

Two files holding the same words is NOT placed. A fixer sent to one of two identical sentences is a
fixer sent to a coin toss, and the report naming the quote as unplaced is the honest answer. The pages,
docstrings and examples are searched first and the rationale documents only when none of them holds the
quote, so a sentence a decision log repeats is still the docstring's. Whitespace
is flattened before the search, so a sentence the build re-wrapped is still found.
"""
function place(cfg::Model.Config, root::AbstractString, text::AbstractString)
    isempty(flatten(text)) && return nothing
    # As the source writes it first, across every file; as the page reads it only where no file holds it
    # so. Within each, the text a user reads first and the rationale documents only where none of it holds
    # the quote: a docstring whose sentence a decision log also records is the docstring's (found in
    # review, 2026-09-23), while a decision-log sentence a code comment merely READS like is the log's.
    for form in (:written, :read)
        for tier in ((Model.FileSet.PAGES, Model.FileSet.DOCSTRINGS, Model.FileSet.LITERATE), (Model.FileSet.RATIONALE,))
            hits = Model.Location[]
            for fileset in tier, file in files(cfg, root, fileset)
                any(h -> h.file == file, hits) && continue
                found = flattened_lines(joinpath(root, file), text; form)
                isempty(found) && continue
                line = first(found)
                push!(hits, Model.Location(; file, node = node_at(root, file, line), text = String(text),
                                            line = line, found = Model.Anchor.BY_QUOTE))
            end
            isempty(hits) || return length(hits) == 1 ? only(hits) : nothing
        end
    end
    return nothing
end

# One run of whitespace is one space, so a sentence the build re-wrapped still matches the source.
flatten(text::AbstractString) = strip(replace(String(text), r"\s+" => " "))

"""
    reading(text) -> String

A text as the built page reads it: what the source's markup renders away is taken away, and whitespace is
flattened. The argument is `text`, a quote or a stretch of source. Returns the reading.

A reader given a built page quotes the page, where a cross-reference is its label alone, `**same**` is
`same`, a formula written between double backticks stands between dollars, a docstring's doubled
backslash is a single one, and a Literate example has no comment marks. Both the quote and the source are put in this form before
one is searched for in the other, so the two spellings of one sentence meet; the source's line numbers
are kept, since the reading is taken line by line.

It is a comparison form and nothing is ever written in it. It deletes more than a renderer would — every
backtick, dollar, asterisk and bracket — because a character deleted from both sides costs a match
nothing, while one kept on one side loses it.
"""
reading(text::AbstractString) = flatten(join((reading_line(l) for l in split(String(text), '\n')), " "))

# One line as the page reads it. `escaped` is for a line of a Julia file, whose docstrings double every
# backslash the page shows once; a quote copied from the page is never escaped.
function reading_line(line::AbstractString; escaped::Bool = false)
    l = String(line)
    occursin(r"^\s*```", l) && return ""                         # a fence line renders as nothing
    l = replace(l, r"^\s*!!!\s+\w+(?:\s+\"(.*)\")?\s*$" => s"\1")  # an admonition renders as its title
    l = replace(l, r"\s+#src\s*$" => "")                          # Literate's end-of-line filter
    l = replace(l, r"^\s*#!?(?:md|jl|nb|src)\s+" => "")           # Literate's line filters, `#md # …`
    l = replace(l, r"^\s*#+\s?" => "")                            # a heading's, or a Literate line's, marks
    l = replace(l, r"^\s*(?:[-*+]|\d+[.)]|>)\s+" => "")            # a list item's or a quotation's leader
    l = replace(l, r"\]\((?:[^()]|\([^()]*\))*\)" => "")          # a link's target, one level of ( ) inside
    escaped && (l = replace(l, "\\\\" => "\\"))                     # a docstring's escaped backslash
    l = replace(l, r"\\+[\[\]()$]" => "")                        # display and inline delimiters, \[ … \], and \$
    return replace(l, r"[`$*\[\]]" => "")
end

"""
    occurrences(cfg, root, text) -> Vector{Model.Location}

Every place in the package's documentation that holds a quote, one location each. The arguments are:

- `cfg` — the package's config, which says where its documentation is.
- `root` — the package root.
- `text` — the quote, as it was read.

Returns the locations, ordered by file and line, empty where nothing holds it.

This is what a fix pass runs over each finding before the fixer is sent out: a sentence, and above all a
formula, is often written in several places, and a fix made where the reader happened to look leaves the
others standing. A fourth copy of a corrected formula once survived a whole run that way.
"""
function occurrences(cfg::Model.Config, root::AbstractString, text::AbstractString)
    # As WRITTEN only: a copy is the same spelling. The reading form erases exactly the difference a
    # markup rule is about, and listed text already written right as a copy of the defect (found in
    # review, 2026-09-24).
    isempty(flatten(text)) && return Model.Location[]
    out = Model.Location[]
    seen = Set{String}()
    for fileset in (Model.FileSet.PAGES, Model.FileSet.DOCSTRINGS, Model.FileSet.LITERATE, Model.FileSet.RATIONALE)
        for file in files(cfg, root, fileset)
            file in seen && continue
            push!(seen, file)
            path = joinpath(root, file)
            hits = flattened_lines(path, text; form = :written)
            isempty(hits) && continue
            nodes = nodes_of(path)                          # once per file, not once per hit
            for line in hits
                push!(out, Model.Location(; file, node = node_in(path, nodes, line), text = String(text),
                                           line = line, found = Model.Anchor.BY_QUOTE))
            end
        end
    end
    return sort!(out; by = l -> (l.file, l.line))
end

"""
    formulas(text) -> Vector{String}

Every mathematical expression written in a text, as the LaTeX idiom writes them: what stands between
single dollars. The argument is `text`. Returns the expressions, without their delimiters and without
repetition.

A fix pass searches for these as well as for the whole quote. A formula travels between documents on its
own, without the sentence that carried it, so a search for the sentence alone finds one copy of three.

A single character between dollars is not one of these: searching a whole documentation for one letter
finds every page and means nothing.
"""
function formulas(text::AbstractString)
    out = String[]
    t = String(text)
    add(f) = (f = strip(f); length(f) >= 2 && !(f in out) && push!(out, String(f)))
    # Between double backticks. A quote the reader cut at a line end leaves a formula open at one of its
    # ends, so the delimiters cannot be paired from the left: `` ``\hat f(k)`` holds, and ``u_k`` ``
    # paired that way made one formula of the two and prose of the rest (found in review, 2026-09-24).
    # The pieces between delimiters alternate prose and formula; which alternation is right is read off
    # the pieces themselves — the one whose formulas look like mathematics and whose prose like words.
    pieces = split(t, r"(?<!`)``(?!`)")
    if length(pieces) > 1
        score(k) = sum((isodd(i) == isodd(k) ? (mathlike(p) - wordlike(p)) : (wordlike(p) - mathlike(p)))
                       for (i, p) in pairs(pieces))
        k = iseven(length(pieces)) && score(1) > score(2) ? 1 : 2   # an odd count is balanced: formulas at even places
        for (i, p) in pairs(pieces)
            isodd(i) == isodd(k) || continue
            wordlike(p) > mathlike(p) && continue
            add(p)
        end
    end
    # Between single dollars, as a quote copied from the page spells them; an escaped dollar is prose.
    for m in eachmatch(r"(?<![\$\\])\$([^\$\n]{2,})\$(?!\$)", t)
        wordlike(m.captures[1]) > mathlike(m.captures[1]) && continue
        add(m.captures[1])
    end
    return out
end

# How much a piece reads like mathematics, and how much like prose: a macro, a sub- or superscript, a
# brace; and a run of two ordinary words.
mathlike(p) = count(c -> c in ('\\', '^', '_', '{', '}', '='), p)
wordlike(p) = length(collect(eachmatch(r"\b[a-z]{3,}\b", p)))

# Every line a quote starts on, in order, with whitespace flattened on both sides. `form = :written`
# compares the text as the source spells it; `:read` compares both as the page reads them, a Julia
# file's escaped backslashes unescaped on the source side alone.
function flattened_lines(path::AbstractString, text::AbstractString; form::Symbol = :written)
    needle = form === :read ? reading(text) : flatten(text)
    isempty(needle) && return Int[]
    escaped = endswith(path, ".jl")
    isfile(path) || return Int[]
    lines = try
        readlines(path)
    catch
        return Int[]
    end
    io = IOBuffer(); at = Int[]
    for (i, l) in pairs(lines)
        piece = form === :read ? flatten(reading_line(l; escaped)) : flatten(l)
        isempty(piece) && continue
        position(io) == 0 || (write(io, " "); push!(at, i))
        for _ in 1:length(piece); push!(at, i); end
        write(io, piece)
    end
    hay = String(take!(io))
    out = Int[]
    from = 1
    chars = 0; counted = 1                 # characters before byte `counted`, carried from hit to hit
    while true
        r = findnext(needle, hay, from)
        r === nothing && break
        # `findnext` indexes bytes; the map is per character, so count the characters up to the hit —
        # from the last hit on, since counting from the start again made a long page quadratic.
        chars += length(SubString(hay, counted, prevind(hay, first(r))))
        counted = first(r)
        line = at[min(chars + 1, length(at))]
        isempty(out) || last(out) == line || push!(out, line)
        isempty(out) && push!(out, line)
        from = nextind(hay, first(r))
    end
    return out
end

outdated(loc) = Model.Location(; file = loc.file, node = loc.node, text = loc.text, line = loc.line,
                               found = Model.Anchor.OUTDATED, at = loc.at)

"""
    node_at(root, file, line) -> String

The name of the node the line falls in — the innermost Julia definition, or the Markdown heading path —
empty where it falls in none. The arguments are:

- `root` — the package root.
- `file` — the path relative to it.
- `line` — the line to place.

Returns the name.
"""
function node_at(root::AbstractString, file::AbstractString, line::Integer)
    path = joinpath(root, file)
    return node_in(path, nodes_of(path), line)
end

# ────────────────────────────────────────────────────────────────────────────────── the built site
#
# Harvested from `HtmlWalker` of the tree being replaced: what a rule about the RENDERED page needs is
# the page as a reader meets it, not as its source was written. A built-site rule reads through these.

parse_page(path::AbstractString) = parsehtml(read(path, String); preserve_whitespace = true)

"""
    tagname(node) -> Symbol

The tag of an element node (`:div`, `:p`, …), or `:text` for a text node (Gumbo drops comments at
parse time, so no comment node exists). Returns the symbol.
"""
tagname(::HTMLText) = :text
tagname(el::HTMLElement{T}) where {T} = T
tagname(::Any) = :other

"""
    classes(el) -> Vector{String}

The `class` attribute of `el` split on whitespace, empty for a node without one. Returns the list.
"""
classes(el) = el isa HTMLElement ? String.(split(get(el.attributes, "class", ""))) : String[]

"""
    attr(el, name, default = "") -> String

The named attribute of a node, or a fallback. The arguments are:

- `el` — the node; anything that is not an `HTMLElement` (a text node) carries no attributes and
  always takes `default`.
- `name` — the attribute name.
- `default` — the value taken when `el` has no such attribute; `""` unless given.

Returns the string.
"""
attr(el, name::AbstractString, default = "") = el isa HTMLElement ? get(el.attributes, name, default) : default

"""
    elements(root, pred) -> Vector

Every element node under `root` (inclusive, document order) for which `pred(el)` is true. Returns the
list; `pred` receives `HTMLElement`s only.
"""
function elements(root, pred)
    out = Any[]
    for n in PreOrderDFS(root)
        n isa HTMLElement && pred(n) && push!(out, n)
    end
    return out
end

"""
    text_of(node) -> String

The concatenated text of every text node under `node` (comments excluded), as BeautifulSoup's
`get_text()` would give it. Returns the string.
"""
function text_of(node)
    io = IOBuffer()
    for n in PreOrderDFS(node)
        n isa HTMLText && write(io, n.text)
    end
    return String(take!(io))
end

"""
    page_text(node) -> String

The text of `node` as a reader of the page meets it: every text node in order, with a line break where
a block — a paragraph, a heading, a list item, a table cell — begins or ends, inline code between
backticks and a code block between fences. The argument is `node`. Returns the string.

Documenter writes no whitespace between tags, so the bare concatenation [`text_of`](@ref) gives runs a
heading into the paragraph after it (`…of the same field.The parts are:`): a reader shown that quotes
words no source holds, and a quote across the boundary could never be placed (found in review,
2026-09-23).
"""
function page_text(node)
    io = IOBuffer()
    page_text!(io, node)
    return String(take!(io))
end

const BLOCK_TAGS = Set([:p, :h1, :h2, :h3, :h4, :h5, :h6, :li, :ul, :ol, :div, :pre, :table, :tr, :td, :th,
                        :dt, :dd, :dl, :br, :section, :article, :header, :footer, :blockquote, :details,
                        :summary, :hr, :figure, :figcaption])

# Code is kept visible as code: an inline span between backticks, a block between fences. A reader
# judging whether a backtick span holds Julia was shown the span's words with nothing around them.
function page_text!(io::IO, n; in_pre::Bool = false)
    if n isa HTMLText
        write(io, n.text)
    elseif n isa HTMLElement
        t = tagname(n)
        block = t in BLOCK_TAGS
        mark = t === :pre ? "```" : (t === :code && !in_pre ? "`" : "")
        # A link is shown as one, `[text](target)`: with links stripped a term fixed by linking it to its
        # definition read exactly as the unfixed text, and no verifier could pass such a fix (found by PF,
        # 2026-09-24, ten findings).
        href = t === :a ? String(attr(n, "href")) : ""
        block && write(io, '\n')
        t === :pre && write(io, mark, '\n')
        t === :code && !in_pre && write(io, mark)
        isempty(href) || write(io, '[')
        for c in children(n)
            page_text!(io, c; in_pre = in_pre || t === :pre)
        end
        isempty(href) || write(io, "](", href, ")")
        t === :code && !in_pre && write(io, mark)
        t === :pre && write(io, '\n', mark)
        block && write(io, '\n')
    end
    return io
end

"""
    article_of(doc) -> Union{HTMLElement,Nothing}

The `<article class="content">` Documenter renders a page's body into, or `nothing` when the page has
none (the search page, an asset). Returns the element.
"""
function article_of(doc::HTMLDocument)
    hits = elements(doc.root, e -> tagname(e) == :article && "content" in classes(e))
    return isempty(hits) ? nothing : first(hits)
end


end # module Texts
