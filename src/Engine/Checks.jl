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
naming it turns it off, and one naming files turns it off for those files alone. The arguments are:

- `cfg` — the package's config.
- `id` — what is being asked about.
- `file` — the file it would run over, empty to ask about the package.

Returns whether it applies.
"""
function applies(cfg::Model.Config, id::Symbol; file::AbstractString = "")
    for s in cfg.switches
        s.target === id || continue
        isempty(s.files) && return false
        isempty(file) && continue
        any(pattern -> occursin(Regex("^" * replace(replace(pattern, "." => "\\."), "*" => ".*") * "\$"), file), s.files) && return false
    end
    return true
end

"""
    run_rule(rule, cfg, root; network = false) -> Vector{Model.Location}

Everywhere the rule is broken in the package at `root`. The arguments are:

- `rule` — the rule to run.
- `cfg` — the package's config.
- `root` — the package root.
- `network` — whether a check that reaches the network may run; `false` inside every build and test, so a
  run gives the same answer offline.

A rule an agent decides, or one with no check at all, reports nothing here: this is the program half.
Returns the locations, in file and line order.
"""
function run_rule(rule::Model.Rule, cfg::Model.Config, root::AbstractString; network::Bool = false,
                  pkg = nothing, site = nothing)
    check = rule.check
    check isa Model.ProgramCheck || return Model.Location[]
    check.network && !network && return Model.Location[]
    applies(cfg, rule.id) || return Model.Location[]

    out = Model.Location[]
    # A per-file switch is honoured on EVERY kind of check, not only the one that reads file by file.
    # It used to be consulted inside the `SOURCE_TEXT` branch alone, so a switch naming files on a rule
    # that reads the tree, the built site or the loaded module was a silent no-op — and its reason was
    # still rendered onto the package's site, publishing a claim that was not in force.
    keep(l) = isempty(l.file) || applies(cfg, rule.id; file = l.file)
    if check.input === Model.Input.SOURCE_TEXT
        for fs in rule.filesets, file in files(cfg, root, fs)
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
    elseif check.input === Model.Input.FILE_TREE
        append!(out, check.run(root, cfg))
    elseif check.input === Model.Input.LOADED_MODULE
        # The package itself, loaded. A caller that has not loaded it — `gbg check` run from outside a
        # package's own environment — passes nothing, and the rule is NOT silently skipped: it is the
        # caller's business to say so, which `run_all` does by returning the rules it could not run.
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
    run_all(cfg, root; intention = nothing, network = false)
        -> Vector{Tuple{Symbol,Model.Location}}

Everywhere any rule of the rulebook is broken in the package at `root`, for the rules of one intention —
the documentation rules in a docs build, the code rules in a test suite — or for every rule when
`intention` is `nothing`. The arguments are:

- `cfg` — the package's config, which says which rules are off here and where its files are.
- `root` — the package root.
- `intention` — the intention to run, or `nothing` for every rule.
- `network` — whether a check that reaches the network may run; `false` inside every build and test.

Returns the locations, in file and line order.
"""
function run_all(cfg::Model.Config, root::AbstractString; intention = nothing, network::Bool = false,
                 pkg = nothing, site = nothing)
    out = Tuple{Symbol,Model.Location}[]
    for rule in Catalogue.RULES
        intention === nothing || rule.intention === intention || continue
        # The rule's id travels WITH its finding. A report that prints only the message leaves a reader
        # to infer the class from the wording, and a class inferred from wording is a class miscounted:
        # a consumer counting one rule's findings from the text got two different totals in two runs.
        for l in run_rule(rule, cfg, root; network, pkg, site)
            push!(out, (rule.id, l))
        end
    end
    return out
end

"""
    not_run(cfg; pkg = nothing, site = nothing, network = false) -> Vector{Symbol}

The rules a run could not reach, and why it could not: those that read the loaded package where nothing
loaded it, those that read the built site where none was built, and those that reach the network where
that was not allowed. The arguments are:

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
