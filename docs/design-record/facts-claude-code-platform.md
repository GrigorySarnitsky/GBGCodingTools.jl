
!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

Based on the fetched documentation and the embedded reference in your system context, here are the precise, current facts about Claude Code's sharing mechanisms:

---

## 1. **PLUGINS: Manifest Layout & Capabilities**

**Structure:**
```
my-plugin/
├── .claude-plugin/plugin.json
├── skills/
│   └── <name>/SKILL.md
├── commands/
│   └── <name>.md  (legacy; use skills/ for new plugins)
├── agents/
│   └── <name>.md
├── hooks/
│   └── hooks.json
├── .mcp.json
├── .lsp.json
├── monitors/monitors.json
├── settings.json
└── bin/
```

**plugin.json fields:**
```json
{
  "name": "unique-identifier",
  "description": "Shown in plugin manager",
  "version": "1.0.0",
  "author": { "name": "Author Name" },
  "homepage": "https://...",
  "repository": "https://...",
  "license": "MIT"
}
```

**Skill/Command Invocation Namespacing:**
- Plugin skills: `/plugin-name:skill-name`
- Standalone/project skills: `/skill-name`
- `name` field in `plugin.json` becomes the namespace prefix

**`${CLAUDE_PLUGIN_ROOT}` Variable:**
- Resolves to the plugin's root directory
- **Usable in:** hook command paths, MCP server references, monitor commands
- **NOT directly usable in:** skill/command bodies (use as file path reference only)
- Set as an environment variable when the plugin is loaded

**Agents in Plugins:**
- Plugins ship `agents/*.md` files with full subagent frontmatter (model, tools, description, permissionMode, etc.)
- Invoked as `@plugin-name:agent-name` or automatically by Claude if the description matches
- **Plugin agents are scoped to the plugin namespace**

**Hooks in Plugins:**
- Plugins ship `hooks/hooks.json` with the same schema as project/user hooks
- **Fires when the plugin is enabled** across all sessions
- Receives same JSON input as regular hooks
- Can use `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` in commands

**Workflows in Plugins:**
- **NOT directly supported.** Plugins cannot ship saved workflow scripts (`.claude/workflows/`).
- Workaround: scripts live in the plugin's `bin/` directory and are added to `$PATH` when the plugin is enabled.

---

## 2. **MARKETPLACES & INSTALL**

**marketplace.json Layout:**
```json
{
  "name": "my-marketplace",
  "owner": { "name": "Your Name", "email": "email@example.com" },
  "plugins": [
    {
      "name": "plugin-name",
      "source": "./plugins/plugin-name",
      "description": "...",
      "version": "1.0.0",
      "defaultEnabled": false
    }
  ],
  "renames": {
    "old-name": "new-name",
    "deprecated": null
  }
}
```

**Plugin Sources (in marketplace):**
- **Local path:** `"source": "./plugins/my-plugin"`
- **GitHub:** `"source": { "source": "github", "repo": "owner/repo", "ref": "v1.0.0", "sha": "..." }`
- **Git URL:** `"source": { "source": "url", "url": "https://gitlab.com/org/plugin.git", "ref": "main" }`
- **npm package:** `"source": { "source": "npm", "package": "@org/plugin", "version": "1.0.0" }`
- **Zip archive:** `"source": { "source": "archive", "url": "https://...", "sha256": "..." }`

**CLI Commands:**
```bash
# Install from marketplace (add marketplace first if not registered)
claude plugin marketplace add owner/repo      # GitHub
claude plugin marketplace add https://gitlab.com/org/plugins.git
claude plugin install plugin-name@marketplace-name

# Update all plugins in a marketplace
claude plugin marketplace update marketplace-name

# List installed plugins
claude plugin list --json
```

**Versioning & Updates:**
- Plugins with explicit `version` in manifest: **users only get updates when you bump the version**
- Plugins without `version`: fallback to git commit SHA for versioning
- **No per-project or per-user pinning** in current documentation; pinning is at the session level only via `--plugin-dir` or `--plugin-url`
- Updates propagate manually via `claude plugin marketplace update` or automatically on next session startup (for GitHub sources with credentials)

**Where Plugins Are Recorded:**
- **`~/.claude/settings.json`** (user scope): `"enabledPlugins": { "plugin-name": true/false }`
- **`.claude/settings.json`** (project scope): same key for project-level defaults
- **`.claude/settings.local.json`** (local/machine scope): personal overrides
- **No automatic requirement:** a project's `.claude/settings.json` can pre-enable a plugin, but only works if it's already installed; there's no "lock file" or manifest to auto-install on fresh clone

**Private Repository Hosting:**
- Host marketplace in a private GitHub/GitLab repo
- Use git credential helpers or tokens in git config for background auto-updates
- Share marketplace URL with team via `/plugin marketplace add`

---

## 3. **SKILLS vs COMMANDS: Current State**

