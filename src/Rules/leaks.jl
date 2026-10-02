# The design's §3.1; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Rules.Leaks

The `RULE.LEAK.*` rules: what a package may not publish when its repository is made public. Only
`gbg leak` runs them, over every commit on every branch and tag, its metadata, and on a flag the GitHub
side; no build, test or hook does. Each rule's pattern has one home, here: [`patterns`](@ref) renders
it into Gitleaks' configuration, and the rule's own check applies the same pattern to a text.

A finding never carries what it matched: a printed finding enters what a session sends to its model.
"""
module Leaks

using ...Model

# Each pattern is written once, in the subset of regular expressions Julia's PCRE and Gitleaks' RE2 read
# alike: no look-around, no back-reference.
const HOME = raw"(?:/home/|/Users/)[A-Za-z0-9._-]+/|[A-Za-z]:\\Users\\[A-Za-z0-9._-]+"
const SYNCED = raw"(?i)(?:Dropbox|OneDrive|Google Drive|iCloud Drive|Nextcloud)/"
const SESSION = raw"(?i)claude\.ai/(?:code/)?(?:session|chat|share)[_/][A-Za-z0-9_-]+"
const SCRATCH = raw"/tmp/claude-[0-9]+"
const EMAIL = raw"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}"
const MANIFEST_FILE = raw"(?:^|/)(?:Julia)?(?:Manifest|Project)(?:-v[0-9.]+)?\.toml$"
const MANIFEST_ABSOLUTE = raw"path\s*=\s*\"(?:/|[A-Za-z]:)"
const NEVER_FILE = raw"(?i)(?:^|/)(?:\.env(?:\.[A-Za-z0-9]+)?|\.netrc|\.pypirc|id_(?:rsa|dsa|ecdsa|ed25519)|credentials(?:\.[A-Za-z]+)?|settings\.local\.json|[^/]+\.(?:pem|key|p12|pfx|keystore|jsonl))$"

# Addresses that are public by design: GitHub's no-reply addresses and git's own SSH user, and the
# address of the commit trailer RULE.GIT.TRAILER requires on every commit.
const PUBLIC_EMAILS = [raw"(?i)^[A-Za-z0-9._%+-]+@users\.noreply\.github\.com$", raw"(?i)^noreply@github\.com$",
                       raw"(?i)^git@github\.com$", raw"(?i)^noreply@anthropic\.com$"]

escape_regex(s) = replace(s, r"[.^$|?*+()\[\]{}\\]" => x -> "\\" * x)

"""
    allowed_emails(cfg) -> Vector{String}

The patterns of every address that may be published: those public by design, and those the package's
config approves in `leak_emails`. The argument is `cfg`. Returns the patterns, anchored.
"""
allowed_emails(cfg) = vcat(PUBLIC_EMAILS, ["(?i)^" * escape_regex(e) * "\$" for e in cfg.leak_emails])

"""
    term_pattern(cfg) -> Union{String,Nothing}

The pattern of the words the package's config names in `leak_terms`, whole words in any case, or
`nothing` where it names none. The argument is `cfg`.
"""
term_pattern(cfg) = isempty(cfg.leak_terms) ? nothing :
    "(?i)\\b(?:" * join(escape_regex.(cfg.leak_terms), "|") * ")\\b"

"""
    patterns(cfg) -> Vector{NamedTuple}

