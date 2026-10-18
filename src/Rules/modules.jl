# The design's §5.2 and §7; the coordinates live here rather than in a docstring, which must read
# complete at the REPL.
"""
    Rules.Modules

The rules that need the package loaded: what a docstring shows against what the module actually holds.
A cross-module name mentioned bare where a reader cannot follow it, and a displayed signature that no
longer matches the method table, are both invisible in the source of any one file.

A check here is handed the loaded package and the package root together, since what it compares is the
module against the source that documents it. Where nothing loaded the package the rule does not run, and
the caller is told so rather than the run reporting clean.
"""
module Modules

using ...Model
using ...Texts

"""
    owners(pkg, cfg) -> Dict{String,Symbol}

Which module of the package owns each name it exports. The arguments are `pkg`, the loaded package, and
`cfg`, the package's config. Returns the map from name to owning module.
"""
function owners(pkg::Module, cfg)
    mods = Module[pkg]
    for n in names(pkg; all = true)
        isdefined(pkg, n) || continue
        v = getfield(pkg, n)
        v isa Module && v !== pkg && push!(mods, v)
    end
    modnames = Set(nameof.(mods))
    out = Dict{String,Symbol}()
    for mod in mods, n in names(mod)
        s = String(n)
        s == String(nameof(mod)) && continue
        isdefined(mod, n) || continue
        v = getfield(mod, n)
        parent = (v isa Function || v isa Type) ? nameof(parentmodule(v)) : nameof(mod)
        # A generic of Base or a standard library that a package module extends and re-exports — `norm`,
        # `dot`, `mul!` — is owned by no module of the package: a reader meeting it knows it already, and
        # crediting it to the extending module reported every mention of `norm` in a sibling as foreign
        # (found upgrading GBGPeriodicFields, 2026-09-27).
        (v isa Function || v isa Type) && !(parent in modnames) && continue
        out[s] = parent in modnames ? parent : nameof(mod)
    end
    return out
end

"""
    documented(pkg, own_of) -> Set{String}

The names of `own_of` — what the package exports, by owner — that carry a docstring in the module that
owns them. The arguments are `pkg`, the loaded package, and `own_of`, the map [`owners`](@ref) returns.
Returns the names.
"""
function documented(pkg::Module, own_of)
    mods = Dict{Symbol,Module}(nameof(pkg) => pkg)
    for n in names(pkg; all = true)
        isdefined(pkg, n) || continue
        v = getfield(pkg, n)
        v isa Module && (mods[nameof(v)] = v)
    end
    out = Set{String}()
    for (name, owner) in own_of
        mod = get(mods, owner, nothing)
        mod === nothing && continue
        Base.Docs.hasdoc(mod, Symbol(name)) && push!(out, name)
    end
    return out
end

