# Hunt.jl — the hunt-specific verbs: `gbg witnesses fail|pass <round> [names…]` and `gbg bug-hunt bank`.

"""
    cmd_witnesses(args) -> Int

`gbg witnesses fail|pass <round> [names…]`: `Witnesses.run` over the round's `witnesses/` directory with
the expectation named. Returns the runner's exit code.
"""
function cmd_witnesses(args)
    o = parse_options(args)
    length(o.positional) >= 2 || (println(stderr, "usage: gbg witnesses fail|pass <round> [names…]"); return 2)
    expect = o.positional[1] == "fail" ? :fail : o.positional[1] == "pass" ? :pass : (println(stderr, "witnesses: fail or pass"); return 2)
    cfg = Config.read()
    dir = joinpath(RoundFiles.rounds_dir(cfg), o.positional[2], "witnesses")
    code, _ = Witnesses.run(dir; expect, package = cfg["package"]["name"], project = joinpath(cfg["root"], cfg["instruments"]["bug-hunt"]["witness_env"]),
                            names = String.(o.positional[3:end]))
    return code
end
VERBS["witnesses"] = cmd_witnesses
VERBS["bug-hunt bank"] = args -> (isempty(args) ? (println(stderr, "usage: gbg bug-hunt bank <round>"); 2) : Rounds.cmd_round(vcat(["bank"], args)))
