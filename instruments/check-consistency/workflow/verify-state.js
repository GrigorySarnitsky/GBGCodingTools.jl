// VERIFY-STATE — the BLIND auditor of the STATE: it never sees the diff. Sources: PF verify.js (blind,
// regenerated manuscripts), IT verify.js (PARTIAL/surviving_class, repo grep, the .claude exclusion).
// Changes: vocabulary PRESENT | PARTIAL | REGRESSED | ABSENT | NOT-A-DEFECT | UNCLEAR; grep scope
// `--glob '!.gbg/**'`; nonce + sha in the output; no census; finding text unabridged in args; the
// manuscripts and the finding texts arrive as FILES named by args (Revision 9).
//
// Args: { schema_version, round, pass_dir, repo, nonce, graded_sha256, lanes: [{nn, key, substrate,
//         expected}], findings: [{id, lane, n, title, seeded?}], findings_path, manuscripts?: {full: path, siteonly: path},
//         source_scope: [paths], adjudicated_titles, package, models: {economy}, strength }
export const meta = {
  name: 'verify-state',
  description: 'Per banked finding, does the defect exist in the corpus RIGHT NOW? Blind to the diff; default PRESENT',
  phases: [{ title: 'Verify state' }],
}

const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
for (const k of ['round', 'pass_dir', 'repo', 'nonce', 'graded_sha256', 'lanes', 'findings', 'findings_path', 'models']) {
  if (A[k] === undefined) throw new Error(`verify-state.js: args.${k} is required`)
}
const STRENGTH = A.strength === 'full' ? 'full' : 'economy'
const ECONOMY = A.models.economy
const SCOPE = A.source_scope || ['src', 'ext', 'docs/src', 'docs']

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
        id: { type: 'string' },
        verdict: { type: 'string', enum: ['PRESENT', 'PARTIAL', 'REGRESSED', 'ABSENT', 'NOT-A-DEFECT', 'UNCLEAR'] },
        surviving_class: { type: 'string', description: 'PARTIAL only: the other sites where the class is alive, file:line each' },
        evidence: { type: 'string', description: 'For PRESENT/PARTIAL/REGRESSED: where the defect lives now, quoted. For ABSENT/NOT-A-DEFECT: the searches run and what they returned. <= 60 words.' },
      },
      required: ['id', 'verdict', 'evidence'],
    } },
  },
  required: ['schema_version', 'lane', 'graded_sha256', 'pass_nonce', 'verdicts'],
}

const ADJ = (A.adjudicated_titles && A.adjudicated_titles.length)
  ? `\nSETTLED NON-DEFECTS: the owner has ruled these findings NOT to be defects; one of them is verdict NOT-A-DEFECT with "owner-adjudicated" as evidence:\n${A.adjudicated_titles.map(t => `  - ${t}`).join('\n')}\nNothing merely FIXED is listed, so absence proves nothing.\n`
  : ''

