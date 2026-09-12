// VERIFY-ACT — the adversarial auditor of the ACT: it SEES the diff. Sources: PF verify-fixes.js (per-lane
// over banked piles, mechanical demotion note), IT verify-fixes.js (eight verdicts, `question`, array
// class_surfaces, batches). Changes: the verdict object is {id, verdict, question, evidence,
// class_surfaces[{surface, swept, evidence}]}; output carries graded_sha256 and pass_nonce from args;
// `range` required; one agent per lane; NO demotion here (the CLI applies it); finding text
// arrives unabridged in a FILE named by args (Revision 9); no census (the CLI knows the denominator).
//
// Args: { schema_version, round, round_dir, pass_dir, repo, range, nonce, graded_sha256,
//         lanes: [{nn, key, expected}], findings: [{id, lane, n, title}], findings_path,
//         adjudicated_titles, rulebook_summary?, package, models: {economy}, strength }
export const meta = {
  name: 'verify-act',
  description: 'Grade a fix pass finding by finding, SEEING the diff: HONORED / ADJACENT / INSERTED / LINE-ONLY / NEW-DEFECT / SCOPE-CREEP / UNDONE / LAUNDERED',
  phases: [{ title: 'Verify act' }],
}

// gbg:prelude
for (const k of ['round', 'pass_dir', 'repo', 'range', 'nonce', 'graded_sha256', 'findings', 'findings_path', 'models', 'schema_version', 'package']) {
  if (A[k] === undefined) throw new Error(`verify-act.js: args.${k} is required — without a range a lane grades edits it cannot see`)
}
if (!A.findings.length) throw new Error('verify-act.js: no open id to grade — the CLI launches the act verifier only when one is open')

const LANE_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    schema_version: { type: 'integer' },
    lane: { type: 'string' },
    graded_sha256: { type: 'string' },
    pass_nonce: { type: 'string' },
    verdicts: { type: 'array', items: {
      type: 'object', additionalProperties: false,
      properties: {
        id: { type: 'string', description: 'the finding id EXACTLY as given' },
        verdict: { type: 'string', enum: ['HONORED', 'ADJACENT', 'INSERTED', 'LINE-ONLY', 'NEW-DEFECT', 'SCOPE-CREEP', 'UNDONE', 'LAUNDERED'] },
        question: { type: 'string', enum: ['fidelity', 'strategy', 'implementation', 'scope', 'none'], description: 'which of the four questions the verdict answers; "none" for HONORED' },
        evidence: { type: 'string', description: 'file:line + the decisive quote from the CURRENT source, and the diff hunk where the act matters; <= 80 words' },
        class_surfaces: { type: 'array', items: {
          type: 'object', additionalProperties: false,
          properties: { surface: { type: 'string', description: 'file:line' }, swept: { type: 'boolean' }, evidence: { type: 'string' } },
          required: ['surface', 'swept', 'evidence'] },
          description: 'EVERY surface the finding\'s OWN TEXT names or implies as carrying the same class, enumerated from the FINDING, never from the diff. A class swept to zero still lists the sites you checked. An empty array under HONORED is demoted to LINE-ONLY by the CLI, mechanically.' },
      },
      required: ['id', 'verdict', 'question', 'evidence', 'class_surfaces'],
    } },
  },
  required: ['schema_version', 'lane', 'graded_sha256', 'pass_nonce', 'verdicts'],
}

// One agent grades SEVERAL lanes, so the diff and the corpus are read once per unit rather than once per
// lane; each lane still gets its own file, which is what `grade` reads, and its own object here.
const SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: { lane_files: { type: 'array', items: LANE_SCHEMA, description: 'one object per lane of your unit, in the order the prompt lists them' } },
  required: ['lane_files'],
}

const ADJ = (A.adjudicated_titles && A.adjudicated_titles.length)
  ? `\nBEFORE grading anything UNDONE, know that the owner has ruled these findings NOT to be defects (they were deliberately left alone; grading one UNDONE is the one verdict that looks identical to real neglect):\n${A.adjudicated_titles.map(t => `  - ${t}`).join('\n')}\nNothing merely FIXED is listed, so absence from this list proves nothing.\n`
  : ''

