# Rehearsing GBGHomogeneousTurbulence's first wiring — the record (2026-09-28)

HT (head `c016f95`) wired on a scratch clone, pushing disabled, at GBGCodingTools v2.0.0-rc.31 and again
from a fresh clone at v2.0.0-rc.32, then from a fresh clone of head `8c7ab73` at v2.0.0-rc.34, and last in one script at head `8a0e279`,
first at rc.34 and then at rc.35.
Every figure in `docs/HT-WIRING.md` comes from this rehearsal. What it
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
  session to re-install on its machine. · fate: fixed 2026-09-29 — `gbg --dev` compares the installed copy
  with the checkout's `bin/gbg` and says to re-install when they differ
- **W-6.** `gbg check`'s summary counts the build-script, test-entry and workflow findings as "generated
  path(s) adrift"; none is a generated path. · fate: fixed in the rc.33 commit (wiring findings counted and split by what fixes them; verified by re-measuring HT's clone)
- **W-7.** A first wiring cannot use `gbg init`: the shim refuses in a directory with no `.gbg/config.jl`,
  since it cannot know which version to run. `gbg --dev init` is the only way in. · fate: kept by design
  (2026-09-29), and the refusal for `init` now names `gbg --dev init`

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

## Found writing `HT-WIRING.md` (2026-09-28)

