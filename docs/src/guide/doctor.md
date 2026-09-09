# The doctor's checks

Generated at build time from the doctor's own table (`Doctor.CHECKS`): every stable id, its family, whether
the `QUICK` set runs it, whether it needs `--deep`, and whether a `scope = "check"` ledger entry may
exempt it. The check's own detail line says what failed and what fixes it; ARCHITECTURE §7.3 is the
authoritative table with the failure conditions.

| Id | Family | QUICK | `--deep` | Exemptable |
|---|---|---|---|---|
| `ENV.JULIA` | ENV |  |  | no |
| `ENV.SHIM` | ENV |  |  | no |
| `ENV.DEV_CHECKOUT` | ENV |  |  | no |
| `SHIM.HASH` | SHIM |  |  | no |
| `PIN.CONFIG` | PIN | yes |  | no |
| `PIN.SOURCES` | PIN | yes |  | no |
| `PIN.TREESHA` | PIN |  |  | no |
| `PIN.SELF` | PIN |  |  | no |
| `PIN.NOT_DEV` | PIN | yes |  | no |
| `SELF.CONSUMER` | SELF | yes |  | no |
| `CFG.VALID` | CFG | yes |  | no |
| `CFG.TORN` | CFG |  |  | no |
| `CFG.SURFACES` | CFG | yes |  | no |
| `CFG.HATS` | CFG | yes |  | no |
| `CFG.SEEDS` | CFG | yes |  | no |
| `CFG.EXEMPTIONS` | CFG | yes |  | no |
| `EXEMPT.EXPIRED` | EXEMPT | yes |  | no |
| `EXEMPT.EXPIRING` | EXEMPT | yes |  | no |
| `EXEMPT.STALE` | EXEMPT | yes |  | no |
| `EXEMPT.BROAD` | EXEMPT | yes |  | no |
| `WIRE.MAKEDOCS` | WIRE | yes |  | no |
| `WIRE.RUNTESTS` | WIRE | yes |  | no |
| `WIRE.CI_AUTH` | WIRE | yes |  | no |
| `WIRE.GITIGNORE` | WIRE | yes |  | no |
| `WIRE.CLAUDE_MD` | WIRE | yes |  | no |
| `MANAGED.HASH` | MANAGED | yes |  | no |
| `MANAGED.STALE` | MANAGED |  |  | no |
| `LEG.COMMANDS` | LEG |  |  | yes |
| `LEG.PILES` | LEG |  |  | yes |
| `LEG.LINTS` | LEG |  |  | yes |
| `LEG.SENTINELS` | LEG |  |  | yes |
| `POL.IMPORT` | POL |  |  | no |
| `POL.SENTINEL` | POL | yes |  | no |
| `POL.COLLAPSED` | POL |  |  | no |
| `GIT.BRANCH` | GIT |  |  | yes |
| `GIT.TRAILER` | GIT |  |  | yes |
| `ROUND.DIR` | ROUND | yes |  | no |
| `ROUND.MARKER` | ROUND | yes |  | no |
| `ROUND.OPEN` | ROUND | yes |  | no |
| `ROUND.ABANDONED` | ROUND | yes |  | no |
| `ROUND.DEV` | ROUND | yes |  | no |
| `ROUND.FROZEN` | ROUND | yes |  | no |
| `AUDIT.GAP` | AUDIT |  |  | yes |
| `LOAD.ENVS` | LOAD |  | yes | no |
| `BUILD.DOCS` | BUILD |  | yes | no |
| `SELF.DOCS` | SELF |  | yes | no |
| `TEST.PKG` | TEST |  | yes | no |
| `WITNESSES.ESCALATED` | WITNESSES |  | yes | no |
| `WITNESSES.BLOCKED` | WITNESSES |  | yes | no |
