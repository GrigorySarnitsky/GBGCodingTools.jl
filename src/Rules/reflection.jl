# The design's §5.2 and §7; the coordinates live here rather than in a docstring, which must read
# complete at the REPL.
"""
    Rules.Reflection

The rules that hold a docstring against the thing it documents: every argument accounted for, and no
target linked twice in one docstring. Both read the source rather than the loaded package, because what
they compare is the docstring's own signature with its own body.

These are the fifth batch of the conversion. The two that need the package loaded — the displayed
signature against the method table, and a cross-module name linked at its first mention — are the batch
after this one.
"""
module Reflection

using ...Model
using ...Texts
using ..Docstrings: body_line
using ..Arguments: delegation_verdict

const WRAPPER_PHRASE = "Allocating form of"
const THRESHOLD = 3

"""
    argcov(src, cfg) -> Vector{Model.Location}

Every argument of a docstring's signature that its body never mentions. The arguments are `src`, the
Julia source, and `cfg`, the package's config, which this rule does not read. Returns one location per
undocumented argument.

It runs from the signature, not from the prose: a body that lists three arguments where the signature
takes four is the case this exists to catch, and a check that reads the prose first cannot see the
fourth. Every displayed signature counts, so an argument only the wider form takes is held to the rule
too. Exempt, as the rule says: an internal helper, a thin allocating wrapper, and a call short enough
to bind its arguments in prose. Documented means: the name is a code span, or a word of one that is not
the function's own call restated. A splat is held to it too (ruled 2026-09-29).
"""
function argcov(src::AbstractString, cfg)
    out = Model.Location[]
    docs = Texts.docstrings_of(src)
    for d in docs
        own = argcov_one(d)
        # A delegation answers only for arguments the body leaves unnamed; an exempt docstring stays exempt.
        isempty(own) && continue
        verdict = delegation_verdict(d, docs)
        verdict === :ok && continue
        if verdict isa String
            push!(out, Model.Location(; file = "", line = d.line, node = d.node, text = "`$(d.node)` " * verdict))
            continue
        end
        append!(out, own)
    end
    return out
end

# One docstring's verdict under the rule, delegation aside.
function argcov_one(d)
    out = Model.Location[]
    begin
        startswith(d.node, "_") && return out
        occursin(WRAPPER_PHRASE, d.text) && return out
        # The union of every displayed signature's parameters, each remembered with the signature that
        # introduced it; the widest form decides whether the docstring is short enough for prose.
        shown = Tuple{String,String}[]; widest = 0; widest_kw = 0
        for sig in Texts.signature_lines(d.text)
            signature = replace(sig, r"\s*->.*$" => "")
            inside = Texts.argument_list(signature)
            inside === nothing && continue
            positional, keyword = Texts.parameters(inside)
            for p in vcat(positional, keyword)
                any(s -> s[1] == p, shown) || push!(shown, (p, strip(signature)))
            end
            n = length(positional) + length(keyword)
            n > widest && (widest = n; widest_kw = length(keyword))
        end
        isempty(shown) && return out
        widest < THRESHOLD && widest_kw == 0 && return out
        # The function's own names, from its signatures: a fenced line restating the call is skipped below.
        own = [m.captures[1] for m in (match(r"^\s*([^(\s]+)\(", s) for s in Texts.signature_lines(d.text))
               if m !== nothing]
        # Every inline code span counts, the function's own call restated among them: `merge!(into, from;
        # weight)` names `from` and `weight` as code, as the statement asks. Excluded until 2026-10-06, it
        # reported both undocumented in GBGStreamingStatistics' `merge!`.
        spans = [m.captures[1] for m in eachmatch(r"(?<!`)`([^`\n]+)`(?!`)", d.text)]
        # A splat passed on in a fenced Julia example is documented by it: `run!(C(; kwargs...), sim)` says
        # where `kwargs...` goes as plainly as the same call inline, which alone counted (HT's `warmup!`,
        # found verifying its findings, 2026-09-29). Nothing else counts there: a name in a `math` block or
        # a doctest's local variable is no argument's documentation, and counting every fenced line hid two
        # real findings. A line restating the call itself is not documentation either.
        fenced_splats = String[]
        lang = nothing
        for l in split(d.text, '\n')
            m = match(r"^\s*(?:```|~~~)\s*([A-Za-z@]*)", l)
            if m !== nothing
                lang = lang === nothing ? m.captures[1] : nothing
                continue
            end
            (lang in ("julia", "jldoctest", "")) || continue
            any(f -> startswith(strip(l), f * "("), own) && continue
            for s in eachmatch(r"([\p{L}_][\p{L}\p{N}_!]*)\.\.\.", l); push!(fenced_splats, s.captures[1]); end
        end
        for (p, signature) in shown
            # A splat may be documented by its base name or with its dots — `rows` or `kwargs...` — and
            # both are the same argument to a reader; so is a name carrying its type or its default.
            base = replace(p, r"\.\.\.$" => "")
            q = "\\Q" * base * "\\E"
            documented = occursin(Regex("`" * q * "(?:\\.\\.\\.)?(?:::[^`]*)?`"), d.text) ||
                         occursin(Regex("`" * q * "\\s*=[^`]*`"), d.text) ||
                         any(sp -> occursin(Regex("(?<![\\w!.])" * q * "(?![\\w!])"), sp), spans) ||
                         (endswith(p, "...") && base in fenced_splats)
            documented && continue
            push!(out, Model.Location(; file = "", line = d.line, node = d.node,
                                       text = "`$p` of `$signature` is undocumented"))
        end
    end
    return out
