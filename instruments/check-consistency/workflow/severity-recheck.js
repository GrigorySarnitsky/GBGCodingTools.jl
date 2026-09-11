// SEVERITY RE-CHECK — the blind recalibration pass. Source: IT check-consistency/severity_recheck.js.
// Changes: generic `subject` from args; items arrive as TEXT (a Workflow agent must not read .gbg/);
// also invoked by the audit-changes round before "serious" is counted; the result is Written to `out`.
//
// Args: { schema_version, round, out, subject, items: [{id}], items_path, models: {economy} }
//   The per-id blocks in items_path carry NO severity or confidence line — the CLI strips them; this
//   script trusts the caller's blinding (Revision 9: the texts are a file, not args). The comparison against the self-ratings happens in the CLI, which knows them.
export const meta = {
  name: 'severity-recheck',
  description: 'Blind re-rating of findings: fresh agents rate severity from the evidence alone',
  phases: [{ title: 'Re-rate' }],
}

const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
for (const k of ['out', 'items', 'items_path', 'subject', 'models', 'round', 'schema_version']) if (A[k] === undefined) throw new Error(`severity-recheck.js: args.${k} is required`)
if (!A.items.length) throw new Error('severity-recheck.js: an EMPTY item list must not report success')

const SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    id: { type: 'string' },
    severity: { type: 'string', enum: ['blocker', 'major', 'minor', 'nit'] },
    reason: { type: 'string', description: 'one sentence: what the rating turns on' },
  },
  required: ['id', 'severity', 'reason'],
}

const SCALE = `Severity scale:
- blocker — wrong or misleading: a reader acting on this text gets a wrong result or a wrong belief about the mathematics, the API, or a cost.
- major — a real defect a reader will plausibly hit: a contradiction between surfaces, a stale quantified claim, a missing load-bearing statement.
- minor — real but unlikely to mislead: localized wording, a gap with nearby correction, drift on a secondary surface.
- nit — cosmetic or judgment-flavored.
Rate what the EVIDENCE supports, not what the prose's tone suggests.`

phase('Re-rate')
const out = await parallel(A.items.map(it => () => agent(
`You are re-rating the severity of ONE review finding about ${A.subject}. You did not produce the finding and owe its author nothing. You see only the finding's evidence — no self-assigned rating, no fix status. Open ONE file and nothing else: ${A.items_path}, and read the block "--- ${it.id} ---" in it.

${SCALE}

THE FINDING: id ${it.id}, its block in the file above.

Return {id: "${it.id}", severity, reason}.`,
  { label: `rate:${it.id}`.slice(0, 60), phase: 'Re-rate', schema: SCHEMA, model: A.models.economy })))

// the id is the item's, stamped here, never the model's retyping
const ratings = out.map((r, i) => r && { ...r, id: A.items[i].id }).filter(Boolean)
const dead = A.items.length - ratings.length
await agent(`Use the Write tool to write EXACTLY this JSON to ${A.out} and return the single word done:\n\n${JSON.stringify({ schema_version: A.schema_version, round: A.round, ratings }, null, 2)}`,
  { label: 'write-ratings', phase: 'Re-rate', model: A.models.economy })
log(`re-rated ${ratings.length}/${A.items.length}${dead ? ` — ${dead} DEAD (unrated, not confirmed)` : ''}`)
return { written: ratings.map(r => r.id), dead: A.items.filter(i => !ratings.some(r => r.id === i.id)).map(i => i.id), empty: [], truncated: [] }
