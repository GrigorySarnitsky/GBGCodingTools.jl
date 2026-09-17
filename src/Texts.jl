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
the old line; failing that it says `OUTDATED` rather than guessing (`docs/ARCHITECTURE.md` §4.5).

This module is the second of the order and may name only [`Model`](@ref). It parses Julia with the
compiler's own parser, so what it calls a definition is what Julia calls one.
"""
module Texts

using ..Model

const JS = Base.JuliaSyntax

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
        sig = first(cs)
        return JS.kind(sig) === JS.K"call" && !isempty(JS.children(sig)) ? node_text(first(JS.children(sig))) : node_text(sig)
    elseif k === JS.K"struct"
        isempty(cs) && return nothing
        head = first(cs)
        JS.kind(head) === JS.K"<:" && !isempty(JS.children(head)) && (head = first(JS.children(head)))
        JS.kind(head) === JS.K"curly" && !isempty(JS.children(head)) && (head = first(JS.children(head)))
        return node_text(head)
    elseif k === JS.K"const" || k === JS.K"global"
        isempty(cs) && return nothing
        inner = first(cs)
        JS.kind(inner) === JS.K"=" && !isempty(JS.children(inner)) && (inner = first(JS.children(inner)))
        JS.kind(inner) === JS.K"::" && !isempty(JS.children(inner)) && (inner = first(JS.children(inner)))
        return node_text(inner)
    elseif k === JS.K"="
        isempty(cs) && return nothing
        lhs = first(cs)
        JS.kind(lhs) === JS.K"call" && !isempty(JS.children(lhs)) && return node_text(first(JS.children(lhs)))
        return nothing
    elseif k === JS.K"macrocall"
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

"""
    definitions(path) -> Vector{NodeSpan}

Every named node of the Julia file at `path`, in source order: each function, macro, struct, module and
constant, and each keyword field of a constant that is written as a keyword call, which is how a
generated docstring such as `ARGS_FORM.statement` has a node of its own.

The argument is `path`, the file to read. A file that does not parse yields an empty list rather than an
error, since a caller asking where something is must not be stopped by a file that is temporarily broken.
Returns the spans.
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
    walk!(out, tree, src, "")
    return out
end

function walk!(out, node, src, prefix)
    cs = JS.children(node)
    cs === nothing && return
    for c in cs
        k = JS.kind(c)
        if k === JS.K"doc"
            # A docstring and what it documents are ONE node here: the parser wraps them together, and a
            # finding is nearly always in the docstring, which sits above the definition and so outside
            # its own byte range. Anchoring to the definition alone would send every such finding down the
            # weaker path, the quote searched over the whole file.
            kids = something(JS.children(c), ())
            if length(kids) >= 2 && bound_name(kids[2]) !== nothing
                name = bound_name(kids[2])
                r = JS.byte_range(c)
                span = NodeSpan(isempty(prefix) ? name : prefix * "." * name, JS.source_line(c), r, line_range(src, r))
                push!(out, span)
                JS.kind(kids[2]) === JS.K"const" && keyword_fields!(out, kids[2], src, span.name)
                JS.kind(kids[2]) === JS.K"module" && walk!(out, kids[2], src, "")
                continue
            end
            walk!(out, c, src, prefix)
            continue
        end
        name = bound_name(c)
        if name !== nothing
            r = JS.byte_range(c)
            span = NodeSpan(isempty(prefix) ? name : prefix * "." * name, JS.source_line(c), r, line_range(src, r))
            push!(out, span)
            if k === JS.K"const"                             # the keyword fields of a constant value
                keyword_fields!(out, c, src, span.name)
            elseif k === JS.K"macrocall"
        # A defining macro call binds what it wraps: `Base.@kwdef struct S` is a struct named S, and
        # treating it as anonymous sent every keyword-default type down the weaker anchoring path.
        for c in cs
            n = bound_name(c)
            n === nothing || return n
        end
        return nothing
    elseif k === JS.K"module"
                walk!(out, c, src, "")                       # a module's own contents keep their bare names
            end
            continue
        end
        walk!(out, c, src, prefix)
    end
end

# A constant built by a keyword call — `const ARGS_FORM = Rule(id = :x, statement = "…")` — gives each
# keyword a node of its own, so a finding inside one of those strings anchors to `ARGS_FORM.statement`
# rather than to a line of a text no file holds whole.
function keyword_fields!(out, node, src, owner)
    for c in something(JS.children(node), ())
        if JS.kind(c) === JS.K"call"                          # only a call's keywords, never the binding itself
            for a in something(JS.children(c), ())
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
    first_line = count(==('\n'), SubString(src, 1, min(first(bytes), lastindex(src)))) + 1
    last_line = count(==('\n'), SubString(src, 1, min(last(bytes), lastindex(src)))) + 1
    return first_line:last_line
end

