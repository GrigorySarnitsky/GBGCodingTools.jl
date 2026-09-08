# Git conventions (`RULE.GIT.*`)

### RULE.GIT.PUSH
Commit ⇒ push, directly on the configured branch; no feature branches. The repository is private and
synced across machines through GitHub, so work is committed on the default branch and pushed in the same
step; GitHub is the cross-machine sync path and the docs site deploys on push. Stage with `git add -u`
plus every new file by name, never `-A`.

### RULE.GIT.TRAILER
Every commit message ends with the versionless trailer `Co-Authored-By: Anthropic Claude
<noreply@anthropic.com>`, and never carries `[skip ci]`. The trailer names no model version on purpose:
the model in use changes often and the versions supersede each other, so a version in the trailer is a
fact about the day rather than about the work, and it goes stale in the one place git never lets anyone
correct it.

### RULE.GIT.CI_MANUAL
CI is manual-only; the matrix runs locally before a commit, and the docs deploy on every push. Before
committing a code change, run the gate locally; a documentation-only change needs a load and the docs
build. The docs build is therefore the per-push enforcement point, and the doctor, the hard scans and the
gate stay inside it.

### RULE.GIT.NO_SHIMS
The API is not frozen; no backward-compatibility shims are built. Errors found later are fixed one by
one; architectural soundness is judged on the full picture first.

### RULE.GIT.BRANCH
The working branch is the one the package's config names, `master` by default. A rename is a decision
about the package, never bundled with a tooling adoption.

### RULE.GIT.MANIFEST_TRACKED
Sub-environment manifests are gitignored, and a tracked root manifest is a declared deviation. A stale
sub-environment manifest is resolved locally when precompilation breaks; CI resolves its own.

### RULE.GIT.REQUESTS
A cross-package request is a tracked file `.gbg/requests/to-<PKG>-<date>-<topic>.md` in the requester
with a status paragraph on top, and a concluded request is deleted, not kept. The requests directory holds
what is still awaiting the other package and nothing else.
