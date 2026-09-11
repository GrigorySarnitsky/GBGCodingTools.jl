// ADVERSARIAL ATTACK ON AN INSTRUMENT'S LENS DESIGN — what kind of defect passes every lane? Source: IT
// audit-changes/attack-design.js. Changes: generic — the default CONTEXT is removed and `subject` is
// REQUIRED; the design arrives as text; the result is Written to `out`.
//
// Args: { schema_version, round, repo, design_path, subject: {object, defects, context, standpoint,
//         source, directions?}, out, models: {economy} }  (Revision 9: the design is a file)
export const meta = {
  name: 'attack-design',
  description: 'Adversarial attack on ANY instrument\'s lens set: what defect passes every lane?',
  phases: [{ title: 'Attack' }],
}

// gbg:prelude
for (const k of ['repo', 'design_path', 'subject', 'out', 'models', 'round', 'schema_version']) if (A[k] === undefined) throw new Error(`attack-design.js: args.${k} is required`)
const S = A.subject
for (const k of ['object', 'defects', 'context', 'standpoint', 'source']) if (!S[k]) throw new Error(`attack-design.js: subject.${k} is required — the attacker has no default subject`)
const DEFECTS = S.defects, OBJECT = S.object
const DIRECTIONS = S.directions || 'whatever the object admits'

const SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    role: { type: 'string' },
    verdict: { type: 'string', enum: ['SOUND', 'GAPS'] },
    gaps: { type: 'array', items: {
      type: 'object', additionalProperties: false,
      properties: {
        severity: { type: 'string', enum: ['fatal', 'serious', 'worth-fixing'] },
        gap: { type: 'string', description: 'the blind spot, stated as a KIND of defect the instrument cannot see' },
        evading_example: { type: 'string', description: 'a CONCRETE instance, real for this package, that is harmful and passes EVERY lane. Required.' },
        why_each_lane_misses: { type: 'string', description: 'lane by lane, why it does not fire' },
        proposed_lens: { type: 'string', description: 'the lens that would catch it, or "no lens — needs a different mechanism"' },
      },
      required: ['severity', 'gap', 'evading_example', 'why_each_lane_misses', 'proposed_lens'] } },
  },
  required: ['role', 'verdict', 'gaps'],
}

const PREAMBLE = `You are attacking the DESIGN of an automated review instrument — not the thing it reviews. The instrument's object is ${OBJECT}.

CONTEXT. ${S.context}

WHY THIS ATTACK EXISTS. A hand-written list of lenses is a hypothesis about where defects live: on a real corpus eight hand-specified lanes reported themselves COMPLETE while missing an entire class, and two unconstrained readers then found nine defects the eight could not see. This lens set was written by the same author as the thing it audits. Assume it is inadequate and find out how.

THE DESIGN UNDER ATTACK: read it in full from ${A.design_path} — the ONLY file under .gbg/ you may open.

YOUR OUTPUT MUST CONTAIN CONCRETE EVADING EXAMPLES. A gap asserted in the abstract is worth nothing here. What is worth something is: here is a specific instance in this package (read the real material at ${S.source}; nothing else under .gbg/, never ~/.gbg/, and scope every search with \`--glob '!.gbg/**'\`), it is harmful, and here is why each lane individually fails to fire on it. Walk the lanes one at a time. If you cannot construct such an example for a gap you suspect, say so plainly. Say SOUND if you genuinely cannot break it; that verdict is permitted and will be believed.`

const ROLES = [
  { key: 'logician', anchor: true, brief: `You are a LOGICIAN. Treat the lens set as a proposed partition of a space and test it AS a partition. Is the space itself well-defined — what is the set of all possible ${DEFECTS} for this instrument's object (${OBJECT}), and under what relation are the lenses a cover of it? Attack on structure: (a) DUALS — for each lens, does its logical dual have a lane? (b) QUANTIFIERS — find the scope restriction the instrument's own question carries, state it, and name what falls outside it. (c) COMPOSITION — each lens judges items one at a time; what harm exists only in the CONJUNCTION of two individually-innocent ones? (d) NEGATIVE SPACE — every lens examines something PRESENT; what about a harmful ABSENCE? (e) OVERLAP vs GAP — where two lenses both plausibly own something, does it fall between them?` },
  { key: 'philosopher', anchor: true, brief: `You are a PHILOSOPHER working on epistemology and philosophy of science. Attack the instrument's CONCEPTS, not its coverage. (a) THE BASELINE PROBLEM — on what grounds is the status quo normative, and what false positives and negatives does that assumption generate? (b) "JUSTIFIED"/"CORRECT" — relative to WHAT? show a case where the candidate referents disagree and the instrument gives the wrong answer. (c) INDEPENDENCE — the auditors are the same kind of agent as the author; what failure would be invisible to ALL of them at once? (d) FALSIFIABILITY — how would anyone discover that the instrument had missed something? (e) WHOSE STANDPOINT — ${S.standpoint}; does the instrument's central predicate, indexed to THAT reader, differ from what these lenses measure?` },
  { key: 'counterexample', anchor: true, brief: `You are a COUNTEREXAMPLE HUNTER. The panel is testing a universal claim — "these lenses catch ${DEFECTS}" — and your job is to falsify it: WRITE THE INSTANCES THAT GET THROUGH. Produce as many concrete, harmful, plausible instances in this package as you can that pass EVERY lane. A plausible instance is one a competent author would genuinely produce, not one contrived to evade. Fruitful directions: ${DIRECTIONS}. For each, walk EVERY lane and show each one missing.` },
  { key: 'measurement', brief: `You are a MEASUREMENT and EVALUATION specialist. Attack the instrument's EVIDENCE STANDARD rather than its categories. What does a lane's CLEAN verdict actually license anyone to conclude? What does a reporting cap do to a lens that should have reported thirty? Severity is self-assigned by the reporting agent — what does that do to a reader triaging by it? What is the false-negative rate and how would anyone estimate it? Is there any measurement that could come back and say "the instrument was wrong", and if not, what would have to be built? Propose the specific instrument, not the aspiration.` },
]

phase('Attack')
const results = await parallel(ROLES.map(r => () => agent(
  `${PREAMBLE}\n\nYOUR ROLE: ${r.key}\n\n${r.brief}\n\nReturn the structured object with role="${r.key}".`,
  { label: `attack:${r.key}`, phase: 'Attack', schema: SCHEMA, agentType: 'general-purpose',
    ...(r.anchor ? {} : { model: A.models.economy }) })))

const done = results.filter(Boolean)
const dead = ROLES.filter((r, i) => !results[i]).map(r => r.key)
const gaps = done.flatMap(r => (r.gaps || []).map(g => ({ ...g, role: r.role })))
const bySeverity = {}
for (const g of gaps) bySeverity[g.severity] = (bySeverity[g.severity] || 0) + 1
for (const r of done) log(`${r.role}: ${r.verdict} (${(r.gaps || []).length} gap(s))`)
log(`TOTAL: ${JSON.stringify(bySeverity)}`)
for (const g of gaps.filter(g => g.severity === 'fatal')) log(`   FATAL [${g.role}] ${g.gap}`)
if (dead.length) log(`!! ${dead.length} attacker(s) DIED — that angle is UNTESTED, not sound`)
await agent(`Use the Write tool to write EXACTLY this JSON to ${A.out} and return the single word done:\n\n${JSON.stringify({ schema_version: A.schema_version, round: A.round, bySeverity, gaps, dead, complete: dead.length === 0 }, null, 2)}`,
  { label: 'write-attack', phase: 'Attack', model: A.models.economy })
return { written: done.map(r => r.role), dead, empty: [], truncated: [] }