"""
    xlink(loaded, cfg) -> Vector{Model.Location}

Every name mentioned bare that owes a link: in a docstring, one another module owns; on a page, one
the package exports and documents. The arguments are `loaded`, the loaded package and root, and `cfg`,
the config. Returns one location per first bare mention.

Only a first mention is judged. A docstring's own module's names, its signature's name and parameters
need no link; a call inside it exempts nothing.
"""
function xlink(loaded, cfg)
    own_of = owners(loaded.pkg, cfg)
    out = Model.Location[]
    # A module declared in a file the config excludes is out of the rulebook, and so is linking to its
    # names from anywhere else (the owner, 2026-09-29, of HT's Phenomenology).
    out_of_scope = Set{Symbol}()
    for e in cfg.exclusions, pat in e.files, f in Texts.expand(loaded.root, pat)
        endswith(f, ".jl") || continue
        for m in eachmatch(r"(?m)^\s*(?:bare)?module\s+([A-Za-z_][A-Za-z0-9_]*)", read(joinpath(loaded.root, f), String))
            push!(out_of_scope, Symbol(m.captures[1]))
        end
    end
    # Through the same resolver every other rule uses. Read as a list of files, the config's code set is
    # a list of globs — empty by default — and both rules here visited nothing and reported clean in
    # every real package (found in review, 2026-09-26).
    for f in Texts.files(cfg, loaded.root, Model.FileSet.CODE)
        path = joinpath(loaded.root, f)
        src = read(path, String)
        # The declaration line holds the name and nothing after it but a comment: matched loosely, a
        # docstring's prose line "module for what the point layer provides" named the module `for`, and
        # every function of that module was reported as foreign to it (found upgrading PF, 2026-09-27).
        m = match(r"^(?:bare)?module\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:#.*)?$"m, src)
        m === nothing && continue
        me = Symbol(m.captures[1])
        for d in Texts.docstrings_of(src)
            lines = split(d.text, '\n')
            first_prose = something(findfirst(l -> !startswith(l, "    ") && !isempty(strip(l)), lines), 1)
            signature = join(lines[1:first_prose-1], "\n")
            prose = join(lines[first_prose:end], "\n")
            # What the signature documents: the name it is written under, qualified or not, and its
            # parameters. A name called in it — the default `velocity_forcing = ConstantPower()` — is a
            # code expression, and exempting it hid the bare prose mention of `ConstantPower` further down
            # (GBGHomogeneousTurbulence's `predicted_stationary_state`, found verifying its findings,
            # 2026-09-29).
            in_signature = Set{String}()
            for sig in Texts.signature_lines(signature)
                s = match(Regex("^(?:[\\p{L}_][\\p{L}\\p{N}_]*\\.)*(" * Texts.NAME * ")"), sig)
                s === nothing || push!(in_signature, String(s.captures[1]))
                inside = Texts.argument_list(sig)
                inside === nothing && continue
                union!(in_signature, Texts.parameters(inside)...)
            end
            # A name heading a bullet is the docstring's own field or argument, not a mention: a field
            # called `audit` is not the function of that name elsewhere.
            for b in Texts.bullets(prose); union!(in_signature, Texts.bullet_head_names(b)); end
            # The first mention decides, as the statement says. Read as "linked anywhere in the docstring",
            # a bare first mention with a link forty lines further down was never reported
            # (GBGHomogeneousTurbulence's `StochasticOU`, found verifying its findings, 2026-09-28).
            # A link is read as a page's is, through `Texts.ref_links`: any text reaching the binding counts,
            # or this rule and RULE.DOC.LINKS judged one docstring by two readings and contradicted each
            # other (found in review, 2026-10-18).
            seen = Set{String}()
            prose = Texts.mask_even_code(prose)
            links = Texts.ref_links(prose; bindings = keys(own_of))
            events = Tuple{Int,Bool,String}[(l.offset, true, l.name) for l in links]
            for (at, name) in Texts.name_mentions(prose, links); push!(events, (at, false, name)); end
            for (offset, linked, name) in sort!(events)
                (haskey(own_of, name) && !(name in in_signature) && !(name in seen)) || continue
                push!(seen, name)
                linked && continue
                own_of[name] === me && continue
                own_of[name] in out_of_scope && continue
                before = first_prose == 1 ? 0 : ncodeunits(join(lines[1:first_prose-1], "\n")) + 1
                at = Texts.docstring_line(d, before + offset)
                push!(out, Model.Location(; file = f, line = at, node = d.node,
                    text = "`$name` is owned by $(own_of[name]) and mentioned here without a link to its docstring"))
            end
        end
    end
    # A hand-written page links nothing of itself: its section leads, its module maps and its tables send
    # the reader to docstrings he could not reach, and nothing reported it (GBGHomogeneousTurbulence,
    # 2026-10-18: 85 names on 11 pages, `max_speed` the one the owner asked about).
    doc_names = setdiff(documented(loaded.pkg, own_of), Set(n for (n, o) in own_of if o in out_of_scope))
    for f in Texts.files(cfg, loaded.root, Model.FileSet.PAGES)
        endswith(f, ".md") || continue
        for l in page_xlinks(read(joinpath(loaded.root, f), String), doc_names, f)
            push!(out, Model.Location(; file = f, line = l.line, node = Texts.node_at(loaded.root, f, l.line), text = l.text))
        end
    end
    return out
end

