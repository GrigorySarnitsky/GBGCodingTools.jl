# The design's §4.1, §5.2, §11; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Site

The built site a run reads: building it inside the run, and cutting it into the units a withheld reader
is given one at a time.

Two of the three reader bundles are rendered, not written: the WITHHELD reader is given one built page
and nothing else, and the RENDERED reader the whole site. Neither can be served from the source — what
the build made of a comment, a formula or a docstring is visible only after the build — so a run builds
the site itself, from the package's own `docs/make.jl`, before it launches those readers.

**A run builds; a build never reads a run.** Starting the docs build here is allowed precisely because
it runs the other way: the instrument side may start git, the build and the tests, while nothing a
consumer's build or test suite may reach this module, which the self-tests hold rather than trust.

The site lands where the build puts it, `docs/build`, which every package ignores, so building inside a
run leaves the tracked tree exactly as the readers found it.
"""
module Site

using ...Model
using ...Texts
using ...Catalogue

"""
    BUILDER

What [`build`](@ref) calls to build the site. It is a `Ref` so the test suite can put a written site in
place of a real build: the child process is the one part of this module a test may not run — Documenter
would have to be installed in the package under test, and a rehearsal of a whole run would pay a full
build for each of its stages — and everything after it, the pages, the units and the launches, is
exercised against a site written by hand.
"""
const BUILDER = Ref{Function}()

"""
    build(root, cfg; io = stdout) -> Union{String,Nothing}

Builds the package's site. The arguments are:

- `root` — the package root.
- `cfg` — the package's config, which names the build command.
- `io` — where a failure is reported.

Returns the built site's directory, or `nothing` when the build failed or wrote nothing.

The build is a child process running the package's own `docs/make.jl` in its `docs/` environment, as
`gbg release` and the floor script run it: Documenter is a developer's dependency and is not loaded
here. Its output is shown, because a build that failed is the run's first news and a reader sent at a
stale site would judge the last build's pages.
"""
build(root::AbstractString, cfg::Model.Config; io::IO = stdout) = BUILDER[](root, cfg; io)

# The real build: the package's own `docs/make.jl`, in its own environment, as a child process.
function build_with_make(root::AbstractString, cfg::Model.Config; io::IO = stdout)
    make = joinpath(root, "docs", "make.jl")
    isfile(make) || (println(io, "run: ", relpath(make, root), " does not exist; the site cannot be built"); return nothing)
    cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(joinpath(root, "docs")) $make`
    ok = try
        Base.run(pipeline(setenv(cmd; dir = root); stdout = io, stderr = io))
        true
    catch
        false
    end
    dir = joinpath(root, "docs", "build")
    ok || (println(io, "run: the docs build failed; nothing is launched against a stale site"); return nothing)
    isdir(dir) || (println(io, "run: the docs build wrote no ", relpath(dir, root)); return nothing)
    return dir
end

BUILDER[] = build_with_make

"""
    pages(dir, cfg, root) -> Vector{NamedTuple}

The built pages of the site at `dir` a reader may be given, each with the text a reader meets. The
arguments are:

- `dir` — the built site's directory.
- `cfg` — the package's config, which names the generated pages and the copies.
- `root` — the package root.

Returns one entry per page, sorted by path, with:

- `path` — the page's `index.html`, relative to the site.
- `key` — a name for the page that is safe in a file name and in an agent's label.
- `text` — the article body as text, which is the page without the navigation, the search box and the
  footer the build puts on every page alike.

A file with no article body is not a page a reader reads — the search page, an asset — and is left out.

TWO KINDS OF PAGE ARE LEFT OUT because the package said so, and this walk could not hear it until
2026-09-22: it took a directory and no config, while the file surfaces dropped both in one filter with
the reason beside them.

