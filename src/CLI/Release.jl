# Release.jl — `gbg release <ver>` and `gbg release <ver>-rc.<n>`: the tag, from the dev checkout at a
# clean tree, after every precondition of ARCHITECTURE D16 and §8 (IMPLEMENTATION 1.10 item 7).
# The design's §10; the coordinates live here rather than in a docstring, which must read complete at the REPL.

# `cites_round` and `carry_release_fails` stood here until 2026-09-17: a final release used to be
# held back by an open round, by a candidate whose /check-docs round was not closed, and by the
# carry ledger. The new design holds a release with none of those (docs/ARCHITECTURE.md §10):
# a clean pushed tree, green tests, a green docs build and the changelog entry, and nothing else.



"""
    ci_verdict(root, sha) -> Union{String,Nothing}

Why the CI workflow does not say this commit is green, or `nothing` when it does. The arguments are
`root`, the checkout, and `sha`, the commit about to be tagged. Returns the reason, in words.

It is asked over the network and is therefore not in [`release_fails`](@ref), which reads the tree alone
and is what the refusal tests exercise.

A tag is permanent and a local gate is not the same question: `v2.0.0-rc.2` and `v2.0.0-rc.3` both went
out on 2026-09-18 with every local command green, one failing on a git identity this machine has and a
runner does not, the other on a workflow step greping a banner that had been renamed. Neither could fail
here. CI runs on a tag or a dispatch (`RULE.GIT.CI_MANUAL`), so the run to ask about is a dispatch on
this commit — `gh workflow run CI --ref master` — before the tag, not after it.

Where `gh` is missing or GitHub cannot be reached this refuses rather than passing: a release cut blind
is what the two red tags were. `GBG_RELEASE_IGNORE_CI=1` is the deliberate way past it.
"""
function ci_verdict(root::AbstractString, sha::AbstractString)
    get(ENV, "GBG_RELEASE_IGNORE_CI", "") == "" || return nothing
    Sys.which("gh") === nothing && return "no `gh` on this machine, so CI's verdict on $sha cannot be read"
    # Asked by commit, and the newest run at it is the verdict: the newest thirty runs of the workflow
    # could miss an older dispatch at this commit, and any one success among them passed a commit whose
    # re-run had gone red (found in review, 2026-09-26). `gh` lists the newest first.
    newest = try
        strip(read(setenv(`gh run list --workflow CI --commit $sha --limit 1 --json status,conclusion
                           --jq $(".[0] // empty | \"\\(.status) \\(.conclusion)\"")`; dir = root), String))
    catch
        return "GitHub could not be reached, so CI's verdict on $sha cannot be read"
    end
    isempty(newest) && return "CI has no run at $sha — dispatch one (`gh workflow run CI --ref master`) and wait for it"
    newest == "completed success" && return nothing
    return "the newest CI run at $sha is `$newest`, not a completed success"
end

"""
    release_fails(cfg, root, ver, base, rc) -> Vector{String}

Every reason `v<ver>` may not be tagged from `root`, in the order they are checked; empty when there is
none.

# Arguments

- `cfg` — the package's config, read at `root`.
- `root` — the checkout to release.
- `ver` — the version to tag.
- `base` — its `X.Y.Z` part.
- `rc` — whether it is a candidate.

It reads the tree, the tags, `CHANGELOG.md` and `Project.toml`, and writes nothing — which is the point
of it being separate. A test of [`release`](@ref) can only reach the refusals: past them the verb runs
`git tag` and `git push`, and a test must never cut a tag. So the conditions beyond this list were
untestable, and that is exactly where a defect lived for nine releases. Lifted out so each can be
exercised over a temporary repository (2026-09-12 work queue).
"""
function release_fails(cfg::Model.Config, root::AbstractString, ver::AbstractString,
                       base::AbstractString, rc::Bool)
    fails = String[]
    isempty(Git.porcelain(root)) || push!(fails, "the tree is not clean")
    branch = Git.run(root, "rev-parse", "--abbrev-ref", "HEAD")
    want = Catalogue.branch_of(cfg)
    branch == want || push!(fails, "on branch $branch, not $want")
    Git.run(root, "rev-parse", "-q", "--verify", "refs/tags/v$ver") === nothing || push!(fails, "tag v$ver exists — a tag is never re-issued")
    # A named refusal, never a crash. The exit contract is 0 clean, 1 substantive finding, 2 cannot
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

Tags and pushes `v<ver>` from the dev checkout.

# Arguments

- `ver` — the version to tag, `X.Y.Z` or `X.Y.Z-rc.N`.
- `io` — where the checks are reported.
- `skip_tests` — skips all four gates after the refusal list: `Pkg.test()`, the docs build, the
  wiring check and the question to GitHub; for the self-tests of this verb only, never set by the CLI.

- `root` — the checkout to release, the running package directory by default; the CLI never passes it.
  A keyword because the verb read `pkgdir(GBGCodingTools)` directly and so had no test at all. Every
  refusal below reads `root`, the dev-checkout guard included: `root` must be a git working tree, since
  it is what gets tagged and pushed.

