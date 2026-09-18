# The design's §3; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Check

`gbg check`: the always-on checks of, run on demand over a package — the
rulebook's program checks and the wiring check, the same programs a docs build and a test suite run.

It reports and repairs nothing: regenerating a drifted file is `gbg sync`'s, and fixing what a rule found
is the work of whoever ran it. Exit 0 when it found nothing, 1 when it found something, 2 when it could
not read the package.
"""
module Check

using ..GBGCodingTools: GBGCodingTools, Catalogue, ConfigIO, Engine, Model, Render, parse_options, VERBS

"""
    run(root; intention = nothing, network = false, io = stdout) -> Int

Runs the rules and the wiring check over the package at `root` and prints what they found. The arguments
are:

- `root` — the package root.
- `intention` — `Model.Intention.DOCUMENTATION` for what a docs build runs, `Model.Intention.CODE` for
  what a test suite runs, or `nothing` for both.
- `network` — whether a check that reaches the network may run; `false` everywhere but this verb.
- `io` — where the report goes.

Returns the exit code: 0 clean, 1 findings, 2 the package could not be read.
"""
function run(root::AbstractString; intention = nothing, network::Bool = false, io::IO = stdout)
    cfg = try
        ConfigIO.read_config(root)
    catch err
        err isa ConfigIO.ConfigError || rethrow()
        println(io, sprint(showerror, err))
        return 2
    end
    problems = ConfigIO.validate(cfg, root)
    if !isempty(problems)
        println(io, "check: the config describes a package this is not:")
        for p in problems; println(io, "  - ", p); end
        return 2
    end

    found = Engine.Checks.run_all(cfg, root; intention, network)
    drift = intention === Model.Intention.DOCUMENTATION ? Model.Location[] : Render.wiring(cfg, root)

    if isempty(found) && isempty(drift)
        println(io, "check: clean — ", length(Catalogue.RULES), " rule(s), ",
                length(Render.GENERATED), " generated path(s).")
        return 0
    end
    for (id, l) in found
        println(io, "  ", rpad(String(id), 30), " ", l.file, ":", l.line,
                isempty(l.node) ? "" : "  [" * l.node * "]", "  ", l.text)
    end
    for l in drift
        println(io, "  WIRING ", l.file, "  ", l.text, " — run `gbg sync`")
    end
    println(io, "check: ", length(found), " finding(s), ", length(drift), " generated path(s) adrift.")
    return 1
end

function cmd_check(args)
    o = parse_options(args; valued = ["only"])
    root = ConfigIO.require_root("check")
    root === nothing && return 2
    intention = get(o.values, "only", "") == "docs" ? Model.Intention.DOCUMENTATION :
                get(o.values, "only", "") == "code" ? Model.Intention.CODE : nothing
    return run(root; intention, network = "network" in o.flags)
end
VERBS["check"] = cmd_check

end # module Check