const PREAMBLE = `You are an ADVERSARIAL FIX AUDITOR for ${A.package.name} — ${A.package.description}

A review panel banked findings against this package's documentation, and a fix pass then ran. YOU AUDIT THE FIXES. Your allegiance is to the findings, not to the fixer: assume a fix is deficient until its evidence convinces you otherwise. You are NOT re-reviewing the docs and you are NOT looking for new defects.

You have: (1) THE FINDINGS, UNABRIDGED, in the file ${A.findings_path} — read the blocks for YOUR ids in full (each block opens with "--- <id> ---"); the text is ground truth for what was asked, and that file is the ONLY file under .gbg/ you may open besides the one you write; (2) THE DIFF — run \`git -C "${A.repo}" log --stat ${A.range}\` and \`git -C "${A.repo}" diff ${A.range}\` (scope with \`-- <path>\` when large). The ACT is what you audit, so how the text changed matters as much as what it now says; (3) THE CURRENT CORPUS under ${A.repo} (src/, ext/, docs/). NEVER read anything under .gbg/ or ~/.gbg/, and scope every search with \`--glob '!.gbg/**'\`: earlier passes' verdicts live there and they are an answer key.

FOR EACH FINDING, ask FOUR questions in order and stop at the first failure:
  (1) FIDELITY — did the ask land, and land EVERYWHERE it applies? A synonym is not the fix asked for.
  (2) STRATEGY — the right KIND of repair? Hunt (a) FIX BY INSERTION — the flagged text still there with correct text appended beside it; (b) LINE, NOT CLASS — the flagged instance fixed and the same defect surviving elsewhere; (c) WRONG SURFACE — a docstring reworded to explain away a defect that lives in the code.
  (3) IMPLEMENTATION — is the replacement text CORRECT? Verify formulas against the source; a fix can honour the instruction and still be false.
  (4) SCOPE — anything changed that was not asked for; a flagged TERM carried through a rewrite because it was not the literal flagged word.

VERDICTS — HONORED is the ONLY verdict that must be earned by evidence; prefer the others when in doubt:
  HONORED     — the ask landed, by the right means, correctly, without creep — AND class_surfaces enumerates every other surface carrying the same class, each with whether the diff swept it and a file:line. Start from the computed list where one is given, add what it could not know, and check every entry. A class swept to zero still lists what you checked. Never grade HONORED on a plausible story; grade it on hunks you can quote. HONORED means EVERY surface you list is swept: the tool demotes to LINE-ONLY any HONORED verdict whose own list leaves one unswept, so if the class is alive somewhere, say LINE-ONLY and name the site — that is the verdict, not a penalty.
  ADJACENT    — something was done, but not what was asked.
  INSERTED    — repaired by appending; the flagged text survives.
  LINE-ONLY   — the instance is fixed, the class is alive. Name the surviving sites. THIS IS THE MOST COMMON REAL OUTCOME.
  NEW-DEFECT  — the fix introduced a fresh defect.
  SCOPE-CREEP — unasked changes, or a flagged term carried through a rewrite.
  UNDONE      — nothing in the diff addresses this finding.
  LAUNDERED   — closed by DECLARING it acceptable ("by design", "for symmetry", "already recorded") rather than fixed or put to the owner. An assistant-authored dismissal is LAUNDERED however reasonable it reads; only the owner's ledger entry closes a finding without a fix.
${ADJ}
DEFAULT TO THE UNFAVOURABLE VERDICT. Grade EVERY finding you are given, in order, one verdict per id; a shortfall is under-grading and the missing ones are UNVERIFIED, not clean. Do not propose fixes. Do not rank. Do not soften.`

// The CLI already grepped each finding's own quoted text in the files that finding names, so no verifier
// spends a tool call on it. It is EVIDENCE, never a verdict: the quote is the site's identifying text as
// often as the defect's, so a surviving one does not settle STRATEGY and a vanished one does not settle
// the class. Absent (an older CLI), the line is simply omitted.
const probe = (id) => {
  const p = A.quote_probe && A.quote_probe[id]
  if (!p) return ''
  return p.length ? `\n      [computed] its quoted text still stands in: ${p.join(', ')}`
                  : `\n      [computed] its quoted text is gone from every file it names`
}
// The CLI greps every place the tree writes down a rule or scan id this finding cites, so the class
// checklist is one to MARK rather than one to invent — a class rarely lives only where it was quoted,
// and enumerating it one site per pass is what makes a round long. The list is a floor, never a ceiling.
const sites = (id) => {
  const s = A.class_candidates && A.class_candidates[id]
  return (s && s.length) ? `\n      [computed] this id is written down at: ${s.join(', ')}` : ''
}
const fmt = (f) => `  ${f.id} (lane ${f.lane}, #${f.n}) — ${f.title}${probe(f.id)}${sites(f.id)}`
const outFile = (name) => `${A.pass_dir}/act/${name}.json`