Every pattern of the rules here, as Gitleaks reads one: `(id, regex, path, allow)` — the rule's id, the
pattern of the text, the pattern of the file's path (empty for any file), and the patterns of a match
that is allowed. The argument is `cfg`, the package's config. Returns them; a rule with nothing to look
for in this package is left out.
"""
function patterns(cfg)
    out = [(id = "RULE.LEAK.HOME_PATH", regex = HOME, path = "", allow = String[]),
           (id = "RULE.LEAK.SYNCED_PATH", regex = SYNCED, path = "", allow = String[]),
           (id = "RULE.LEAK.SESSION_LINK", regex = SESSION, path = "", allow = String[]),
           (id = "RULE.LEAK.SCRATCH_PATH", regex = SCRATCH, path = "", allow = String[]),
           (id = "RULE.LEAK.EMAIL", regex = EMAIL, path = "", allow = allowed_emails(cfg)),
           (id = "RULE.LEAK.MANIFEST_PATH", regex = MANIFEST_ABSOLUTE, path = MANIFEST_FILE, allow = String[]),
           (id = "RULE.LEAK.NEVER_PUBLISHED", regex = "", path = NEVER_FILE, allow = String[])]
    t = term_pattern(cfg)
    t === nothing || push!(out, (id = "RULE.LEAK.TERM", regex = t, path = "", allow = String[]))
    return out
end

# A text's lines that hold a match no allowed pattern covers, as locations naming the rule's subject and
# never the match.
function matches(text, regex, allow, subject)
    out = Model.Location[]
    re = Regex(regex)
    keep = [Regex(a) for a in allow]
    for (i, line) in enumerate(split(text, '\n'))
        any(m -> !any(k -> occursin(k, m.match), keep), eachmatch(re, line)) || continue
        push!(out, Model.Location(; file = "", line = i, text = subject))
    end
    return out
end

text_check(id, subject) = Model.ProgramCheck(Model.Input.PUBLICATION, function (text, cfg)
    p = only(x for x in patterns(cfg) if x.id == id)
    return matches(text, p.regex, p.allow, subject)
end, false)

const WHY_HISTORY = "A repository made public publishes every commit it ever held, on every branch and tag, deleted files included; a later commit that removes a thing does not unpublish it."

const CREDENTIAL = Model.Rule(
    id = Symbol("RULE.LEAK.CREDENTIAL"),
    statement = "No credential — a token, a key, a password, a connection string with one in it — is in any commit of a package that is to be published, in a commit's metadata, or on its GitHub side.",
    why = WHY_HISTORY * " A credential found must be revoked, not only removed.",
    intention = Model.Intention.PUBLICATION,
    filesets = [Model.FileSet.CODE],
    unchecked_reason = "an instruction to the session, never to commit one; `gbg leak` decides it with Gitleaks' own credential rules, over every commit, the commit metadata and the GitHub side, which no program here restates")

const HOME_PATH = Model.Rule(
    id = Symbol("RULE.LEAK.HOME_PATH"),
    statement = "No home-directory path — `/home/<name>/`, `/Users/<name>/`, `C:\\Users\\<name>` — is published.",
    why = WHY_HISTORY * " A home path names the person and the machine, and a credential scanner allows it on purpose.",
    intention = Model.Intention.PUBLICATION,
    filesets = [Model.FileSet.CODE],
    check = text_check("RULE.LEAK.HOME_PATH", "a home-directory path"),
    examples = [
        Model.TextExample(Model.FileSet.CODE, "The checkout is at /home/someone/work/pkg.\n",
                          [Model.Location(; file = "", line = 1)], "no home-directory path"),
        Model.TextExample(Model.FileSet.CODE, "The checkout is at `~/work/pkg`, or under /home in general.\n",
                          Model.Location[], "no home-directory path"),
    ])

const SYNCED_PATH = Model.Rule(
    id = Symbol("RULE.LEAK.SYNCED_PATH"),
    statement = "No path inside a synced folder — Dropbox, OneDrive, Google Drive, iCloud Drive, Nextcloud — is published.",
    why = WHY_HISTORY * " A synced folder's path tells where the owner keeps his work, and which service holds it.",
    intention = Model.Intention.PUBLICATION,
    filesets = [Model.FileSet.CODE],
    check = text_check("RULE.LEAK.SYNCED_PATH", "a path inside a synced folder"),
    examples = [
        Model.TextExample(Model.FileSet.CODE, "Kept in Dropbox/Research/pkg.\n",
                          [Model.Location(; file = "", line = 1)], "no path inside a synced folder"),
        Model.TextExample(Model.FileSet.CODE, "Do not keep scratch in a synced folder such as Dropbox.\n",
                          Model.Location[], "no path inside a synced folder"),
    ])

const SESSION_LINK = Model.Rule(
    id = Symbol("RULE.LEAK.SESSION_LINK"),
    statement = "No link to an assistant's session is published.",
    why = WHY_HISTORY * " A session link opens a conversation that was never meant to be public, with whatever it held.",
    intention = Model.Intention.PUBLICATION,
    filesets = [Model.FileSet.CODE],
    check = text_check("RULE.LEAK.SESSION_LINK", "a link to an assistant's session"),
    examples = [
        Model.TextExample(Model.FileSet.CODE, "Claude-Session: https://claude.ai/code/session_01ABCdef\n",
                          [Model.Location(; file = "", line = 1)], "no link to an assistant's session"),
        Model.TextExample(Model.FileSet.CODE, "Written with Claude Code, https://claude.com/claude-code\n",
                          Model.Location[], "no link to an assistant's session"),
    ])

const SCRATCH_PATH = Model.Rule(
    id = Symbol("RULE.LEAK.SCRATCH_PATH"),
    statement = "No path into an assistant's scratch directory, `/tmp/claude-<uid>/…`, is published.",
    why = WHY_HISTORY * " A scratch path carries the user's id and the name of the session's project, and points at nothing a reader can open.",
    intention = Model.Intention.PUBLICATION,
    filesets = [Model.FileSet.CODE],
    check = text_check("RULE.LEAK.SCRATCH_PATH", "a path into an assistant's scratch directory"),
    examples = [
        Model.TextExample(Model.FileSet.CODE, "S=/tmp/claude-1000/project/scratchpad\n",
                          [Model.Location(; file = "", line = 1)], "no path into an assistant's scratch directory"),
        Model.TextExample(Model.FileSet.CODE, "Scratch goes to a system temporary directory, mktempdir().\n",
                          Model.Location[], "no path into an assistant's scratch directory"),
    ])

const EMAIL_RULE = Model.Rule(
    id = Symbol("RULE.LEAK.EMAIL"),
    statement = "No email address is published but those the package's config approves in `leak_emails`, GitHub's no-reply addresses, and the commit trailer's.",
    why = WHY_HISTORY * " An address in a commit's author field is published with the commit; only a rewrite of the history removes it, which is the owner's to make.",
    intention = Model.Intention.PUBLICATION,
    filesets = [Model.FileSet.CODE],
    check = text_check("RULE.LEAK.EMAIL", "an email address not approved for publication"),
    examples = [
        # The examples' config approves owner@example.org (test/rules.jl).
        Model.TextExample(Model.FileSet.CODE, "Write to someone@private.example for access.\n",
                          [Model.Location(; file = "", line = 1)], "but those the package's config approves"),
        Model.TextExample(Model.FileSet.CODE, "Write to owner@example.org; 12345+someone@users.noreply.github.com committed it.\n",
                          Model.Location[], "but those the package's config approves"),
        Model.TextExample(Model.FileSet.CODE, "Co-Authored-By: Anthropic Claude <noreply@anthropic.com>\n",
                          Model.Location[], "but those the package's config approves"),
    ])

const TERM = Model.Rule(
    id = Symbol("RULE.LEAK.TERM"),
    statement = "No word the package's config names in `leak_terms` — the machines' names, or anything else the owner keeps private — is published, in any case.",
    why = WHY_HISTORY * " What is private to one owner no generic scanner knows; the config says it once.",
    intention = Model.Intention.PUBLICATION,
    filesets = [Model.FileSet.CODE],
    check = text_check("RULE.LEAK.TERM", "a word the config keeps private"),
    examples = [
        # The examples' config names the term Examplehost (test/rules.jl).
        Model.TextExample(Model.FileSet.CODE, "Benchmarked on examplehost, the home workstation.\n",
                          [Model.Location(; file = "", line = 1)], "no word the package's config names"),
        Model.TextExample(Model.FileSet.CODE, "Benchmarked on an Examplehostile machine.\n",
                          Model.Location[], "no word the package's config names"),
    ])

const MANIFEST_PATH = Model.Rule(
    id = Symbol("RULE.LEAK.MANIFEST_PATH"),
    statement = "No `Manifest.toml` or `Project.toml` in any commit names an absolute path.",
    why = WHY_HISTORY * " `RULE.GIT.LOCAL_PATH` holds the tree as it is; a path committed once and removed since is still in the history.",
    intention = Model.Intention.PUBLICATION,
    filesets = [Model.FileSet.CODE],
    check = text_check("RULE.LEAK.MANIFEST_PATH", "an absolute path in a manifest"),
    examples = [
        Model.TextExample(Model.FileSet.CODE, "[[deps.X]]\npath = \"/somewhere/X\"\n",
                          [Model.Location(; file = "", line = 2)], "names an absolute path"),
        Model.TextExample(Model.FileSet.CODE, "[sources]\nX = {path = \"..\"}\n",
                          Model.Location[], "names an absolute path"),
    ])

const NEVER_PUBLISHED = Model.Rule(
    id = Symbol("RULE.LEAK.NEVER_PUBLISHED"),
    statement = "No file that is never published — an environment file, a private key or certificate, a credentials file, a session transcript, a local settings file — is in any commit.",
    why = WHY_HISTORY * " Such a file is judged by its name and kind, whatever it holds: its holding nothing today says nothing of the commit that held something.",
    intention = Model.Intention.PUBLICATION,
    filesets = [Model.FileSet.CODE],
    # Read as one path per line: what the check is about is the file's name, not its text.
    check = Model.ProgramCheck(Model.Input.PUBLICATION,
        (text, cfg) -> [Model.Location(; file = "", line = i, text = "a file that is never published")
                        for (i, l) in enumerate(split(text, '\n')) if occursin(Regex(NEVER_FILE), strip(l))], false),
    examples = [
        Model.TextExample(Model.FileSet.CODE, "src/Pkg.jl\n.env\ndeploy/id_ed25519\n",
                          [Model.Location(; file = "", line = 2), Model.Location(; file = "", line = 3)], "no file that is never published"),
        Model.TextExample(Model.FileSet.CODE, "src/Pkg.jl\ndocs/environment.md\nsrc/keys.jl\n",
                          Model.Location[], "no file that is never published"),
    ])

"""
    RULES

The rules of this family.
"""
const RULES = Model.Rule[CREDENTIAL, HOME_PATH, SYNCED_PATH, SESSION_LINK, SCRATCH_PATH, EMAIL_RULE, TERM,
                         MANIFEST_PATH, NEVER_PUBLISHED]

end # module Leaks