A GENERATED page — the rulebook, the readers, the instruments — is by construction full of text that
breaks the rules it states, since it quotes every banned spelling in order to ban it, and a reader sent
to one spends its whole budget there. Three were, on [GBGPeriodicFields](https://grigorysarnitsky.github.io/GBGPeriodicFields.jl/)'s first real
run, and returned seventeen findings nobody should act on.

A page built from a declared COPY is kept or dropped by its SOURCE: kept, under the source's name, where
the source is a target — the architecture document — and dropped where it is not, which is every other
rationale document, whose text no reader is given. A finding on a kept copy names the source through
[`source_of`](@ref), so a fix lands where the next build will not overwrite it, and the count is not
inflated by a copy and its source read as two places — thirty-one findings of one run were.
"""
function pages(dir::AbstractString, cfg::Model.Config, root::AbstractString)
    out = NamedTuple{(:path, :key, :text),Tuple{String,String,String}}[]
    isdir(dir) || return out
    ignored = Texts.ignored(root)
    for (here, _, files) in walkdir(dir; onerror = _ -> nothing)
        for f in files
            f == "index.html" || continue
            full = joinpath(here, f)
            rel = relpath(full, dir)
            startswith(rel, "search") && continue
            article = try
                Texts.article_of(Texts.parse_page(full))
            catch
                nothing                              # an unparseable page is not a page a reader reads
            end
            article === nothing && continue
            # A page is kept by what it was WRITTEN FROM (ruled 2026-09-23): a generated page is nobody's;
            # a copy resolves to its source, and stays only if that source is a target — so the
            # architecture document's page is read, under the source's name, and the copies of the
            # package's working notes are not. Until now every copy was dropped, so the one rationale
            # document the owner holds to a cold read was the one built page no reader was launched over.
            src = source_of(root, rel; cfg)
            written(cfg, src) && continue
            Catalogue.target(cfg, src) || continue
            # A page whose only source is a file the build writes and git ignores has no text a fixer
            # could edit; one that says where it came from was resolved above.
            !isempty(src) && ignored(src) && continue
            text = strip(Texts.page_text(article))
            text = replace(text, r"[ \t]*\n(?:[ \t]*\n)*" => "\n")   # blank runs, never a code line's indent
            isempty(text) && continue
            push!(out, (path = rel, key = key_of(rel), text = String(text)))
        end
    end
    return sort!(out; by = p -> p.path)
end

# Whether the package said this path is not a reader's to read: written by a generator, or a copy whose
# text belongs to the source it was copied from. The same list the file surfaces filter on.
written(cfg::Model.Config, path::AbstractString) =
    !isempty(path) && (any(g -> replace(g, '\\' => '/') == path, cfg.generated) ||
                       any(c -> replace(first(c), '\\' => '/') == path, cfg.copies))

# A page's name, safe in a file name and in an agent's label: the directories it sits in, joined.
function key_of(rel::AbstractString)
    parts = filter(!isempty, split(replace(rel, '\\' => '/'), '/'))
    parts = filter(p -> p != "index.html", parts)
    return isempty(parts) ? "home" : join(parts, "-")
end

"""
    source_of(root, path; cfg = nothing) -> String

The tracked file a built page was made from, by Documenter's own convention: `guide/config/index.html`
is `docs/src/guide/config.md`, and the home page is `docs/src/index.md`. The arguments are:

- `root` — the package root.
- `path` — the page's path inside the site.
- `cfg` — the package's config where the caller has one.

Returns the path relative to the package, or `""` where no such file exists.

Where `cfg` is given and the page was built from a declared COPY, the SOURCE is named instead. A fix
landing in a copy is gone at the next build, and a finding that names the copy sends its fixer to a file
the guard will refuse — so it names the file the text is actually written in.

It is a HINT, not an answer. A page also carries docstrings collected from the source, and a quote read
in one of those is not in this file at all; the collector searches the documentation for the quote and
reports what it cannot place. The hint is what makes the common case — a defect in a page's own prose —
land in the right file without a search.
"""
function source_of(root::AbstractString, path::AbstractString; cfg::Union{Model.Config,Nothing} = nothing)
    parts = filter(p -> p != "index.html", filter(!isempty, split(replace(path, '\\' => '/'), '/')))
    stem = isempty(parts) ? "index" : join(parts, "/")
    for candidate in (joinpath("docs", "src", stem * ".md"), joinpath("docs", "src", stem, "index.md"))
        isfile(joinpath(root, candidate)) || continue
        # A page Literate writes says what it was written from, in Documenter's own `EditURL`; the
        # generated Markdown is a build output, and a finding sent there is overwritten at the next
        # build (found in review, 2026-09-23, on a real example page).
        edit = edit_url(root, candidate)
        edit === nothing || return edit
        here = replace(candidate, '\\' => '/')
        cfg === nothing && return candidate
        # A declared COPY is written by the build from a tracked source, and a fix landing in the copy is
        # gone at the next build. Name the source instead: the guard refuses the copy either way, but a
        # finding that names the copy sends its fixer to a file nobody may edit.
        k = findfirst(c -> replace(first(c), '\\' => '/') == here, cfg.copies)
        return k === nothing ? candidate : last(cfg.copies[k])
    end
    return ""
end

# The file a page's `@meta` block names in `EditURL`, relative to the package, when it is one inside it.
function edit_url(root::AbstractString, page::AbstractString)
    text = try
        read(joinpath(root, page), String)
    catch
        return nothing
    end
    m = match(r"^```@meta\s*\n(.*?)^```"ms, text)
    m === nothing && return nothing
    u = match(r"^\s*EditURL\s*=\s*\"([^\"]+)\""m, m.captures[1])
    u === nothing && return nothing
    occursin("://", u.captures[1]) && return nothing
    full = normpath(joinpath(root, dirname(page), u.captures[1]))
    rel = relpath(full, root)
    (startswith(rel, "..") || !isfile(full)) && return nothing
    return replace(rel, '\\' => '/')
end

"""
    write_units(dir, pages) -> Vector{NamedTuple}

Writes each page's text into its own file under `dir`, so a reader given one unit is given one file and
can reach no other. The arguments are `dir`, where the stage's files live, and `pages`, what
[`pages`](@ref) returned. Returns the pages, each with the `file` written for it.
"""
function write_units(dir::AbstractString, pages::AbstractVector)
    mkpath(dir)
    out = NamedTuple{(:path, :key, :text, :file),Tuple{String,String,String,String}}[]
    for p in pages
        file = joinpath(dir, "unit-" * p.key * ".txt")
        write(file, p.text)
        push!(out, (path = p.path, key = p.key, text = p.text, file = file))
    end
    return out
end

end # module Site