end

# The delegation examples: `f` documents its three arguments, and a second function hands its own to it.
const DELEGATE = "\"\"\"\n    f(a, b, c)\n\nDoes a thing.\n\n# Arguments\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third.\n\"\"\"\nf(x) = x\n"
delegating(sig, sentence) = "\"\"\"\n    " * sig * "\n\nDoes another thing.\n\n" * sentence * "\n\"\"\"\n" *
                             first(split(sig, "(")) * "(x) = x\n"

# A splat is named like any argument. A sentence sending "every other keyword" on counted for it until
# the owner ruled, on 2026-09-29, that `kwargs...` is named as code, as the rule's statement says: the
# sentence says where the keywords go and leaves the reader to guess which name holds them.
const ARGCOV = Model.Rule(
    id = Symbol("RULE.DOC.ARGCOV"),
    statement = "Every argument in a docstring's signature, positional and keyword, is named as code in its body, or delegated: a paragraph opening \"Arguments: as for\", or an `# Arguments` section opening \"As for\", links a function documented in the same file whose own docstring names all its arguments, in the form `RULE.DOC.ARGS_FORM` asks, without delegating, whose arguments include all of this signature's, and the paragraph names as code each of its arguments this signature lacks.",
    why = "A reader passing an argument the docstring never mentions has to read the source to learn what it does. Where several functions take one function's arguments, one list serves them all, and the conditions keep the pointer from covering an argument that list lacks.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, argcov, false),
    examples = [
        # a comment on a wrapped signature's first line hid every argument after it (SS, 2026-10-04)
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a, b;   # ≡ φ(a, b)\n      tol = 1e-6)\n\nDoes a thing.\n\n# Arguments\n\n- `a` — the first.\n- `b` — the second.\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 1)], "is named as code in its body"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a, b;   # ≡ φ(a, b)\n      tol = 1e-6)\n\nDoes a thing.\n\n# Arguments\n\n- `a` — the first.\n- `b` — the second.\n- `tol` — the tolerance.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "is named as code in its body"),
        # a `#` that is a default, not a comment, hides nothing (review, 2026-10-04)
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    read_table(io; delim = ',', comment = '#', header = true)\n\nReads a table from `io`.\n\"\"\"\nread_table(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 1), Model.Location(; file = "src/Example.jl", line = 1),
             Model.Location(; file = "src/Example.jl", line = 1)], "is named as code in its body"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    read_table(io; delim = ',', comment = '#', header = true)\n\nReads a table from `io`, split at `delim`, skipping lines that open with `comment`, with `header` naming the columns.\n\"\"\"\nread_table(x) = x\n",
            Model.Location[], "is named as code in its body"),
        # a delegate the rule would exempt, short and naming nothing, documents nothing in full
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a, b)\n\nDoes a thing.\n\"\"\"\nf(x) = x\n" * delegating("g(a; b = 1)", "Arguments: as for [`f`](@ref)."),
            [Model.Location(; file = "src/Example.jl", line = 7)], "whose own docstring names all its arguments, in the form `RULE.DOC.ARGS_FORM` asks, without delegating"),
        Model.TextExample(Model.FileSet.CODE,
            DELEGATE * delegating("g(a; b = 1)", "# Arguments\n\nAs for [`f`](@ref), without `c`."),
            Model.Location[], "names as code each of its arguments this signature lacks"),
        # the delegation, asked for by GBGStreamingStatistics (2026-10-04): it stands, or it is reported
        # at the delegating docstring with the condition it breaks
        Model.TextExample(Model.FileSet.CODE,
            DELEGATE * delegating("g(a, b, c)", "Arguments: as for [`f`](@ref)."),
            Model.Location[], "a function documented in the same file"),
        Model.TextExample(Model.FileSet.CODE,
            delegating("g(a, b, c)", "Arguments: as for [`h`](@ref)."),
            [Model.Location(; file = "src/Example.jl", line = 1)], "a function documented in the same file"),
        Model.TextExample(Model.FileSet.CODE,
            DELEGATE * delegating("g(a, b, c)", "# Arguments\n\nAs for [`f`](@ref GBGExample.f)."),
            Model.Location[], "whose own docstring names all its arguments, in the form `RULE.DOC.ARGS_FORM` asks, without delegating"),
        Model.TextExample(Model.FileSet.CODE,
            replace(DELEGATE, "- `c` — the third.\n" => "") * delegating("g(a, b, c)", "Arguments: as for [`f`](@ref)."),
            [Model.Location(; file = "src/Example.jl", line = 1), Model.Location(; file = "src/Example.jl", line = 12)],
            "whose own docstring names all its arguments, in the form `RULE.DOC.ARGS_FORM` asks, without delegating"),
        Model.TextExample(Model.FileSet.CODE,
            DELEGATE * delegating("g(a, b, c)", "Arguments: as for [`f`](@ref).") *
                       delegating("k(a, b, c)", "Arguments: as for [`g`](@ref)."),
            [Model.Location(; file = "src/Example.jl", line = 21)], "whose own docstring names all its arguments, in the form `RULE.DOC.ARGS_FORM` asks, without delegating"),
        Model.TextExample(Model.FileSet.CODE,
            DELEGATE * delegating("g(a, b, d)", "Arguments: as for [`f`](@ref)."),
            [Model.Location(; file = "src/Example.jl", line = 13)], "whose arguments include all of this signature's"),
        Model.TextExample(Model.FileSet.CODE,
            DELEGATE * delegating("g(a, b; c = 1)", "Arguments: as for [`f`](@ref)."),
            Model.Location[], "whose arguments include all of this signature's"),
        Model.TextExample(Model.FileSet.CODE,
            DELEGATE * delegating("g(a; b = 1)", "Arguments: as for [`f`](@ref)."),
            [Model.Location(; file = "src/Example.jl", line = 13)], "names as code each of its arguments this signature lacks"),
        Model.TextExample(Model.FileSet.CODE,
            DELEGATE * delegating("g(a; b = 1)", "Arguments: as for [`f`](@ref), without `c`."),
            Model.Location[], "names as code each of its arguments this signature lacks"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a, b, c)\n\nDoes a thing.\n\n# Arguments\n\n- `a` — the first.\n- `b` — the second.\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 1)], "every argument is documented"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a, b, c)\n\nDoes a thing.\n\n# Arguments\n\n- `a` — the first.\n- `b` — the second.\n- `c` — the third.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "every argument is documented"),
        # A bullet naming the argument with its type documents it.
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a, b; tol = 1e-6)\n\nDoes a thing.\n\n# Arguments\n\n- `a::Int` — the first.\n- `b` — the second.\n- `tol::Float64` — the tolerance.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "every argument is documented"),
        # An argument only the wider of two displayed signatures takes is still an argument.
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a)\n    f(a, b, c, d)\n\nDoes a thing with `a`.\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 1),
             Model.Location(; file = "src/Example.jl", line = 1),
             Model.Location(; file = "src/Example.jl", line = 1)],
            "positional and keyword"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a)\n    f(a, b, c, d)\n\nDoes a thing with `a`, `b`, `c` and `d`.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "positional and keyword"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    _helper(a, b, c)\n\nAn internal helper.\n\"\"\"\n_helper(x) = x\n",
            Model.Location[], "an internal helper is exempt"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    g(a, b, c)\n\nAn ordinary operation.\n\"\"\"\ng(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 1),
             Model.Location(; file = "src/Example.jl", line = 1),
             Model.Location(; file = "src/Example.jl", line = 1)],   # one per undocumented argument
            "an internal helper is exempt"),
        # A name inside a larger code span is documented by it, the call itself restated included; a splat
        # is named like any argument, and a sentence about "every other keyword" does not name it.
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a, b; kwargs...)\n\nDoes a thing: `f(a, b; kwargs...)` is `g(a + b; kwargs...)`.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "positional and keyword"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a, b; kwargs...)\n\nDoes a thing with `a`; `f(a, b; kwargs...)` is the call.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "positional and keyword"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a, b; kwargs...)\n\nDoes a thing with `a` and `b`; every other keyword is\npassed through to `g` untouched.\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 1)], "positional and keyword"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a, b; kwargs...)\n\nDoes a thing.\n\n# Arguments\n\n- `a` — the first.\n- `b` — the second.\n- `kwargs...` — every other keyword, passed to `g` untouched.\n\"\"\"\nf(x) = x\n",
            Model.Location[], "positional and keyword"),
        # a fenced example passing the splat on documents it; one restating the call does not
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a, b; kwargs...)\n\nDoes a thing with `a` and `b`, as\n\n```julia\ng(C(; kwargs...), a, b)\n```\n\"\"\"\nf(x) = x\n",
            Model.Location[], "positional and keyword"),
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a, b; kwargs...)\n\nDoes a thing with `a` and `b`:\n\n```julia\nf(a, b; kwargs...)\n```\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 1)], "positional and keyword"),
        # a name in a `math` block or a doctest's own variable documents no argument
        Model.TextExample(Model.FileSet.CODE,
            "\"\"\"\n    f(a, b, h)\n\nDoes a thing with `a` and `b`.\n\n```math\nh^2\n```\n\n```jldoctest\njulia> h = 1;\n```\n\"\"\"\nf(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 1)], "positional and keyword"),
    ])