phase('Verify act')
// Lanes are grouped into units of at most `batch` findings (6 by default): the whole diff, which every
// act agent must read, is then bought once per unit instead of once per lane. A lane with more findings
// than the batch is a unit of its own; nothing is split across agents.
const BATCH = Math.max(1, A.batch || 6)
const units = []
for (const l of A.lanes) {
  const items = A.findings.filter(f => f.lane === l.key)
  if (!items.length) { log(`${l.key}: no findings in this pass — skipped`); continue }
  const last = units[units.length - 1]
  if (last && last.n + items.length <= BATCH) { last.lanes.push({ l, items }); last.n += items.length }
  else units.push({ lanes: [{ l, items }], n: items.length })
}
const unitName = (u) => u.lanes.map(x => x.l.key).join('+')


// the scribe and the nonce stamp: instruments/prelude.js

const results = await parallel(units.map(u => () => agent(
`${PREAMBLE}

YOUR UNIT: ${u.lanes.length} lane(s), ${u.n} finding(s) in all. Return one object per lane in \`lane_files\`, in the order below, each carrying exactly its own lane's verdicts and no others.

${u.lanes.map(x => `LANE ${x.l.key} — ${x.items.length} finding(s), write to ${outFile(`${x.l.nn}-${x.l.key}`)}:\n${x.items.map(fmt).join('\n')}`).join('\n\n')}

FIRST use the Write tool to save each lane's object as JSON to the path named above it, with schema_version=${A.schema_version}, lane=<that lane's key>, graded_sha256="${A.graded_sha256}", pass_nonce="${A.nonce}" (both copied EXACTLY — they bind your verdicts to this pass and this frozen finding set). THEN return {lane_files: [...]} in the same order.`,
  { label: `verify-act:${unitName(u)}`, phase: 'Verify act', schema: SCHEMA, agentType: 'general-purpose',
    ...(STRENGTH === 'economy' ? { model: ECONOMY } : {}) })
  .then(r => scribeAll(u.lanes.map((x, j) => {
    const obj = laneFile(r, x.l.key, j)
    return obj && { obj: stamped(obj, x.l.key), path: outFile(`${x.l.nn}-${x.l.key}`) }
  }).filter(Boolean), `scribe:${unitName(u)}`, 'Verify act').then(() => r))))

const written = [], dead = [], empty = [], truncated = [], mismatched = []
units.forEach((u, i) => u.lanes.forEach((x, j) => {
  const key = x.l.key
  const obj = laneFile(results[i], key, j)
  if (!obj) { dead.push(key); log(`${key}: DEAD — no object for this lane in its unit's return`); return }
  written.push(key)
  const got = (obj.verdicts || []).length
  if (got === 0) empty.push(key)
  // against the CLI's own count where it gave one (`lanes[].expected`, computed from the banked
  // findings before this script ran): comparing only with the unit's own list checks the input against
  // itself, so a lane the CLI expected more verdicts from reads as complete. The two counts are
  // checked against each other FIRST — a partition that dropped a finding and one that assigned it
  // twice both show up here, and neither is masked by taking the larger side.
  if (x.l.expected !== undefined && x.l.expected !== x.items.length) {
    mismatched.push(key)
    log(`${key}: PARTITION MISMATCH — the CLI expected ${x.l.expected} verdict(s), this unit carries ${x.items.length} finding(s); a finding was dropped, duplicated or mis-tagged`)
  }
  const want = x.l.expected === undefined ? x.items.length : x.l.expected
  if (got < want) { truncated.push(key); log(`${key}: UNDER-GRADED ${got}/${want} — the missing are UNVERIFIED, not clean`) }
  else if (got > want) { mismatched.push(key); log(`${key}: OVER-GRADED ${got}/${want} — a duplicate or invented verdict, not extra coverage`) }
  else log(`${key}: ${got}/${want} graded`)
}))
if (dead.length) log(`!! ${dead.length} DEAD lane(s): ${dead.join(', ')} — the pass is incomplete; gbg round grade will report them`)
if (mismatched.length) log(`!! ${mismatched.length} lane(s) whose verdict count does not match the CLI's: ${mismatched.join(', ')} — read them before grading`)
return { written, dead, empty, truncated, mismatched }