"""
    page_xlinks(text, names, file) -> Vector{Model.Location}

Every name of `names` whose first mention in a page's prose is a bare code span.

# Arguments

- `text` — the page.
- `names` — the documented names the package exports.
- `file` — the page's path, which each location carries.

Returns one location per name.

The prose is what [`Texts.page_prose`](@ref) leaves: not a fenced block — `@docs`, `@example` and every
other Documenter block among them — and not a heading. A name inside a code expression (`f(x)`,
`depth > 1`) is not a mention; a link of any text to the binding counts as one, linked.
"""
function page_xlinks(text::AbstractString, names, file::AbstractString)
    out = Model.Location[]
    prose = Texts.mask_even_code(Texts.page_prose(text))
    starts = [0; findall(==('\n'), prose)]
    line_of(at) = searchsortedlast(starts, at - 1)
    # The mentions in the order a reader meets them: a link, whose target names the binding it reaches
    # whatever its text says, and a code span holding a name alone — a macro's included.
    links = Texts.ref_links(prose; bindings = names)
    events = Tuple{Int,Bool,String}[(l.offset, true, l.name) for l in links]
    for (at, name) in Texts.name_mentions(prose, links); push!(events, (at, false, name)); end
    seen = Set{String}()
    for (at, linked, name) in sort!(events)
        (name in names && !(name in seen)) || continue
        push!(seen, name)
        linked || push!(out, Model.Location(; file, line = line_of(at),
            text = "`$name` is documented by the package and its first mention on this page is not a link to its docstring"))
    end
    return out
end

