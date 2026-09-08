// /check-docs LANES — the judgment half of the battery: one lane per surface plus the cross-cutting
// lanes. Sources: IT check-docs/lanes.js (the fan-out), PF check-docs.md (Write-first banking, the
// family and cold-reader lanes, the `?name` substrate rule). Changes: surfaces and lanes arrive
// RESOLVED from args (engine lanes + lanes_extra + cross lanes, numbered by the CLI); no package string,
// path or round datum in the source; the rendered policy arrives as text; the lane file is the ONE
// finding shape of the fleet; the operational-claims lane runs on the docstring surface.
//
// Args (instruments/check-docs/schema.json): { schema_version, round, round_dir, repo, package,
//   preamble, lanes: [{nn, key, kind, brief, files, anchor}], policy: {file: text}, finding_types,
//   models: {economy}, strength }
export const meta = {
  name: 'check-docs-lanes',
  description: 'The judgment lanes of /check-docs: per-surface checks plus the family, cold-reader and operational-claims lanes',
  phases: [{ title: 'Lanes' }],
}

const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
for (const k of ['round', 'round_dir', 'repo', 'lanes', 'preamble', 'models']) if (A[k] === undefined) throw new Error(`lanes.js: args.${k} is required`)
const STRENGTH = A.strength === 'full' ? 'full' : 'economy'
const ECONOMY = A.models.economy
const TYPES = A.finding_types || ['math', 'notation', 'structure', 'citation', 'style', 'operational', 'currency', 'self-containment']

const SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    schema_version: { type: 'integer' },
    round: { type: 'string' },
    lane: { type: 'string' },
    candidates_found: { type: 'integer', description: 'distinct candidates weighed BEFORE the cap' },
    checked: { type: 'array', items: { type: 'string' }, description: 'the files (or pairs, or terms) you actually examined; REQUIRED and non-empty even with zero findings' },
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

const POLICY = A.policy ? Object.entries(A.policy).map(([f, t]) => `--- rendered policy file ${f} ---\n${t}`).join('\n\n') : ''

const prompt = (l) => `${A.preamble}

THE RULEBOOK (authoritative; given verbatim):
${POLICY}

GROUND TRUTH IS ${A.repo}/src (and ext/): verify every claim against the code and quote the decisive line. NEVER read anything under .gbg/ or ~/.gbg/; scope searches with \`--glob '!.gbg/**'\`.

YOUR LANE: ${l.key} (${l.kind})
${l.brief}

SURFACE TO AUDIT (read every file fully):
${(l.files && l.files.length) ? l.files.map(f => `  ${A.repo}/${f}`).join('\n') : '  (the whole source surface, as your brief says)'}

When done, FIRST use the Write tool to save the structured object as JSON to:
  ${A.round_dir}/findings/${l.nn}-${l.key}.json
with schema_version=${A.schema_version}, round="${A.round}", lane="${l.key}". THEN return the same object. Report checked[] even when you found nothing — an empty checked[] reads as a dead lane.`

phase('Lanes')
const outcomes = await parallel(A.lanes.map(l => () => agent(prompt(l),
  { label: l.key, phase: 'Lanes', schema: SCHEMA, agentType: 'general-purpose',
    ...((STRENGTH === 'economy' && !l.anchor) ? { model: ECONOMY } : {}) })))

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
