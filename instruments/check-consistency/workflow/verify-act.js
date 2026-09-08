// VERIFY-ACT — the adversarial auditor of the ACT: it SEES the diff. Sources: PF verify-fixes.js (per-lane
// over banked piles, mechanical demotion note), IT verify-fixes.js (eight verdicts, `question`, array
// class_surfaces, batches). Changes: the verdict object is {id, verdict, question, evidence,
// class_surfaces[{surface, swept, evidence}]}; output carries graded_sha256 and pass_nonce from args;
// `range` required; mode ∈ lanes|batches from args; NO demotion here (the CLI applies it); finding text
// arrives unabridged in args; no census (the CLI knows the denominator).
//
// Args: { schema_version, round, round_dir, pass_dir, repo, range, nonce, graded_sha256, mode,
//         lanes: [{nn, key, expected}], batches?: [[from,to]], findings: [{id, lane, n, title, text}],
//         adjudicated_titles, rulebook_summary?, package, models: {economy}, strength }
export const meta = {
  name: 'verify-act',
  description: 'Grade a fix pass finding by finding, SEEING the diff: HONORED / ADJACENT / INSERTED / LINE-ONLY / NEW-DEFECT / SCOPE-CREEP / UNDONE / LAUNDERED',
  phases: [{ title: 'Verify act' }],
}

const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
for (const k of ['round', 'pass_dir', 'repo', 'range', 'nonce', 'graded_sha256', 'findings', 'models']) {
  if (A[k] === undefined) throw new Error(`verify-act.js: args.${k} is required — without a range a lane grades edits it cannot see`)
}
const MODE = A.mode === 'batches' ? 'batches' : 'lanes'
const STRENGTH = A.strength === 'full' ? 'full' : 'economy'
const ECONOMY = A.models.economy

