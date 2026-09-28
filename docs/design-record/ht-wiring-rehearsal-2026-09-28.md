# Rehearsing GBGHomogeneousTurbulence's first wiring — the record (2026-09-28)

HT (head `c016f95`) wired on a scratch clone, pushing disabled, at GBGCodingTools v2.0.0-rc.31 and again
from a fresh clone at v2.0.0-rc.32. Every figure in `docs/HT-WIRING.md` comes from this rehearsal. What it
found in the TOOL is recorded here first, each with its fate, before any fix — the rule the owner set on
2026-09-27 after the code review: a mistake found is written down with the check that catches it.

## Defects in the tool

- **W-1.** Every wiring finding said "run `gbg sync`", including those about `docs/make.jl`,
  `test/runtests.jl` and the workflows, which sync does not write. · fate: fixed in rc.32 (`Render.remedy`)
- **W-2.** The tooling page `docs/src/gbg.md`, written by every build, was in no ignore block. · fate:
  fixed in rc.32 (in the managed block)
- **W-3.** RULE.DOC.HOME_ORDER's why claimed the prose-shape rule reads a heading after `# Fields` as a
  finding; it does not. · fate: fixed in rc.32
- **W-4.** This package's `make.jl` guarded `deploydocs` on a result that could never be nothing. · fate:
  fixed in rc.32
- **W-5.** The installed `gbg` shim on this machine predated the review's shim fixes: `gbg install` is
  per machine, and nothing says when it is stale. · fate: re-installed here; `HT-WIRING.md` tells HT's
  session to re-install on its machine. A staleness check is open (not built).
- **W-6.** `gbg check`'s summary counts the build-script, test-entry and workflow findings as "generated
  path(s) adrift"; none is a generated path. · fate: fixed in the rc.33 commit (wiring findings counted and split by what fixes them; verified by re-measuring HT's clone)
- **W-7.** A first wiring cannot use `gbg init`: the shim refuses in a directory with no `.gbg/config.jl`,
  since it cannot know which version to run. `gbg --dev init` is the only way in. · fate: open — by
  design or not is the owner's; `HT-WIRING.md` says to use `--dev`

## Measured, and read as the tool working

- `API_GROUPING` read 159 docstring bindings on HT's built site and found nothing: a real zero, checked
  because the same rule had been blind until the review.
- The site rules are unchanged between rc.31, where the site was measured, and rc.32 (`git diff
  v2.0.0-rc.31 v2.0.0-rc.32 -- src/Rules src/Engine src/Texts.jl` touches only a why).

## Every finding verified (2026-09-28)

HT's docs build at rc.32 reported 308 findings; 137 were the missing prose baseline, recorded by `gbg check
--rebaseline` as a first wiring does. The other 171 were each checked against the rule's statement by
three verifiers: **110 true, 11 false, 50 unclear**. The per-line verdicts are in the session's scratch
(`htv/*.verified.md`); what they found in the tool:

- **W-8.** RULE.DOC.SIBLING_LINK counts a sibling's name inside a link's target (an `@extref` target, a
  URL) as a mention. 10 false findings in HT, and 2 real bare first mentions hidden. · fate: fixed in the rc.33 commit (names read in the visible text only; on HT the 10 false findings go and 2 hidden ones appear; verified by re-measuring HT's clone)
- **W-9.** RULE.DOC.FIELDS accepts only the phrase "The fields are", while RULE.DOC.HOME_ORDER names the
  `# Fields` section the same rule governs. HT writes `# Fields` 33 times: 27 complete field lists are
  reported as "documents no fields", and the check never compares a `# Fields` list with the struct, so
  it cannot find the one real drift. · fate: fixed in rc.34 — ruled 2026-09-28: a `# Fields` section; the check compares it with the struct
- **W-10.** RULE.DOC.ARGS_FORM's statement asks for "the marker phrase and a colon" and never names the
  phrase; only the check's regex does ("The arguments are"). HT's `# Arguments` heading, and types whose
  constructor arguments are their fields, are read as prose. · fate: fixed in rc.34 — ruled 2026-09-28: an `# Arguments` heading,
  named in the statement
- **W-11.** RULE.DOC.ARGCOV counts an argument documented only when its name is a code span of its own; a
  splat described by a pass-through sentence, or a name inside a larger code expression, is missed.
  · fate: fixed in the rc.33 commit (a name inside a code span, and a splat whose pass-through is stated, count as documented; verified by re-measuring HT's clone)
- **W-12.** `Texts.unwrapped` reports a joined run at its first line, so a finding inside it points one to
  two lines early (three DOIs on lines 75–77 all reported at 75). · fate: fixed in the rc.33 commit (`Texts.line_at` maps a match to its own line; HT's DOIs report 75, 76, 77; verified by re-measuring HT's clone)
- **W-13.** RULE.CIT.FULL_INLINE recognises only `[*Title*](https://doi.org/…)`, so a mid-sentence
  `[doi:…]` reference is not seen; once HT fixes its DOI findings those become FULL_INLINE findings — a
  second round the first did not announce. · fate: fixed in the rc.33 commit (the `[doi:…]` label form is a full inline reference too; HT's 10 appear in one round; verified by re-measuring HT's clone)
- **W-14.** RULE.CIT.DOI accepts only a DOI or an Open Library link; a report with no DOI that is not a
  book (Rogallo 1981, Lundgren 2003, Carpenter & Kennedy 1994) cannot comply. · fate: fixed in rc.34 — ruled
  2026-09-28: an entry saying "no DOI" links its title to the work's stable public record
- **W-15.** RULE.DOC.SIGNATURE_MIRROR's 88-column limit is in the check's code only, and counts the
  Markdown indent. · fate: fixed in the rc.33 commit (the limit stated, measured as rendered; verified by re-measuring HT's clone)

## Found meanwhile, by GBGPeriodicFields (2026-09-28)

- **W-16.** The package failed to load on Julia 1.13: it named parser kinds (`MacroName`,
  `StringMacroName`) that 1.13's bundled parser renamed, and the witness wrapper assigned Test's print
  switch, a `ScopedValue` on 1.13. PF's docs deploy stopped at its first build on `version: '1'`. Nothing
  here ran on a Julia newer than the floor. · fate: fixed in rc.33 (version-proof macro-name reader, both
  Test forms, the newest Julia in CI; the whole suite green on 1.12.7 and 1.13.1)