const XLINK = Model.Rule(
    id = Symbol("RULE.DOC.XLINK"),
    statement = "A name another module owns, mentioned on its own, is linked at its first mention in a docstring; in the prose of a page under `docs/src/`, every name a module of the package exports and documents is linked at its first mention there. Each link is qualified so it resolves; a name inside a code expression owes no link, and a heading is not prose.",
    why = "A reader meeting a name from elsewhere has nowhere to go: the docstring in front of him does not define it, and a page defines nothing of itself — its section leads, module maps and tables send him to docstrings he cannot reach without the link (one package's pages named 85 such names plain, 2026-10-18). A design document is not such a page: it is read raw as well, where a link to a docstring does not resolve. Documenter's build checks that a link resolves. An argument that shares a documented name is written as the expression it is — `depth > 1`, `depth = 3` — which owes no link, since a program cannot tell the argument from the binding.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE, Model.FileSet.PAGES],
    check = Model.ProgramCheck(Model.Input.LOADED_MODULE, xlink, false),
    examples = [
        Model.ModuleExample("""
            module Example
            module Inner
                export helper
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
            end
            using .Inner
            \"\"\"
                caller(x)

            Calls `helper` on its argument.
            \"\"\"
            caller(x) = Inner.helper(x)
            end
            """, [Model.Location(; file = "src/Example.jl", line = 15)], "linked at its first mention"),
        Model.ModuleExample("""
            module Example
            module Inner
                export helper
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
            end
            using .Inner
            \"\"\"
                caller(x)

            Calls [`helper`](@ref Example.Inner.helper) on its argument.
            \"\"\"
            caller(x) = Inner.helper(x)
            end
            """, Model.Location[], "linked at its first mention"),
        # A field that shares a name with another module's function is the docstring's own field.
        Model.ModuleExample("""
            module Example
            module Inner
                export helper
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
            end
            using .Inner
            \"\"\"
                Holder

            A holder.

            # Fields

            - `helper` — what it holds.
            \"\"\"
            struct Holder
                helper::Int
            end
            end
            """, Model.Location[], "linked at its first mention"),
        # The first mention is bare and a later one links it: reported. Linked first and bare after: not.
        Model.ModuleExample("""
            module Example
            module Inner
                export helper
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
            end
            using .Inner
            \"\"\"
                caller(x)

            Calls `helper` on its argument; see [`helper`](@ref Example.Inner.helper).
            \"\"\"
            caller(x) = Inner.helper(x)
            end
            """, [Model.Location(; file = "src/Example.jl", line = 15)], "linked at its first mention"),
        Model.ModuleExample("""
            module Example
            module Inner
                export helper
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
            end
            using .Inner
            \"\"\"
                caller(x)

            Calls [`helper`](@ref Example.Inner.helper) on its argument; `helper` returns it.
            \"\"\"
            caller(x) = Inner.helper(x)
            end
            """, Model.Location[], "linked at its first mention"),
        # Every name heading a bullet is the docstring's own, the second of two as well as the first.
        Model.ModuleExample("""
            module Example
            module Inner
                export a, b
                a(x) = x
                b(x) = x
            end
            using .Inner
            \"\"\"
                Holder

            A holder.

            # Fields

            - `a`, `b` — its two ends.
            \"\"\"
            struct Holder
                a::Int
                b::Int
            end
            end
            """, Model.Location[], "linked at its first mention"),
        Model.ModuleExample("""
            module Example
            module Inner
                export a, b
                a(x) = x
                b(x) = x
            end
            using .Inner
            \"\"\"
                Holder

            A holder.

            # Fields

            - `a`,
              `b` — its two ends, the head of names wrapping.
            \"\"\"
            struct Holder
                a::Int
                b::Int
            end
            end
            """, Model.Location[], "linked at its first mention"),
        # a name inside a code expression owes no link (the owner, 2026-09-29)
        Model.ModuleExample("""
            module Example
            module Inner
                export helper
                helper(x) = x
            end
            using .Inner
            \"\"\"
                caller(x)

            Calls it as `helper(2x)` on its argument.
            \"\"\"
            caller(x) = Inner.helper(x)
            end
            """, Model.Location[], "a name inside a code expression owes no link"),
        Model.ModuleExample("""
            module Example
            module Inner
                export helper
                helper(x) = x
            end
            using .Inner
            \"\"\"
                caller(x)

            Calls `helper` on its argument.
            \"\"\"
            caller(x) = Inner.helper(x)
            end
            """, [Model.Location(; file = "src/Example.jl", line = 10)], "a name inside a code expression owes no link"),
        # A name called in the signature's default is a code expression there; its bare prose mention owes
        # the link. The name the signature is written under is the docstring's own.
        Model.ModuleExample("""
            module Example
            module Inner
                export helper
                helper(x) = x
            end
            using .Inner
            \"\"\"
                caller(x; h = helper(1))

            Calls `helper` on its argument.
            \"\"\"
            caller(x; h = Inner.helper(1)) = x
            end
            """, [Model.Location(; file = "src/Example.jl", line = 10)], "a name inside a code expression owes no link"),
        Model.ModuleExample("""
            module Example
            module Inner
                export helper
                helper(x) = x
            end
            using .Inner
            \"\"\"
                Inner.helper(x::Float64)

            A float `helper`, which returns `x`.
            \"\"\"
            Inner.helper(x::Float64) = x
            end
            """, Model.Location[], "a name inside a code expression owes no link"),

        # a page: the first mention of a documented name is linked, wherever it stands in the prose
        Model.ModuleExample("""
            module Example
            module Inner
                export helper, plain
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
                plain(x) = x
            end
            using .Inner
            end
            """, [Model.Location(; file = "docs/src/page.md", line = 7)],
            "every name a module of the package exports and documents is linked at its first mention there",
            ["docs/src/page.md" => "# A page about `helper`\n\n```@docs\nExample.Inner.helper\n```\n\nThe map: `helper` does it, `plain` too, and `helper(x)` is the call; see [`helper`](@ref Example.Inner.helper).\n"]),
        Model.ModuleExample("""
            module Example
            module Inner
                export helper, plain
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
                plain(x) = x
            end
            using .Inner
            end
            """, Model.Location[],
            "every name a module of the package exports and documents is linked at its first mention there",
            ["docs/src/page.md" => "# A page\n\nThe map: [the helper](@ref Example.Inner.helper) does it; `helper` again needs none.\n\n| name | role |\n|---|---|\n| [`helper`](@ref Example.Inner.helper) | helps |\n\nWith `helper > 1`, an expression, nothing is owed.\n"]),
        # a table cell is prose, and a link later on the same line comes too late
        Model.ModuleExample("""
            module Example
            module Inner
                export helper, plain
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
                plain(x) = x
            end
            using .Inner
            end
            """, [Model.Location(; file = "docs/src/page.md", line = 5)],
            "every name a module of the package exports and documents is linked at its first mention there",
            ["docs/src/page.md" => "# A page\n\n| name | role |\n|---|---|\n| `helper` | see [`helper`](@ref Example.Inner.helper) |\n"]),

        # read as Julia's Markdown reads a page, as Documenter does: a link broken across a line, a heading
        # of either kind, a fence closed only by its own line, and a target holding a signature
        Model.ModuleExample("""
            module Example
            module Inner
                export helper, plain
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
                plain(x) = x
            end
            using .Inner
            end
            """, Model.Location[],
            "every name a module of the package exports and documents is linked at its first mention there",
            ["docs/src/page.md" => "# About `helper`\n\nThe `helper`\n===\n\n~~~\n```\n`helper`\n~~~\n\nSee [the\nhelper](@ref Example.Inner.helper(::Any)); `helper` after it.\n"]),
        Model.ModuleExample("""
            module Example
            module Inner
                export helper, plain
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
                plain(x) = x
            end
            using .Inner
            end
            """, [Model.Location(; file = "docs/src/page.md", line = 8)],
            "every name a module of the package exports and documents is linked at its first mention there",
            ["docs/src/page.md" => "# A page\n\n````markdown\n```julia\n`helper`\n```\n````\nNow `helper`.\n"]),

        # what Julia's Markdown shows: two lines over an underline are a paragraph, a comment is text, a
        # fence never closed is none, a quotation holds a fence, and a one-word link to a documented name
        # reaches it
        Model.ModuleExample("""
            module Example
            module Inner
                export helper, plain
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
                plain(x) = x
            end
            using .Inner
            end
            """, [Model.Location(; file = "docs/src/page.md", line = 3)],
            "every name a module of the package exports and documents is linked at its first mention there",
            ["docs/src/page.md" => "# A page\n\nThe `helper` is\nhere\n---\n\n<!-- `plain` ```\n-->\n\n> ```\n> `helper`\n> ```\n\nSee [the helper](@ref helper); `helper` after it.\n"]),
        # in a docstring, a link of prose text reaches the binding as one of code text does
        Model.ModuleExample("""
            module Example
            module Inner
                export helper
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
            end
            using .Inner
            \"\"\"
                caller(x)

            Calls [the helper](@ref Example.Inner.helper); `helper` returns it.
            \"\"\"
            caller(x) = Inner.helper(x)
            end
            """, Model.Location[], "linked at its first mention"),
    ])