"""
    dupref(src, cfg) -> Vector{Model.Location}

Every cross-reference target linked more than once inside one docstring. The arguments are `src`, the
Julia source, and `cfg`, the package's config, which this rule does not read. Returns one location per
repeated target.

The second link is invisible in the rendered text and tells the reader nothing the first did not: the
rubric caps a target at its first genuine mention.
"""
function dupref(src::AbstractString, cfg)
    out = Model.Location[]
    for d in Texts.docstrings_of(src)
        # The line of each link, not just its target: a module docstring runs to seventy lines, and a
        # finding anchored at its first one sends the fixer to search the whole of it for the repeat.
        # One target under any text, `[`g`](@ref)` and `[the g](@ref P.g)` alike, as a page's links are
        # read (2026-10-18).
        opens = body_line(src, d)
        seen = Dict{String,Int}()
        repeats = Tuple{String,Int,Int}[]
        for l in Texts.ref_links(d.text)
            at = opens + count(==('\n'), d.text[1:prevind(d.text, l.offset)])
            first_at = Texts.same_link!(seen, l, at)
            first_at === nothing || push!(repeats, (l.target, at, first_at))
        end
        for (t, at, first_at) in repeats
            push!(out, Model.Location(; file = "", line = at, node = d.node,
                text = "`$t` is linked here and again at line $first_at; the first mention carries the link"))
        end
    end
    return out
