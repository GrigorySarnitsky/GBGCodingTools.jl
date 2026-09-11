// THE RUBRIC AUDIT — for each finding a HUMAN read produced, which hat's rubric should have caught it, tested
// BLIND: run the hat's verbatim persona on the passage alone and see whether the finding comes out.
// Source: IT check-consistency/rubric_audit.js. Changes: generic `subject`; the defects and substrates
// arrive as TEXT in args (no .gbg/ reads); no package string in the source.
//
// Args: { schema_version, round, subject, hats: [{key, persona_path}], items: [{id, title, defect_path,
//         substrate_path}], personas_path, models: {economy}, out }  (Revision 9: texts are files)
export const meta = {
  name: 'rubric-audit',
  description: 'Test, blind, whether each panel hat’s own rubric produces the findings a human read found',
  phases: [{ title: 'Assign' }, { title: 'Blind run' }, { title: 'Score' }],
}

const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
for (const k of ['subject', 'hats', 'items', 'personas_path', 'models', 'out', 'round', 'schema_version']) if (A[k] === undefined) throw new Error(`rubric-audit.js: args.${k} is required`)
if (!A.hats.length || !A.items.length) throw new Error('rubric-audit.js: an empty audit is not a clean one')
const ECONOMY = A.models.economy

const ASSIGN_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: { assignments: { type: 'array', items: {
    type: 'object', additionalProperties: false,
    properties: {
      id: { type: 'string' },
      hats: { type: 'array', items: { type: 'string' }, description: 'the 1-2 hat keys whose OWN STATED RUBRIC covers this defect. [] if none does.' },
      why: { type: 'string', description: 'quote the clause of the persona that covers it, or say why none does. <= 40 words.' },
    }, required: ['id', 'hats', 'why'] } } },
  required: ['assignments'],
}
const REPORT_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: { findings: { type: 'array', items: {
    type: 'object', additionalProperties: false,
    properties: { where: { type: 'string' }, defect: { type: 'string' } }, required: ['where', 'defect'] } } },
  required: ['findings'],
}
const SCORE_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    id: { type: 'string' },
    verdict: { type: 'string', enum: ['CAUGHT', 'MISSED', 'PARTIAL'] },
    evidence: { type: 'string', description: 'the hat’s own words that match the defect, or "nothing reported on this" — <= 40 words' },
  }, required: ['id', 'verdict', 'evidence'],
}

// 1. ASSIGN — this agent MAY see the findings; it is not the one under test.
phase('Assign')
const CHUNK = 9
const chunks = []
for (let i = 0; i < A.items.length; i += CHUNK) chunks.push(A.items.slice(i, i + CHUNK))
const assigned = (await parallel(chunks.map((chunk, ci) => () => agent(
`You are mapping DEFECTS onto the RUBRICS that should have caught them, for a panel of documentation hats reviewing ${A.subject}. Below are the panel's personas, verbatim. For each finding, decide which hat's OWN STATED RUBRIC covers that defect.

Judge the persona AS WRITTEN. The question is not "which hat is nearest in topic" but "does this persona's text instruct a reader to look for this class of thing?" If none does, answer with an EMPTY list — that is the finding this audit exists to produce, and a forced assignment destroys it. Quote the clause you relied on.

PERSONAS: read them all, in full, from ${A.personas_path} (each opens with "### <key>"). That file and the defect files below are the ONLY files under .gbg/ you may open.

FINDINGS IN YOUR CHUNK (read each defect description from its file):
${chunk.map(f => `  ${f.id}: ${f.title} — ${f.defect_path}`).join('\n')}`,
  { label: `assign:${ci + 1}`, phase: 'Assign', schema: ASSIGN_SCHEMA, agentType: 'general-purpose' })))
).filter(Boolean).flatMap(r => r.assignments)

const byHat = {}
const unassigned = []
for (const a of assigned) {
  if (!a.hats || !a.hats.length) { unassigned.push(a); continue }
  for (const h of a.hats) (byHat[h] ||= []).push(a.id)
}
log(`assigned ${assigned.length} findings; ${unassigned.length} covered by NO persona`)
for (const u of unassigned) log(`   no rubric covers ${u.id}: ${u.why}`)

