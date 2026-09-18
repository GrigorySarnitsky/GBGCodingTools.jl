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
        if JS.kind(c) === JS.K"doc"
            kids = something(JS.children(c), ())
            if length(kids) >= 2
                # The INDENTATION is kept: a docstring opens with its signature, indented, and stripping
                # the text of leading space hides that line from any rule that reads it. Only the quotes
                # and the blank lines around the body come off.
                raw = String(JS.sourcetext(kids[1]))
                body = strip(replace(raw, r"^(?:raw)?\"{1,3}" => "", r"\"{1,3}$" => ""), '\n')
                target = something(bound_name(kids[2]), "")
                push!(out, DocBlock(target, body, JS.source_line(c)))
            end
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
    # the directory that holds it, and GBGIsotropicTurbulence ignores 129 files that way. A deeper file
    # overrides a shallower one, and within one file the last matching line wins, as git decides it.
    levels = Tuple{String,Vector{Tuple{Regex,Bool}}}[]
    for (dir, _, fs) in walkdir(root)
        rel = relpath(dir, root)
        startswith(rel, ".git") && continue
        ".gitignore" in fs || continue
        prefix = rel == "." ? "" : replace(rel, '\\' => '/') * "/"
        push!(levels, (prefix, gitignore_rules(joinpath(dir, ".gitignore"))))
    end
    isempty(levels) && return _ -> false
    sort!(levels; by = first)
    return function (f::AbstractString)
        hit = false
        for (prefix, rules) in levels
            startswith(f, prefix) || continue
            rest = f[nextind(f, 0, length(prefix) + 1):end]
            for (rx, negated) in rules
                occursin(rx, rest) && (hit = !negated)
            end
        end
        return hit
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
        line = strip(raw)
        (isempty(line) || startswith(line, "#")) && continue
        negated = startswith(line, "!")
        negated && (line = line[2:end])
        isdir_only = endswith(line, "/")
        # Anchoring is decided BEFORE the leading slash is stripped. `!/Manifest.toml` anchors to the
        # root; read after stripping it looks unanchored, and the negation then re-includes the file at
        # every depth — which is exactly what GBGIsotropicTurbulence's `Manifest.toml` / `!/Manifest.toml`
        # pair is written to prevent.
        anchored = startswith(line, "/") || occursin('/', strip(line, '/'))
        line = strip(line, '/')
        isempty(line) && continue
        # `**` is held aside as a sentinel while `*` is rewritten, or the first pass would eat it.
        body = replace(line, "." => "\\.", "**" => "\0", "*" => "[^/]*", "?" => "[^/]")
        body = replace(body, "\0" => ".*")
        # A directory matches everything under it; an unanchored pattern matches at any depth.
        tail = isdir_only ? "/.*" : "(?:/.*)?"
        push!(rules, (Regex("^" * (anchored ? "" : "(?:.*/)?") * body * tail * "\$"), negated))
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

Every signature a docstring displays: the run of indented lines it opens with, before its first line of
prose. The argument is `doc`, the docstring's text. Returns them stripped, in order, empty where it
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
        isempty(strip(line)) && (isempty(out) && isempty(current) ? continue : break)
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

The arguments are:

- `root` — the package root.
- `file` — the path relative to it.
- `node` — the name to find.

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
empty where it falls in none. The arguments are:

- `root` — the package root.
- `file` — the path relative to it.
- `line` — the line to place.

Returns the name.
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
    article_of(doc) -> Union{HTMLElement,Nothing}

The `<article class="content">` Documenter renders a page's body into, or `nothing` when the page has
none (the search page, an asset). Returns the element.
"""
function article_of(doc::HTMLDocument)
    hits = elements(doc.root, e -> tagname(e) == :article && "content" in classes(e))
    return isempty(hits) ? nothing : first(hits)
end


end # module Texts