**Skill File Format (`SKILL.md`):**
```yaml
---
name: skill-invocation-name        # Optional; defaults to folder name
description: What this skill does. Use when...
disable-model-invocation: true     # Manual-only if true
user-invocable: false              # Hidden from /menu if false
allowed-tools: Bash(git *) Read Edit
arguments: [issue, branch]         # Named positional args
context: fork                      # Run in isolated subagent
agent: Explore                     # Subagent to use (Explore/Plan/general-purpose or custom)
background: false                  # Wait for result (true = concurrent)
paths:
  - "src/**/*.ts"                 # Trigger only for matching files
---

Instructions for Claude...
Use $ARGUMENTS or $0, $1, $issue, $branch
```

**Commands vs Skills:**
- `commands/` (legacy): flat `.md` files, no subdirectories
- `skills/` (current standard): `<name>/SKILL.md` folder structure
- **Functionally identical** for basic use; `skills/` supports subdirectory organization
- New plugins should use `skills/`

**Skill Invocation (Subagent):**
- `context: fork` isolates the skill in its own context window with no conversation history
- The subagent can be specified: `agent: Explore` (read-only), `agent: Plan`, or a custom agent name from `.claude/agents/`
- `background: false` blocks the main conversation; `true` (default) runs concurrently

**Dynamic Context Injection:**
```markdown
Current changes:
!`git diff HEAD`

Or multi-line:
```!
git status
node --version
```
```
Commands run once; output is inserted as plain text (not re-scanned).

---

## 4. **CLAUDE.md IMPORTS: `@path` Syntax**

**Syntax:**
```markdown
See @README for overview and @../shared/conventions.md for team standards.
@~/.claude/my-global-rules.md
```

**Path Resolution:**
- **Relative paths:** resolved relative to the file containing the import (not the working directory)
- **Home `~` paths:** resolved to user home directory (e.g., `@~/.claude/shared.md`)
- **Absolute paths:** supported (e.g., `@/etc/claude-code/standards.md`)
- **Maximum nesting depth:** 4 hops (can import files that import other files)
- **Backticks prevent import:** `` `@README` `` keeps the text literal