Refused (exit 2) unless: the tree is clean and on the configured branch; the tag is absent; `CHANGELOG.md`
carries `## <ver> — `; `Project.toml`'s version equals the release version (the base version for a
prerelease); `Pkg.test()` is green; the tool's own docs build exits 0 (`SELF.DOCS`); `gbg sync --check`
is clean at the root; the newest CI run at this commit is a success ([`ci_verdict`](@ref)). Nothing else
holds a release — no review, no open finding, no unanswered question, no audit. A tag is never moved or
re-issued. Returns the exit code; a failed gate, tag or push prints the reason its command gave.
"""
function release(ver::AbstractString; io::IO = stdout, skip_tests::Bool = false,
                 root::AbstractString = pkgdir(GBGCodingTools))
    m = match(r"^(\d+\.\d+\.\d+)(-rc\.(\d+))?$", ver)
    m === nothing && (println(io, "release: $ver is neither X.Y.Z nor X.Y.Z-rc.N"); return 2)
    base = m.captures[1]; rc = m.captures[2] !== nothing
    ispath(joinpath(root, ".git")) || (println(io, "release: the dev checkout only — $root is not a git working tree"); return 2)
    cfg = ConfigIO.read_config(root)
    fails = release_fails(cfg, root, ver, base, rc)
    if !isempty(fails)
        println(io, "release: refused —"); foreach(f -> println(io, "  - ", f), fails); return 2
    end
    if !skip_tests
        for (label, cmd) in (("Pkg.test()", `$(Base.julia_cmd()) --startup-file=no --project=$root -e "using Pkg; Pkg.test()"`),
                             ("docs build (SELF.DOCS)", `$(Base.julia_cmd()) --startup-file=no --project=$(joinpath(root, "docs")) $(joinpath(root, "docs", "make.jl"))`))
            println(io, "release: running $label …"); flush(io)
            said = IOBuffer()
            ok = success(pipeline(setenv(cmd; dir = root); stdout = said, stderr = said))
            if !ok
                # the tail of what it printed: the cause sits at the end, and the whole log is thousands of lines
                lines = split(rstrip(String(take!(said))), '\n')
                println(io, "release: refused — $label failed; the last of what it printed:")
                for l in lines[max(1, end - 39):end]; println(io, "    ", l); end
                return 2
            end
        end
        # `gbg doctor --deep` was the third gate here until 2026-09-17, when the doctor was deleted.
        # What it checked of a package's wiring is the wiring check, which both commands above already
        # run — the docs build and the test suite each call it — so a third invocation added nothing.
        println(io, "release: running gbg sync --check …"); flush(io)
        GBGCodingTools.Wire.sync(root; check = true, io = devnull) == 0 ||
            (println(io, "release: refused — generated files are adrift; run `gbg sync`"); return 2)
        println(io, "release: asking GitHub about CI at this commit …"); flush(io)
        sha = Git.run(root, "rev-parse", "HEAD")
        why = sha === nothing ? "the commit to tag could not be read" : ci_verdict(root, String(sha))
        why === nothing || (println(io, "release: refused — ", why); return 2)
    end
    # A refused tag or push is a named condition with git's reason, exit 2 — no exception escaped, so
    # it is not the crash code.
    ok, said = Git.said(root, "tag", "-a", "v$ver", "-m", "GBGCodingTools v$ver")
    ok || (println(io, "release: git tag failed:\n    ", replace(said, "\n" => "\n    ")); return 2)
    ok, said = Git.said(root, "push", "origin", "v$ver")
    ok || (println(io, "release: tag created but the push failed — push it by hand: git push origin v$ver\n    ",
                   replace(said, "\n" => "\n    ")); return 2)
    println(io, "release: v$ver tagged and pushed", rc ? " (a prerelease; `gbg bump $ver` pins it)" : "")
    return 0
end

"""
    counts(; io = stdout, root = pkgdir(GBGCodingTools)) -> Int

`gbg release --counts`: prints, for `v2.0.0` alone, what still holds that release — the number of ids
of the frozen register (`test/RULES-v1.toml`) that are neither a `Rule` value nor retired,
the count the conversion test ratchets. It prints the one number and refuses nothing (ruled
2026-09-16: nothing else holds a release); the Phase 5 gate reads it as `0`.

# Arguments

- `io` — where the number goes.
- `root` — the checkout whose register and rulebook are counted.

Returns 0, or 2 where the register is not there to read.
"""
function counts(; io::IO = stdout, root::AbstractString = pkgdir(GBGCodingTools))
    register = joinpath(root, "test", "RULES-v1.toml")
    isfile(register) || (println(stderr, "release: no register at $register"); return 2)
    ids = [String(r["id"]) for r in TOML.parsefile(register)["rule"]]
    held = Set(String(r.id) for r in Catalogue.RULES)
    retired = Set(String(r.id) for r in Catalogue.RETIRED)
    println(io, count(id -> !(id in held) && !(id in retired), ids))
    return 0
end

function cmd_release(args)
    o = parse_options(args)
    "counts" in o.flags && return counts()
    isempty(o.positional) && (println(stderr, "usage: gbg release <ver> | gbg release <ver>-rc.<n> | gbg release --counts"); return 2)
    return release(o.positional[1])
end
VERBS["release"] = cmd_release
