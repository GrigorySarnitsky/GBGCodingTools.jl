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
    pages(dir) -> Vector{NamedTuple}

The built pages of the site at `dir`, each with the text a reader meets. The argument is `dir`, the
built site's directory. Returns one entry per page, sorted by path, with:

- `path` — the page's `index.html`, relative to the site.
- `key` — a name for the page that is safe in a file name and in an agent's label.
- `text` — the article body as text, which is the page without the navigation, the search box and the
  footer the build puts on every page alike.

A file with no article body is not a page a reader reads — the search page, an asset — and is left out.
"""
function pages(dir::AbstractString)
    out = NamedTuple{(:path, :key, :text),Tuple{String,String,String}}[]
    isdir(dir) || return out
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
            text = strip(Texts.text_of(article))
            isempty(text) && continue
            push!(out, (path = rel, key = key_of(rel), text = String(text)))
        end
    end
    return sort!(out; by = p -> p.path)
end

# A page's name, safe in a file name and in an agent's label: the directories it sits in, joined.
function key_of(rel::AbstractString)
    parts = filter(!isempty, split(replace(rel, '\\' => '/'), '/'))
    parts = filter(p -> p != "index.html", parts)
    return isempty(parts) ? "home" : join(parts, "-")
end

"""
    source_of(root, path) -> String

The tracked file a built page was made from, by Documenter's own convention: `guide/config/index.html`
is `docs/src/guide/config.md`, and the home page is `docs/src/index.md`. The arguments are `root`, the
package root, and `path`, the page's path inside the site. Returns the path relative to the package, or
`""` where no such file exists.

It is a HINT, not an answer. A page also carries docstrings collected from the source, and a quote read
in one of those is not in this file at all; the collector searches the documentation for the quote and
reports what it cannot place. The hint is what makes the common case — a defect in a page's own prose —
land in the right file without a search.
"""
function source_of(root::AbstractString, path::AbstractString)
    parts = filter(p -> p != "index.html", filter(!isempty, split(replace(path, '\\' => '/'), '/')))
    stem = isempty(parts) ? "index" : join(parts, "/")
    for candidate in (joinpath("docs", "src", stem * ".md"), joinpath("docs", "src", stem, "index.md"))
        isfile(joinpath(root, candidate)) && return candidate
    end
    return ""
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