end

"""
    page_dupref(text, cfg) -> Vector{Model.Location}

Every cross-reference target linked more than once in one section of a page's prose, a heading starting
a section. The arguments are `text`, the page, and `cfg`, the package's config, which this rule does not
read. Returns one location per repeated link.

The prose is what the page shows as running text, outside its fenced blocks — a docstring an `@docs`
block renders there carries its own links, judged as that docstring's — and outside its tables, where a
row stands alone and a reader scanning it wants its link there.
"""
function page_dupref(text::AbstractString, cfg)
    out = Model.Location[]
    prose, headings = Texts.page_structure(text)
    lines = split(prose, '\n')
    starts = [0; findall(==('\n'), prose)]
    seen = Dict{String,Int}()
    section = 0                                         # the heading the links are under
    for l in Texts.ref_links(prose)
        at = searchsortedlast(starts, l.offset - 1)
        # a heading starts the count again: a reader landing in a section has not met the links above it
        under = searchsortedlast(headings, at)
        under == section || (empty!(seen); section = under)
        occursin(r"^\s*\|", lines[at]) && continue          # a table's row stands alone
        first_at = Texts.same_link!(seen, l, at)
        first_at === nothing && continue
        push!(out, Model.Location(; file = "", line = at,
            text = "`$(l.target)` is linked here and " * (first_at == at ? "earlier on this line" : "at line $first_at") * " of this section; the first mention carries the link"))
    end
    return out
