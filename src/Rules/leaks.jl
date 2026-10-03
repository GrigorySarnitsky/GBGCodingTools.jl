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
# The review of 2026-10-02 widened each: a home path needs no trailing slash and may be escaped; a synced
# folder may be a team's or a business account's, and is written with a capital, so `github.com/dropbox`
# is not one; any assistant's shared session counts.
const HOME = raw"(?:/home/|/Users/)[A-Za-z0-9._-]+|[A-Za-z]:\\{1,2}Users\\{1,2}[A-Za-z0-9._-]+"
const SYNCED = raw"(?:Dropbox(?: \([^)/\\]*\))?|OneDrive(?: - [^/\\]+|-[^/\\]+)?|Google Drive|GoogleDrive-[^/\\]+|iCloud Drive|Nextcloud)[/\\]"
const SESSION = raw"(?i)(?:claude\.ai/(?:code/)?(?:session|chat|share)[_/]|chatgpt\.com/(?:share|c)/|chat\.openai\.com/(?:share|c)/|gemini\.google\.com/(?:share|app)/)[A-Za-z0-9_-]+"
const SCRATCH = raw"/tmp/claude-[0-9]+"
const EMAIL = raw"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}"
const MANIFEST_FILE = raw"(?:^|/)(?:Julia)?(?:Manifest|Project)(?:-v[0-9.]+)?\.toml$"
const MANIFEST_ABSOLUTE = raw"path\s*=\s*[\"'](?:/|[A-Za-z]:)"
# Read by this package alone, over every path any commit held — binary files and renames among them,
# which a scan of patches misses — so it may use look-ahead: a committed template is not a secret.
const NEVER_FILE = raw"(?i)(?:^|/)(?:\.env(?!\.(?:example|sample|template)$)(?:rc|\.[^/]+)?|\.git-credentials|\.netrc|\.pypirc|\.npmrc|id_(?:rsa|dsa|ecdsa|ed25519)|credentials(?:\.(?:json|ya?ml|toml|xml|csv|txt|ini))?|settings\.local\.json|[^/]+\.(?:pem|key|p12|pfx|keystore|jks|jsonl))$"

# Addresses that are public by design: GitHub's no-reply addresses and git's own SSH user, and the
# address of the commit trailer RULE.GIT.TRAILER requires on every commit.
# GitHub's own service addresses — the bots of every workflow log — are on the same footing (measured on
# this package's 1013 workflow logs, 2026-10-02: every address in them was at github.com).
const PUBLIC_EMAILS = [raw"(?i)^[A-Za-z0-9._%+-]+@users\.noreply\.github\.com$", raw"(?i)^[A-Za-z0-9._%+-]+@github\.com$",
                       raw"(?i)^noreply@anthropic\.com$"]

# The home of GitHub's hosted runners, on Linux, macOS and Windows: public, and in every workflow log
# (39,299 of this package's findings before it was allowed, 2026-10-02).
const RUNNER_HOMES = [raw"^/home/runner$", raw"^/Users/runner$", raw"(?i)^[A-Za-z]:\\{1,2}Users\\{1,2}runneradmin$"]
# A domain reserved for documentation (RFC 2606, RFC 6761) belongs to no one, so no address in it is
# personal; the three left in this package's records after its first scan were all such (2026-10-03).
const RESERVED_DOMAIN = raw"(?i)@(?:[A-Za-z0-9-]+\.)*(?:example\.(?:com|org|net)|example|invalid|test|localhost)$"
# A retina image's name, `logo@2x.png`, has an address's shape and is not one.
const IMAGE_NAME = raw"(?i)@[0-9]+x\.(?:png|jpe?g|gif|svg|webp)$"

escape_regex(s) = replace(s, r"[.^$|?*+()\[\]{}\\]" => x -> "\\" * x)

"""
    allowed_emails(cfg) -> Vector{String}

The patterns of every address that may be published: those public by design, and those the package's
config approves in `leak_emails`. The argument is `cfg`. Returns the patterns, anchored.
"""
allowed_emails(cfg) = vcat(PUBLIC_EMAILS, [IMAGE_NAME, RESERVED_DOMAIN], ["(?i)^" * escape_regex(e) * "\$" for e in cfg.leak_emails])

"""
    term_pattern(cfg) -> Union{String,Nothing}

The pattern of the words the package's config names in `leak_terms`, whole words in any case, or
`nothing` where it names none. The argument is `cfg`.
"""
# Bounded by any character that is not a letter or a digit, not by `\b`: RE2's `\b` is ASCII and found no
# term with a letter like Ö at its edge, and both engines took `_` for a letter, missing `host_bench`.
term_pattern(cfg) = isempty(cfg.leak_terms) ? nothing :
    "(?i)(?:^|[^\\p{L}\\p{N}])(?:" * join(escape_regex.(cfg.leak_terms), "|") * ")(?:[^\\p{L}\\p{N}]|\$)"