**Scope:**
- **CLAUDE.md:** ✅ Fully supported
- **CLAUDE.local.md:** ✅ Fully supported
- **.claude/rules/*.md:** ✅ Fully supported
- **Plugin agent/skill frontmatter:** ❌ NOT supported (no imports in YAML)

**External Imports Security:**
- Imports that resolve outside the working directory (e.g., from `~/.claude/`) show an approval dialog on first load
- User-scope files (`~/.claude/CLAUDE.md`) load imports without dialog (you wrote them)
- Subsequent sessions skip the dialog; you can re-enable it with `/permissions`

---

## 5. **HOOKS: Events, Schema & Capabilities**

**Hook Events Available:**
```
Per-session:   SessionStart, SessionEnd
Per-turn:      UserPromptSubmit, Stop, StopFailure
Per tool call: PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest
File events:   FileChanged, ConfigChange, CwdChanged
Other:         Notification, SubagentStart, SubagentStop, etc.
```

**Configuration Schema (in any settings file):**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/script.sh",
            "args": [],
            "timeout": 30,
            "async": false
          }
        ]
      }
    ]
  },
  "disableAllHooks": false,
  "allowedHttpHookUrls": ["https://example.com/hooks/*"],
  "httpHookAllowedEnvVars": ["MY_TOKEN"]
}
```

**Hook Handler Types:**
1. **command:** Shell script, receives JSON on stdin, outputs JSON
2. **http:** POST JSON to endpoint, optional headers with env var interpolation
3. **mcp_tool:** Call tool on connected MCP server
4. **prompt:** Send evaluation prompt to Claude
5. **agent:** Spawn a subagent (experimental)

**Hooks in Plugins:**
- ✅ Plugins ship `hooks/hooks.json` at the plugin root (not in `.claude-plugin/`)
- **Fires when the plugin is enabled** across all sessions
- Can reference `${CLAUDE_PLUGIN_ROOT}` in command paths
- Uses same schema as project/user hooks

**SessionStart Hook & Context Injection:**
- `SessionStart` fires once when a session begins
- Can output JSON with `"systemMessage": "..."` to inject context
- No built-in "append to system prompt" mechanism; use `--append-system-prompt` flag instead
- Alternative: return `"additionalContext": "..."` to add context to the first turn

**Disabling:**
```bash
claude -p --settings '{"disableAllHooks": true}' "query"
```

---

## 6. **`claude plugin eval` & `/skill-doctor`**

**`claude plugin eval` — Current Status:**
- ✅ **`/skill-doctor`** is **generally available** in current releases — in-session skill usage report (cost, 7-day token/use, never-invoked warnings)
- ❌ **`claude plugin eval`** is **early access** (enabled per organization, not yet public docs)
  - When not enabled: prints "plugin eval is currently in early access" and exits 1
  - When enabled: runs eval suite in fresh isolated sessions, tests plugins, scores results
  - **Eval suite format** (from embedded reference): cases live under `evals/` → `<case>/prompt.md` + `evals/<case>/graders/*.md`
  - Frontmatter in `prompt.md`: `name`, `tags`, `plugins`, `runs`, `max_turns`, `timeout_seconds`, `allowed_tools`, `model`
  - Grader types: `regex`, `tool_used`, `tool_order`, `file_exists`, `llm`, `baseline`

**For shipped tooling, use `/skill-doctor`:**
```bash
/skill-doctor   # Opens stats tab (interactive) or prints report (non-interactive sessions)
```

---

## 7. **SUBAGENT ORCHESTRATION from Scripts**

**Non-Interactive Agent Tool (Claude API, not Claude Code CLI):**

There is **no supported Claude Code CLI flag for running a subagent non-interactively.** The documented path for scripted orchestration is the **Claude API's Managed Agents** (server-hosted; start sessions, SSE stream), not the Claude Code CLI.

**Claude Code CLI Non-Interactive Flags (for direct model queries, not subagent delegation):**
```bash
claude -p "prompt" \
  --model sonnet \
  --output-format json \
  --allowed-tools "Bash(git *)" "Read" "Glob" \
  --append-system-prompt "Custom instructions..." \
  --max-turns 3 \
  --permission-prompts none
```

**For Node/Python script orchestration, documented approach:**
1. Use the **Claude API SDK** (Python `anthropic` or Node.js `@anthropic-ai/sdk`)
2. If you need agent loop with tools: **Tool Runner** (`client.beta.messages.tool_runner`) or **Managed Agents** (if hosted deployment is acceptable)
3. **NOT** the Claude Code CLI for programmatic orchestration

**Custom Agent via CLI is not supported programmatically; agents are invoked interactively or via `--agent` flag at session start:**
```bash
claude --agent my-custom-agent -p "query"   # Runs query with agent as main session agent
```

---

## 8. **ADDITIONAL RELEVANT SETTINGS & ENVIRONMENT**

**settings.json Keys (Project/User/Local Scope):**
```json
{
  "model": "sonnet",
  "enabledPlugins": { "plugin-name": true },
  "permissions": {
    "allow": ["Bash(git *)", "Read"],
    "deny": ["Bash(rm *)"],
    "additionalDirectories": ["/shared/data"]
  },
  "hooks": { /* ... */ },
  "autoMemoryEnabled": true,
  "autoMemoryDirectory": "~/custom-memory-path",
  "disableBundledSkills": false,
  "pluginConfigs": { "plugin-name": { /* config */ } },
  "claudeMdExcludes": ["**/monorepo/CLAUDE.md"],
  "allowedHttpHookUrls": ["https://..."],
  "agent": "security-reviewer"  /* plugin settings.json only */
}
```

**`.claude/settings.local.json` Semantics:**
- Machine-local, **not synced** (add to `.gitignore`)
- Merged on top of project `.claude/settings.json`
- Overrides project settings without removing them
- Useful for personal sandbox URLs, test credentials, local paths

**Environment Variables:**
```bash
CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1  # Load CLAUDE.md from --add-dir
CLAUDE_CODE_PROJECT_DIR_NAME=custom-name        # Override project dir in memory
CLAUDE_CODE_DISABLE_AUTO_MEMORY=1               # Disable auto memory for session
CLAUDE_CONFIG_DIR=/custom/path                  # Override ~/.claude location
```

**`additionalDirectories` (in permissions):**
```json
{
  "permissions": {
    "additionalDirectories": [
      "/home/user/shared-data",
      "/mnt/external/project"
    ]
  }
}
```

---

## Summary: What's Unsupported or Unclear

| Feature | Status | Note |
|---------|--------|------|
| Plugins ship workflows | ❌ Unsupported | Use `bin/` scripts instead |
| Per-project plugin pinning | ❌ Unsupported | Only session-level via `--plugin-dir` |
| Auto-install plugins on clone | ❌ Unsupported | Manual `claude plugin install` required |
| Import in skill/agent frontmatter | ❌ Unsupported | Imports only work in `.md` body |
| Programmatic subagent orchestration from CLI | ❌ Unsupported | Use Claude API SDK instead |
| `claude plugin eval` CLI | 🔶 Early access | Not enabled by default; no public docs yet |

---

**Documentation Sources:**
- https://code.claude.com/docs/en/plugins.md
- https://code.claude.com/docs/en/plugin-marketplaces.md
- https://code.claude.com/docs/en/skills.md
- https://code.claude.com/docs/en/settings-reference.md
- https://code.claude.com/docs/en/memory.md
- https://code.claude.com/docs/en/sub-agents.md
- https://code.claude.com/docs/en/hooks.md
- https://code.claude.com/docs/en/cli-reference.md
- Embedded reference: Plugin eval and `/skill-doctor` (early access, not yet public)