end

"""
    links(root, cfg) -> Vector{Model.Location}

Every target linked more than once in one docstring, or in one section of a page. The arguments are
`root`, the package root, and `cfg`, the package's config, which names the files. Returns the locations.

It reads the files itself, since a docstring is found in Julia source and a page's prose in Markdown, and
neither reading fits the other: read as a page, a source file's string holding a link would be prose.
"""
function links(root::AbstractString, cfg)
    out = Model.Location[]
    for (fs, judge) in ((Model.FileSet.CODE, dupref), (Model.FileSet.PAGES, page_dupref))
        for f in Texts.files(cfg, root, fs)
            endswith(f, fs === Model.FileSet.CODE ? ".jl" : ".md") || continue
            for l in judge(read(joinpath(root, f), String), cfg)
                node = isempty(l.node) ? Texts.node_at(root, f, l.line) : l.node
                push!(out, Model.Location(; file = f, line = l.line, node, text = l.text))
            end
        end
    end
    return out
end

const LINKS = Model.Rule(
    id = Symbol("RULE.DOC.LINKS"),
    statement = "Cross-referencing is discriminating: a target is linked at most once in one docstring, or in the prose of one section of a page under `docs/src/` outside its tables, at its first genuine mention; a heading begins a section and is not prose.",
    why = "A link draws the eye and says the target is worth following; a second one to the same target adds nothing a reader of the same docstring or section has not just met, and dilutes the links that matter. A long page is read from the middle — a reader lands in a section from a search, a heading's link or the sidebar — so a page's count starts again at each heading (the owner, 2026-10-18). A table is not held to it, since a row stands alone and is read alone. A target is a binding, one target under any text that reaches it, qualified or bare; a link to a heading is a way around the site, which no rule here counts.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE, Model.FileSet.PAGES],
    check = Model.ProgramCheck(Model.Input.FILE_TREE, links, false),
    examples = [
        Model.TreeExample(["src/Example.jl" => "\"\"\"\n    f(x)\n\nSee [`g`](@ref) and then [`g`](@ref) again.\n\"\"\"\nf(x) = x\n"],
            [Model.Location(; file = "src/Example.jl", line = 4)], "linked at most once"),
        Model.TreeExample(["src/Example.jl" => "\"\"\"\n    f(x)\n\nSee [`g`](@ref), which does the rest.\n\"\"\"\nf(x) = x\n"],
            Model.Location[], "linked at most once"),
        # One target under two link texts is one target; one text sent to two targets is two.
        Model.TreeExample(["src/Example.jl" => "\"\"\"\n    f(x)\n\nSee [`g`](@ref) and then [`g(x)`](@ref g) again.\n\"\"\"\nf(x) = x\n"],
            [Model.Location(; file = "src/Example.jl", line = 4)], "a target is linked at most once"),
        Model.TreeExample(["src/Example.jl" => "\"\"\"\n    f(x)\n\nSee [`g`](@ref) and then [`g`](@ref h) again.\n\"\"\"\nf(x) = x\n"],
            Model.Location[], "a target is linked at most once"),
        # A docstring opening with a blank line: the repeat is reported where it stands.
        Model.TreeExample(["src/Example.jl" => "\"\"\"\n\n    f(x)\n\nSee [`g`](@ref) and then [`g`](@ref) again.\n\"\"\"\nf(x) = x\n"],
            [Model.Location(; file = "src/Example.jl", line = 5)], "linked at most once"),
        # a page's prose, outside its fenced blocks; a source file's own string is not prose
        # a heading starts a section, whose count starts again
        Model.TreeExample(["docs/src/page.md" => "# A page\n\nSee [`g`](@ref P.g).\n\n## Later\n\nThen [`g`](@ref P.g) again, and [`g`](@ref P.g) once more.\n"],
            [Model.Location(; file = "docs/src/page.md", line = 7)], "in the prose of one section of a page"),
        Model.TreeExample(["docs/src/page.md" => "# A page\n\nSee [`g`](@ref P.g).\n\nLater\n-----\n\nThen [`g`](@ref P.g) again.\n"],
            Model.Location[], "in the prose of one section of a page"),
        Model.TreeExample(["docs/src/page.md" => "# A page\n\nSee [`g`](@ref P.g).\n\n```@docs\nP.g\n```\n\nLater, [`g`](@ref P.g) again.\n",
                           "src/Example.jl" => "const PAGE = \"see [`g`](@ref) and [`g`](@ref)\"\n"],
            [Model.Location(; file = "docs/src/page.md", line = 9)], "in the prose of one section of a page"),
        Model.TreeExample(["docs/src/page.md" => "# A page\n\nSee [`g`](@ref P.g), and [`h`](@ref P.h).\n\n```julia\n[`g`](@ref P.g)\n```\n"],
            Model.Location[], "in the prose of one section of a page"),
        # a table's rows each stand alone
        Model.TreeExample(["docs/src/page.md" => "# A page\n\nSee [`g`](@ref P.g).\n\n| symbol | object |\n|---|---|\n| ``a`` | [`g`](@ref P.g) |\n| ``b`` | [`g`](@ref P.g) |\n"],
            Model.Location[], "outside its tables"),
        Model.TreeExample(["docs/src/page.md" => "# A page\n\n| symbol | object |\n|---|---|\n| ``a`` | [`g`](@ref P.g) |\n\nSee [`g`](@ref P.g), then [`g`](@ref P.g).\n"],
            [Model.Location(; file = "docs/src/page.md", line = 7)], "outside its tables"),
        # one target under any text, across a line break; a heading is not prose; two modules' names differ
        Model.TreeExample(["docs/src/page.md" => "# About [`g`](@ref P.g)\n\nSee [`g`](@ref P.g), then\n[the g function](@ref\nP.g) and [`g`](@ref Q.g).\n"],
            [Model.Location(; file = "docs/src/page.md", line = 4)], "is not prose"),
        # a comment is text on the page, so its link is the page's
        Model.TreeExample(["docs/src/page.md" => "# A page\n\nSee [`g`](@ref P.g), then [`g`](@ref Q.g).\n\n<!-- [`g`](@ref P.g) -->\n"],
            [Model.Location(; file = "docs/src/page.md", line = 5)], "is not prose"),
        Model.TreeExample(["docs/src/page.md" => "# A page\n\nSee [`g`](@ref P.g), then [`g`](@ref Q.g).\n"],
            Model.Location[], "is not prose"),
        # a link to a heading's anchor is not a binding's, and two methods named by signature are two
        Model.TreeExample(["docs/src/page.md" => "# A page\n\nSee [`gbg run`](@ref verbs) and [`gbg check`](@ref verbs); [`f`](@ref f(::Int)) and [`f`](@ref f(::Float64)).\n"],
            Model.Location[], "linked at most once"),
    ])

