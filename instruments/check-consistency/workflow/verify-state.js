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

// gbg:prelude
for (const k of ['round', 'pass_dir', 'repo', 'nonce', 'graded_sha256', 'lanes', 'findings', 'findings_path', 'models', 'schema_version', 'package']) {
  if (A[k] === undefined) throw new Error(`verify-state.js: args.${k} is required`)
}
if (!A.findings.length) throw new Error('verify-state.js: nothing in scope to read — the CLI launches the state verifier only over a non-empty scope')
const SCOPE = A.source_scope || ['src', 'ext', 'docs/src', 'docs']

const LANE_SCHEMA = {
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

// One agent reads SEVERAL lanes of the same substrate, so a shared file is read once per unit rather than
// once per lane; each lane still gets its own file, which is what `grade` reads, and its own object here.
const SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: { lane_files: { type: 'array', items: LANE_SCHEMA, description: 'one object per lane of your unit, in the order the prompt lists them' } },
  required: ['lane_files'],
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
// often as the defect's, so a surviving quote does not settle that the defect is still there and a
// vanished one does not settle that the class is gone. Absent (an older CLI), the line is simply omitted.
const probe = (id) => {
  const p = A.quote_probe && A.quote_probe[id]
  if (!p) return ''
  return p.length ? `\n      [computed] its quoted text still stands in: ${p.join(', ')}`
                  : `\n      [computed] its quoted text is gone from every file it names`
}
const fmt = (f) => `  ${f.id} (lane ${f.lane}, #${f.n}) — ${f.title}${probe(f.id)}`

phase('Verify state')
// Lanes are grouped into units of at most `batch` findings (6 by default), and only lanes that read the
// same substrate are grouped, since the substrate is what a unit's prompt names once.
const BATCH = Math.max(1, A.batch || 6)
const units = []
for (const l of A.lanes) {
  const items = A.findings.filter(f => f.lane === l.key)
  if (!items.length) { log(`${l.key}: no findings — skipped`); continue }
  const last = units[units.length - 1]
  const sameSubstrate = last && (last.lanes[0].l.substrate || '') === (l.substrate || '')
  if (sameSubstrate && last.n + items.length <= BATCH) { last.lanes.push({ l, items }); last.n += items.length }
  else units.push({ lanes: [{ l, items }], n: items.length })
}
const unitName = (u) => u.lanes.map(x => x.l.key).join('+')

// the scribe and the nonce stamp: instruments/prelude.js

const stateFile = (l) => `${A.pass_dir}/state/${l.nn}-${l.key}.json`

const results = await parallel(units.map(u => () => agent(
`${PREAMBLE}

YOUR UNIT: ${u.lanes.length} lane(s), ${u.n} finding(s) in all. Return one object per lane in \`lane_files\`, in the order below, each carrying exactly its own lane's verdicts and no others.

YOUR SUBSTRATE:
${substrateFor(u.lanes[0].l)}

${u.lanes.map(x => `LANE ${x.l.key} — ${x.items.length} finding(s), write to ${stateFile(x.l)}:\n${x.items.map(fmt).join('\n')}`).join('\n\n')}

FIRST use the Write tool to save each lane's object as JSON to the path named above it, with schema_version=${A.schema_version}, lane=<that lane's key>, graded_sha256="${A.graded_sha256}", pass_nonce="${A.nonce}" (copied EXACTLY). THEN return {lane_files: [...]} in the same order.`,
  { label: `verify-state:${unitName(u)}`, phase: 'Verify state', schema: SCHEMA, agentType: 'general-purpose',
    ...(STRENGTH === 'economy' ? { model: ECONOMY } : {}) })
  .then(r => scribeAll(u.lanes.map((x, j) => {
    const obj = laneFile(r, x.l.key, j)
    return obj && { obj: stamped(obj, x.l.key), path: stateFile(x.l) }
  }).filter(Boolean), `scribe:${unitName(u)}`, 'Verify state').then(() => r))))

const written = [], dead = [], empty = [], truncated = [], mismatched = []
units.forEach((u, i) => u.lanes.forEach((x, j) => {
  const key = x.l.key
  const obj = laneFile(results[i], key, j)
  if (!obj) { dead.push(key); log(`${key}: DEAD — no object for this lane in its unit's return`); return }
  written.push(key)
  const got = (obj.verdicts || []).length
  if (got === 0) empty.push(key)
  // the CLI's own count where it gave one, not the unit's: comparing got with the unit's own list checks
  // the input against itself, and a duplicated or invented verdict then reads as extra coverage
  const want = x.l.expected === undefined ? x.items.length : x.l.expected
  if (x.l.expected !== undefined && x.l.expected !== x.items.length) {
    mismatched.push(key)
    log(`${key}: PARTITION MISMATCH — the CLI expected ${x.l.expected} verdict(s), this unit carries ${x.items.length} finding(s)`)
  }
  if (got < want) { truncated.push(key); log(`${key}: UNDER-GRADED ${got}/${want} — the missing are UNREAD, not clean`) }
  else if (got > want) { mismatched.push(key); log(`${key}: OVER-GRADED ${got}/${want} — a duplicate or invented verdict, not extra coverage`) }
  else log(`${key}: ${got}/${want} adjudicated`)
}))
if (dead.length) log(`!! ${dead.length} DEAD lane(s): ${dead.join(', ')} — the pass is incomplete`)
if (mismatched.length) log(`!! ${mismatched.length} lane(s) whose verdict count does not match the CLI's: ${mismatched.join(', ')} — read them before grading`)
return { written, dead, empty, truncated, mismatched }
