// VERIFY-ARCHITECTURE — the ARCHITECTURE-class fix verifier. The runtime and api-semantics classes need no
// agent: their witnesses re-run mechanically in the CLI. This covers only what no program can check:
// whether an architecture finding was resolved, or merely RELOCATED. It SEES the fix (the question is
// about an act). Source: IT bug-hunt/verify-fixes.js. Changes: renamed; vocabulary FIXED | RELOCATED |
// PARTIAL | ABSENT | NOT-A-DEFECT, default ABSENT; output bound to the pass by nonce and sha.
//
// Args: { schema_version, round, pass_dir, repo, range, nonce, graded_sha256, package,
//         findings: [{id, title}], findings_path, models: {economy} }  (the per-id blocks — location,
//         mechanism, claimed fix — are in the file, Revision 9)
export const meta = {
  name: 'verify-architecture',
  description: 'Audit whether each architecture-class fix eliminated the defect or merely relocated it',
  phases: [{ title: 'Audit' }],
}

const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
for (const k of ['round', 'pass_dir', 'repo', 'range', 'nonce', 'graded_sha256', 'findings', 'findings_path', 'package', 'models', 'schema_version']) if (A[k] === undefined) throw new Error(`verify-architecture.js: args.${k} is required`)
if (!A.findings.length) throw new Error('verify-architecture.js: an empty audit must not report success')

const SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    id: { type: 'string', description: 'the finding id EXACTLY as given' },
    verdict: { type: 'string', enum: ['FIXED', 'RELOCATED', 'PARTIAL', 'ABSENT', 'NOT-A-DEFECT'] },
    evidence: { type: 'string', description: 'the decisive quoted lines from the CURRENT tree, <= 70 words' },
    residue: { type: 'string', description: 'if not FIXED: exactly what still stands, with file:line' },
  },
  required: ['id', 'verdict', 'evidence'],
}

phase('Audit')
const out = await parallel(A.findings.map(f => () => agent(
`You are auditing ONE claimed fix to an architecture defect in ${A.package.name} at ${A.repo}. You are not the person who made it and you owe it no benefit of the doubt.

  finding:      ${f.id} — ${f.title}
  its record:   the block "--- ${f.id} ---" in ${A.findings_path} (location, second location, mechanism, claimed fix) — read it first; that file is the ONLY file under .gbg/ you may open
  the fix pass: \`git -C "${A.repo}" diff ${A.range}\`

READ THE CURRENT TREE (nothing else under .gbg/, never ~/.gbg/), not only the diff. Scope every search with \`--glob '!.gbg/**'\`: a bare recursive grep sweeps in a prior round's verdicts, which are an answer key to this one. Then decide between:

  FIXED        — the defect is gone. For a duplication that means ONE definition remains and every former site reaches it; quote the single definition and at least one call site.
  RELOCATED    — the shape changed but the defect survives: the duplicate moved to a new file, the literal became a differently-spelled literal, the two copies became two wrappers around two bodies. THIS IS THE VERDICT THE INSTRUMENT EXISTS TO CATCH, because a relocation reads exactly like a fix in a diff and exactly like a defect in the tree.
  PARTIAL      — one of the two sites was swept, the other stands. Name the one that stands.
  ABSENT       — you cannot find evidence the defect was addressed at all. THIS IS YOUR DEFAULT.
  NOT-A-DEFECT — on reading both sites, the original finding was wrong (the two blocks differ for a real reason). Say what the reason is.

Do NOT accept a comment, a docstring, or a decision-log entry as a fix: prose asserting that two copies are intentionally parallel leaves two copies that can drift. The test is what a maintainer would have to edit, and in how many places. Quote from the tree; an assertion with no quoted line is worth ABSENT.

Return {id: "${f.id}", verdict, evidence, residue}.`,
  { label: `arch:${f.id}`.slice(0, 60), phase: 'Audit', schema: SCHEMA, agentType: 'general-purpose' })))

// the id is the finding's, stamped here, never the model's retyping: a paraphrased id reads as a DEAD auditor
const verdicts = out.map((v, i) => v && { ...v, id: A.findings[i].id }).filter(Boolean)
const dead = A.findings.filter(f => !verdicts.some(v => v.id === f.id)).map(f => f.id)
const tally = {}
for (const v of verdicts) tally[v.verdict] = (tally[v.verdict] || 0) + 1
for (const v of verdicts) log(`${v.verdict.padEnd(13)} ${v.id}`)
log(`TALLY: ${JSON.stringify(tally)}`)
if (dead.length) log(`!! ${dead.length} auditor(s) DIED — those findings are UNVERIFIED, not clean`)
const file = { schema_version: A.schema_version, lane: 'architecture', graded_sha256: A.graded_sha256, pass_nonce: A.nonce, verdicts }
await agent(`Use the Write tool to write EXACTLY this JSON to ${A.pass_dir}/act/architecture.json and return the single word done:\n\n${JSON.stringify(file, null, 2)}`,
  { label: 'write-architecture-verdicts', phase: 'Audit', model: A.models.economy })
return { written: verdicts.map(v => v.id), dead, empty: [], truncated: [] }