# ─────────────────────────────────────────────────────── one run of names, linked or bare, not both

const RUN_ITEM = raw"(?:\[`[A-Za-z_]\w*!?`\]\(@ref[^)]*\)|`[A-Za-z_!*/+\-]\w*!?`)"
const RUN_SEP = raw"(?:,\s+|\s+and\s+|\s+or\s+|\s*/\s*)"
const NAME_RUN = Regex(RUN_ITEM * "(?:" * RUN_SEP * RUN_ITEM * ")+")
const RUN_LINKED = r"\[`([A-Za-z_]\w*!?)`\]\(@ref"
const RUN_BARE = r"(?<!\[)`([A-Za-z_]\w*!?)`(?!\]\()"

"""
    exported_names(src) -> Set{String}

Every name the source exports. The argument is `src`, the Julia source. Returns the names.
"""
function exported_names(src::AbstractString)
    names = Set{String}()
    lines = split(src, '\n')
    i = 1
    while i <= length(lines)
        m = match(r"^\s*export\s+(.*)$", lines[i])
        if m !== nothing
            # The export line and its continuations alone: a line ending in a comma carries on to the
            # next. Read up to the next blank line instead, the docstring or comment that followed
            # became a set of "exported names" made of its words.
            block = replace(String(m.captures[1]), r"#.*$" => "")
            while endswith(rstrip(block), ",") && i < length(lines)
                i += 1
                block *= " " * replace(String(lines[i]), r"#.*$" => "")
            end
            for t in eachmatch(r"[A-Za-z_]\w*!?", block); push!(names, t.match); end
        end
        i += 1
    end
    return names
