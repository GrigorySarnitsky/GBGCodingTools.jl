# /audit-changes — were these edits justified, and did they silently change behaviour?

This text is injected into the session by `gbg preflight audit-changes`, which has already validated
the config, run the quick doctor, verified the running copy and OPENED the round named in the lines
that follow it, with the REQUIRED `base` commit recorded in it. Everything below is done in that
round, through the `gbg` verbs.

## The question, and why it is not a defect hunt

> **Was each change proportionate to the defect it claims to fix, and did it silently alter behaviour
> for input that previously worked?**

`/check-docs` and `/check-consistency` audit prose; `/bug-hunt` audits code. This one audits CHANGES to
code — it reads the diff, not the tree. An edit can be a correct fix and still be wrong to make: wider
than the defect required, changing a default, rejecting a workflow that used to be legitimate, breaking
a contract the fix did not need to touch. Neither the code nor the fix looks wrong in isolation, which
is exactly why a hunt cannot find it. A finding that would have been true BEFORE the diff belongs to
`/bug-hunt`, not here. Run it after any instrument's fix pass (the hunt's close requires it), or on
request over any commit range.

## Two structural rules, each from a demonstrated failure

**The norm is pinned at BASE, never at HEAD.** The docstrings and tests a lane would naturally treat as
the standard were themselves edited in the audited window — the audited party rewrote the description
of the thing being audited. A contract quietly amended to match changed behaviour IS the defect, not the
baseline: read it at `base` with `git show <base>:<file>`.

**`test/` is inside the audited material.** A fix that also edited the test that would have caught it,
or re-baselined a frozen ledger in the same commit, is the shape that certifies itself. Every change
under `test/` and to a baseline is a claim to be checked, never the standard.

## Lanes

Thirteen lanes from the catalogue, differing by LENS: ten code lanes (`free-reader`, `executing`†,
`under-rejection`†, `backend-portability`, `behaviour-change`†, `over-rejection`†, `public-contract`,
`numerics`, `invariants`, `claim-versus-edit`) and three prose lanes (`contract-drift`†,
`sweep-completeness`, `reader-consequence`); † is an anchor, never economised. The lane set was
settled by ATTACKING it rather than by taste: the design attacker put a logician, a philosopher, a
red-teamer and a measurement specialist against an earlier list and demanded a concrete harmful edit
that passes every lane; it produced eleven fatal gaps, and three of four attackers converged on the same
one — not a single lane ran anything. Hence `executing`, which RUNS every measurement claim and calls
every new entry point the way its own documentation says to; `under-rejection`, the guards removed or
weakened, which fail silently; and `backend-portability`, bit-identical on `Array` and broken on a
device. The `kind` of the round — `code`, `prose` or `both` — is derived from the diff's paths and
selects the lanes; a lane that cannot fire on the diff at hand teaches the reader to discount `CLEAN`
everywhere. Covered paths are `src`, `test`, `ext`, `docs`, `Project.toml` plus every `[paths]` entry of
the config; config can only add.

## The round, step by step

1. **Prepare.** `gbg round prepare <round>` writes the diff (`git diff <base>..HEAD -- <covered>`), the
   claims (`git log --format="%h %s" <base>..HEAD`), the diffstat, the guard symbols and the invariants
   text from the config into `.gbg/scratch/<round>/`, derives `kind`, and resolves the lanes.
2. **Audit.** Launch the `Workflow` call preflight printed. Each lane reads the diff FIRST and in full,
   then whatever of the tree it needs, and `Write`s `findings/NN-<lane>.json` before returning: a
   verdict `CLEAN` or `CONCERNS`, a non-empty `checked[]` (REQUIRED, especially when clean — clean with
   an empty list is indistinguishable from a lane that did nothing and is read as such),
   `candidates_found`, and the concerns, each with `severity` (`blocker` / `major` / `minor` / `nit`),
   `justified` (`yes` / `no` / `unclear`), `before` and `after` quoted from the diff, `why_it_matters`,
   and on the behaviour-change lane `previously_worked` (`yes` / `no` / `unknown`, `unknown` gated like
   `yes`). An assertion with no quotation is not a concern. Every lane is forbidden `.gbg/` and
   `~/.gbg/`.
3. **Bank.** `gbg audit-changes bank <round>` (like every `round` verb it verifies the running copy and
   the torn-file guard first): schema-validates the lane files; RUNS the executable claims itself —
   the package's test gate and each file the config names under `executable_claims` — under
   `GBG_ROUND` and records their exit codes in `audit.json`, so the `executing` lane's account is
   corroborated by a program; runs the severity re-check (an anchor) before "serious" is counted;
   freezes `findings.json`. A DEAD lane is exit 2: that lens is UNAPPLIED, not clean.
4. **Dispose.** Every serious concern (`blocker` or `major`) and every concern with
   `previously_worked ∈ {yes, unknown}` — that field is what the instrument exists to surface, so its
   severity is not the reporting lane's to downgrade — carries a disposition: `fixed`, `refused` with a
   reason of at least 24 characters, or `escalated` to the owner with `overturn_when`. An absent
   disposition is a dropped finding. Never close a concern by declaring it "by design": answer it or
   escalate it.

   **This step never edits the tree.** `fixed` names a correction the NEXT change set carries, which the
   next audit then covers; it does not mean "corrected just now". Closing requires that no covered path
   has moved since the audited head, so a correction made inside the round makes that round unclosable —
   there is no re-bank — and every disposition recorded in it is lost with it.
5. **Close.** `gbg round close <round>` requires: no dead lane; every gated concern disposed; an
   empty audit's `verdict_all_clean` backed by `checked[]` on every lane AND every recorded
   executable-claim exit code zero; staleness clean — `git diff <audited head>..HEAD -- <covered>` empty,
   with an unreachable audited commit read as `UNCHECKABLE`, never as clean (empty output from a
   rebased-away commit is indistinguishable from "nothing changed", and that inversion once passed a
   stale audit); the dismissal auditor run with `reopened == []`; the files committed and pushed. The
   doctor warns (`AUDIT.GAP`) when this round's `base` is not the previous closed audit's `head`.

## Why it has no adversarial verifier

The doc instruments carry a state verifier because "is this finding fixed?" is a judgement and
judgements get quietly dropped. This one holds its mechanical anchor — the `executing` lane and the
CLI's own re-run of the executable claims — and a second adversarial layer auditing the auditor is
where the regress starts and the grounding stops. What it has instead is the disposition gate above,
the severity re-check, and the design attacker every lane list has to survive.