# ────────────────────────────────────────── what a docstring shows against what the module defines

# A hat is stripped from a name in either spelling: the combining circumflex after a letter that has no
# precomposed form (`φ̂`, `ω̂`), and the precomposed letter itself (`û`, U+00FB), which is what Julia's
# normalised identifiers hold wherever one exists. Stripping only the combining mark, the rule read
# `kinetic_energy(û)` over the method `kinetic_energy(u)` as a different argument (found verifying
# GBGHomogeneousTurbulence's findings, 2026-09-28).
dehat(a::Symbol) = Symbol(Base.Unicode.normalize(replace(Base.Unicode.normalize(String(a), :NFD), "\u0302" => ""), :NFC))

"""
    displayed_signatures(root, cfg) -> Tuple

Every signature a docstring displays, as the names it shows, keyed by binding and file, with the keys
whose signature elides arguments behind a splat. The arguments are `root` and `cfg`. Returns
`(positional, keyword, elided, shown_in, arg_in, ordered)`: the first lines of each key and each
`(name, file, argument)`, and each signature's positionals in order.
"""
function displayed_signatures(root::AbstractString, cfg)
    Key = Tuple{Symbol,String}
    positional = Dict{Key,Set{Symbol}}(); keyword = Dict{Key,Set{Symbol}}()
    elided = Set{Key}(); shown_in = Dict{Key,Int}(); arg_in = Dict{Tuple{Symbol,String,Symbol},Int}()
    ordered = Dict{Key,Vector{Tuple{Vector{Symbol},Int}}}()     # each signature's positionals, in order
    note!(d, key, args) = union!(get!(d, key, Set{Symbol}()), args)
    function harvest!(ex, file, line)
        (ex isa Expr && ex.head === :call) || return
        name = ex.args[1]; name isa Symbol || return
        key = (name, file)
        pos, kw = Symbol[], Symbol[]
        for a in ex.args[2:end]
            if a isa Expr && a.head === :parameters
                for k in a.args
                    k isa Expr && k.head === :(...) && (push!(elided, key); continue)
                    k isa Expr && k.head === :kw && (k = k.args[1])
                    k isa Expr && k.head === :(::) && (k = k.args[1])
                    k isa Symbol && push!(kw, k)
                end
            else
                a isa Expr && a.head === :(...) && (push!(elided, key); continue)
                a isa Expr && a.head === :kw && (a = a.args[1])
                a isa Expr && a.head === :(::) && (a = a.args[1])
                a isa Symbol && push!(pos, a)
            end
        end
        note!(positional, key, dehat.(pos)); note!(keyword, key, kw)
        push!(get!(ordered, key, Tuple{Vector{Symbol},Int}[]), (dehat.(pos), line))
        get!(shown_in, key, line)
        for a in [dehat.(pos); kw]
            get!(arg_in, (name, file, a), line)
        end
    end
    # A docstring's leading block first, every file, then the lists in docstrings' bodies: where a name is
    # shown is where a finding about it goes, and a list in another binding's docstring took a finding away
    # from the name's own docstring when it came first in the file (found in review, 2026-10-18).
    later = Tuple{String,String,Int}[]
    for f in Texts.files(cfg, root, Model.FileSet.CODE)
        path = joinpath(root, f)
        for d in Texts.docstrings_of(read(path, String))
            # The one reader of a signature block, which reads across the blank lines between signatures:
            # a block cut at the first blank line never compared a later signature at all, and reported its
            # keywords as missing (GBGPeriodicFields' request of 2026-09-27).
            # and a list of signatures in its body, read the same way (GBGHomogeneousTurbulence's request,
            # 2026-10-18: five constructors listed after a sentence of prose went unchecked, and a keyword
            # shown only there counted as shown nowhere)
            for signature in Texts.signature_lines(d.text)
                ex = Texts.signature_expr(signature)
                ex === nothing || harvest!(ex, f, d.line)
            end
            for signature in Texts.body_signatures(d.text); push!(later, (signature, f, d.line)); end
        end
    end
    for (signature, f, line) in later
        ex = Texts.signature_expr(signature)
        ex === nothing || harvest!(ex, f, line)
    end
    return (positional, keyword, elided, shown_in, arg_in, ordered)
