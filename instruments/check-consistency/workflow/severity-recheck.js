// SEVERITY RE-CHECK — the blind recalibration pass. Source: IT check-consistency/severity_recheck.js.
// Changes: generic `subject` from args; items arrive as TEXT (a Workflow agent must not read .gbg/);
// also invoked by the audit-changes round before "serious" is counted; the result is Written to `out`.
//
// Args: { schema_version, round, out, subject, items: [{id}], items_path, models: {economy} }
//   Findings are rated BATCH (6) per agent: a constant, not an arg, since no CLI path sends one.
//   The per-id blocks in items_path carry NO severity or confidence line — the CLI strips them; this
//   script trusts the caller's blinding (Revision 9: the texts are a file, not args). The comparison against the self-ratings happens in the CLI, which knows them.
export const meta = {
  name: 'severity-recheck',
  description: 'Blind re-rating of findings: fresh agents rate severity from the evidence alone',
  phases: [{ title: 'Re-rate' }],
}

// gbg:prelude
for (const k of ['out', 'items', 'items_path', 'subject', 'models', 'round', 'schema_version']) if (A[k] === undefined) throw new Error(`severity-recheck.js: args.${k} is required`)
if (!A.items.length) throw new Error('severity-recheck.js: an EMPTY item list must not report success')

const SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: { ratings: { type: 'array', items: {
    type: 'object', additionalProperties: false,
    properties: {
      id: { type: 'string', description: 'the finding id EXACTLY as given' },
      severity: { type: 'string', enum: ['blocker', 'major', 'minor', 'nit'] },
      reason: { type: 'string', description: 'one sentence: what the rating turns on' },
    },
    required: ['id', 'severity', 'reason'] } } },
  required: ['ratings'],
}

const SCALE = `Severity scale:
- blocker — wrong or misleading: a reader acting on this text gets a wrong result or a wrong belief about the mathematics, the API, or a cost.
- major — a real defect a reader will plausibly hit: a contradiction between surfaces, a stale quantified claim, a missing load-bearing statement.
- minor — real but unlikely to mislead: localized wording, a gap with nearby correction, drift on a secondary surface.
- nit — cosmetic or judgment-flavored.
Rate what the EVIDENCE supports, not what the prose's tone suggests.`

// Several findings per agent. One agent per finding spent about 45k tokens a rating — 1.52M for the 33
// concerns of 2026-09-11-audit-changes-01, near what the audit lanes that found them cost. Each finding
// is still rated from its own block alone; only the reading of the scale is shared.
const BATCH = 6
const chunks = []
for (let i = 0; i < A.items.length; i += BATCH) chunks.push(A.items.slice(i, i + BATCH))

phase('Re-rate')
const out = await parallel(chunks.map((chunk, c) => () => agent(
`You are re-rating the severity of ${chunk.length} review finding(s) about ${A.subject}, each ON ITS OWN. You did not produce them and owe their authors nothing. You see only each finding's evidence — no self-assigned rating, no fix status. Open ONE file and nothing else: ${A.items_path}, and read in it the block "--- <id> ---" of each finding below.

${SCALE}

Rate each finding independently of the others: one finding's seriousness is never a reason to rate another up or down, and the order they are listed in means nothing.

THE FINDINGS:
${chunk.map(it => `  - ${it.id}`).join('\n')}

Return {ratings: [{id, severity, reason}]}: exactly one entry per id above, each id copied EXACTLY.`,
  { label: `rate:${c + 1}/${chunks.length}`, phase: 'Re-rate', schema: SCHEMA, model: A.models.economy })))

// an entry counts only for an id its agent was handed, once; an id no agent rated is DEAD, never confirmed
const ratings = []
out.forEach((r, c) => {
  const want = new Set(chunks[c].map(it => it.id))
  for (const x of (r && r.ratings) || []) if (want.has(x.id)) { ratings.push(x); want.delete(x.id) }
})
const dead = A.items.length - ratings.length
await agent(`Use the Write tool to write EXACTLY this JSON to ${A.out} and return the single word done:\n\n${JSON.stringify({ schema_version: A.schema_version, round: A.round, ratings }, null, 2)}`,
  { label: 'write-ratings', phase: 'Re-rate', model: A.models.economy })
log(`re-rated ${ratings.length}/${A.items.length}${dead ? ` — ${dead} DEAD (unrated, not confirmed)` : ''}`)
return { written: ratings.map(r => r.id), dead: A.items.filter(i => !ratings.some(r => r.id === i.id)).map(i => i.id), empty: [], truncated: [] }