"""
    patterns(cfg) -> Vector{NamedTuple}

Every pattern of the rules here, as Gitleaks reads one: `(id, regex, path, allow)` — the rule's id, the
pattern of the text, the pattern of the file's path (empty for any file), and the patterns of a match
that is allowed. The argument is `cfg`, the package's config. Returns them; a rule with nothing to look
for in this package is left out.
"""
function patterns(cfg)
    out = [(id = "RULE.LEAK.HOME_PATH", regex = HOME, path = "", allow = RUNNER_HOMES),
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

"""
    BLOCKING

The rules whose findings must be fixed, never accepted: a credential, which is revoked and then removed,
and a file never published. Every other rule's finding is a note — a path, a word, an address, a link —
which the owner may accept where only the history holds it (ruled 2026-10-02: a machine's name in the
history is no threat; a credential anywhere is).
"""
const BLOCKING = Set([Symbol("RULE.LEAK.CREDENTIAL"), Symbol("RULE.LEAK.NEVER_PUBLISHED")])

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
    statement = "No home-directory path — `/home/<name>/`, `/Users/<name>/`, `C:\\Users\\<name>` — is published, but a hosted runner's.",
    why = WHY_HISTORY * " A home path names the person and the machine, and a credential scanner allows it on purpose.",
    intention = Model.Intention.PUBLICATION,
    filesets = [Model.FileSet.CODE],
    check = text_check("RULE.LEAK.HOME_PATH", "a home-directory path"),
    examples = [
        Model.TextExample(Model.FileSet.CODE, "The checkout is at /home/someone/work/pkg.\n",
                          [Model.Location(; file = "", line = 1)], "no home-directory path"),
        Model.TextExample(Model.FileSet.CODE, "The checkout is at `~/work/pkg`, or under /home in general.\n",
                          Model.Location[], "no home-directory path"),
        # a hosted runner's home is GitHub's, in every workflow log
        Model.TextExample(Model.FileSet.CODE, "Run julia-actions in /home/runner/work/pkg/pkg\n",
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
    statement = "No email address is published but those the package's config approves in `leak_emails`, GitHub's own and no-reply addresses, the commit trailer's, and those in a domain reserved for documentation.",
    why = WHY_HISTORY * " An address in a commit's author field is published with the commit; only a rewrite of the history removes it, which is the owner's to make.",
    intention = Model.Intention.PUBLICATION,
    filesets = [Model.FileSet.CODE],
    check = text_check("RULE.LEAK.EMAIL", "an email address not approved for publication"),
    examples = [
        # The examples' config approves owner@mailbox.zz (test/rules.jl); `.zz` is assigned to no country.
        Model.TextExample(Model.FileSet.CODE, "Write to someone@mailbox.zz for access.\n",
                          [Model.Location(; file = "", line = 1)], "but those the package's config approves"),
        Model.TextExample(Model.FileSet.CODE, "Write to owner@mailbox.zz; 12345+someone@users.noreply.github.com committed it, user@example.com is a placeholder.\n",
                          Model.Location[], "but those the package's config approves"),
        Model.TextExample(Model.FileSet.CODE, "Co-Authored-By: Anthropic Claude <noreply@anthropic.com>\n",
                          Model.Location[], "but those the package's config approves"),
    ])

const TERM = Model.Rule(
    id = Symbol("RULE.LEAK.TERM"),
    statement = "No word this machine's `~/.gbg/leak-terms` lists — the machines' names, or anything else the owner keeps private — is published, in any case.",
    why = WHY_HISTORY * " What is private to one owner no generic scanner knows, and a list of it committed with a package would publish it: it is kept per machine, outside every repository.",
    intention = Model.Intention.PUBLICATION,
    filesets = [Model.FileSet.CODE],
    check = text_check("RULE.LEAK.TERM", "a word the config keeps private"),
    examples = [
        # The examples' config names the term Examplehost (test/rules.jl).
        Model.TextExample(Model.FileSet.CODE, "Benchmarked on examplehost, the home workstation.\n",
                          [Model.Location(; file = "", line = 1)], "no word this machine's `~/.gbg/leak-terms` lists"),
        Model.TextExample(Model.FileSet.CODE, "Benchmarked on an Examplehostile machine.\n",
                          Model.Location[], "no word this machine's `~/.gbg/leak-terms` lists"),
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
