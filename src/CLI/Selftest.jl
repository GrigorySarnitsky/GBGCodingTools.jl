# Selftest.jl — `gbg selftest [--pinned]`: the package's own Pkg.test from a temporary environment (which
# IS every arm of §8); `--pinned` exercises the pinned-copy behaviours on a throwaway fixture copy.

"""
    selftest(; pinned = false, io = stdout) -> Int

Runs the running copy's own `Pkg.test()` from a temporary environment that develops it by path, so the
arms of §8 run over the fixture wherever the tool is installed. With `pinned`, additionally copies the
fixture to `\${TMPDIR}/gbg-pinned-fixture/`, pins it at the newest released tag (its sub-environment
sources rewritten to the https url and rev), instantiates its `docs/` environment and runs the QUICK
doctor there — the pinned-copy behaviours (`PIN.SELF`, `PIN.TREESHA`, `PIN.SOURCES`) — leaving the copy
in place for the install phase. The arguments are `pinned` and `io`, where the report goes. Returns
the exit code.
"""
function selftest(; pinned::Bool = false, io::IO = stdout)
    root = pkgdir(GBGCodingTools)
    println(io, "selftest: Pkg.test() of the copy at $root from a temporary environment …"); flush(io)
    cmd = `$(Base.julia_cmd()) --startup-file=no -e "using Pkg; Pkg.activate(; temp = true); Pkg.develop(path = $(repr(root))); Pkg.test(\"GBGCodingTools\")"`
    ok = success(pipeline(setenv(cmd; dir = root); stdout = io, stderr = io))
    ok || (println(io, "selftest: FAILED"); return 1)
    pinned || (println(io, "selftest: green"); return 0)
    tag = Fleet.latest_tag(root)
    tag === nothing && (println(io, "selftest --pinned: no released tag yet"); return 2)
    dst = joinpath(get(ENV, "TMPDIR", "/tmp"), "gbg-pinned-fixture")
    rm(dst; recursive = true, force = true); cp(joinpath(root, "fixture", "GBG Fixture"), dst)
    rm(joinpath(dst, "docs", "build"); recursive = true, force = true); rm(joinpath(dst, ".gbg", "scratch"); recursive = true, force = true)
    c = joinpath(dst, ".gbg", "config.toml")
    write(c, replace(read(c, String), r"^(version\s*=\s*)\"dev\""m => SubstitutionString("\\1\"$tag\""), "\"../../catalog/seeds/fixture.toml\"" => "\"" * joinpath(root, "catalog", "seeds", "fixture.toml") * "\""))
    for env in ("docs", "test")
        p = joinpath(dst, env, "Project.toml")
        write(p, replace(read(p, String), r"GBGCodingTools = \{path = \"[^\"]*\"\}" => "GBGCodingTools = {url = \"$(Sync.TOOL_URL)\", rev = \"v$tag\"}") * "\n[compat]\nGBGCodingTools = \"=$tag\"\n")
    end
    println(io, "selftest --pinned: fixture copy at $dst pinned $tag; instantiating docs/ …"); flush(io)
    ok = success(pipeline(`$(Base.julia_cmd()) --startup-file=no --project=$(joinpath(dst, "docs")) -e "using Pkg; Pkg.instantiate()"`; stdout = io, stderr = io))
    ok || (println(io, "selftest --pinned: the pinned docs environment does not instantiate"); return 1)
    code = success(pipeline(`$(Base.julia_cmd()) --startup-file=no --project=$(joinpath(dst, "docs")) -e "using GBGCodingTools; exit(GBGCodingTools.main([\"doctor\", \"--only\", \"PIN,CFG.VALID,SELF.CONSUMER\"]))"`; dir = dst, stdout = io, stderr = io)) ? 0 : 1
    println(io, code == 0 ? "selftest --pinned: the pinned copy verifies" : "selftest --pinned: the pinned copy's doctor failed")
    return code
end

cmd_selftest(args) = selftest(; pinned = "pinned" in parse_options(args).flags)
VERBS["selftest"] = cmd_selftest
