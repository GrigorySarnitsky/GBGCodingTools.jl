// /audit-changes — WERE THESE EDITS JUSTIFIED, AND DID THEY SILENTLY CHANGE BEHAVIOUR? Sources: IT
// audit-changes/audit.js (`base` required, checked[], candidates_found, pin-at-base,
// test-in-diff), PF audit-changes/audit.js (previously_worked, strength honoured). Changes: the lanes
// arrive from the catalogue via args (briefs with the guard symbols and invariants substituted);
// previously_worked ∈ yes|no|unknown REQUIRED on the behaviour-change lane; the diffstat, the claims and
// the covered paths from args (the "605 lines…" preamble and the round-specific candidate lists are
// gone); severity is the unified blocker|major|minor|nit; meta.name = 'audit-changes'. PAYLOADS ARE
// FILES (Revision 9): the diff, the diffstat, the claims and each lane's brief are files preflight
// wrote under the round's scratch; args name their paths.
//
// Args (instruments/audit-changes/schema.json): { schema_version, round, round_dir, repo, package,
//   base, head, covered, diff_path, diffstat_path, claims_path, lanes: [{nn, key, kind,
//   brief_path, anchor}], models: {economy}, strength }
export const meta = {
  name: 'audit-changes',
  description: 'Audit a change set: was each edit justified, and did it silently alter behaviour that worked before?',
  phases: [{ title: 'Audit' }],
}

// gbg:prelude
for (const k of ['round', 'round_dir', 'repo', 'base', 'head', 'lanes', 'package', 'models', 'diff_path', 'schema_version']) if (A[k] === undefined) throw new Error(`audit.js: args.${k} is required (base is the commit the norm is read at)`)
if (!A.lanes.length) throw new Error('audit.js: an EMPTY roster is not a clean audit — the CLI never launches one over nothing')

const SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    schema_version: { type: 'integer' },
    round: { type: 'string' },
    lane: { type: 'string' },
    verdict: { type: 'string', enum: ['CLEAN', 'CONCERNS'], description: 'CLEAN only if you found nothing in your lens worth the owner reading' },
    checked: { type: 'array', items: { type: 'string' }, description: 'REQUIRED, especially when CLEAN: what you actually examined, item by item (the specific hunks, names, guards or calls). CLEAN with an empty or vague list is indistinguishable from a lane that did nothing, and is read as such.' },
    candidates_found: { type: 'integer', description: 'how many candidates you found BEFORE the reporting cap' },
    findings: { type: 'array', items: {
      type: 'object', additionalProperties: false,
      properties: {
        type: { type: 'string', enum: ['operational', 'math', 'structure', 'currency', 'style', 'notation', 'citation', 'self-containment'], description: 'operational for a behaviour, contract or guard concern; math for a numerical one; currency for a stale-prose one' },
        severity: { type: 'string', enum: ['blocker', 'major', 'minor', 'nit'] },
        confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
        title: { type: 'string' },
        locations: { type: 'array', items: { type: 'string' }, description: 'file:line and the hunk' },
        before: { type: 'string', description: 'what the code did BEFORE, quoted from the diff' },
        after: { type: 'string', description: 'what it does NOW, quoted' },
        why_it_matters: { type: 'string', description: 'who is affected and how — concrete' },
        justified: { type: 'string', enum: ['yes', 'no', 'unclear'], description: 'was this change warranted by a defect, or wider than the defect required?' },
        previously_worked: { type: 'string', enum: ['yes', 'no', 'unknown'], description: 'REQUIRED on the behaviour-change lane: did a concrete input that was valid BEFORE now behave differently? Name it in why_it_matters. unknown is gated like yes.' },
        description: { type: 'string' },
        evidence: { type: 'string', description: 'quoted from the diff or the tree — an assertion with no quotation is not a concern' },
      },
      required: ['type', 'severity', 'confidence', 'previously_worked', 'title', 'locations', 'before', 'after', 'why_it_matters', 'justified', 'description', 'evidence'],
    } },
  },
  required: ['schema_version', 'round', 'lane', 'verdict', 'checked', 'candidates_found', 'findings'],
}

// One item schema, but `previously_worked` is REQUIRED only on the lane the design asks it of
// (PROTOCOL.md, the behaviour-change brief). Requiring it of all thirteen would make every other lane
// answer a question its lens never looks at.
const schemaFor = (lane) => {
  const s = JSON.parse(JSON.stringify(SCHEMA))
  if (lane.key !== 'behaviour-change') {
    const req = s.properties.findings.items.required
    s.properties.findings.items.required = req.filter(k => k !== 'previously_worked')
  }
  return s
}

