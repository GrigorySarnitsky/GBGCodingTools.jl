# Release.jl — `gbg release <ver>` and `gbg release <ver>-rc.<n>`: the tag, from the dev checkout at a
# clean tree, after every precondition of ARCHITECTURE D16 and §8 (IMPLEMENTATION 1.10 item 7).

# `cites_round` and `carry_release_fails` stood here until 2026-09-17: a final release used to be
# held back by an open round, by a candidate whose /check-docs round was not closed, and by the
# carry ledger. The new design holds a release with none of those (docs/ARCHITECTURE.md §10):
# a clean pushed tree, green tests, a green docs build and the changelog entry, and nothing else.



"""
    release_fails(cfg, root, ver, base, rc) -> Vector{String}

Every reason `v<ver>` may not be tagged from `root`, in the order they are checked; empty when there is
none. The arguments are:

- `cfg` — the config read at `root`.
- `root` — the checkout to release.
- `ver` — the version to tag.
- `base` — its `X.Y.Z` part.
- `rc` — whether it is a candidate.

It reads the tree, the tags, `CHANGELOG.md` and `Project.toml`, and writes NOTHING — which is the point
of it being separate. A test of [`release`](@ref) can only reach the refusals: past them the verb runs
`git tag` and `git push`, and a test must never cut a tag. So the conditions beyond this list were
untestable, and that is exactly where a defect lived for nine releases. Lifted out so each can be
exercised over a temporary repository (2026-09-12 work queue).
"""
function release_fails(cfg::AbstractDict, root::AbstractString, ver::AbstractString,
                       base::AbstractString, rc::Bool)
    fails = String[]
    isempty(Git.porcelain(root)) || push!(fails, "the tree is not clean")
    branch = Git.run(root, "rev-parse", "--abbrev-ref", "HEAD")
    branch == cfg["git"]["branch"] || push!(fails, "on branch $branch, not $(cfg["git"]["branch"])")
    Git.run(root, "rev-parse", "-q", "--verify", "refs/tags/v$ver") === nothing || push!(fails, "tag v$ver exists — a tag is never re-issued")
    # A NAMED refusal, never a crash. The exit contract is 0 clean, 1 substantive finding, 2 cannot
    # evaluate, 3 crash; a bare `read` threw SystemError out of the verb — exit 3, with a backtrace — for
    # a consumer that has simply not written a changelog yet, while every sibling condition here is a
    # line in `fails` and exit 2. Found by giving this verb its first test (2026-09-12 work queue), and
    # the same shape as src#1, where four audit lanes converged on a condition surfacing as a crash.
    chlog = joinpath(root, "CHANGELOG.md")
    if !isfile(chlog)
        push!(fails, "CHANGELOG.md is absent")
    else
        occursin("## $ver — ", read(chlog, String)) || push!(fails, "CHANGELOG.md has no `## $ver — <date>` entry")
    end
    pv = String(TOML.parsefile(joinpath(root, "Project.toml"))["version"])
    pv == base || push!(fails, "Project.toml version is $pv, the release is $base")
    return fails
end

"""
    release(ver; io = stdout, skip_tests = false, root = pkgdir(GBGCodingTools)) -> Int

Tags and pushes `v<ver>` from the dev checkout. The arguments are:

- `ver` — the version to tag, `X.Y.Z` or `X.Y.Z-rc.N`.
- `io` — where the checks are reported.
- `skip_tests` — skips `Pkg.test()`, the docs build and the deep doctor; for the self-tests of this
  verb only, never set by the CLI.

- `root` — the checkout to release, the running package directory by default; the CLI never passes it.
  A keyword because the verb read `pkgdir(GBGCodingTools)` directly and so had no test at all. Every
  refusal below reads `root`, the dev-checkout guard included: `root` must be a git working tree, since
  it is what gets tagged and pushed.

Refused (exit 2) unless: the tree is clean and on the configured branch; the tag is absent; `CHANGELOG.md`
carries `## <ver> — `; `Project.toml`'s version equals the release version (the base version for a
prerelease); `Pkg.test()` is green; the tool's own docs build exits 0 (`SELF.DOCS`); `gbg doctor --deep`
is green at the root. Nothing else holds a release — no review, no open finding, no unanswered
question, no audit (docs/ARCHITECTURE.md §10). A tag is never moved or re-issued.
Returns the exit code.
"""
function release(ver::AbstractString; io::IO = stdout, skip_tests::Bool = false,
                 root::AbstractString = pkgdir(GBGCodingTools))
    m = match(r"^(\d+\.\d+\.\d+)(-rc\.(\d+))?$", ver)
    m === nothing && (println(io, "release: $ver is neither X.Y.Z nor X.Y.Z-rc.N"); return 2)
    base = m.captures[1]; rc = m.captures[2] !== nothing
    ispath(joinpath(root, ".git")) || (println(io, "release: the dev checkout only — $root is not a git working tree"); return 2)
    cfg = Config.read(root)
    fails = release_fails(cfg, root, ver, base, rc)
    if !isempty(fails)
        println(io, "release: refused —"); foreach(f -> println(io, "  - ", f), fails); return 2
    end
    if !skip_tests
        for (label, cmd) in (("Pkg.test()", `$(Base.julia_cmd()) --startup-file=no --project=$root -e "using Pkg; Pkg.test()"`),
                             ("docs build (SELF.DOCS)", `$(Base.julia_cmd()) --startup-file=no --project=$(joinpath(root, "docs")) $(joinpath(root, "docs", "make.jl"))`))
            println(io, "release: running $label …"); flush(io)
            ok = success(pipeline(setenv(cmd; dir = root); stdout = devnull, stderr = devnull))
            ok || (println(io, "release: refused — $label failed"); return 2)
        end
        println(io, "release: running gbg doctor --deep …"); flush(io)
        _, dcode = Doctor.run(cfg; deep = true, io = devnull)
        dcode == 0 || (println(io, "release: refused — gbg doctor --deep is not green"); return 2)
    end
    Git.run(root, "tag", "-a", "v$ver", "-m", "GBGCodingTools v$ver") === nothing && (println(io, "release: git tag failed"); return 3)
    Git.run(root, "push", "origin", "v$ver") === nothing && (println(io, "release: tag created but the push failed — push it by hand: git push origin v$ver"); return 3)
    println(io, "release: v$ver tagged and pushed", rc ? " (a prerelease: nothing pins it)" : "")
    return 0
end

function cmd_release(args)
    o = parse_options(args)
    isempty(o.positional) && (println(stderr, "usage: gbg release <ver> | gbg release <ver>-rc.<n>"); return 2)
    return release(o.positional[1])
end
VERBS["release"] = cmd_release
