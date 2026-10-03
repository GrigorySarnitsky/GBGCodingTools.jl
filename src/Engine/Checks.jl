# The design's §5.2, §9; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Checks

Running the rulebook over a package: which files each file set names here, which rules apply here, and
what their program checks report.

Everything in this module runs inside a consumer's docs build and test suite, so it is offline, starts no
child process and reads no review state: a check must give the same answer on a fresh clone and on CI.
A rule whose check reaches the network is skipped unless it is asked for by name.
"""
module Checks

using ..Model
using ..Catalogue
using ..Texts

# `DEFAULT_PATTERNS`, `files` and `expand` moved to `Texts` on 2026-09-18. Which files a rule reads is a
# text-reading concern, and a RULE could not reach them here: `Rules` is the third module of the order
# and this is the fifth, so `RULE.DOC.SHAPE` had grown its own copy of the resolution and got it wrong.
const DEFAULT_PATTERNS = Texts.DEFAULT_PATTERNS
files(cfg::Model.Config, root::AbstractString, fileset::Model.FileSet.T) = Texts.files(cfg, root, fileset)

"""
    applies(cfg, id; file = "") -> Bool

Whether the rule, agent role or instrument with that id is on in this package: a [`Model.Switch`](@ref)
naming it turns it off, one naming files turns it off for those files alone, and a
[`Model.Deferral`](@ref) naming a rule holds it off — owed, not answered — until the package meets it.

# Arguments

- `cfg` — the package's config.
- `id` — what is being asked about.
- `file` — the file it would run over, empty to ask about the package.

Returns whether it applies.
"""
function applies(cfg::Model.Config, id::Symbol; file::AbstractString = "")
    any(d -> d.rule === id, cfg.deferrals) && return false
    isempty(file) || excluded(cfg, file) && return false
    for s in cfg.switches
        s.target === id || continue
        isempty(s.files) && return false
        isempty(file) && continue
        # The same glob every file set is matched by: a switch spelling `src/**/*.jl` meant something else
        # here, with `**/` needing a slash and every metacharacter live (found in review, 2026-09-26).
        any(pattern -> Texts.glob_matches(pattern, file), s.files) && return false
    end
    return true
end

excluded(cfg::Model.Config, file::AbstractString) = Texts.excluded(cfg, file)

"""
    reading(rule, cfg, root) -> Vector{Tuple{Model.FileSet.T,String}}

Every file one rule reads in this package, each with the file set it was reached through.

# Arguments

- `rule` — the rule about to run.
- `cfg` — the package's config, which may name this rule's files itself.
- `root` — the package root.

Returns the pairs, in file order.

Normally that is the rule's file sets. A rule that names a `files_parameter` and whose package has SET
that parameter reads exactly the globs named there instead, so a package can say which files one rule
means without widening a set that other rules also read — which pages carry the provenance banner is
that kind of question, and expressing it as `rationale` put the banner's reach and every rationale
rule's reach on one dial.

The file set reported for a named file is `PAGES`, since what a package names this way is a page; a
docstring surface is not selectable this way and does not need to be.
"""
function reading(rule::Model.Rule, cfg::Model.Config, root::AbstractString)
    if rule.files_parameter !== nothing
        globs = String[]
        for s in cfg.settings
            s.rule === rule.id && s.name === rule.files_parameter && s.value isa Vector{String} &&
                append!(globs, s.value)
        end
        if !isempty(globs)
            named = String[]
            for g in globs; append!(named, Texts.expand(root, g)); end
            skip = Texts.ignored(root)
            written = Set(vcat(cfg.generated, first.(cfg.copies)))
            return [(Model.FileSet.PAGES, f) for f in
                    sort!(unique!(filter(f -> !(f in written) && !skip(f), named)))]
        end
    end
    return [(fs, file) for fs in rule.filesets for file in files(cfg, root, fs)]
end

"""
    run_rule(rule, cfg, root; network = false, history = false, pkg = nothing,
             site = nothing) -> Vector{Model.Location}

Everywhere the rule is broken in the package at `root`.

# Arguments

- `rule` — the rule to run.
- `cfg` — the package's config.
- `root` — the package root.
- `network` — whether a check that reaches the network may run; `false` inside every build and test, so a
  run gives the same answer offline.
- `history` — whether a check that reads the repository's branch and commits may run; `false` inside
  every build and test, `true` under `gbg check`, and the end-of-turn hook runs the same lines itself.
- `pkg` — the loaded package, which a rule reading the module needs; `nothing` skips such a rule.
- `site` — the built site's directory, which a rule reading the site needs; `nothing` skips such a rule.

