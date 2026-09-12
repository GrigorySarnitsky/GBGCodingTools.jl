// /check-docs LANES — the judgment half of the battery: one lane per surface plus the cross-cutting
// lanes. Sources: IT check-docs/lanes.js (the fan-out), PF check-docs.md (Write-first banking, the
// one-home and cold-reader lanes, the `?name` substrate rule). Changes: surfaces and lanes arrive
// RESOLVED from args (engine lanes + lanes_extra + cross lanes, numbered by the CLI); no package string,
// path or round datum in the source; the lane file is the ONE finding shape of the fleet; the
// operational-claims lane runs on the docstring surface. PAYLOADS ARE FILES (Revision 9): the rendered
// policy, each lane's brief and each lane's claim checklist are files preflight wrote; args name their
// paths.
//
// Args (instruments/check-docs/schema.json): { schema_version, round, round_dir, repo,
//   preamble, lanes: [{nn, key, kind, brief_path, claims_path, files, anchor}], policy_path,
//   finding_types, models: {economy}, strength }
export const meta = {
  name: 'check-docs-lanes',
  description: 'The judgment lanes of /check-docs: per-surface checks plus the one-home, cold-reader and operational-claims lanes',
  phases: [{ title: 'Lanes' }],
}

// gbg:prelude
for (const k of ['round', 'round_dir', 'repo', 'lanes', 'preamble', 'models', 'policy_path', 'schema_version']) if (A[k] === undefined) throw new Error(`lanes.js: args.${k} is required`)
if (!A.lanes.length) throw new Error('lanes.js: an EMPTY roster is not a clean round — the CLI never launches one over nothing')
const TYPES = A.finding_types || ['math', 'notation', 'structure', 'citation', 'style', 'operational', 'currency', 'self-containment']

const SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    schema_version: { type: 'integer' },
    round: { type: 'string' },
    lane: { type: 'string' },
    candidates_found: { type: 'integer', description: 'distinct CLASSES weighed BEFORE the budget bound you, never the number of sites' },
    checked: { type: 'array', items: { type: 'string' }, description: 'the files (or pairs, or terms) you actually examined; REQUIRED and non-empty even with zero findings' },
    claims_checked: { type: 'array', description: 'one entry per item of your CLAIM CHECKLIST; an item left out reads as an item you did not check', items: {
      type: 'object', additionalProperties: false,
      properties: {
        claim: { type: 'string', description: 'the checklist item verbatim, its file and line included' },
        verdict: { type: 'string', enum: ['TRUE', 'FALSE', 'UNVERIFIABLE'] },
        evidence: { type: 'string', description: 'what settled it: the line of code, the register, or the measurement' },
      },
      required: ['claim', 'verdict', 'evidence'],
    } },
    findings: { type: 'array', items: {
      type: 'object', additionalProperties: false,
      properties: {
        type: { type: 'string', enum: TYPES, description: 'correct → math (or operational for a claim about what the call does); self-contained → self-containment; notation → notation; formatted → style; current → currency; cited → citation; family → structure' },
        severity: { type: 'string', enum: ['blocker', 'major', 'minor', 'nit'] },
        confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
        title: { type: 'string' },
        locations: { type: 'array', items: { type: 'string' }, description: 'file:line + the decisive quote (<= 25 words)' },
        contradicts: { type: 'string' },
        description: { type: 'string', description: 'the problem, verified against the source' },
        resolution_hint: { type: 'string', description: 'a concrete fix' },
      },
      required: ['type', 'severity', 'confidence', 'title', 'locations', 'description'],
    } },
  },
  required: ['schema_version', 'round', 'lane', 'candidates_found', 'checked', 'findings'],
}

const prompt = (l) => `${A.preamble}

FILES UNDER .gbg/ YOU MAY OPEN — exactly these, with Read, and nothing else under .gbg/ or ~/.gbg/:
    ${A.policy_path}    (THE RULEBOOK — authoritative; read it in full first)
    ${l.brief_path}     (YOUR LANE BRIEF — read it in full second; it is your procedure)${l.claims_path ? `
    ${l.claims_path}    (YOUR CLAIM CHECKLIST — read it third; every item needs a verdict in claims_checked[])` : ''}
Scope every search with \`--glob '!.gbg/**'\`.

GROUND TRUTH IS ${A.repo}/src (and ext/): verify every claim against the code and quote the decisive line.

YOUR LANE: ${l.key} (${l.kind})

SURFACE TO AUDIT (read every file fully):
${(l.files && l.files.length) ? l.files.map(f => `  ${A.repo}/${f}`).join('\n') : '  (the whole source surface, as your brief says)'}

When done, FIRST use the Write tool to save the structured object as JSON to:
  ${A.round_dir}/findings/${l.nn}-${l.key}.json
with schema_version=${A.schema_version}, round="${A.round}", lane="${l.key}". THEN return the same object. Report checked[] even when you found nothing — an empty checked[] reads as a dead lane.${l.claims_path ? ' Report one claims_checked[] entry per checklist item, whatever its verdict.' : ''}`


// the scribe, the model choice and the stamps: instruments/prelude.js
phase('Lanes')
const outcomes = await parallel(A.lanes.map(l => () => agent(prompt(l),
  { label: l.key, phase: 'Lanes', schema: SCHEMA, agentType: 'general-purpose', ...laneModel(l) })
  .then(r => scribe(r, `${A.round_dir}/findings/${l.nn}-${l.key}.json`, `scribe:${l.key}`, 'Lanes'))))

const written = [], dead = [], empty = [], truncated = []
outcomes.forEach((r, i) => {
  const l = A.lanes[i]
  if (!r) { dead.push(l.key); log(`${l.nn} ${l.key}: DEAD — no result`); return }
  written.push(l.key)
  const n = (r.findings || []).length
  if (n === 0) empty.push(l.key)
  if ((r.candidates_found || 0) > n) truncated.push(l.key)
  log(`${l.nn} ${l.key}: ${n} findings${n === 0 ? ' (EMPTY)' : ''}${(r.candidates_found || 0) > n ? ` (TRUNCATED ${r.candidates_found}→${n})` : ''}`)
})
if (dead.length) log(`!! ${dead.length} DEAD lane(s): ${dead.join(', ')} — bank will refuse; rerun them`)
return { written, dead, empty, truncated }
