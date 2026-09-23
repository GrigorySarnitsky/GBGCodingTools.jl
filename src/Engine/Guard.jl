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

Every mathematical expression a text writes, in order and with repetition: a double-backtick span
(the spelling the rulebook requires), a fenced math block, a display between doubled dollar signs,
and a span between single dollar signs. The argument is `text`. Returns the expressions, whitespace flattened and a doubled
backslash read singly, so that a re-wrapped line, or the same formula in a Julia docstring, is the same
expression it was.

Until 2026-09-23 only the single-dollar spelling was seen, which the rulebook forbids: every formula in
a package written as the rulebook requires was invisible to clause 6, and the fixer of
[GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/) edited eight of them unasked.
"""
function math_spans(text::AbstractString)
    t = String(text)
    out = String[]
    norm(x) = strip(replace(replace(x, "\\\\" => "\\"), r"\s+" => " "))
    rx = r"^[ \t]*(?:#[ \t]?)?(```+|~~~+)[ \t]*math[ \t]*\n(.*?)^[ \t]*(?:#[ \t]?)?\1[ \t]*$"ms
    for m in eachmatch(rx, t); push!(out, norm(m.captures[2])); end
    t = replace(t, rx => "")
    for m in eachmatch(r"\$\$(.+?)\$\$"s, t); push!(out, norm(m.captures[1])); end
    t = replace(t, r"\$\$(.+?)\$\$"s => "")
    for m in eachmatch(r"(?<!`)``(?!`)(.+?)(?<!`)``(?!`)"s, t); push!(out, norm(m.captures[1])); end
    t = replace(t, r"(?<!`)``(?!`)(.+?)(?<!`)``(?!`)"s => "")
    for m in eachmatch(r"(?<!\$)\$([^\$\n]+)\$(?!\$)", t); push!(out, norm(m.captures[1])); end
    return out
end

"""
    math_changed(before, after) -> Vector{String}

The mathematics this change adds, alters, removes or reorders. The arguments are `before` and `after`,
the file's text on each side. Returns the expressions that differ — those added, then those removed —
and, where the same expressions now stand in a different order, all of them; empty when the
mathematics is untouched.

CLAUSE 6, and the owner's ruling of 2026-09-21: **no edit inside a math span is made automatically**.
A program has no oracle for whether a formula is true — only the code it documents has that, and code
that is itself wrong then certifies prose that matches it — so a changed symbol, number or sign is put
to the owner as a question rather than committed. Deleting a formula and swapping two are edits too.
Whitespace alone is not a change, and a year in a citation is not mathematics.
"""
function math_changed(before::AbstractString, after::AbstractString)
    was = math_spans(before)
    now = math_spans(after)
    was == now && return String[]
    left = copy(was); added = String[]
    for span in now
        i = findfirst(==(span), left)
        i === nothing ? push!(added, String(span)) : deleteat!(left, i)
    end
    out = vcat(added, String.(left))
    return isempty(out) ? String.(now) : out                  # same expressions, a different order
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
        # A file that reads its own line numbers runs differently when a docstring above grows a line,
        # and the shape holds no line numbers, so such a file is code whenever a line moved.
        occursin("@__LINE__", before * after) && count('\n', before) != count('\n', after) &&
            return Ruling(path, false, "the file reads its own line numbers (`@__LINE__`) and a line moved (clause 2)")
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
one built by interpolation, whose text is a program. A docstring on a bare NAME comes out — that is how a
whole generic is documented where its methods are written one per backend — because what is left is the
name alone, which runs nothing.

The arguments are `src`, the file's content, and `rule_prose`, whether the plain string literals given to
`statement` or `why` as the Rule call's own keywords are elided too (clause 3). Returns the shape, or
`nothing` when the source does not parse.

A string standing alone is documentation only where it is not a block's value, and a string inside a
struct only when it stands directly in the struct's body; an interpolated string is never
documentation. Every leaf keeps its exact text, whitespace included.
"""
function code_shape(src::AbstractString; rule_prose::Bool = false)
    tree = try
        JS.parseall(JS.SyntaxNode, src; filename = "shape.jl")
    catch
        return nothing
    end
    any_error(tree) && return nothing
    io = IOBuffer()
    shape!(io, tree; rule_prose)
    return String(take!(io))
end

any_error(node) = JS.kind(node) === JS.K"error" ||
                  any(any_error, something(JS.children(node), ()))

