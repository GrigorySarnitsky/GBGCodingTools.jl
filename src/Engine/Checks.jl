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
    skip = ignored(root)
    return sort!(unique!(filter(f -> !(f in written) && !skip(f), out)))
end

"""
    ignored(root) -> Function

A predicate saying whether a path, relative to `root`, is one the package's own `.gitignore` excludes.
The argument is `root`, the package root. Returns the predicate; it is `false` everywhere when there is
no `.gitignore`.

**Why a rule never reads an ignored file.** Such a file is not source — the package has said so. It is
build output, and a finding in it names a line that will not exist after the next build, sends whoever
fixes it into an artefact, and cannot be fixed there at all. A consumer copies four rationale
documents into `docs/src/` as lowercase siblings and renders a Literate example beside them; all five
are ignored, all five are rewritten every build, and the default pages pattern `docs/src/**/*.md` globs
them. On a built tree that was 264 findings against 108 real ones, and once its `docs/make.jl` called
this package the build would have been linting its own output.

It is read from the FILES rather than from `git check-ignore`, because the harness that runs these
checks starts no child process: a rule must give the same answer on a machine with no git on its path.
Checked against `git check-ignore` over 3,203 files in four repositories, it disagrees on two, both
deliberate and both the same name:

- a file that a pattern matches but the repository TRACKS. Git never ignores a tracked file; knowing
  which are tracked needs git, so this skips it. The difference is conservative — a file the package
  told git to ignore goes unread — and it is a file the package asked not to have around.
- a file ignored by the user's GLOBAL excludes (`~/.config/git/ignore`). Those are per-machine, and
  reading them would make a rule answer differently on two machines from the same commit, which is the
  one thing this may not do.
"""
function ignored(root::AbstractString)
    # Every `.gitignore` under the root, not only the one at it: a package may ignore build output from
    # the directory that holds it, and GBGIsotropicTurbulence ignores 129 files that way. A deeper file
    # overrides a shallower one, and within one file the last matching line wins, as git decides it.
    levels = Tuple{String,Vector{Tuple{Regex,Bool}}}[]
    for (dir, _, fs) in walkdir(root)
        rel = relpath(dir, root)
        startswith(rel, ".git") && continue
        ".gitignore" in fs || continue
        prefix = rel == "." ? "" : replace(rel, '\\' => '/') * "/"
        push!(levels, (prefix, gitignore_rules(joinpath(dir, ".gitignore"))))
    end
    isempty(levels) && return _ -> false
    sort!(levels; by = first)
    return function (f::AbstractString)
        hit = false
        for (prefix, rules) in levels
            startswith(f, prefix) || continue
            rest = f[nextind(f, 0, length(prefix) + 1):end]
            for (rx, negated) in rules
                occursin(rx, rest) && (hit = !negated)
            end
        end
        return hit
    end
end

"""
    gitignore_rules(path) -> Vector{Tuple{Regex,Bool}}

The lines of one `.gitignore` as patterns, each with whether it re-includes rather than excludes. The
argument is `path`, the file to read. Returns them in file order, since the last match decides.
"""
gitignore_rules(path::AbstractString) = gitignore_rules_of(isfile(path) ? read(path, String) : "")

"""
    gitignore_rules_of(text) -> Vector{Tuple{Regex,Bool}}

The same, from the text of a `.gitignore` rather than its path, so the pattern grammar can be tested
without a directory. The argument is `text`, the file's content. Returns the rules in file order.
"""
function gitignore_rules_of(text::AbstractString)
    rules = Tuple{Regex,Bool}[]
    for raw in split(text, '\n')
        line = strip(raw)
        (isempty(line) || startswith(line, "#")) && continue
        negated = startswith(line, "!")
        negated && (line = line[2:end])
        isdir_only = endswith(line, "/")
        # Anchoring is decided BEFORE the leading slash is stripped. `!/Manifest.toml` anchors to the
        # root; read after stripping it looks unanchored, and the negation then re-includes the file at
        # every depth — which is exactly what GBGIsotropicTurbulence's `Manifest.toml` / `!/Manifest.toml`
        # pair is written to prevent.
        anchored = startswith(line, "/") || occursin('/', strip(line, '/'))
        line = strip(line, '/')
        isempty(line) && continue
        # `**` is held aside as a sentinel while `*` is rewritten, or the first pass would eat it.
        body = replace(line, "." => "\\.", "**" => "\0", "*" => "[^/]*", "?" => "[^/]")
        body = replace(body, "\0" => ".*")
        # A directory matches everything under it; an unanchored pattern matches at any depth.
        tail = isdir_only ? "/.*" : "(?:/.*)?"
        push!(rules, (Regex("^" * (anchored ? "" : "(?:.*/)?") * body * tail * "\$"), negated))
    end
    return rules
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
function run_rule(rule::Model.Rule, cfg::Model.Config, root::AbstractString; network::Bool = false,
                  pkg = nothing, site = nothing)
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
function run_all(cfg::Model.Config, root::AbstractString; intention = nothing, network::Bool = false,
                 pkg = nothing, site = nothing)
    out = Model.Location[]
    for rule in Catalogue.RULES
        intention === nothing || rule.intention === intention || continue
        append!(out, run_rule(rule, cfg, root; network, pkg, site))
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
