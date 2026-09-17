"""
    Checks

Running the rulebook over a package: which files each file set names here, which rules apply here, and
what their program checks report (`docs/ARCHITECTURE.md` §5.2, §9).

Everything in this module runs inside a consumer's docs build and test suite, so it is offline, starts no
child process and reads no review state: a check must give the same answer on a fresh clone and on CI.
A rule whose check reaches the network is skipped unless it is asked for by name.
"""
module Checks

using ..Model
using ..Catalogue
using ..Texts

"""
    DEFAULT_PATTERNS

Where each file set lives in a package that says nothing about it. A package's own config overrides any of
these, which is how a package whose examples are elsewhere, or whose rationale is one document, says so.
"""
const DEFAULT_PATTERNS = Dict{Model.FileSet.T,Vector{String}}(
    Model.FileSet.DOCSTRINGS => ["src/**/*.jl", "ext/**/*.jl"],
    Model.FileSet.CODE       => ["src/**/*.jl", "ext/**/*.jl"],
    Model.FileSet.PAGES      => ["docs/src/**/*.md"],
    Model.FileSet.RATIONALE  => String[],
    Model.FileSet.LITERATE   => ["examples/**/*.jl"],
    Model.FileSet.TESTS      => ["test/**/*.jl"],
)

"""
    files(cfg, root, fileset) -> Vector{String}

The files of one file set in the package at `root`, as paths relative to it, sorted and without
duplicates. The arguments are:

- `cfg` — the package's config.
- `root` — the package root.
- `fileset` — the set to resolve.

A package's own patterns replace the defaults for that set rather than adding to them, so a package that
says where its pages are is believed. Returns the paths.
"""
function files(cfg::Model.Config, root::AbstractString, fileset::Model.FileSet.T)
    patterns = get(cfg.filesets, fileset, DEFAULT_PATTERNS[fileset])
    out = String[]
    for pattern in patterns
        append!(out, expand(root, pattern))
    end
    # A page written at build time is nobody's to fix: the rules page is by construction full of text
    # that breaks the rules it lists, and a reader would spend its whole budget reporting it
    # (docs/ARCHITECTURE.md §5.2). Same for a declared copy, whose text belongs to its source.
    written = Set(vcat(cfg.generated, first.(cfg.copies)))
    return sort!(unique!(filter(f -> !(f in written), out)))
end

# `**` matches any run of directories, `*` anything within one name. Written out rather than taken from a
# package: the patterns are few and the walk is over a source tree, not a corpus.
function expand(root::AbstractString, pattern::AbstractString)
    isfile(joinpath(root, pattern)) && return [String(pattern)]
    rx = Regex("^" * replace(replace(replace(pattern, "." => "\\."), "**/" => "\0"), "*" => "[^/]*") * "\$")
    rx = Regex(replace(rx.pattern, "\0" => "(?:.*/)?"))
    out = String[]
    for (dir, _, fs) in walkdir(root)
        rel = relpath(dir, root)
        for f in fs
            p = rel == "." ? f : joinpath(rel, f)
            p = replace(p, '\\' => '/')
            startswith(p, ".git/") && continue
            occursin(rx, p) && push!(out, p)
        end
    end
    return out
end

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
function run_rule(rule::Model.Rule, cfg::Model.Config, root::AbstractString; network::Bool = false)
    check = rule.check
    check isa Model.ProgramCheck || return Model.Location[]
    check.network && !network && return Model.Location[]
    applies(cfg, rule.id) || return Model.Location[]

    out = Model.Location[]
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
    else
        return Model.Location[]      # LOADED_MODULE, BUILT_SITE and QUESTION are run by their own callers
    end
    return sort!(out; by = l -> (l.file, l.line))
end

# A check reading one text reports the line inside that text; the file, and the node it fell in, are the
# runner's to fill in — a check never has to know where it was pointed.
function located(loc::Model.Location, file::AbstractString, root::AbstractString)
    isempty(loc.file) || return loc
    return Model.Location(; file, node = Texts.node_at(root, file, loc.line), text = loc.text,
                           line = loc.line, found = Model.Anchor.FRESH)
end

"""
    run_all(cfg, root; intention = nothing, network = false) -> Vector{Model.Location}

Everywhere any rule of the rulebook is broken in the package at `root`, for the rules of one intention —
the documentation rules in a docs build, the code rules in a test suite — or for every rule when
`intention` is `nothing`. The arguments are:

- `cfg` — the package's config, which says which rules are off here and where its files are.
- `root` — the package root.
- `intention` — the intention to run, or `nothing` for every rule.
- `network` — whether a check that reaches the network may run; `false` inside every build and test.

Returns the locations, in file and line order.
"""
function run_all(cfg::Model.Config, root::AbstractString; intention = nothing, network::Bool = false)
    out = Model.Location[]
    for rule in Catalogue.RULES
        intention === nothing || rule.intention === intention || continue
        append!(out, run_rule(rule, cfg, root; network))
    end
    return out
end

end # module Checks
