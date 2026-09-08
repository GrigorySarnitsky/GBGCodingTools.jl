# REVIEW-final — Revision 7 (the prerelease tag) and the consistency re-run (2026-09-08)

A = `ARCHITECTURE.md` (2371 lines), I = `IMPLEMENTATION.md` (959), F = `FIXLOG.md` (333). Pre-edit copies
`*.rev6.bak`; edit script `rev7.py` (20 spans, each matched exactly once); checkers `check.py`, `check_b.py`, `check_c.py`.

## Task 1 — the ruling applied (what changed, by file:line)

- A:773–774 (D15): the first `/check-docs` round is "opened at the clean prerelease tag `v1.0.0-rc.1` and CLOSED".
- A:805–822 (D16): the release preconditions gain "the `/check-docs` round opened at the latest `<ver>-rc.<n>`
  tag is closed — `closed_by` honored or adjudicated per id, never `abandoned`"; a new **The prerelease form**
  sentence (A:808–812) beside **The dev-round rule, extended**, whose released tag now reads "a prerelease
  `vX.Y.Z-rc.<n>` included" and whose stamp sentence names the rc tag as the measuring instrument; the semver
  note (an rc tag is never a consumer pin; `PIN.CONFIG` only `vX.Y.Z`, `PIN.SOURCES` refuses `-rc.` outside the tool).
- A:1674 `PIN.CONFIG` ("never a prerelease"), A:1675 `PIN.SOURCES` (the `-rc.` refusal, pass and fail columns),
  A:1709 `ROUND.DEV` (rc tag named). A:1758–1759 (§8 arms): a round at a clean `v9.9.9-rc.1` closes (entailment).