end

# Every module of the package, nested ones included: a module two levels down is as much the package's as a
# module directly under it, and a search one level deep judged its docstrings against another module's
# function of the same name.
function modules_of(pkg::Module)
    out = Module[pkg]; i = 1
    while i <= length(out)
        m = out[i]; i += 1
        for n in names(m; all = true)
            isdefined(m, n) || continue
            v = getfield(m, n)
            v isa Module && v !== m && parentmodule(v) === m && !(v in out) && push!(out, v)
        end
    end
    return out
end

"""
    signature_fidelity(loaded, cfg) -> Vector{Model.Location}

Every displayed signature that no longer matches the method table: a keyword shown that no method takes,
a keyword taken that no signature shows, and a positional name shown that matches no defined argument.
The arguments are `loaded`, the loaded package with the package root, and `cfg`, the package's config.
Returns one location per disagreement, at the docstring.

A docstring is held to the function of its name whose methods are defined in its own file; where none
is, to the one function of that name the package owns, and where several are, it is skipped rather
than compared with a namesake. A binding whose methods live in an extension that is not loaded is
skipped too.
"""
function signature_fidelity(loaded, cfg)
    pkg, root = loaded.pkg, loaded.root
    shown, shown_kw, elided, shown_in, arg_in, ordered = displayed_signatures(root, cfg)
    mods = modules_of(pkg)
    # A module with no package directory — one an example loaded into memory — has methods whose file is
    # not a path at all, so the filter that keeps a package's own methods would reject every one of them.
    home = pkgdir(pkg)
    pkgroot = something(home, root)
    every_method = home === nothing
    ours(m) = every_method || startswith(String(m.file), pkgroot) || occursin(cfg.package, String(m.file))
    # Every helper below takes a function as a plain value, never as its own type: each Julia function
    # has a type of its own, and a helper specialised on it was compiled again for every function of the
    # package. The rule spent 67 of its 72 seconds compiling in this package's docs build, 13 in
    # GBGHomogeneousTurbulence's and 17 in GBGPeriodicFields' (measured 2026-09-28).
    function owned(name)
        found = Any[]
        for m in mods
            (isdefined(m, name) && Base.which(m, name) === m) || continue
            v = getfield(m, name)
            any(x -> x === v, found) || push!(found, v)
        end
        return found
    end
    in_file(@nospecialize(f), file) = f isa Function &&
        any(m -> endswith(replace(String(m.file), '\\' => '/'), "/" * file) || String(m.file) == file, methods(f))
    function resolve(name, file)
        cands = Any[f for f in owned(name) if f isa Function || f isa Type]
        here = Any[f for f in cands if in_file(f, file)]
        length(here) == 1 && return here[1]
        length(cands) == 1 && return cands[1]
        return nothing
    end
    function defined_sets(@nospecialize(f))
        f isa Function && isempty(methods(f)) && return :extension
        pos, kw = Set{Symbol}(), Set{Symbol}(); unnamed = false; tuples = Set{Vector{Symbol}}(); vararg = false
        for m in methods(f)
            ours(m) || continue
            names_ = Base.method_argnames(m)[2:end]
            m.isva && (vararg = true)
            for a in names_
                (a === Symbol("#unused#") || a === Symbol("")) ? (unnamed = true) : push!(pos, dehat(a))
            end
            push!(tuples, dehat.(names_))
            for k in Base.kwarg_decl(m)
                endswith(String(k), "...") || push!(kw, k)
            end
        end
        return (pos = pos, kw = kw, unnamed = unnamed, tuples = tuples, vararg = vararg)
    end

    exported = Set(names(pkg))
    by_export = length(exported) > 1      # a package that exports nothing publishes through its docstrings
    # Every docstring held to one function is read together: a function whose methods are documented in
    # two files shows its keywords across both, and one file's docstring compared alone reported the
    # other file's keywords as shown nowhere. Grouping by the resolved function, not by name, still
    # keeps two modules' namesakes apart.
    groups = Dict{Any,Vector{Tuple{Symbol,String}}}()
    for key in sort!(collect(keys(shown)))
        name, file = key
        (!by_export || name in exported) || continue
        f = resolve(name, file)
        f === nothing && continue
        push!(get!(groups, f, Tuple{Symbol,String}[]), key)
    end
    out = Model.Location[]
    for keys_ in sort!(collect(values(groups)); by = first)
        def = defined_sets(resolve(keys_[1]...))
        def === :extension && continue
        name = keys_[1][1]; node = String(name)
        all_kw = union((shown_kw[k] for k in keys_)...)
        all_pos = union((shown[k] for k in keys_)...)
        # At the docstring that displays the disagreeing argument; a keyword no signature displays is
        # reported at the first docstring of the name. A finding with no file could be neither switched
        # off for that file nor anchored, and sent a fixer nowhere.
        function at(a)
            for (n, file) in keys_
                haskey(arg_in, (n, file, a)) && return (file, arg_in[(n, file, a)])
            end
            return (keys_[1][2], shown_in[keys_[1]])
        end
        for a in sort!(collect(setdiff(all_kw, def.kw)))
            file, line = at(a)
            push!(out, Model.Location(; file, line, node,
                text = "$name: the displayed keyword `$a` matches no defined method"))
        end
        for a in (any(in(elided), keys_) ? Symbol[] : sort!(collect(setdiff(def.kw, all_kw))))
            file, line = keys_[1][2], shown_in[keys_[1]]
            push!(out, Model.Location(; file, line, node,
                text = "$name: the defined keyword `$a` appears in no displayed signature"))
        end
        for a in (def.unnamed ? Symbol[] : sort!(collect(setdiff(all_pos, def.pos, def.kw))))
            file, line = at(a)
            push!(out, Model.Location(; file, line, node,
                text = "$name: the displayed positional `$a` matches no defined argument name"))
        end
        # In position too, by the owner's ruling (2026-10-06): a displayed signature whose every name is
        # defined still takes its positionals in an order, and a number, some method takes. A method with an
        # unnamed or a splatted argument cannot be compared so, and the names alone are judged there.
        (def.unnamed || def.vararg) && continue
        for key in keys_
            key in elided && continue
            for (sig, line) in get(ordered, key, Tuple{Vector{Symbol},Int}[])
                issubset(sig, def.pos) || continue             # an unknown name is reported above
                sig in def.tuples && continue
                takes = join(sort!(["(" * join(t, ", ") * ")" for t in def.tuples]), ", ")
                push!(out, Model.Location(; file = key[2], line, node,
                    text = "$name: the displayed positionals ($(join(sig, ", "))) are no method's, in that order and number; the methods take $takes"))
            end
        end
    end
    return out