"""
    docstrings(path) -> Vector{DocBlock}

Every docstring of the Julia file at `path`, in source order, each with the name of what it documents.
A docstring whose text is interpolated is returned as written, since what a rule reads is the source.

The argument is `path`, the file to read. Returns the blocks; a file that does not parse yields none.
"""
function docstrings(path::AbstractString)
    isfile(path) || return DocBlock[]
    return docstrings_of(read(path, String); filename = path)
end

"""
    docstrings_of(src; filename = "source.jl") -> Vector{DocBlock}

The docstrings of Julia source held in memory, for a rule handed the text rather than the path. The
arguments are `src`, the source, and `filename`, the name to parse it under. Returns the blocks.
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
        if JS.kind(c) === JS.K"doc"
            kids = something(JS.children(c), ())
            if length(kids) >= 2
                text = node_text(kids[1])
                target = something(bound_name(kids[2]), "")
                push!(out, DocBlock(target, strip(strip(text, '"')), JS.source_line(c)))
            end
        end
        docs!(out, c)
    end
end

"""
    prose_text(path; comments = true) -> String

The file's PROSE alone, with every other line left empty so that line numbers are unchanged. The
arguments are `path`, the Julia file to read, and `comments`, whether ordinary comments count as prose
here. Returns the masked text.

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
    fenced = false
    for (i, line) in pairs(lines)
        startswith(strip(line), "```") && (fenced = !fenced)
        fenced && continue
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

"""
    heading_path(path, line) -> String

The heading path of the section the line `line` of the Markdown file at `path` falls in, empty above the
first heading. The arguments are `path`, the file, and `line`, the line in it. Returns the path.
"""
function heading_path(path::AbstractString, line::Integer)
    best = ""
    for h in headings(path)
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

The arguments are `root`, the package root, `file`, the path relative to it, and `node`, the name.
Returns the line range.
"""
function find_node(root::AbstractString, file::AbstractString, node::AbstractString)
    isempty(node) && return 1:0
    path = joinpath(root, file)
    spans = endswith(file, ".jl") ? definitions(path) : headings(path)
    for s in spans
        s.name == node && return s.lines
    end
    return 1:0
end

"""
    reanchor(root, loc) -> Model.Location

The location as it stands now: the same file, the same node and quote, with the line found again and
`found` saying how. The node is looked for first and the quote inside it (`BY_NODE`); failing that the
quote alone, the occurrence nearest the old line (`BY_QUOTE`); failing that the location is `OUTDATED`
and its line is left as it was, never pointed at whatever now sits there.

A node that survives does not anchor a finding whose quote is gone: the finding was about that text, and
a fixer sent to a paragraph it was not written about is the failure this exists to prevent. A location
with a node and no quote is about the node itself and anchors to it.

The arguments are `root`, the package root, and `loc`, the location to find again. A location with
neither node nor quote is the file itself and comes back unchanged while the file exists. Returns the
located copy.
"""
function reanchor(root::AbstractString, loc::Model.Location)
    path = joinpath(root, loc.file)
    isfile(path) || return outdated(loc)
    isempty(loc.node) && isempty(loc.text) && return loc
    lines = readlines(path)

    span = find_node(root, loc.file, loc.node)
    if !isempty(span)
        isempty(loc.text) && return Model.Location(; file = loc.file, node = loc.node, text = loc.text,
                                                    line = first(span), found = Model.Anchor.BY_NODE)
        for i in span
            i <= length(lines) && occursin(loc.text, lines[i]) &&
                return Model.Location(; file = loc.file, node = loc.node, text = loc.text,
                                       line = i, found = Model.Anchor.BY_NODE)
        end
    end

    if !isempty(loc.text)
        hits = [i for (i, l) in pairs(lines) if occursin(loc.text, l)]
        if !isempty(hits)
            i = argmin(abs.(hits .- loc.line))
            return Model.Location(; file = loc.file, node = node_at(root, loc.file, hits[i]), text = loc.text,
                                   line = hits[i], found = Model.Anchor.BY_QUOTE)
        end
    end
    return outdated(loc)
end

outdated(loc) = Model.Location(; file = loc.file, node = loc.node, text = loc.text, line = loc.line,
                               found = Model.Anchor.OUTDATED)

"""
    node_at(root, file, line) -> String

The name of the node the line falls in — the innermost Julia definition, or the Markdown heading path —
empty where it falls in none. The arguments are `root`, the package root, `file`, the path relative to
it, and `line`, the line. Returns the name.
"""
function node_at(root::AbstractString, file::AbstractString, line::Integer)
    path = joinpath(root, file)
    endswith(file, ".jl") || return heading_path(path, line)
    best = ""
    width = typemax(Int)
    for s in definitions(path)
        if line in s.lines && length(s.lines) < width
            best = s.name; width = length(s.lines)
        end
    end
    return best
end

end # module Texts
