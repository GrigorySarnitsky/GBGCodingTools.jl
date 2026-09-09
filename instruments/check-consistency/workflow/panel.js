// /check-consistency PANEL — the fresh-eyed multi-hat audit of the RENDERED docs. Concurrent, collect-only.
// Sources: PF check-consistency/panel.js (parallel, dead/empty/TRUNCATED), IT check-consistency/panel.js
// (profile/subset, hats.json). Changes: hats arrive RESOLVED and NUMBERED in args (the CLI applied the
// profile and assigned NN); no census agent, no hats.json; no package string, path or round datum in
// this source; every hat Writes its lane file FIRST. PAYLOADS ARE FILES (ARCHITECTURE Revision 9): a
// Workflow script has no filesystem and its args are re-emitted by the session, so the manuscripts,
// the rulebook and the personas are files preflight wrote under the round's scratch, named in args;
// each hat may open exactly the paths its args name under .gbg/ and nothing else there.
//
// Args (instruments/check-consistency/schema.json, rendered by `gbg preflight`):
//   { schema_version, round, round_dir, repo, rawhtml, package: {name, description, domain, terms,
//     deliberate_absences}, preamble, manuscripts: {full: path, siteonly: path}, rulebook_path,
//     hats: [{nn, key, persona_path, substrate, needs, anchor}], adjudicated_titles, finding_types,
//     cost, strength, models: {economy}, opened }
export const meta = {
  name: 'check-consistency-panel',
  description: 'Fresh-eyed panel auditing the RENDERED docs for consistency, mathematics, typesetting, structure and design (concurrent, collect-only)',
  phases: [{ title: 'Panel' }],
}

const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
for (const k of ['round', 'round_dir', 'repo', 'manuscripts', 'hats', 'preamble', 'models', 'package']) {
  if (A[k] === undefined) throw new Error(`panel.js: args.${k} is required`)
}
const ECONOMY = A.models.economy
const STRENGTH = A.strength === 'full' ? 'full' : 'economy'
const TYPES = A.finding_types || ['math', 'notation', 'structure', 'citation', 'style', 'operational', 'currency', 'self-containment']

const SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    schema_version: { type: 'integer' },
    round: { type: 'string' },
    lane: { type: 'string' },
    candidates_found: { type: 'integer', description: 'distinct candidates weighed BEFORE the 25-finding cap — the truncation signal' },
    checked: { type: 'array', items: { type: 'string' }, description: 'the pages you actually read, by their PAGE banner; REQUIRED and non-empty even with zero findings' },
    findings: { type: 'array', items: {
      type: 'object', additionalProperties: false,
      properties: {
        type: { type: 'string', enum: TYPES, description: 'the core axis; a contradiction is filed under the axis it concerns, a design or API gap under operational, wording under style, organisation under structure' },
        severity: { type: 'string', enum: ['blocker', 'major', 'minor', 'nit'] },
        confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
        title: { type: 'string' },
        locations: { type: 'array', items: { type: 'string' }, description: 'page (its PAGE banner) + section + the exact quoted rendered text, <= 20 words per quote' },
        contradicts: { type: 'string', description: 'for a contradiction: the OTHER location + its quote + the axis; else empty' },
        description: { type: 'string', description: '<= 90 words' },
        resolution_hint: { type: 'string', description: 'advisory only' },
      },
      required: ['type', 'severity', 'confidence', 'title', 'locations', 'description'],
    } },
  },
  required: ['schema_version', 'round', 'lane', 'candidates_found', 'checked', 'findings'],
}

const ADJ = (A.adjudicated_titles && A.adjudicated_titles.length)
  ? `\n- ALREADY ADJUDICATED. The following findings were raised by an earlier panel and settled by the owner as NOT defects (extraction artefacts of the manuscript, or design decisions closed deliberately). Do NOT spend a finding on anything they cover. Nothing merely FIXED is listed here, so everything else is fair game:\n${A.adjudicated_titles.map(t => `    - ${t}`).join('\n')}\n`
  : ''

const permitted = (h) => {
  const p = [h.substrate === 'siteonly' ? A.manuscripts.siteonly : A.manuscripts.full, h.persona_path]
  if ((h.needs || []).includes('rulebook') && A.rulebook_path) p.push(A.rulebook_path)
  return p
}

const rules = (h) => `
RULES:
- FILES UNDER .gbg/ YOU MAY OPEN — exactly these, with the Read tool, and NOTHING else under .gbg/ or ~/.gbg/ (other rounds' verdicts and this round's answer key live there):
${permitted(h).map(p => `    ${p}`).join('\n')}
  plus the ONE file you WRITE, named at the end. Read ONLY what your substrate below grants. Unless it EXPLICITLY grants more, do NOT open src/, tests, the rulebook, memory, or anything else — you judge the docs AS WRITTEN, from your own expertise.
- COLLECT findings only. Do NOT edit anything and do NOT apply fixes.
- A PRIMARY goal is INTERNAL CONSISTENCY: flag anything defined, stated, valued, or formatted one way in one place and DIFFERENTLY in a similar place. Cross-reference relentlessly across every page you are given.
- ALSO flag anything that contradicts your expert knowledge or instinct ("this smells wrong").
- EVERY finding needs EVIDENCE: quote the exact rendered text and name the page (the "PAGE:" banner) + section. For a contradiction, quote BOTH sides and name the axis of disagreement.
- Severity: blocker (wrong/misleading) / major / minor / nit. Confidence: high / medium / low — a marked-low suspicion is welcome; do not inflate.
- resolution_hint is optional and advisory only.${ADJ}
- The package's DELIBERATE ABSENCES are design, not gaps — do not flag them: ${(A.package.deliberate_absences || []).join('; ') || '(none recorded)'}.
- Report what you actually see NOW in the document, not what you might expect from a prior version.
- OUTPUT DISCIPLINE (HARD LIMIT): at most your 25 MOST SIGNIFICANT findings, ranked most-severe first; each description <= 90 words; quote only the DECISIVE phrase (<= 20 words) on each side. Report candidates_found — the count you weighed BEFORE the cap; a capped hat that reports its denominator can be re-run narrowed, a capped hat that stays silent reads as complete. Report checked[] — the PAGE banners you actually read — even when you found nothing: a zero-finding file with an empty checked[] is a DEAD lane, not a clean one.`