end

const SIGNATURE_FIDELITY = Model.Rule(
    id = Symbol("RULE.DOC.SIGNATURE_FIDELITY"),
    statement = "The signature a docstring displays — in its leading block, or listed in its body — and the methods the module defines agree, argument for argument, in name and in position.",
    why = "A displayed signature is what a reader calls and the names a reader learns: one the method table has moved past is a call that fails, and a renamed argument is one the reader looks for in the code and does not find.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.LOADED_MODULE, signature_fidelity, false),
    examples = [
        # a list of signatures in a docstring's body is read as the leading block is, and counts as shown;
        # an example call, which passes a call as a positional, is not a signature
        Model.ModuleExample("""
            module Example
            export Family, member, other
            \"\"\"
                Family

            The family. Its members are built as

                member(; rate = 1.0, seed = rand(Int))
                other(x::Int; depth)

            and an example is

                other(member(), 3)
            \"\"\"
            struct Family end
            \"\"\"
                member()

            One member.
            \"\"\"
            member(; rate = 1.0, seed = 0) = rate
            \"\"\"
                other(x)

            Another.
            \"\"\"
            other(x::Int; depth = 1) = x
            end
            """, Model.Location[], "listed in its body"),
        Model.ModuleExample("""
            module Example
            export Family, member
            \"\"\"
                Family

            The family. Its members are built as

                member(; pace = 1.0)
            \"\"\"
            struct Family end
            \"\"\"
                member()

            One member.
            \"\"\"
            member(; rate = 1.0) = rate
            end
            """, [Model.Location(; file = "src/Example.jl", line = 3), Model.Location(; file = "src/Example.jl", line = 11)],
            "listed in its body"),
        # an example call passing values is not a list of signatures, however its keywords default
        Model.ModuleExample("""
            module Example
            export measure
            \"\"\"
                measure(field; window)

            The measure. It is computed as

                measure(u; window = hann(n))
            \"\"\"
            measure(field; window = 1) = field
            end
            """, Model.Location[], "listed in its body"),
        Model.ModuleExample("""
            module Example
            export measure
            \"\"\"
                measure(u; tol = 1e-6)

            The mean of `u`, to within `tol`.
            \"\"\"
            measure(u; atol = 1e-6) = sum(u) / length(u)
            end
            """,
            # A renamed keyword disagrees in both directions at once — the shown one no method takes, the
            # taken one no signature shows — and the rule reports what it found, not one summary of it,
            # each at the docstring that displays the signature.
            [Model.Location(; file = "src/Example.jl", line = 3), Model.Location(; file = "src/Example.jl", line = 3)],
            "argument for argument"),
        # The standard form carries a return annotation, and the rule reads through it: a signature
        # written `-> T` is not a lambda to be dropped.
        Model.ModuleExample("""
            module Example
            export measure
            \"\"\"
                measure(u; tol = 1e-6) -> Float64

            The mean of `u`, to within `tol`.
            \"\"\"
            measure(u; atol = 1e-6) = sum(u) / length(u)
            end
            """,
            [Model.Location(; file = "src/Example.jl", line = 3), Model.Location(; file = "src/Example.jl", line = 3)],
            "argument for argument"),
        Model.ModuleExample("""
            module Example
            export measure
            \"\"\"
                measure(u; atol = 1e-6) -> Float64

            The mean of `u`, to within `atol`.
            \"\"\"
            measure(u; atol = 1e-6) = sum(u) / length(u)
            end
            """, Model.Location[], "argument for argument"),
        Model.ModuleExample("""
            module Example
            export measure
            \"\"\"
                measure(u; atol = 1e-6)

            The mean of `u`, to within `atol`.
            \"\"\"
            measure(u; atol = 1e-6) = sum(u) / length(u)
            end
            """, Model.Location[], "argument for argument"),
        # In position too, by the owner's ruling (2026-10-06): a swapped order or a missing argument is no
        # method's signature; a default shown as one is, since Julia defines the shorter method too.
        Model.ModuleExample("""
            module Example
            export spread
            \"\"\"
                spread(b, a)

            The difference of `a` and `b`.
            \"\"\"
            spread(a, b) = a - b
            end
            """, [Model.Location(; file = "src/Example.jl", line = 3)], "in name and in position"),
        Model.ModuleExample("""
            module Example
            export spread
            \"\"\"
                spread(a)

            The difference of `a` and `b`.
            \"\"\"
            spread(a, b) = a - b
            end
            """, [Model.Location(; file = "src/Example.jl", line = 3)], "in name and in position"),
        Model.ModuleExample("""
            module Example
            export spread
            \"\"\"
                spread(a, b = 0)

            The difference of `a` and `b`.
            \"\"\"
            spread(a, b = 0) = a - b
            end
            """, Model.Location[], "in name and in position"),
        # A spectral field shown hatted over a method that names it plainly is the same argument, in the
        # precomposed spelling (`û`, the one Julia's normalised identifiers hold) as in the combining one.
        Model.ModuleExample("""
            module Example
            export energy, enstrophy
            \"\"\"
                energy(û)

            Half the sum of the squares of `û`.
            \"\"\"
            energy(u) = sum(abs2, u) / 2
            \"\"\"
                enstrophy(ω̂)

            Half the sum of the squares of `ω̂`.
            \"\"\"
            enstrophy(ω) = sum(abs2, ω) / 2
            end
            """, Model.Location[], "argument for argument"),
    ])

"""
    RULES

The rules of this batch.
"""
const RULES = Model.Rule[XLINK, SIGNATURE_FIDELITY]

end # module Modules