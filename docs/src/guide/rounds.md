# [Rounds](@id rounds)

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

A **round** is one run of one instrument over one consumer, tracked under `.gbg/rounds/<date>-<instrument>-<NN>/`.
The CLI writes its marker `ROUND.toml`; the lane agents — one agent per surface or territory the
instrument covers, a **lane** — write their lane files; the CLI banks, the session fixes, the verifiers
grade, the CLI closes. Nothing is done by hand that a verb does.

## The lifecycle

1. **Open** — `gbg preflight <instrument>` (the skill's `!` block): the quick doctor, the torn-file guard,
   `gbg self verify`; the roster resolved; `ROUND.toml` written with every stamp; the Workflow scripts
   copied into `.gbg/scratch/<round>/workflow/` and every payload written beside them as a file.
2. **Prepare** — `gbg round prepare <round>`: the build under `GBG_ROUND`, the manuscripts consolidated
   (and seeded), or the scan battery banked as lane `00-scans`, or the audit's diff files.
3. **Lanes** — the printed `Workflow` call; each lane writes `findings/NN-<lane>.json` first.
4. **Bank** — `gbg round bank <round>`: lane files validated and classified (a DEAD or REJECTED lane is exit 2 and
   nothing is frozen), ids `<round>/<lane>#<n>` assigned, seeds marked, `findings.json` frozen.
5. **Fix** — on the owner's word, from `findings.md` by id; builds and tests through
   `gbg round build|test <round>`.
6. **Verify** — `gbg round pass open <round>`: a nonce, the range, the regenerated manuscripts; the act
   verifier (sees the diff) and the state verifier (blind) launched as printed.
7. **Grade** — `gbg round grade <round>`: the demotion, the closure channels, the tally; exit 1 while
   any id is open, and equally while any id is `pending_state` — closed by the act verifier with no
   blind reading to confirm it. Loop 5–7 over the same `findings.json`.
8. **Close** — `gbg round close <round>` when every condition holds. `--carry <id>,<id>` closes over a
   `minor` or `nit` finding by carrying it into the next round of that instrument, on a severity re-rated
   by `severity-recheck.js` rather than by the lane that reported it (`RULE.INST.CARRY`); it is re-banked
   there and never rediscovered. `gbg round abandon` is the only
   wholesale exit and names every open id.

## Closure channels

| Channel | Condition |
|---|---|
| `honored` | act `HONORED` after demotion and state `ABSENT` or `NOT-A-DEFECT` in the same pass |
| `adjudicated` | a ledger entry `scope = "finding"` naming the id, reason ≥ 40 characters, `overturn_when` present, recorded after the round opened; audited at close |
| `seeded` | a planted finding whose state is favourable |
| `rescan` | a hard-scan hit of lane `00-scans` that no longer fires when `grade` re-runs the scan |
| `carried` | an id the round hands to the next run of the same instrument, under the carry conditions |

The demotion is mechanical: `HONORED` becomes `LINE-ONLY` when `class_surfaces[]` is empty, and equally when any entry in it is `swept: false` — a verdict that claims the fix landed while its own evidence names a surface the class still lives on.

## The gate

`gbg gate [instrument…]` fails on any open round of the named instruments except the one named in
`GBG_ROUND`, which the CLI exports only while it runs a build, a test or an audit's executable claim on
that round's behalf. The
`makedocs` wrapper runs it for the doc instruments and `TestHarness.gate()` for the code instruments,
so a fix pass cannot be committed around an open round.