const substrateText = (h) => {
  const parts = []
  if (h.substrate === 'siteonly') parts.push(`THE RENDERED USER-FACING SITE, the design docs EXCLUDED on purpose. Read it IN FULL, first, from:\n    ${A.manuscripts.siteonly}\n(one reader-text manuscript; each page is delimited by a "===== PAGE: <name> =====" banner; math is its TeX). It is long — read it in successive chunks until the end; a hat that reads half the site reports half the defects and does not know it.`)
  else parts.push(`THE WHOLE RENDERED SITE incl. the design docs. Read it IN FULL, first, from:\n    ${A.manuscripts.full}\n(one reader-text manuscript; each page is delimited by a "===== PAGE: <name> =====" banner; math is its TeX). It is long — read it in successive chunks until the end.`)
  const needs = h.needs || []
  if (needs.includes('html')) parts.push(`ALSO inspect the RAW built HTML under: ${A.rawhtml}`)
  if (needs.includes('source')) parts.push(`ALSO the AUTHORED SOURCE (read it with Read/Grep; quote findings at file:line): the docstrings under ${A.repo}/src/ and ${A.repo}/ext/, the pages under ${A.repo}/docs/src/, and the rationale documents under ${A.repo}/docs/.`)
  if (needs.includes('rulebook')) parts.push(`THE RULEBOOK (AUTHORITATIVE — read it first, in full): ${A.rulebook_path}`)
  if (needs.includes('git')) parts.push(`HISTORY: you may use Bash with git (log, diff, show, grep) and Read inside ${A.repo}; scope every search with `--glob '!.gbg/**'`. Never open anything under .gbg/ beyond the files named above, and never ~/.gbg/.`)
  return parts.join('\n\n')
}

const prompt = (h) => `${A.preamble}
${rules(h)}

YOUR HAT (${h.key}): read your persona in full from ${h.persona_path} before anything else; it is who you are for this review.

YOUR SUBSTRATE:
${substrateText(h)}

When your review is complete, FIRST use the Write tool to save your findings as JSON to:
  ${A.round_dir}/findings/${h.nn}-${h.key}.json
— the object must be EXACTLY the structured object you return, with schema_version=${A.schema_version}, round="${A.round}", lane="${h.key}". THEN return the same object. The written file is the durable record; a returned object can be lost while the work was done.`


// The scribe. A lane's own Write happens BEFORE its object is validated against SCHEMA, so the file can
// carry a value outside a closed set while the returned object cannot (the rc.1 round's built-html lane
// wrote `type: "formatted"` and was quarantined twice). The validated object is therefore written again,
// verbatim, by a cheap agent; the lane's own Write stays as the durable fallback when a return is lost.
const DONE = { type: 'object', properties: { done: { type: 'boolean' } }, required: ['done'] }
const scribe = (r, path, label, phase) => !r ? null :
  agent(`Use the Write tool to write EXACTLY this JSON to ${path} and return {done: true}. No other text.\n\n${JSON.stringify(r, null, 2)}`,
        { label, phase, schema: DONE, model: ECONOMY }).then(w => { if (!(w && w.done)) log(`${label}: the scribe did not confirm; the lane's own file stands`); return r })

phase('Panel')
const outcomes = await parallel(A.hats.map(h => () => {
  const economized = STRENGTH === 'economy' && !h.anchor
  return agent(prompt(h), { label: h.key, phase: 'Panel', schema: SCHEMA, agentType: 'general-purpose',
                            ...(economized ? { model: ECONOMY } : {}) })
    .then(r => scribe(r, `${A.round_dir}/findings/${h.nn}-${h.key}.json`, `scribe:${h.key}`, 'Panel'))
}))

// Liveness only. A hat that DIED and a hat that found NOTHING both look like "0 findings", and the
// bank tells them apart from the files; here they are logged apart so a hole is visible at once.
const written = [], dead = [], empty = [], truncated = []
outcomes.forEach((r, i) => {
  const h = A.hats[i]
  if (!r) { dead.push(h.key); log(`${h.nn} ${h.key}: DEAD — no result`); return }
  written.push(h.key)
  const n = (r.findings || []).length
  if (n === 0) empty.push(h.key)
  if ((r.candidates_found || 0) > n) truncated.push(h.key)
  log(`${h.nn} ${h.key}${economizedLabel(h)}: ${n} findings${n === 0 ? ' (EMPTY — not the same as dead)' : ''}${(r.candidates_found || 0) > n ? `  (TRUNCATED: weighed ${r.candidates_found}, reported ${n})` : ''}`)
})
function economizedLabel(h) { return (STRENGTH === 'economy' && !h.anchor) ? ' (economy)' : ' (anchor/full)' }
if (dead.length) log(`!! ${dead.length} HAT(S) DEAD — the panel is INCOMPLETE: ${dead.join(', ')}; run gbg round bank, then gbg round rerun --lanes for these`)
return { written, dead, empty, truncated }