const SCHEMA = {
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

const ADJ = (A.adjudicated_titles && A.adjudicated_titles.length)
  ? `\nBEFORE grading anything UNDONE, know that the owner has ruled these findings NOT to be defects (they were deliberately left alone; grading one UNDONE is the one verdict that looks identical to real neglect):\n${A.adjudicated_titles.map(t => `  - ${t}`).join('\n')}\nNothing merely FIXED is listed, so absence from this list proves nothing.\n`
  : ''

const PREAMBLE = `You are an ADVERSARIAL FIX AUDITOR for ${A.package.name} — ${A.package.description}

A review panel banked findings against this package's documentation, and a fix pass then ran. YOU AUDIT THE FIXES. Your allegiance is to the findings, not to the fixer: assume a fix is deficient until its evidence convinces you otherwise. You are NOT re-reviewing the docs and you are NOT looking for new defects.

You have: (1) THE FINDINGS, each given below UNABRIDGED — the text is ground truth for what was asked; (2) THE DIFF — run \`git -C "${A.repo}" log --stat ${A.range}\` and \`git -C "${A.repo}" diff ${A.range}\` (scope with \`-- <path>\` when large). The ACT is what you audit, so how the text changed matters as much as what it now says; (3) THE CURRENT CORPUS under ${A.repo} (src/, ext/, docs/). NEVER read anything under .gbg/ or ~/.gbg/, and scope every search with \`--glob '!.gbg/**'\`: earlier passes' verdicts live there and they are an answer key.

FOR EACH FINDING, ask FOUR questions in order and stop at the first failure:
  (1) FIDELITY — did the ask land, and land EVERYWHERE it applies? A synonym is not the fix asked for.
  (2) STRATEGY — the right KIND of repair? Hunt (a) FIX BY INSERTION — the flagged text still there with correct text appended beside it; (b) LINE, NOT CLASS — the flagged instance fixed and the same defect surviving elsewhere; (c) WRONG SURFACE — a docstring reworded to explain away a defect that lives in the code.
  (3) IMPLEMENTATION — is the replacement text CORRECT? Verify formulas against the source; a fix can honour the instruction and still be false.
  (4) SCOPE — anything changed that was not asked for; a flagged TERM carried through a rewrite because it was not the literal flagged word.

VERDICTS — HONORED is the ONLY verdict that must be earned by evidence; prefer the others when in doubt:
  HONORED     — the ask landed, by the right means, correctly, without creep — AND class_surfaces enumerates, FROM THE FINDING'S OWN TEXT, every other surface carrying the same class, each with whether the diff swept it and a file:line. A class swept to zero still lists what you checked. Never grade HONORED on a plausible story; grade it on hunks you can quote.
  ADJACENT    — something was done, but not what was asked.
  INSERTED    — repaired by appending; the flagged text survives.
  LINE-ONLY   — the instance is fixed, the class is alive. Name the surviving sites. THIS IS THE MOST COMMON REAL OUTCOME.
  NEW-DEFECT  — the fix introduced a fresh defect.
  SCOPE-CREEP — unasked changes, or a flagged term carried through a rewrite.
  UNDONE      — nothing in the diff addresses this finding.
  LAUNDERED   — closed by DECLARING it acceptable ("by design", "for symmetry", "already recorded") rather than fixed or put to the owner. An assistant-authored dismissal is LAUNDERED however reasonable it reads; only the owner's ledger entry closes a finding without a fix.
${ADJ}
DEFAULT TO THE UNFAVOURABLE VERDICT. Grade EVERY finding you are given, in order, one verdict per id; a shortfall is under-grading and the missing ones are UNVERIFIED, not clean. Do not propose fixes. Do not rank. Do not soften.`

const fmt = (f) => `--- ${f.id} (lane ${f.lane}, #${f.n}) — ${f.title} ---\n${f.text}`
const outFile = (name) => `${A.pass_dir}/act/${name}.json`

phase('Verify act')
let units
if (MODE === 'batches') {
  const batches = A.batches || []
  if (!batches.length) throw new Error('mode=batches needs a non-empty batches array covering EVERY finding')
  units = batches.map(([from, to]) => {
    const items = A.findings.slice(from - 1, to)
    return { name: `batch-${from}-${to}`, lane: `batch-${from}-${to}`, items }
  })
} else {
  units = A.lanes.map(l => ({ name: `${l.nn}-${l.key}`, lane: l.key, items: A.findings.filter(f => f.lane === l.key), expected: l.expected }))
}

const results = await parallel(units.map(u => () => u.items.length === 0 ? Promise.resolve({ __skip: true }) : agent(
`${PREAMBLE}

YOUR UNIT: ${u.lane} — ${u.items.length} finding(s); return exactly ${u.items.length} verdicts.

THE FINDINGS:
${u.items.map(fmt).join('\n\n')}

FIRST use the Write tool to save the structured object as JSON to ${outFile(u.name)} with schema_version=${A.schema_version}, lane="${u.lane}", graded_sha256="${A.graded_sha256}", pass_nonce="${A.nonce}" (both copied EXACTLY — they bind your verdicts to this pass and this frozen finding set). THEN return the same object.`,
  { label: `verify-act:${u.lane}`, phase: 'Verify act', schema: SCHEMA, agentType: 'general-purpose',
    ...(STRENGTH === 'economy' ? { model: ECONOMY } : {}) })))

const written = [], dead = [], empty = [], truncated = []
results.forEach((r, i) => {
  const u = units[i]
  if (r && r.__skip) { log(`${u.lane}: no findings in this unit — skipped`); return }
  if (!r) { dead.push(u.lane); log(`${u.lane}: DEAD — no result`); return }
  written.push(u.lane)
  const got = (r.verdicts || []).length
  if (got === 0) empty.push(u.lane)
  if (got < u.items.length) { truncated.push(u.lane); log(`${u.lane}: UNDER-GRADED ${got}/${u.items.length} — the missing are UNVERIFIED, not clean`) }
  else log(`${u.lane}: ${got}/${u.items.length} graded`)
})
if (dead.length) log(`!! ${dead.length} DEAD unit(s): ${dead.join(', ')} — the pass is incomplete; gbg round grade will report them`)
return { written, dead, empty, truncated }