- A:1762–1768 (§8 preconditions restated, the prerelease form); A:1773–1774 (the first round opens at the rc tag).
- A:2041–2044 (§11): the residue names the prerelease tag as the reason a clean-tag round is needed.
- A:2358–2371: Revision 7 note. No "abandon listing none" sentence survives in A (grep: only the note's quotation).
- I:176–177 (1.1): `CHANGELOG.md` gains the `## 1.0.0-rc.1 — <date>` entry (entailment of "the same refusals").
- I:255 (1.3 `release` row): `gbg release <ver>-rc.<n>` added; the closed-round precondition; the rc exceptions.
- I:453–456 (1.8): the rc-tag arm. I:506–522 (1.10 item 7 rewritten: commit, `gbgdev release 1.0.0-rc.1`, the
  round at the clean rc tag, closed by `gbgdev round close`, never `abandon`; optional `1.0.0-rc.2`; item 8 commits twice).
- I:534, I:542–544 (Phase 1 definition of done: round closed, rc tag on GitHub). I:622–626 (Phase 3 opening
  paragraph), I:633–634 (the block's comment). I:940–944 (Revision 6 note marked SUPERSEDED). I:946–959 (Revision 7).
- F:298 (row 5: "RE-RULED by Revision 7"), F:313 (counts), F:316–333 (Revision 7 section, verification, counts).

## Task 2 — the seven checks

**(a) Doctor ids.** 48 rows in §7.3 (17 prefixes). Every id cited in A or I resolves to a row — the scripted
list of 23 "unresolved" was false positives: `\bGIT\.`/`\bTEST\.` matching inside `RULE.GIT.*`/`RULE.TEST.*`
(A:480, 1227, 1893, 2130–2158; I:743), `EXEMPT.EXPIRING` sharing the `EXEMPT.EXPIRED` row head (A:1686), and
`ENV.PYTHON` in the Revision 4 note recording its removal (A:2274). Membership agrees everywhere: `SELF.CONSUMER`
QUICK + non-exemptable (A:1657, 1679; D14 A:708–709, §7.2 A:1650–1651; I:504, 533), `SELF.DOCS` `--deep` only
(A:1661, 1714), `CFG.TORN` outside QUICK at every statement (A:463, 1377, 1662, 1681, 1747; I:275, 310, 448, 674);
the Revision 4 note's retracted "QUICK" claim (A:2282) is marked inline (A:2304). **0 mismatches.**
**(b) `gbg` verbs.** 1.3 defines 22 verbs (`round` with 13 sub-verbs incl. `close`/`abandon`/`pass open`, `scan
docs|html`, `self verify`, `migrate baselines`, `witnesses fail|pass`, `release` with both spellings). Every usage
in A and I is a row; the only non-row string, `gbg hook queue-guard` (A:680, 2272; I:260, 888), is stated at
each site as a verb that does NOT exist. **0 mismatches.**
**(c) IMPL paths vs §3 / §4.** Every tool-tree path 1.10 names is in §3 (`docs/src/`, `rounds/.keep`,
`test/regressions/`, `prose_shape.csv`, `hats/tooling-maintainer.toml`, `.claude/skills/`, `CI.yml`, `docs.yml`,
`managed.json`, `Scans/`, `lanes/`, `seeds/fixture.toml`). The 22-token residue after a basename filter is all
brace-form tree entries (`api/{…,CLI}.md` I:291; `lanes/{check-docs,bug-hunt,audit-changes}.toml` I:347, 380–382;
`guide/{install,rounds,ledger,config}.md` I:473–478), globs (`schema/*.schema.json` I:390, 918; `policy/*.md`;
`docs/src/**/*.md` I:486), migration SOURCES (`xlink.jl`, `dupref.jl`, `signature_fidelity.jl`, `witnesses.jl`,
`check-docs.md` I:317–320, 343, 363, 713), a throwaway probe (`/gbg-probe` I:565) and consumer instances of §4
shapes (`requests/to-PF-<date>-<topic>.md` I:759; `hats/cloud-microphysicist.toml` I:813). Round artefacts
(`ROUND.toml`, `findings.json`, `import.json`, `recorded.toml`) are §6's, reached from §4's `rounds/… P §6` line.
`docs/docstring_shape.csv` (I:756, 772) is PF's legacy name being renamed to `prose_shape.csv`. **0 mismatches.**
**(d) `RULE.*` / `SCAN.*`.** §12 defines 130 ids; every citation resolves. The 12 scripted leftovers are family
prefixes (`RULE.DOC`…`RULE.GIT` A:623–624), the `SCAN.HTML_*` stem (A:921, 2165; I:299, 363) and the §12 row
`SCAN.CUSTOM.<id>` (A:2211). **0 mismatches.**
**(e) Fences and tables.** A: 14 fence lines, 10 tables; I: 22, 7; F: 0, 8 — all balanced, every row's column
count equals its separator's (the edited 1.3 `release` row and F rows 5 and Revision 7 included). **0 defects.**
**(f) Revision 4–6 notes vs FIXLOG.** No contradiction. Three summary omissions, none introduced today and none
fixed (outside task 1): A:2272–2275 Rev 4 item (4) omits the D2 item 3 / D8 / §4 / §5.1 / §6.2 step 10 / §9 /
D14 sites F:224–226 lists; I:882–900 omits Rev 4 item (11)'s "I 1.4" (F:231); I:930–931 Rev 6 keeps the
pre-Rev-7 verb "the recorded `/check-docs` round" (history of that edit; the document body now says "closed").
A's Rev 6 note never named the collision, so A states the supersession only in its Rev 7 note (A:2360–2362);
I's Rev 6 note marks it (I:940–944), matching F:298. Rev 5 (A–D) and Rev 6 ((1)–(8)) section lists agree. Rev 7
notes in A and I match F:324 item for item.
**(g) Phases 0–3.** Read in full (I:92–657). Every artefact a step uses is defined: `gbgdev`/`$DEV` (§B),
`v0.0.1`/`probe/gbg-v4` (V3/V4), `gbg-pinned-fixture` (1.3), `## 1.0.0-rc.1 — <date>` (1.1), `closed_by`
honored/adjudicated (A §6), `tool_tree_sha` from the tag and `git describe --exact-match --dirty` (D16),
`gbg release <ver>-rc.<n>` and `gbg round close` (1.3), the `-rc.` refusal (§7.3). **0 undefined artefacts.**

## Residual observations (no action taken)

- The fleet detail `clean at vX.Y.Z` (A:304; I:238) will read `clean at v1.0.0-rc.1` between 1.10 and Phase 3;
  Phase 3's definition of done (`clean at v1.0.0`) is stated after the final tag, so it is consistent.
- Phase 1.9's `v0.0.1` clean-up "leaves one slug for Phase 3" still holds: nothing instantiates an rc tag.

## Summary

1. Task 1 applied in 20 exactly-once spans: D16 gains the prerelease form and the closed-round precondition, the
   extension admits rc tags, `PIN.CONFIG`/`PIN.SOURCES`/`ROUND.DEV` refuse or name them, D15/§8/§11/I 1.3/1.10/Phase 3 restated.
2. The "abandon listing no open id" resolution is gone from A and I except where its retirement is recorded.
3. Checks (a)–(e), (g): 0 mismatches after triage of scripted false positives; (f): 3 pre-existing summary omissions, unchanged.
4. Every scripted list was hand-triaged to a cause before being called clean; the checkers stay beside the documents.