A rule an agent decides, or one with no check at all, reports nothing here: this is the program half.
Returns the locations, in file and line order.
"""
function run_rule(rule::Model.Rule, cfg::Model.Config, root::AbstractString; network::Bool = false,
                  history::Bool = false, pkg = nothing, site = nothing)
    check = rule.check
    check isa Model.ProgramCheck || return Model.Location[]
    check.network && !network && return Model.Location[]
    check.input === Model.Input.HISTORY && !history && return Model.Location[]
    # A publication rule reads what a repository would publish — every commit, its metadata, the GitHub
    # side — and only `gbg leak` runs it, through `Engine.Leak`; no build, test or hook ever does.
    check.input === Model.Input.PUBLICATION && return Model.Location[]
    applies(cfg, rule.id) || return Model.Location[]

    out = Model.Location[]
    # A per-file switch is honoured on EVERY kind of check, not only the one that reads file by file.
    # It used to be consulted inside the `SOURCE_TEXT` branch alone, so a switch naming files on a rule
    # that reads the tree, the built site or the loaded module was a silent no-op — and its reason was
    # still rendered onto the package's site, publishing a claim that was not in force.
    keep(l) = isempty(l.file) || applies(cfg, rule.id; file = l.file)
    if check.input === Model.Input.SOURCE_TEXT
        for (fs, file) in reading(rule, cfg, root)
            applies(cfg, rule.id; file) || continue
            # A documentation rule reads the file's PROSE, not its source: Julia code is full of text
            # that looks like prose markup, and a rule handed the whole file reports the code as though
            # it were the prose about it (`Texts.prose_text` keeps the line numbering).
            # A DOCSTRINGS rule reads the docstrings alone — a docstring is published and a comment is
            # not, so a rule about how text renders has nothing to say about a comment. A CODE rule reads
            # the SOURCE, because what it is about is the code and the text together: whether a docstring
            # tells the truth about the thing under it cannot be decided from either half alone.
            text = fs === Model.FileSet.DOCSTRINGS ?
                   Texts.prose_text(joinpath(root, file); comments = false) :
                   read(joinpath(root, file), String)
            for loc in check.run(text, cfg)
                push!(out, located(loc, file, root))
            end
        end
    elseif check.input === Model.Input.FILE_TREE || check.input === Model.Input.HISTORY
        append!(out, check.run(root, cfg))
    elseif check.input === Model.Input.LOADED_MODULE
        # The package itself, loaded. A caller that has not loaded it — `gbg check` run from outside a
        # package's own environment — passes nothing, and the rule is NOT silently skipped: it is the
        # caller's business to say so, by asking `not_run` which rules it could not reach.
        pkg === nothing && return Model.Location[]
        # A check that reads the loaded package nearly always reads the SOURCE too — what a docstring
        # says against what the module actually holds — so it is handed both.
        append!(out, check.run((pkg = pkg, root = root), cfg))
    elseif check.input === Model.Input.BUILT_SITE
        site === nothing && return Model.Location[]
        # A built-site check names the page it read by the path it walked; a location is relative to the
        # package, so the runner relativises it — the check has no business knowing where the root is.
        for loc in check.run(site, cfg)
            file = isabspath(loc.file) ? relpath(loc.file, root) : loc.file
            push!(out, Model.Location(; file, node = loc.node, text = loc.text, line = loc.line, found = loc.found))
        end
    else
        return Model.Location[]      # a QUESTION check is run when a question is put, by `Questions`
    end
    return sort!(filter(keep, out); by = l -> (l.file, l.line))
end

# A check reading one text reports the line inside that text; the file, and the node it fell in, are the
# runner's to fill in — a check never has to know where it was pointed.
function located(loc::Model.Location, file::AbstractString, root::AbstractString)
    isempty(loc.file) || return loc
    return Model.Location(; file, node = Texts.node_at(root, file, loc.line), text = loc.text,
                           line = loc.line, found = Model.Anchor.FRESH)
end

"""
    run_all(cfg, root; intention = nothing, network = false, history = false,
            pkg = nothing, site = nothing) -> Vector{Tuple{Symbol,Model.Location}}

Everywhere any rule of the rulebook is broken in the package at `root`, for the rules of one intention —
the documentation rules in a docs build, the code rules in a test suite — or for every rule when
`intention` is `nothing`.

# Arguments

- `cfg` — the package's config, which says which rules are off here and where its files are.
- `root` — the package root.
- `intention` — the intention to run, or `nothing` for every rule.
- `network` — whether a check that reaches the network may run; `false` inside every build and test.
- `history` — whether a check that reads the repository's history may run; `false` inside every build
  and test.
- `pkg`, `site` — the loaded package and the built site's directory, passed on to [`run_rule`](@ref).

Returns the locations, in file and line order.
"""
function run_all(cfg::Model.Config, root::AbstractString; intention = nothing, network::Bool = false,
                 history::Bool = false, pkg = nothing, site = nothing)
    out = Tuple{Symbol,Model.Location}[]
    for rule in Catalogue.RULES
        intention === nothing || rule.intention === intention || continue
        # The rule's id travels WITH its finding. A report that prints only the message leaves a reader
        # to infer the class from the wording, and a class inferred from wording is a class miscounted:
        # a consumer counting one rule's findings from the text got two different totals in two runs.
        for l in run_rule(rule, cfg, root; network, history, pkg, site)
            push!(out, (rule.id, l))
        end
    end
    append!(out, run_patterns(cfg, root; intention))
    return out
end

"""
    run_patterns(cfg, root; intention = nothing) -> Vector{Tuple{Symbol,Model.Location}}

