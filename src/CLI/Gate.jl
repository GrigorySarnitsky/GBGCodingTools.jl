# Gate.jl — `gbg gate [instrument…]`: the closure gate (ARCHITECTURE §6.2 step 10). Called in-process by
# the makedocs wrapper (check-docs, check-consistency), by TestHarness.gate() (bug-hunt, audit-changes),
# bare by hand and by the CI fragments.

"""
    gate(cfg, instruments...; io = stderr) -> Int

The closure gate (§6.2 step 10). The arguments are:

- `cfg` — the validated config.
- `instruments...` — the instruments whose open rounds block (all four when none is named).
- `io` — where the refusal is explained.

It scans EVERY round directory under `.gbg/rounds/`. An open round of a named instrument is exit 1,
naming it — except the rounds named in `GBG_ROUND` (comma separated), which the CLI exports only while
it runs a build, a test or an executable claim on behalf of that round. An open round of a disabled
instrument is exit 1 (`CFG.VALID`).

In a working tree (no `CI` variable) an open round whose directory is untracked or modified while
`HEAD ≠ ROUND.head` is exit 1: the fixes were committed without the round. A round directory without
`ROUND.toml` is exit 2; `.gbg/rounds/` absent while instruments are enabled is exit 2 (`ROUND.DIR`).
`gbg self verify` runs first and its exit 2 is the gate's. Closed rounds are never re-graded here.
Returns the code.
"""
function gate(cfg::AbstractDict, instruments::AbstractString...; io::IO = stderr)
    root = cfg["root"]
    code = self_verify(root; io = devnull)
    code == 0 || (println(io, "gate: gbg self verify failed (exit $code) — the running copy is not the pinned one"); return 2)
    wanted = isempty(instruments) ? Sync.INSTRUMENTS : instruments
    enabled = cfg["instruments"]["enabled"]
    if !isdir(RoundFiles.rounds_dir(cfg))
        isempty(enabled) && return 0
        println(io, "gate: ROUND.DIR — .gbg/rounds/ is absent while instruments are enabled; the gate never passes vacuously (gbg init writes it)")
        return 2
    end
    ignored = Set(filter(!isempty, split(get(ENV, "GBG_ROUND", ""), ',')))
    in_ci = haskey(ENV, "CI")
    head = Git.head(root)
    dirty = Set(p for (_, p) in Git.porcelain(root))
    problems = String[]; fatal = false
    for r in RoundFiles.rounds(cfg)
        if r.state in (:nomarker, :invalid)
            println(io, "gate: round directory $(r.name) has no valid ROUND.toml — exit 2"); fatal = true; continue
        end
        r.state == :open || continue
        inst = r.round["instrument"]
        if !(inst in enabled)
            push!(problems, "$(r.name) is an open round of the DISABLED instrument $inst (CFG.VALID)"); continue
        end
        inst in wanted || continue
        r.name in ignored && continue
        push!(problems, "$(r.name) is open ($inst) — close or abandon it, or run this build/test through `gbg round build|test $(r.name)`")
        if !in_ci && head !== nothing && head != r.round["head"]
            rel = relpath(r.dir, root)
            any(p -> startswith(p, rel * "/") || p == rel, dirty) &&
                push!(problems, "$(r.name): its files are untracked or modified while HEAD moved past the round's opening head — the fixes were committed without the round")
        end
    end
    fatal && return 2
    if !isempty(problems)
        println(io, "gate: refused —"); foreach(p -> println(io, "  ", p), problems)
        return 1
    end
    return 0
end

"""
    cmd_gate(args) -> Int

`gbg gate [instrument…]`: the CLI face of [`gate`](@ref) over the config found from the working
directory; prints `gate: clean` on 0. Returns the code.
"""
function cmd_gate(args)
    o = parse_options(args)
    cfg = Config.read()
    for i in o.positional
        i in Sync.INSTRUMENTS || (println(stderr, "gate: unknown instrument $i"); return 2)
    end
    code = gate(cfg, o.positional...; io = stdout)
    code == 0 && println("gate: clean — no open round" * (isempty(o.positional) ? "" : " of " * join(o.positional, ", ")))
    return code
end
VERBS["gate"] = cmd_gate