end

"""
    link_uniformity(root, cfg) -> Vector{Model.Location}

Every run of names in one docstring where some are linked and others are not. The arguments are `root`,
the package root, and `cfg`, the package's config, which names the code files. Returns one location per
run.

A list where one name is a link and the next is not reads as though the difference meant something. The
docstring's own binding is not counted: a docstring does not link to itself. What is public is gathered
over every code file first, since the usual layout exports in the module file and documents elsewhere,
and a name exported in one file is public in all of them.
"""
function link_uniformity(root::AbstractString, cfg)
    files = Texts.files(cfg, root, Model.FileSet.CODE)
    sources = Dict(f => read(joinpath(root, f), String) for f in files)
    public = Set{String}()
    for f in files; union!(public, exported_names(sources[f])); end
    out = Model.Location[]
    for f in files, d in Texts.docstrings_of(sources[f])
        doc = join(split(d.text), " ")
        for run in eachmatch(NAME_RUN, doc)
            text = run.match
            linked = [m.captures[1] for m in eachmatch(RUN_LINKED, text)]
            bare = [m.captures[1] for m in eachmatch(RUN_BARE, text) if m.captures[1] in public && m.captures[1] != d.node]
            (isempty(linked) || isempty(bare)) && continue
            # the run itself, found in the docstring's own text with its whitespace free again: the first
            # appearance of its linked name elsewhere in the docstring took the line (found in review)
            words = split(String(text))
            place = match(Regex(join(("\\Q" * w * "\\E" for w in words), "\\s+")), d.text)
            at = place === nothing ? d.line : Texts.docstring_line(d, place.offset)
            push!(out, Model.Location(; file = f, line = at, node = d.node,
                text = "linked " * join(("`$n`" for n in linked), ", ") * " beside bare " *
                       join(("`$n`" for n in bare), ", ") * " in one run: " * first(String(text), 90)))
        end
    end
    return out
end

