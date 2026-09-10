// /bug-hunt HUNT — static hunt, dynamic confirmation. Sources: IT bug-hunt/hunt.js (pipeline, the
// reproducer stage, kind/severity/files_read, quoted paths), PF bug-hunt/hunt.js (territories, the
// mandatory mechanical re-run). Changes: lanes = args.territories + the two free lanes (anchored),
// numbered by the CLI; witnesses written as witnesses/<lane>-<n>.jl inside args.round_dir; the lanes
// subset only as the CLI passes it (DEAD lanes); ALREADY-COVERED requires evidence (file:line);
// BLOCKED admitted with a `# blocked:` header reason; the oracle list from args; no `include(` in a
// witness; no package string in the source. PAYLOADS ARE FILES (Revision 9): each lane's brief and the
// invariants text are files preflight wrote; args name their paths.
//
// Args (instruments/bug-hunt/schema.json): { schema_version, round, round_dir, repo, package, preamble,
//   lanes: [{nn, key, kind, brief_path, files, anchor}], oracles, witness_cmd, witness_env,
//   invariants_path?, models: {economy}, strength }
export const meta = {
  name: 'bug-hunt',
  description: 'Static hunt across the code, every candidate defect confirmed by a failing witness before it is reported',
  phases: [{ title: 'Hunt' }, { title: 'Reproduce' }],
}

const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
for (const k of ['round', 'round_dir', 'repo', 'lanes', 'preamble', 'witness_cmd', 'models', 'schema_version', 'package']) if (A[k] === undefined) throw new Error(`hunt.js: args.${k} is required`)
const STRENGTH = A.strength === 'full' ? 'full' : 'economy'
const ECONOMY = A.models.economy
const WIT = `${A.round_dir}/witnesses`

const CANDIDATE_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    lane: { type: 'string' },
    files_read: { type: 'array', items: { type: 'string' }, description: 'every source file you actually opened — coverage is measured, not asserted' },
    candidates_found: { type: 'integer' },
    candidates: { type: 'array', items: {
      type: 'object', additionalProperties: false,
      properties: {
        kind: { type: 'string', enum: ['runtime', 'architecture', 'api-semantics'] },
        severity: { type: 'string', enum: ['blocker', 'major', 'minor'] },
        title: { type: 'string', description: 'one line, the defect not the location' },
        file: { type: 'string' },
        line: { type: 'integer' },
        mechanism: { type: 'string', description: 'WHY it is wrong — the causal chain, not a restatement' },
        witness_plan: { type: 'string', description: 'runtime/api-semantics: the concrete call and the assertion that should hold but will not. architecture: the second location to diff against and the maintenance consequence.' },
        second_location: { type: 'string', description: 'architecture only: file:line of the divergent copy' },
      },
      required: ['kind', 'severity', 'title', 'file', 'line', 'mechanism', 'witness_plan'],
    } },
  },
  required: ['lane', 'files_read', 'candidates_found', 'candidates'],
}

const VERDICT_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    title: { type: 'string' },
    verdict: { type: 'string', enum: ['REPRODUCED', 'NOT-REPRODUCED', 'WITNESS-WRONG', 'NO-WITNESS-POSSIBLE', 'EVIDENCED', 'NOT-A-DEFECT', 'ALREADY-COVERED', 'BLOCKED'] },
    witness_path: { type: 'string', description: 'the banked .jl witness (REPRODUCED and BLOCKED); empty otherwise' },
    observed: { type: 'string', description: 'the ACTUAL evidence — the failing @test line as printed, or the two quoted divergent blocks; <= 60 words' },
    evidence: { type: 'string', description: 'ALREADY-COVERED: the file:line of the existing assertion (REQUIRED). BLOCKED: the environment reason. api-semantics: the official page URL and the sentence it says.' },
    docs_url: { type: 'string' },
    severity: { type: 'string', enum: ['blocker', 'major', 'minor'] },
  },
  required: ['title', 'verdict', 'observed', 'evidence'],
}

const LANE_FILE_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: { done: { type: 'boolean' } }, required: ['done'],
}

const FREE_PREAMBLE = `${A.preamble}

YOUR BRIEF IS TO FIND WHAT IS WRONG WITH THIS CODE. That is the whole brief.

You are deliberately given NO list of defect classes to look for. Other lanes in this panel work from territories, and any list is somebody's guess about where bugs live — so a defect that falls outside every one of them is invisible to every one of them, and the run still reports success. You are the lane that catches what the guess missed. If you find yourself working through a mental checklist, stop and read the actual code again.

Read the source. Follow the data. Nothing under \`.gbg/\` or \`~/.gbg/\` is yours to open but the files this prompt names; scope every grep with \`--glob '!.gbg/**'\`. Ask, of each thing you read, what would have to be true for it to be correct, and then check whether it is.

REPORT \`candidates_found\`: how many candidates you WEIGHED, not how many you report. You have no cap, so the two usually agree — but where you weighed something and set it aside, the count says so, and a lane whose two numbers never differ is a lane that never discarded anything.`