const PREAMBLE = `You are an ADVERSARIAL CLOSURE AUDITOR for ${A.package.name} — ${A.package.description}

A review panel banked findings against this package's documentation. A fix pass then ran. YOUR JOB IS NOT TO REVIEW THE FIX PASS — you are deliberately not shown it, and you must not go looking for it: no git log, no git diff, no commit messages. FILES UNDER .gbg/ YOU MAY OPEN: the findings file ${A.findings_path} (read the blocks for YOUR ids in full; each opens with "--- <id> ---") and the manuscript your substrate names below — nothing else under .gbg/ or ~/.gbg/ (earlier passes' verdicts live there — an answer key). Scope every search with \`--glob '!.gbg/**'\`. If a forbidden file surfaces anyway, disregard it and say so.

Answer ONE question per finding, from the CURRENT corpus alone: DOES THE DEFECT THIS FINDING DESCRIBES EXIST RIGHT NOW?

VERDICTS — the DEFAULT IS PRESENT; you must actively earn anything else:
- PRESENT      — the defect is still there. Quote it.
- PARTIAL      — fixed at the exact site the finding quoted, but the CLASS is alive elsewhere. THE MOST IMPORTANT VERDICT YOU CAN RETURN: whenever a finding describes something that could recur, SEARCH FOR OTHER INSTANCES before accepting a fix, and list them in surviving_class.
- REGRESSED    — the area was changed and the change introduced a NEW defect (a false statement, a broken link, a formula that no longer matches the code). Report the new defect.
- ABSENT       — genuinely gone. ADMISSIBLE ONLY WITH EVIDENCE: the searches you ran (spellings, synonyms, files) and that they came back empty.
- NOT-A-DEFECT — the original finding was itself wrong (a misreading of the rendered text; a claim false against the source). ADMISSIBLE ONLY WITH EVIDENCE quoting the line that refutes it.
- UNCLEAR      — you cannot find the passage or cannot tell. Never write ABSENT for this; UNCLEAR is the honest answer and it stays open.
${ADJ}
Names may have CHANGED since the finding was written: follow the concept, not the string — a defect that moved to a new name is PRESENT. Use grep aggressively; one Read is almost never enough for ABSENT. One verdict per finding id, in order; a shortfall is under-grading. Evidence <= 60 words. Do not editorialise, propose fixes, or rank.`

const substrateFor = (lane) => {
  if (A.manuscripts) {
    const text = lane.substrate === 'siteonly' ? A.manuscripts.siteonly : A.manuscripts.full
    return `THE CURRENT RENDERED SITE, regenerated after the fix pass, in ${text} (a reader-text manuscript; each page delimited by a "===== PAGE: <name> =====" banner) — this is your primary substrate, read it in full; the source under ${A.repo} (${SCOPE.join(', ')}) is available for confirmation.`
  }
  return `THE CURRENT SOURCE under ${A.repo}: ${SCOPE.join(', ')}. Ground truth for a documentation finding is the source text; the built site under ${A.repo}/docs/build is available for rendering questions.`
}
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
const fmt = (f) => `  ${f.id} (lane ${f.lane}, #${f.n}) — ${f.title}${probe(f.id)}`

phase('Verify state')
const units = A.lanes.map(l => ({ lane: l, items: A.findings.filter(f => f.lane === l.key) }))

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

YOUR LANE: ${u.lane.key} — ${u.items.length} finding(s); return exactly ${u.items.length} verdicts.

YOUR SUBSTRATE:
${substrateFor(u.lane)}

YOUR FINDING IDS (their full text is in ${A.findings_path}):
${u.items.map(fmt).join('\n')}

FIRST use the Write tool to save the structured object as JSON to ${A.pass_dir}/state/${u.lane.nn}-${u.lane.key}.json with schema_version=${A.schema_version}, lane="${u.lane.key}", graded_sha256="${A.graded_sha256}", pass_nonce="${A.nonce}" (copied EXACTLY). THEN return the same object.`,
  { label: `verify-state:${u.lane.key}`, phase: 'Verify state', schema: SCHEMA, agentType: 'general-purpose',
    ...(STRENGTH === 'economy' ? { model: ECONOMY } : {}) })
  .then(r => scribe(r, `${A.pass_dir}/state/${u.lane.nn}-${u.lane.key}.json`, `scribe:${u.lane.key}`, 'Verify state'))))

const written = [], dead = [], empty = [], truncated = []
results.forEach((r, i) => {
  const u = units[i]
  if (r && r.__skip) { log(`${u.lane.key}: no findings — skipped`); return }
  if (!r) { dead.push(u.lane.key); log(`${u.lane.key}: DEAD — no result`); return }
  written.push(u.lane.key)
  const got = (r.verdicts || []).length
  if (got === 0) empty.push(u.lane.key)
  if (got < u.items.length) { truncated.push(u.lane.key); log(`${u.lane.key}: UNDER-GRADED ${got}/${u.items.length}`) }
  else log(`${u.lane.key}: ${got}/${u.items.length} adjudicated`)
})
if (dead.length) log(`!! ${dead.length} DEAD lane(s): ${dead.join(', ')} — the pass is incomplete`)
return { written, dead, empty, truncated }