const permitted = (lane) => [A.diff_path, A.diffstat_path, lane.brief_path, ...(lane.key === 'claim-versus-edit' && A.claims_path ? [A.claims_path] : [])].filter(Boolean)
const PREAMBLE = (lane) => `You are auditing a CHANGE SET in ${A.package.name} — ${A.package.description}

FILES UNDER .gbg/ YOU MAY OPEN — exactly these, with Read, and nothing else under .gbg/ or ~/.gbg/. Scope every search with \`--glob '!.gbg/**'\`: a bare recursive grep sweeps in a prior round's verdicts, which are an answer key to this one.
The files:
${permitted(lane).map(p => `    ${p}`).join('\n')}
THE DIFF: base ${A.base} → head ${A.head}, over ${(A.covered || []).join(', ')} — read it IN FULL and FIRST from ${A.diff_path} (the diffstat is ${A.diffstat_path || 'not written'}); \`git -C "${A.repo}" diff ${A.base}..${A.head} -- <path>\` scopes it when you need one file.
THE CODE: ${A.repo} — read the current files, not only the diff.

PIN THE NORM AT BASE, NOT AT HEAD. The docstrings, comments and tests you would naturally treat as the standard were themselves EDITED in the window you are auditing — the audited party rewrote the description of the thing you are auditing. When you need to know what the package PROMISED, read it at base: \`git -C "${A.repo}" show ${A.base}:<file>\`. A contract quietly rewritten to match a changed behaviour is the defect, not the baseline.

THE ORACLE IS PART OF THE CHANGE SET. \`test/\` is in this diff. A fix that also edited the test that would have caught it, or a frozen baseline re-baselined in the same commit, is exactly the shape that certifies itself. Treat every test/ and baseline change as a claim to be checked, never as the standard.

YOUR QUESTION IS NOT "what is wrong with this code". It is: WAS EACH CHANGE JUSTIFIED, AND DID IT SILENTLY ALTER WHAT THE PACKAGE DOES FOR INPUT THAT WAS PREVIOUSLY VALID? An edit is a problem for this audit if it is WIDER than the defect it claims to fix, if it changes a computed result, if it rejects usage that used to work, or if it alters a public contract — even when the underlying fix was correct. A finding that would have been true before the diff belongs to /bug-hunt, not here.

READ THE CODE FIRST AND FORM YOUR VERDICT BEFORE reading any commit message. The author's commit messages are CLAIMS about these edits, not evidence about them (only the claim-versus-edit lane reads them first). The package's deliberate absences are design, not defects: ${(A.package.deliberate_absences || []).join('; ') || '(none recorded)'}.

AUDIT ONLY. Do not edit, create or delete any file. Quote the before and after from the diff for every finding. Return CLEAN honestly if your lens turns up nothing — with a non-empty checked[]. A lane returning CONCERNS with an empty findings array is a contradiction and is read as dead. Cap: your 8 most substantial findings; report candidates_found.`

const CLAIMS = A.claims_path ? `\n\nTHE CLAIMS (the commit messages of the audited range) are in ${A.claims_path} — your lens reads them, after the code.` : ''


// the scribe and the model choice: instruments/prelude.js
phase('Audit')
const results = await parallel(A.lanes.map(lane => () => agent(
  `${PREAMBLE(lane)}\n\nYOUR LENS: ${lane.key} — read your brief in full from ${lane.brief_path}; it is your procedure.${lane.key === 'claim-versus-edit' ? CLAIMS : ''}\n\nWhen done, FIRST use the Write tool to save the structured object as JSON to ${A.round_dir}/findings/${lane.nn}-${lane.key}.json with schema_version=${A.schema_version}, round="${A.round}", lane="${lane.key}". THEN return the same object.`,
  { label: `audit:${lane.key}`, phase: 'Audit', schema: schemaFor(lane), agentType: 'general-purpose', ...laneModel(lane) })
  .then(r => scribe(r, `${A.round_dir}/findings/${lane.nn}-${lane.key}.json`, `scribe:${lane.key}`, 'Audit'))))

const written = [], dead = [], empty = [], truncated = []
results.forEach((r, i) => {
  const lane = A.lanes[i]
  if (!r) { dead.push(lane.key); log(`${lane.nn} ${lane.key}: DEAD — that lens is UNAPPLIED, not clean`); return }
  written.push(lane.key)
  const n = (r.findings || []).length
  if (n === 0) empty.push(lane.key)
  if ((r.candidates_found || 0) > n) truncated.push(lane.key)
  log(`${lane.nn} ${lane.key}: ${r.verdict} (${n})${(r.candidates_found || 0) > n ? ` TRUNCATED ${r.candidates_found}→${n}` : ''}`)
})
if (dead.length) log(`!! ${dead.length} DEAD lane(s): ${dead.join(', ')}`)
return { written, dead, empty, truncated }