const HUNT_PREAMBLE = `${A.preamble}

YOU ARE PRODUCING HYPOTHESES, NOT VERDICTS. Every candidate you raise will be handed to a separate agent whose only job is to write a program that demonstrates it, and which discards anything that does not reproduce. So: do NOT report what merely looks unusual — report what you can say will MISBEHAVE, and say with what input; give a WITNESS PLAN for every candidate (the concrete call, the input, the assertion that ought to hold but will not) or do not raise it; prefer one candidate you can specify a failing call for over five you cannot. Do not report style, naming, or documentation defects — other instruments own those.

THREE KINDS, and the kind decides the evidence: "runtime" — wrong values, wrong types, aliasing, mutation of a caller's data, an edge case that errors or silently misbehaves; witness = a failing @testset. "api-semantics" — a claim about what Base or a dependency does; you are very likely wrong from memory, say what you believe and the reproducer checks the official documentation AND runs it. "architecture" — duplication, divergent copies of one rule, a leaked abstraction, an invariant broken in code; no test can fail on these, so they need a SECOND LOCATION to diff and a stated maintenance consequence.

The ORACLES available in this package, independent of the code: ${(A.oracles || []).join('; ') || '(none recorded — derive from documented contracts)'}.
${A.invariants_path ? `\nTHE PACKAGE'S RECORDED INVARIANTS: read them first from ${A.invariants_path}.\n` : ''}
Report files_read honestly: it is cross-checked against the tree. FILES UNDER .gbg/ YOU MAY OPEN: your brief and the invariants file named in this prompt, and nothing else under .gbg/ or ~/.gbg/. Cap: your 6 most substantial candidates, ranked by what would actually go wrong; report candidates_found, the number you weighed before the cap.`

phase('Hunt')
const laneModel = (lane) => (STRENGTH === 'economy' && !lane.anchor) ? { model: ECONOMY } : {}

const results = await pipeline(
  A.lanes,
  (lane) => agent(lane.kind === 'free'
    ? `${FREE_PREAMBLE}\n\nWHERE TO START: read your brief in full from ${lane.brief_path} (the one file under .gbg/ you may open besides the invariants named above).\n\nReturn the structured object with lane="${lane.key}".`
    : `${HUNT_PREAMBLE}\n\nYOUR TERRITORY (hunt HERE; you may read anything else in the repository to understand it): read your brief in full from ${lane.brief_path}, then these files:\n${(lane.files || []).map(f => `  ${A.repo}/${f}`).join('\n')}\n\nReturn the structured object with lane="${lane.key}".`,
    { label: `hunt:${lane.key}`, phase: 'Hunt', schema: CANDIDATE_SCHEMA, agentType: 'general-purpose', ...laneModel(lane) }),

  async (found, lane) => {
    const candidates = (found && found.candidates) || []
    const verdicts = candidates.length === 0 ? [] : (await parallel(candidates.map((c, i) => () => {
      const slug = `${lane.key}-${String(i + 1).padStart(2, '0')}`
      return agent(`You are the REPRODUCER for one candidate defect in ${A.package.name} (Julia, at ${A.repo}). A hunter claims the following. Your job is NOT to agree with it.

  kind:      ${c.kind}
  severity:  ${c.severity}
  title:     ${c.title}
  location:  ${c.file}:${c.line}
  mechanism: ${c.mechanism}
  plan:      ${c.witness_plan}
  ${c.second_location ? 'second location: ' + c.second_location : ''}

THE DEFAULT VERDICT IS "NOT-REPRODUCED". You must earn anything else with evidence a third party could re-run. An unproven bug report costs a fix pass on working code, which is worse than a missed bug, so failing to reproduce is the SAFE outcome.

HOW TO PROVE IT, by kind:

* kind = "runtime" — Write a SELF-CONTAINED Julia file that asserts the CORRECT behaviour and therefore FAILS on the current tree:

      using Test, ${A.package.name}
      @testset "<the claim, as a sentence>" begin
        # minimal setup — small sizes, fixed rng
        @test <what SHOULD hold>
      end

  HARD RULES for the witness: it may \`using\`/\`import\` ONLY ${A.package.name}, Test and the standard library — nothing else — and it must NEVER \`include(\` another file (the bank REFUSES such a witness outright). It locates files, if it must, through \`pkgdir(${A.package.name})\`, never by counting \`..\` hops. Save it to ${WIT}/${slug}.jl, then RUN it — NOTE THE QUOTES, these paths contain spaces:
      cd "${A.repo}" && ${A.witness_cmd} "${WIT}/${slug}.jl"
  Read the output. If everything PASSES, the hunter was wrong: verdict NOT-REPRODUCED — do not rescue the candidate by weakening the assertion until it fails.

  A FAILING TEST IS NECESSARY AND NOT SUFFICIENT. Before returning REPRODUCED, DERIVE THE EXPECTED VALUE INDEPENDENTLY of the assertion you wrote — from the documented contract, an analytic case, a mathematical identity, a second route to the same quantity (the oracles: ${(A.oracles || []).join('; ') || 'the documented contract'}). State that derivation in \`observed\`. If it agrees with the CODE rather than with your assertion, the verdict is WITNESS-WRONG. Keep the file: on REPRODUCED it becomes the regression test, so it must assert the RIGHT behaviour.

  If the witness ERRORS for an environmental reason you cannot remove here (a device the host lacks, a resource), and it was never observed to FAIL, you may return BLOCKED: put a first line \`# blocked: <reason>\` in the file and give the reason in \`evidence\`.

* kind = "api-semantics" — (1) Fetch the OFFICIAL documentation (docs.julialang.org for Base; the package's own docs for a dependency) and quote the sentence that settles it, with the URL, in \`evidence\`. (2) Then write and run a witness as above. REPRODUCED only if the documentation and the run agree that the code is wrong.

* kind = "architecture" — No program can fail on this: read BOTH locations, quote the two blocks, and state precisely what a maintainer would have to change in both places and what happens if they change only one. EVIDENCED if the duplication/divergence/violation is real and you have both quotes; NOT-A-DEFECT if the second site differs for a reason or there is no second site.

ALREADY-COVERED — if the existing suite already asserts exactly this (grep ${A.repo}/test), return it WITH the file:line of that assertion in \`evidence\`; without a file:line the verdict is not admissible. NO-WITNESS-POSSIBLE — the claim is real but nothing currently reaches it; say what would have to change for it to bite.

NEVER read anything under .gbg/ other than writing your own witness file; never read ~/.gbg/. OUTPUT: the structured object; \`observed\` must contain the ACTUAL evidence, not a description of it.`,
        { label: `repro:${slug}`, phase: 'Reproduce', schema: VERDICT_SCHEMA, agentType: 'general-purpose' })
        .then(v => v ? ({ ...v, slug, candidate: c }) : null)
    }))).filter(Boolean)

    // Bank the lane file FIRST through an agent's Write (a workflow script has no filesystem), then
    // return liveness. The file is the durable record the CLI banks from.
    const laneFile = {
      schema_version: A.schema_version, round: A.round, lane: lane.key,
      files_read: (found && found.files_read) || [],
      candidates_found: (found && found.candidates_found) || candidates.length,
      checked: (found && found.files_read) || [],
      findings: verdicts.map(v => ({
        kind: v.candidate.kind, severity: v.severity || v.candidate.severity, title: v.title || v.candidate.title,
        file: v.candidate.file, line: v.candidate.line, mechanism: v.candidate.mechanism, witness_plan: v.candidate.witness_plan,
        second_location: v.candidate.second_location || '', verdict: v.verdict, witness_path: v.witness_path || '',
        observed: v.observed, evidence: v.evidence || '', docs_url: v.docs_url || '',
        type: 'operational', confidence: 'high', locations: [`${v.candidate.file}:${v.candidate.line}`], description: v.candidate.mechanism,
      })),
    }
    const w = found ? await agent(`Use the Write tool to write EXACTLY this JSON to ${A.round_dir}/findings/${lane.nn}-${lane.key}.json and return {done: true}. No other text.\n\n${JSON.stringify(laneFile, null, 2)}`,
      { label: `bank:${lane.key}`, phase: 'Reproduce', schema: LANE_FILE_SCHEMA, model: ECONOMY }) : null
    return { lane: lane.key, dead: !found, written: !!(w && w.done), n: verdicts.length,
             confirmed: verdicts.filter(v => v.verdict === 'REPRODUCED' || v.verdict === 'EVIDENCED').length }
  },
)

const written = [], dead = [], empty = [], truncated = []
results.forEach((r, i) => {
  const lane = A.lanes[i]
  if (!r || r.dead) { dead.push(lane.key); log(`${lane.nn} ${lane.key}: DEAD — no result (its territory is UNHUNTED, not clean)`); return }
  if (!r.written) { dead.push(lane.key); log(`${lane.nn} ${lane.key}: lane file NOT written — treated as dead`); return }
  written.push(lane.key)
  if (r.n === 0) empty.push(lane.key)
  log(`${lane.nn} ${lane.key}: ${r.n} candidates reproduced-or-dismissed, ${r.confirmed} confirmed`)
})
if (dead.length) log(`!! ${dead.length} DEAD lane(s): ${dead.join(', ')} — the hunt is INCOMPLETE`)
return { written, dead, empty, truncated }