# What counts as documentation inside the code is exactly three things, and each is recognised by its
# PLACE, never inherited by a subtree (found in review, 2026-09-23 — an inherited flag made every string
# anywhere inside a struct, defaults and constructor arguments included, a "field docstring"):
#
# - a plain literal docstring on a definition or a name (`removable_doc`);
# - a plain string standing DIRECTLY in a struct's body block: a field docstring;
# - a plain string standing alone as a statement of a block that is NOT that block's value — at top
#   level, in a module, or before the last statement of a function, `let`, `begin` or branch body. The
#   last statement of such a block is what it returns, so a string there is code: `f() = "hello"`
#   changed to "goodbye" changes what `f()` returns.
#
# An interpolated string is never documentation anywhere: its text is a program. Every leaf is printed
# with `repr`, so the shape cannot be forged by a literal that spells another shape, and a string's
# whitespace is part of its value.
function shape!(io, node; rule_prose::Bool = false)
    k = JS.kind(node)
    cs = something(JS.children(node), ())

    if k === JS.K"doc" && length(cs) >= 2 && removable_doc(cs[1], cs[2])
        shape!(io, cs[2]; rule_prose)                       # the docstring goes; what it documents stays
        return
    end
    if isempty(cs)
        print(io, "(", k, " ", repr(String(JS.sourcetext(node))), ")")
        return
    end
    print(io, "(", k)
    rule_call = rule_prose && k === JS.K"call" && is_rule_callee(cs[1])
    struct_body = k === JS.K"struct"
    for (i, c) in enumerate(cs)
        ck = JS.kind(c)
        # a field docstring: a plain string directly in the struct's own body block
        if struct_body && ck === JS.K"block"
            print(io, " (block")
            for g in something(JS.children(c), ())
                plain_string(g) && continue
                # a field docstring parses as a docstring on the field: the text goes, the field stays
                gc = something(JS.children(g), ())
                if JS.kind(g) === JS.K"doc" && length(gc) >= 2 && plain_string(gc[1])
                    print(io, " "); shape!(io, gc[2]; rule_prose); continue
                end
                print(io, " "); shape!(io, g; rule_prose)
            end
            print(io, ")")
            continue
        end
        # an unattached docstring: a plain string standing alone where it is not the block's value
        if plain_string(c) && standalone(k, i, length(cs))
            continue
        end
        # clause 3: the Rule call's OWN statement and why keywords, never anything nested inside it
        if rule_call && prose_kw(c)
            print(io, " (= ", strip(String(JS.sourcetext(something(JS.children(c), ())[1]))), " <prose>)")
            continue
        end
        if rule_call && ck === JS.K"parameters"
            print(io, " (parameters")
            for g in something(JS.children(c), ())
                prose_kw(g) ? print(io, " (= ", strip(String(JS.sourcetext(something(JS.children(g), ())[1]))), " <prose>)") :
                              (print(io, " "); shape!(io, g; rule_prose))
            end
            print(io, ")")
            continue
        end
        print(io, " ")
        shape!(io, c; rule_prose)
    end
    print(io, ")")
end

# A child of `parent` at position `i` of `n` standing alone as a statement that is not the value of its
# block: anywhere at top level or in a module, and anywhere but last in a block.
standalone(parent, i, n) = parent === JS.K"toplevel" || parent === JS.K"module" ||
                           (parent === JS.K"block" && i < n)

prose_kw(node) = JS.kind(node) === JS.K"=" && (cs = something(JS.children(node), ()); length(cs) == 2 &&
                 is_prose_keyword(cs[1]) && plain_string(cs[2]))

# `Rule(` or `Model.Rule(`: the one constructor whose statement and why are prose (clause 3).
is_rule_callee(node) = (t = strip(String(JS.sourcetext(node))); t == "Rule" || endswith(t, ".Rule"))
is_prose_keyword(node) = JS.kind(node) === JS.K"Identifier" && strip(String(JS.sourcetext(node))) in ("statement", "why")
plain_string(node) = JS.kind(node) === JS.K"string" &&
                     all(c -> JS.kind(c) === JS.K"String", something(JS.children(node), ()))


# A docstring may be dropped only when it is a plain literal AND its target is something the file can
# keep without it: a definition, or a bare name.
function removable_doc(text_node, target)
    JS.kind(text_node) in (JS.K"string", JS.K"String") || return false
    kids = [c for c in something(JS.children(text_node), ()) if JS.kind(c) !== JS.K"String"]
    isempty(kids) || return false                           # interpolation: the text is a program
    return defining(target) || naming(target)
end

"""
Whether this docstring target is a NAME — an identifier, a dotted path, or a quoted symbol.

A docstring on a bare name is how a whole generic is documented where its methods are written one per
backend and no single one of them is the place: `\"\"\"…\"\"\" mean` above the module's methods of `mean`.
Removing the docstring leaves the name standing alone, which evaluates to the binding and does nothing,
so the shape is the same before and after and an edit to the prose is documentation.

Until 2026-09-23 this returned nothing and those docstrings were code. The count says why it went
unnoticed here and hurt elsewhere: NINETEEN targets in
GBGPeriodicFields — every operator of its
field algebra and every reduction — and NONE in this package, which documents no generic that way. A
guard clause is exercised by the shapes the package it was written in happens to use.
"""
function naming(node)
    k = JS.kind(node)
    k === JS.K"Identifier" && return true
    cs = something(JS.children(node), ())
    # `Base.:+` and `:+`: a field access off a name, and a quoted operator. Neither runs anything.
    k === JS.K"quote" && return length(cs) == 1 && naming(only(cs))
    k === JS.K"." && return length(cs) == 2 && naming(cs[1]) && naming(cs[2])
    return false
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
    # Three readings of the text, since a block Documenter runs can be written in any of them: as it
    # stands; with a comment's `# ` removed, which is how Literate turns a comment into Markdown; and,
    # in a Julia file, each string literal's VALUE, where a one-line docstring spells its newlines `\n`.
    for text in (String(src), uncommented(src), literal_values(src))
        append!(out, blocks_of(text))
    end
    return out
end

uncommented(src) = join((replace(l, r"^([ \t]*)#[ \t]?" => s"\1") for l in split(String(src), '\n')), '\n')

function literal_values(src)
    tree = try JS.parseall(JS.SyntaxNode, String(src); filename = "values.jl") catch; return "" end
    io = IOBuffer()
    walk(n) = (plain_string(n) && (v = try Meta.parse(String(JS.sourcetext(n))) catch; nothing end;
                                   v isa AbstractString && println(io, v));
               foreach(walk, something(JS.children(n), ())))
    walk(tree)
    return String(take!(io))
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