// 2. BLIND RUN + 3. SCORE, pipelined per hat. The blind hat sees only the substrate text.
phase('Blind run')
const itemById = Object.fromEntries(A.items.map(i => [i.id, i]))
const misassigned = Object.keys(byHat).filter(k => !A.hats.some(h => h.key === k)).map(k => ({ hat: k, ids: byHat[k] }))
if (misassigned.length) log(`!! ${misassigned.length} finding-group(s) assigned to no hat of this roster: ${misassigned.map(m => m.hat).join(', ')} — UNCOVERED, not clean`)
const hatKeys = Object.keys(byHat).filter(k => A.hats.some(h => h.key === k))
const results = await pipeline(
  hatKeys,
  (key) => {
    const personaPath = A.hats.find(h => h.key === key).persona_path
    const ids = byHat[key]
    return agent(`Read your persona in full from ${personaPath}; it is who you are for this review.

YOUR SUBSTRATE is a set of passages from ${A.subject}, one file each — read every one in full:
${ids.map(i => `  passage ${i}: ${itemById[i].substrate_path}`).join('\n')}

Apply your lens and REPORT EVERY DEFECT YOU FIND. Be specific about which passage and what. These are excerpts, so ignore anything that is merely cut off at an edge; judge what is present. Open no file other than those named here.`,
      { label: `blind:${key}`, phase: 'Blind run', schema: REPORT_SCHEMA, agentType: 'general-purpose' })
      // a dead agent must stay dead: wrapping it in a truthy object made stage 2's liveness check and
      // the `dead` tally below unreachable, so a hat that CRASHED read as a hat that found nothing
      .then(r => r && ({ key, ids, reported: r.findings || [] }))
  },
  (run) => {
    if (!run) return null
    const listing = run.reported.map((f, i) => `${i + 1}. [${f.where}] ${f.defect}`).join('\n') || '(reported nothing)'
    return parallel(run.ids.map(id => () => agent(
`You are scoring whether a documentation reviewer, working blind, found ONE specific known defect.

THE KNOWN DEFECT (${id} — ${itemById[id].title}): read its description from ${itemById[id].defect_path} (the only file you open).

WHAT THE REVIEWER REPORTED, having seen only the passage and never the defect description:
${listing}

Did the reviewer report THIS defect? CAUGHT — one of its items is this defect: same passage, same thing wrong with it. PARTIAL — it noticed the passage and something adjacent, but not the defect itself. MISSED — nothing in the list is this defect.

DEFAULT TO MISSED. Topical proximity is not catching it: "this sentence is unclear" does not catch "this sentence states a false quantifier".`,
      { label: `score:${run.key}-${id}`.slice(0, 60), phase: 'Score', schema: SCORE_SCHEMA, model: ECONOMY })
      .then(v => ({ ...v, id, hat: run.key }))))
  },
)

const scores = results.filter(Boolean).flat().filter(Boolean)
const best = {}
const rank = { CAUGHT: 2, PARTIAL: 1, MISSED: 0 }
for (const s of scores) if (!best[s.id] || rank[s.verdict] > rank[best[s.id].verdict]) best[s.id] = s
const tally = { CAUGHT: 0, PARTIAL: 0, MISSED: 0 }
for (const id of Object.keys(best)) tally[best[id].verdict]++
// a finding assigned ONLY to a hat this roster does not carry was read by nobody. It is MISSED, and it
// is named in the artifact, not only in a log line the reader of the JSON never sees.
const orphaned = [...new Set(misassigned.flatMap(m => m.ids))].filter(id => !best[id])
for (const id of orphaned) tally.MISSED++
log(`BEST-OF verdicts across assigned hats: ${JSON.stringify(tally)}; ${unassigned.length} findings NO persona claimed; ${orphaned.length} assigned only to a hat outside this roster`)
const gaps = Object.values(best).filter(s => s.verdict !== 'CAUGHT').concat(orphaned.map(id => (
  { id, hat: '(off-roster)', verdict: 'MISSED', evidence: 'assigned only to a hat this roster does not carry, so no hat ever read it' })))
for (const g of gaps) log(`   GAP ${g.id} [${g.hat}] ${g.verdict}: ${g.evidence}`)
await agent(`Use the Write tool to write EXACTLY this JSON to ${A.out} and return the single word done:\n\n${JSON.stringify({ schema_version: A.schema_version, round: A.round, tally, unassigned, misassigned, orphaned, gaps, scores, byHat }, null, 2)}`,
  { label: 'write-rubric-audit', phase: 'Score', model: ECONOMY })
return { written: Object.keys(best), dead: hatKeys.filter(k => !results[hatKeys.indexOf(k)]), empty: [], truncated: [] }