Everywhere one of the package's OWN rules — each a [`Model.PatternRule`](@ref) in its config — is
broken, for the rules of one intention or for all of them.

# Arguments

- `cfg` — the package's config, which holds the rules.
- `root` — the package root.
- `intention` — the intention to run, or `nothing` for every rule.

Returns the rule id and the location for each, in file and line order.

A pattern rule has no intention of its own: one over the code or the tests is a code rule, run in the
suite, and one over any documentation set is a documentation rule, run in the build. Until 2026-09-26
these rules were rendered into the rulebook and run by nothing.
"""
function run_patterns(cfg::Model.Config, root::AbstractString; intention = nothing)
    out = Tuple{Symbol,Model.Location}[]
    for r in cfg.rules
        intention === nothing || intention_of(r) === intention || continue
        applies(cfg, r.id) || continue
        for fs in r.filesets, file in files(cfg, root, fs)
            applies(cfg, r.id; file) || continue
            text = fs === Model.FileSet.DOCSTRINGS ?
                   Texts.prose_text(joinpath(root, file); comments = false) :
                   read(joinpath(root, file), String)
            if r.forbidden
                for i in pattern_lines(r, text)
                    push!(out, (r.id, located(Model.Location(; file = "", line = i, text = r.statement), file, root)))
                end
            elseif !occursin(r.pattern, text)
                push!(out, (r.id, Model.Location(; file, line = 0, text = r.statement)))
            end
        end
    end
    unique!(out)
    return sort!(out; by = ((_, l),) -> (l.file, l.line))
end

# A rule over any documentation set runs in the build, as a package's own lint over its pages did; one
# over the code or the tests alone runs in the suite.
intention_of(r::Model.PatternRule) =
    all(fs -> fs in (Model.FileSet.CODE, Model.FileSet.TESTS), r.filesets) ? Model.Intention.CODE : Model.Intention.DOCUMENTATION

"""
    pattern_lines(r, text) -> Vector{Int}

The lines of `text` where the forbidden pattern rule `r` is broken. The arguments are `r` and `text`.
Returns the line numbers, in order.

Without a trigger, a line holding the pattern and not the escape. With one, a line holding the trigger
whose window — `window` lines either side — holds the pattern and not the escape: the convention is
about what is said NEAR a word, as
[GBGHomogeneousTurbulence](https://grigorysarnitsky.github.io/GBGHomogeneousTurbulence.jl/)'s Lamb-vector
sign is (its request of 2026-10-03). A line inside a `skip` region is never a trigger, nor a match without one.
"""
function pattern_lines(r::Model.PatternRule, text::AbstractString)
    lines = split(text, '\n')
    skipped = falses(length(lines))
    for (from, to) in r.skip
        i = 1
        while (a = findnext(l -> startswith(l, from), lines, i)) !== nothing
            b = something(findnext(l -> startswith(l, to), lines, a + 1), length(lines))
            skipped[a:b] .= true
            i = b + 1
        end
    end
    escaped(t) = r.escape !== nothing && occursin(r.escape, t)
    if r.trigger === nothing
        return [i for (i, l) in enumerate(lines) if !skipped[i] && occursin(r.pattern, l) && !escaped(l)]
    end
    out = Int[]
    for (i, l) in enumerate(lines)
        (skipped[i] || !occursin(r.trigger, l)) && continue
        window = join(lines[max(1, i - r.window):min(length(lines), i + r.window)], '\n')
        occursin(r.pattern, window) && !escaped(window) && push!(out, i)
    end
    return out
end

"""
    not_run(cfg; pkg = nothing, site = nothing, network = false) -> Vector{Symbol}

The rules a run could not reach, and why it could not: those that read the loaded package where nothing
loaded it, those that read the built site where none was built, and those that reach the network where
that was not allowed. A rule that reads the history is not among them: a build or a test never reaches
it, and it is not told it missed something that was never its to run.

# Arguments

- `cfg` — the package's config.
- `pkg` — the loaded package, or `nothing`.
- `site` — the built site's directory, or `nothing`.
- `network` — whether a check that reaches the network was allowed.

Returns the rule ids, so a caller can say what it did not check rather than reporting clean.
"""
function not_run(cfg::Model.Config; pkg = nothing, site = nothing, network::Bool = false)
    out = Symbol[]
    for rule in Catalogue.RULES
        check = rule.check
        check isa Model.ProgramCheck || continue
        applies(cfg, rule.id) || continue
        (check.input === Model.Input.LOADED_MODULE && pkg === nothing) && (push!(out, rule.id); continue)
        (check.input === Model.Input.BUILT_SITE && site === nothing) && (push!(out, rule.id); continue)
        (check.network && !network) && push!(out, rule.id)
    end
    return out
end

end # module Checks
