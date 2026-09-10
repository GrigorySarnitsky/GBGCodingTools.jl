// VERIFY-ACT — the adversarial auditor of the ACT: it SEES the diff. Sources: PF verify-fixes.js (per-lane
// over banked piles, mechanical demotion note), IT verify-fixes.js (eight verdicts, `question`, array
// class_surfaces, batches). Changes: the verdict object is {id, verdict, question, evidence,
// class_surfaces[{surface, swept, evidence}]}; output carries graded_sha256 and pass_nonce from args;
// `range` required; mode ∈ lanes|batches from args; NO demotion here (the CLI applies it); finding text
// arrives unabridged in a FILE named by args (Revision 9); no census (the CLI knows the denominator).
//
// Args: { schema_version, round, round_dir, pass_dir, repo, range, nonce, graded_sha256, mode,
//         lanes: [{nn, key, expected}], batches?: [[from,to]], findings: [{id, lane, n, title}], findings_path,
//         adjudicated_titles, rulebook_summary?, package, models: {economy}, strength }
export const meta = {
  name: 'verify-act',
  description: 'Grade a fix pass finding by finding, SEEING the diff: HONORED / ADJACENT / INSERTED / LINE-ONLY / NEW-DEFECT / SCOPE-CREEP / UNDONE / LAUNDERED',
  phases: [{ title: 'Verify act' }],
}

const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
for (const k of ['round', 'pass_dir', 'repo', 'range', 'nonce', 'graded_sha256', 'findings', 'findings_path', 'models']) {
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


// The scribe. A lane's own Write happens BEFORE its object is validated against SCHEMA, so the file can
// carry a value outside a closed set while the returned object cannot (the rc.1 round's built-html lane
// wrote `type: "formatted"` and was quarantined twice). The validated object is therefore written again,
// verbatim, by a cheap agent; the lane's own Write stays as the durable fallback when a return is lost.
const DONE = { type: 'object', properties: { done: { type: 'boolean' } }, required: ['done'] }
const scribe = (r, path, label, phase) => !r ? null :
  agent(`Use the Write tool to write EXACTLY this JSON to ${path} and return {done: true}. No other text.\n\n${JSON.stringify(r, null, 2)}`,
        { label, phase, schema: DONE, model: ECONOMY }).then(w => { if (!(w && w.done)) log(`${label}: the scribe did not confirm; the lane's own file stands`); return r })

const results = await parallel(units.map(u => () => u.items.length === 0 ? Promise.resolve({ __skip: true }) : agent(
`${PREAMBLE}

YOUR UNIT: ${u.lane} — ${u.items.length} finding(s); return exactly ${u.items.length} verdicts.

YOUR FINDING IDS (their full text is in ${A.findings_path}):
${u.items.map(fmt).join('\n')}

FIRST use the Write tool to save the structured object as JSON to ${outFile(u.name)} with schema_version=${A.schema_version}, lane="${u.lane}", graded_sha256="${A.graded_sha256}", pass_nonce="${A.nonce}" (both copied EXACTLY — they bind your verdicts to this pass and this frozen finding set). THEN return the same object.`,
  { label: `verify-act:${u.lane}`, phase: 'Verify act', schema: SCHEMA, agentType: 'general-purpose',
    ...(STRENGTH === 'economy' ? { model: ECONOMY } : {}) })
  .then(r => scribe(r, outFile(u.name), `scribe:${u.lane}`, 'Verify act'))))

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