const LINK_UNIFORMITY = Model.Rule(
    id = Symbol("RULE.DOC.LINK_UNIFORMITY"),
    statement = "In one run of names, either every name is linked or none is.",
    why = "A list where one name links and the next does not reads as though the difference meant something.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.FILE_TREE, link_uniformity, false),
    examples = [
        Model.TextExample(Model.FileSet.CODE,
            "export f, g\n\n\"\"\"\n    h(x)\n\nSee [`f`](@ref), `g` and more.\n\"\"\"\nh(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 6)], "either every name is linked or none is"),
        Model.TextExample(Model.FileSet.CODE,
            "export f, g\n\n\"\"\"\n    h(x)\n\nSee [`f`](@ref), [`g`](@ref) and more.\n\"\"\"\nh(x) = x\n",
            Model.Location[], "either every name is linked or none is"),
        # The exports in the module file, the docstring in another: the run is still reported. And the
        # docstring after the export line lends it no names.
        Model.TreeExample(
            ["src/Example.jl" => "module Example\nexport f,\n    g\n\"\"\"\n    f(x)\n\nA thing, with `x` and `y` given.\n\"\"\"\nf(x) = x\ninclude(\"other.jl\")\nend\n",
             "src/other.jl" => "\"\"\"\n    h(x)\n\nSee [`f`](@ref), `g` and more.\n\"\"\"\nh(x) = x\n"],
            [Model.Location(; file = "src/other.jl", line = 4)], "either every name is linked or none is"),
        Model.TreeExample(
            ["src/Example.jl" => "module Example\nexport f\n\"\"\"\n    f(x)\n\nA thing, with `x` and `y` given.\n\"\"\"\nf(x) = x\ninclude(\"other.jl\")\nend\n",
             "src/other.jl" => "\"\"\"\n    h(x)\n\nSee [`f`](@ref), `x` and `y`.\n\"\"\"\nh(x) = x\n"],
            Model.Location[], "either every name is linked or none is"),
        # the run's own line, though its linked name appears earlier in the docstring
        Model.TextExample(Model.FileSet.CODE,
            "export f, g\n\n\"\"\"\n    h(x)\n\nUses [`f`](@ref) first.\n\nThen: see [`f`](@ref), `g` and more.\n\"\"\"\nh(x) = x\n",
            [Model.Location(; file = "src/Example.jl", line = 8)], "either every name is linked or none is"),
    ])

# ───────────────────────────────────────────────────── a rule id that names something that exists

"""
    live_ids() -> Set{String}

Every identifier a document may cite and expect to resolve: the rules of the rulebook, the always-on
checks and the instruments. Returns the ids.
"""
function live_ids()
    cat = parentmodule(@__MODULE__)
    ids = Set{String}(String(r.id) for r in cat.RULES)
    for a in cat.ALWAYS_ON; push!(ids, String(a.id)); end
    for i in cat.INSTRUMENTS; push!(ids, String(i.id)); end
    return ids
end

"""
    id_resolves(text, cfg) -> Vector{Model.Location}

Every dotted identifier in the `RULE.` namespace that names no rule of the running copy. The arguments
are `text`, the file's prose, and `cfg`, the package's config, which this rule does not read. Returns one
location per mention.

A rule id that resolves to nothing is a citation of something that was renamed or removed, and it reads
exactly like one that resolves.
"""
function id_resolves(text::AbstractString, cfg)
    known = live_ids()
    # A family cited whole (`RULE.DOC`) resolves; a truncated or lengthened id does not — `RULE.DOC.LINK`
    # is not a prefix of `RULE.DOC.LINKS` in any sense a reader means.
    mention(id) = any(k -> startswith(k, id * "."), known)
    out = Model.Location[]
    for (i, line) in pairs(split(text, '\n'))
        for m in eachmatch(r"\bRULE\.[A-Z][A-Z0-9_]*(?:\.[A-Z][A-Z0-9_]*)?", line)
            id = String(m.match)
            (id in known || mention(id)) && continue
            push!(out, Model.Location(; file = "", line = i, text = "`$id` names no rule of the running copy"))
        end
    end
    return out
end

const CURRENT = Model.Rule(
    id = Symbol("RULE.DOC.CURRENT"),
    statement = "No stale claim: a rule cited by id names a rule that exists, and a retired phrasing is not used.",
    why = "A citation of something renamed or removed reads exactly like one that resolves, which is why it survives.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.DOCSTRINGS, Model.FileSet.PAGES, Model.FileSet.RATIONALE],
    check = Model.ProgramCheck(Model.Input.SOURCE_TEXT, id_resolves, false),
    examples = [
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nAs RULE.DOC.NO_SUCH_THING says.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "a rule cited by id exists"),
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nAs RULE.DOC.ARGCOV says.\n",
            Model.Location[], "a rule cited by id exists"),
        # A stale id that a live one happens to begin with is still stale; a family cited whole is not.
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nAs RULE.DOC.LINK says.\n",
            [Model.Location(; file = "docs/src/page.md", line = 3)], "a rule cited by id exists"),
        Model.TextExample(Model.FileSet.PAGES, "# A page\n\nAs the RULE.DOC family says.\n",
            Model.Location[], "a rule cited by id exists"),
    ])

"""
    RULES

The rules of this batch.
"""
const RULES = Model.Rule[ARGCOV, LINKS, LINK_UNIFORMITY, CURRENT]

end # module Reflection