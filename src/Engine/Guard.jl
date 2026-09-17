"""
    Guard

The change guard: the program that decides whether one changed file is a DOCUMENTATION change, which the
documentation fixer may commit on its own, or a CODE change, which waits for the owner
(`docs/ARCHITECTURE.md` §4.2). It is the gate the whole automatic half rests on, so it answers `CODE`
whenever it is unsure.

Documentation is exactly: docstrings and comments in `.jl` files under `src/` and `ext/`; hand-written
Markdown under `docs/src/`; the package's `README.md`; and the rationale documents the config names.
Everything else is code — other `.jl` files whole, the config, stored data, generated files, CI and hook
files, `CLAUDE.md`, and any document the config declares normative.

For a `.jl` file that is on the documentation list, being on it is not enough: both versions must parse,
and with the docstrings and the standalone string literals removed, THE CODE MUST BE IDENTICAL. A
docstring whose target is a call rather than a definition is not documentation at all — Julia then
documents the call instead of running it — and neither is one built by interpolation.

Two clauses of the design are not here yet. Clause 0, a generated file equal to its generator's output,
needs the generators (Phase 2), and the caller passes their output in rather than this module reaching
for them, since `Engine` may not name `Render`. Clause 3, the prose fields of a rule, needs the rulebook
to be Julia (Phase 5).
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
    # The two refusals come first, before any path rule can admit the file: a normative document and a
    # declared build-time copy both LOOK like ordinary prose and neither is. A copy's text belongs to the
    # source it is copied from, and a fix landing in the copy is overwritten by the next build.
    any(n -> replace(n, '\\' => '/') == p, cfg.normative) && return false
    any(f -> replace(first(f), '\\' => '/') == p, cfg.copies) && return false
    endswith(p, ".jl") && (startswith(p, "src/") || startswith(p, "ext/")) && return true
    p == "README.md" && return true
    startswith(p, "docs/src/") && endswith(p, ".md") && return true
    return rationale(cfg, p)
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

    if endswith(path, ".jl")
        shape_before = code_shape(before)
        shape_after = code_shape(after)
        shape_before === nothing && return Ruling(path, false, "the file did not parse before the change (clause 2)")
        shape_after === nothing && return Ruling(path, false, "the file does not parse after the change (clause 2)")
        shape_before == shape_after ||
            return Ruling(path, false, "the code changed, not only its docstrings and comments (clause 2)")
        literate_changed(before, after) &&
            return Ruling(path, false, "a comment carrying a Literate mark changed, which moves what runs (clause 4)")
    end

    fenced_kept(before, after) ||
        return Ruling(path, false, "a doctest or an `@` block changed: those are run, not read (clause 5)")
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

The argument is `src`, the file's content. Returns the shape, or `nothing` when the source does not parse.
"""
function code_shape(src::AbstractString)
    tree = try
        JS.parseall(JS.SyntaxNode, src; filename = "shape.jl")
    catch
        return nothing
    end
    any_error(tree) && return nothing
    io = IOBuffer()
    shape!(io, tree, false)
    return String(take!(io))
end

any_error(node) = JS.kind(node) === JS.K"error" ||
                  any(any_error, something(JS.children(node), ()))

# `in_struct` says whether a bare string here is a field docstring, which is documentation like any other.
function shape!(io, node, in_struct)
    k = JS.kind(node)
    cs = something(JS.children(node), ())

    if k === JS.K"doc" && length(cs) >= 2 && removable_doc(cs[1], cs[2])
        shape!(io, cs[2], in_struct)                       # the docstring goes; what it documents stays
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
    for c in cs
        # a bare string standing alone in a block is an unattached docstring, not code
        if JS.kind(c) === JS.K"string" && (k === JS.K"toplevel" || k === JS.K"block" || k === JS.K"module")
            continue
        end
        print(io, " ")
        shape!(io, c, nested && k !== JS.K"toplevel")
    end
    print(io, ")")
end

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