- **W-17.** RULE.DOC.SIBLING_LINK skips fenced code blocks but reads an indented code block in a Markdown
  page as prose, so a package URL in an indented shell command took the first-mention slot. A plain
  "four spaces is code" test would be wrong: PF's and HT's pages indent list continuations by four
  spaces (e.g. HT `docs/src/decisions.md:92`), and those are prose the rule must read. · fate: fixed 2026-09-29 — the owner ruled code in pages and rationale documents fenced
  (RULE.DOC.FENCED_CODE, found by Julia's own Markdown parser); no page rule then needs to tell the two apart

## Every rc.34 finding verified at HT's head `8a0e279` (2026-09-28)

The 155 findings of the one-run rehearsal (153 from the build, 2 from the site) were each checked
against the rule's statement by four verifiers: **150 true, 1 false, 4 unclear**. What they found in the
tool:

- **W-20.** RULE.DOC.SIGNATURE_FIDELITY strips a hat only as the combining circumflex, U+0302. HT's
  `û` is the precomposed U+00FB, which Julia's normalised identifiers hold wherever one exists, so
  `kinetic_energy(û)` over the method `kinetic_energy(u)` was reported. The one false finding. · fate:
  fixed in rc.35 (the name is decomposed before the mark is stripped; an example with
  `û` and `ω̂`, which fails on the old code; HT's finding goes, PF's count is unchanged at 0)
- **W-21.** RULE.DOC.XLINK counted a name linked anywhere in a docstring as linked, while its statement
  judges the first mention; a bare first mention with a later link was never reported (HT's
  `StochasticOU`). · fate: fixed in rc.35 (the first mention decides; a breaking and a
  complying example; HT gains 6 findings, each read and genuine; PF's count is unchanged at 0)
- **W-22.** RULE.DOC.LINK_UNIFORMITY printed its names as `SubString{String}["…"]`. · fate: fixed in rc.35
- **W-23.** ARGS_FORM's "under a sentence" findings, FIELDS, XLINK and LINK_UNIFORMITY report the line
  where the docstring opens, not the line of the defect; the finding names the docstring, so it can be
  found, but not at its line. · fate: fixed 2026-09-29 — each reports its own line: the argument or field sentence,
  the `# Fields` heading, the mention, the run (`Texts.docstring_line`); eleven examples moved to it
- **W-24.** RULE.DOC.XLINK resolves a name through the export table alone, so a field of a local type
  that shares a name with another module's function is read as that function (`scalar_dissipation` in
  HT's `Spectra.jl` and `StructureFunctions.jl`: the two unclear findings). · fate: moot — both are in
  HT's Phenomenology module, which the owner excluded from every rule on 2026-09-29 until it is extracted
- **W-25.** RULE.CIT.FULL_INLINE calls a bare "Author year, [doi:…](…)" a "full reference"; the verdict
  holds, since the rule also requires the work under `# References`, but the message overstates. ·
  fate: fixed 2026-09-29 — the label case says "a DOI label in the prose"
- **W-26.** Fixing HT's ten Phenomenology citations as the messages say — the work under `# References`,
  its DOI on the title — raises a second round the first does not announce: FULL_INLINE compares every
  DOI there with the canonical reference list, which the Phenomenology leaf is exempt from by HT's own
  design (`docs/ARCHITECTURE.md` 3087–3089) with no switch declaring it. The class of W-13. · fate:
  moot — Phenomenology is excluded from every rule (the owner, 2026-09-29)
- The other two unclear findings are readings of a statement: whether a field described inside another
  field's bullet has its bullet (RULE.DOC.FIELDS, `Cache.jl`), and whether `kwargs...` is documented when
  every keyword it collects is but the splat itself is never named (RULE.DOC.ARGCOV, `SimulationRun.jl`).
  · fate: ruled 2026-09-29 — a field heads a bullet of its own, though two may head one together; and
  `kwargs...` is named like any argument, and links the manual's keyword section (RULE.DOC.JULIA_MANUAL)

## Found rehearsing GBGPeriodicFields' upgrade to rc.36 (2026-09-28)

- **W-27.** RULE.DOC.ARGS_FORM tells a type that documents its fields under "The fields are" to bullet
  its arguments under `# Arguments`; the fix that clears it is the `# Fields` heading, which exempts
  the type, and the fix the message names would repeat the field list (six of PF's findings). · fate:
  resolved in rc.37 — the owner ruled the exemption out (2026-09-28), so a type lists its arguments under
  `# Arguments` and the message now names the fix the rule wants
- **W-28.** RULE.DOC.ARGS_FORM's "under a sentence" branch runs before the argument count, so a
  docstring with fewer than three arguments and no keyword, bulleted under "The arguments are", would be
  told to add a heading where the statement asks for prose. It fires nowhere in PF or HT. · fate: fixed
  2026-09-29 — the check counts first
- **W-29.** RULE.DOC.ARGCOV counts an argument documented only when its name is code; PF's six
  allocating constructors describe `family` in italics, which the statement's "documented in its body"
  admits. · fate: resolved 2026-09-29 — the owner ruled the statement to match the check: every argument
  is named as code in the body (PF had already written `family` as code)

## Found rehearsing HT's wiring at rc.45 (2026-09-29)

- **W-30.** The push hook's docs build cannot load HT. Step 5 had HT drop the two lines the old docs
  workflow step adds to `docs/Project.toml`, as HT's commit `224cb8c` does, and a build of what is
  committed then fails on "Package GBGHomogeneousTurbulence not found"; keeping the lines uncommitted
  instead trips the hook's stop on uncommitted tracked files. Every HT push would have been stopped
  whatever its content. · fate: resolved in the wiring document — HT's docs project names HT
  (`path = ".."`) and GBGPeriodicFields (its URL) under `[sources]`, as GBGCloudPhysics' already does,
  and the workflow step is `Pkg.instantiate()` alone. Measured on a copy of the wired clone: the hook's
  build then loads HT and reports the 128 findings and nothing else
- **W-31.** RULE.DOC.XLINK exempted every name CALLED in a docstring's signature, so the default
  `velocity_forcing = ConstantPower()` of `predicted_stationary_state` hid the bare prose mention of
  Forcing's `ConstantPower` below it, which the statement asks to link. · fate: fixed in rc.46 — the
  signature exempts the name it is written under and its parameters; a call inside it is a code
  expression. Measured over the four packages: one finding more, this one, and no other change
- **W-32.** RULE.DOC.ARGS_FORM reports a list under a sentence at the sentence, where the phrase is the
  rule's own, and at the first argument bullet otherwise, and prose that should be a list at the
  docstring's opening line. · fate: kept by design — each is where the defect named begins: the sentence,
  the unheaded list, and the docstring as a whole
- **W-33.** RULE.DOC.ARGS_FORM's statement said "one bullet per argument", and FIELDS' "two may head one
  together", while both checks accept any number of names at a bullet's head; four HT docstrings head a
  bullet with two arguments. Found verifying HT's rc.46 findings. · fate: resolved in rc.47 — the owner
  ruled (2026-09-29) that several names may head one bullet, for fields and arguments alike, since all
  of them are seen at a glance; the statements now say so
- **W-34.** Wiring wrote the bug hunt's and the change audit's skills though both are Phase 6, deferred,
  and their runs refuse to start; HT-WIRING.md listed them as installed, and HT's session read that it
  had a bug hunt beside its old one, "Step 7 settles which stays" (the owner noticed, 2026-09-30).
  · fate: fixed in rc.48 — an instrument not built keeps no skill, and the document says the two do not
  exist yet and that HT's old instruments go in Phase 7
- **W-35.** RULE.CIT.DOI read "no DOI" only where the title's logical line ended, which the check joined
  across wraps only while a bracket was open; HT moved Carpenter & Kennedy's "No DOI" onto the entry's
  first line to clear it (HT's report, 2026-09-30). · fate: fixed after rc.48 — the statement that there
  is no DOI is read from the whole entry; the DOI is still sought on the title's line, since one entry can
  hold two works. No finding in the fleet changes
- **W-36.** Nothing in the rulebook said when a session may message another package's session; the
  practice lived in this session's and PF's memories, which no other package reads, and the generated
  CLAUDE.md block said a missing reader "is requested from the tool's own session". HT sent PF a
  follow-up request the owner had not approved (2026-10-01). · fate: fixed in rc.49 — RULE.INST.PEER_MESSAGE,
  RULE.GIT.REQUESTS names the owner's approval, and the block's sentence corrected (the owner, 2026-10-01)
