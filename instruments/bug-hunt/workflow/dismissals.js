// THE DISMISSAL AUDIT — re-examine every finding that was closed WITHOUT a fix: a hunt's NOT-REPRODUCED /
// WITNESS-WRONG / NOT-A-DEFECT / ALREADY-COVERED verdicts, a refusal in a disposition record, and every
// finding-scope ledger entry recorded after the round opened — for EVERY instrument's close. Source: PF
// bug-hunt/dismissals.js (`complete = dead == 0 && reopened == []`, the third shape). Changes: the
// package-specific postmortem examples removed; items arrive as text; the result is Written to `out`.
//
// Args: { schema_version, round, repo, package, items: [{id, title}], items_path, out, models: {economy} }
//   (the per-id blocks — location, claim, verdict, reasoning — are in items_path, Revision 9)
export const meta = {
  name: 'dismissals',
  description: 'Re-examine every candidate a round dismissed or adjudicated, defaulting to "the dismissal is unsafe"',
  phases: [{ title: 'Audit dismissals' }],
}

const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
for (const k of ['repo', 'items', 'items_path', 'out', 'package', 'models', 'items_sha', 'round']) if (A[k] === undefined) throw new Error(`dismissals.js: args.${k} is required`)
if (!A.items.length) throw new Error('dismissals.js: an EMPTY audit is not a clean one — the CLI does not invoke this over nothing')

const SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    id: { type: 'string' },
    verdict: { type: 'string', enum: ['DISMISSAL-SOUND', 'UNSAFE', 'DISMISSAL-WRONG'] },
    evidence: { type: 'string', description: 'quoted lines from the CURRENT tree that settle it, <= 70 words' },
    what_would_bite: { type: 'string', description: 'if UNSAFE or DISMISSAL-WRONG: the concrete call, input or reader path that misbehaves' },
  },
  required: ['id', 'verdict', 'evidence'],
}

phase('Audit dismissals')
const out = await parallel(A.items.map(d => () => agent(
`A review round over ${A.package.name} — ${A.package.description} — raised this finding and then DISMISSED it without a fix. You are re-examining the DISMISSAL. You are not the agent who made it and you owe it nothing.

  id:         ${d.id}
  claim:      ${d.title}
  its record: the block "--- ${d.id} ---" in ${A.items_path} (location, mechanism, the verdict and its reasoning) — read it first; that file is the ONLY file under .gbg/ you may open

Read the CURRENT tree at ${A.repo} (nothing else under .gbg/, never ~/.gbg/) and decide:

  DISMISSAL-SOUND — the claim is genuinely not a defect and you can SHOW why from the code or the text. Quote the lines that settle it.
  UNSAFE          — you cannot establish that it is not a defect. THIS IS YOUR DEFAULT.
  DISMISSAL-WRONG — it IS a defect. Name the call, input, or reader path that misbehaves.

WHY THE DEFAULT IS UNSAFE: a wrongly-dismissed defect is silent and permanent, because nothing revisits a filed dismissal; a wrongly-upheld one costs one more look. "I could not confirm it is fine" is UNSAFE, never waved through.

THREE DISMISSAL SHAPES THAT WERE WRONG BEFORE ON REAL CORPORA:
  * "correct on the current tree — a test-coverage gap, not a runtime defect." Check the CLAIM, not whether a test exists. One such dismissal hid a blocker.
  * "sanctioned by the contract / deliberate by design." A recorded arrangement is not evidence that it is right. If a sibling operation handles the same situation differently, that asymmetry IS the finding. But the package's recorded DELIBERATE ABSENCES are design: ${(A.package.deliberate_absences || []).join('; ') || '(none recorded)'} — check the docstring before treating an absence as a defect.
  * "the suite would catch it." Only true if a test actually asserts it. Grep for the assertion.

Do not hunt for anything else. Your scope is this one claim.`,
  { label: `dismissal:${d.id}`.slice(0, 60), phase: 'Audit dismissals', schema: SCHEMA, agentType: 'general-purpose' })))

const verdicts = out.filter(Boolean)
const dead = A.items.filter(i => !verdicts.some(v => v.id === i.id)).map(i => i.id)
const tally = {}
for (const v of verdicts) tally[v.verdict] = (tally[v.verdict] || 0) + 1
for (const v of verdicts) log(`${v.verdict.padEnd(16)} ${v.id} ${(A.items.find(i => i.id === v.id) || {}).title || ''}`.slice(0, 120))
log(`TALLY: ${JSON.stringify(tally)}`)
if (dead.length) log(`!! ${dead.length} auditor(s) DIED — those dismissals are UNAUDITED, not upheld`)
const reopened = verdicts.filter(v => v.verdict !== 'DISMISSAL-SOUND').map(v => v.id)
if (reopened.length) log(`!! ${reopened.length} dismissal(s) DO NOT HOLD — close will refuse: ${reopened.join(', ')}`)
await agent(`Use the Write tool to write EXACTLY this JSON to ${A.out} and return the single word done:\n\n${JSON.stringify({ schema_version: A.schema_version, round: A.round, items_sha: A.items_sha, tally, verdicts, reopened, dead, complete: dead.length === 0 && reopened.length === 0 }, null, 2)}`,
  { label: 'write-dismissals', phase: 'Audit dismissals', model: A.models.economy })
return { written: verdicts.map(v => v.id), dead, empty: [], truncated: [] }
