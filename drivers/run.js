// drivers/run.js — the ONE Workflow driver, for every instrument and every stage.
//
// It replaces eleven scripts of the old tree, which differed by instrument and by stage and drifted
// apart: a fix made in one was made in four of the other ten, and the one it was missed in was the one
// that ran. This script knows nothing about any particular instrument. Everything that varies —
// which readers, what each reads, what is withheld, how many findings each may report — arrives in
// `arguments.json`, written by `Orchestration.Agents`.
//
// `test/driver.jl` reads this file and requires it to read EVERY key Julia writes, so a key added on
// the Julia side and never read here is a test failure rather than a silently ignored field.
export const meta = {
  name: 'gbg-run',
  description: 'Run one stage of one GBG instrument: launch its readers, collect what each wrote',
  phases: [{ title: 'Read', detail: 'one agent per role, each over its own surfaces' }],
};

const args = globalThis.args;

// The schema every reader returns. The LINE is deliberately absent: an agent reports the file, the
// quote and the node it read, and Julia finds the line itself. A line an agent reported would be its
// count of the text it was shown, which is not the file's.
const FINDINGS = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          claim: { type: 'string' },
          evidence: { type: 'string' },
          fix: { type: 'string' },
          rule: { type: 'string' },
          maybe_code: { type: 'boolean' },
          locations: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                file: { type: 'string' },
                text: { type: 'string' },
                node: { type: 'string' },
              },
              required: ['file', 'text'],
            },
          },
        },
        required: ['claim', 'locations'],
      },
    },
    checked: { type: 'array', items: { type: 'string' } },
    candidates_found: { type: 'number' },
  },
  required: ['findings', 'checked'],
};

// What a VERIFIER returns: one verdict from the list its arguments allow, and the quote that decides it.
// The grade is Julia's: a verdict without a quote the current text holds is read as NOT_FIXED.
const VERDICT = {
  type: 'object',
  properties: {
    verdict: { type: 'string' },
    quote: { type: 'string' },
    reason: { type: 'string' },
  },
  required: ['verdict', 'quote'],
};

// What a TAGGER returns: one answer per rule, from the rule's TEXT alone. The study measures agreement,
// so a tagger is never shown another tagger's answer, the rulebook's own tag, or the package — any of
// those turns three independent answers into one answer repeated three times.
const TAGS = {
  type: 'object',
  properties: {
    tags: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          rule: { type: 'string' },
          needs: { type: 'array', items: { type: 'string' } },
          discipline: { type: 'boolean' },
          flagged: { type: 'boolean' },
          why: { type: 'string' },
        },
        required: ['rule', 'needs', 'discipline'],
      },
    },
  },
  required: ['tags'],
};

// The standpoint a role was given, resolved from the shared table. A stage's instruction to its
// verifiers is one paragraph and does not vary; a reader's standpoint is a page shared by every unit
// that reader is launched over. Written once per role they filled the arguments file the session has to
// type into the launching call, which is what every byte of that file costs.
const standpoint = (role) => (args.briefs || {})[role.brief] || '';

function taggerBrief(role) {
  return [
    'You are one of three readers answering the same questions about the same rules, independently. You',
    'will not see the others\' answers, and they will not see yours: the study measures whether the rules',
    'are WORDED so that three careful readers answer alike, so an answer influenced by another is worth',
    'nothing. Judge each rule from its TEXT ALONE. Do not open the package, the code, or any file.',
    '',
    'For each rule below, answer three questions.',
    '',
    '1. NEEDS — what must a reader be given to decide whether this rule is broken? Choose from:',
    '   SIBLINGS (other documents of the same kind), OTHER_DOCUMENTS (a different kind: the reference',
    '   list, the notation page), SOURCE (the code), RENDERED (the built site), HISTORY (earlier',
    '   versions), CITED_WORK (the paper a citation names). Answer with an empty list where the one',
    '   page or docstring the rule is about decides it by itself.',
    '2. DISCIPLINE — does deciding it need a field of expertise, rather than a careful generalist?',
    '3. FLAGGED — did the wording leave you guessing between two readings? Say which in `why`.',
    '',
    'Answer for every rule, in the order given. A rule you find obvious is still answered.',
    '',
    (role.rules || []).map((r) => `${r.id}\n${r.statement}`).join('\n\n'),
  ].filter(Boolean).join('\n');
}

function verifierBrief(role) {
  const withheld = role.kept_from_code
    ? 'The SOURCE and the design documents are withheld from you, as they were from the reader: judge the text alone.'
    : '';
  const unit = role.unit
    ? `\nThe page as it now stands is the file ${role.unit}, and it is the whole of what you may read.`
    : '';
  return [
    `You are verifying one fix in the Julia package ${args.package}, pass ${args.pass} of a ${args.instrument.replace(/_/g, ' ')}.`,
    '',
    standpoint(role),
    '',
    withheld,
    '',
    // The finding is a FILE, not a paragraph pasted here: it carries the text quoted at every location,
    // and a hundred of those is most of what the session has to type to launch this stage. Read it FIRST
    // — a verdict reached without it is a verdict about nothing, and the quote it owes cannot be found.
    `READ THIS FIRST: ${role.finding_file}`,
    `It is the finding ${role.finding} as the reader wrote it — the claim, the rule, the fix proposed, and`,
    'every location with the text quoted as the reader read it. Nothing below repeats it.',
    unit,
    role.diff_file ? `\nThe change made for it is the diff in ${role.diff_file}. Read that too.` : '',
    '',
    `Answer with ONE verdict from: ${(role.verdicts || []).join(', ')} — and the decisive QUOTE (at most 25`,
    'words, exactly as it appears in the current text or the diff). A verdict without a quote that is in',
    'the text counts as NOT_FIXED.',
  ].join('\n');
}

// A reader given ONE UNIT: one built page's text, in a file of its own, and nothing else. It never
// sees the surface lists — a reader handed every page at once is not the reader this bundle is for.
function unitBrief(role, checks, settled) {
  return [
    `You are reading ONE PAGE of the built documentation of the Julia package ${args.package}, as a visitor meets it.`,
    '',
    standpoint(role),
    '',
    `The page is the file ${role.unit}. It is the WHOLE of what you may read: do not open the source, the`,
    'other pages, the design documents or the repository. A reader who can see those cannot judge whether',
    'this page stands on its own, which is the only question you are here to answer.',
    checks,
    settled,
    '',
    role.unit_source
      ? `Report each place as the file \`${role.unit_source}\`, which is where this page is written, with`
      : 'Report each place as the file this page is built from, with',
    'the QUOTE you read (at most 25 words, exactly as it appears on the page). A quote that was rendered',
    'from a docstring is looked for across the documentation, so quote the words themselves and never a',
    'line number.',
    '',
    `REPORT CLASSES, NEVER ONE FINDING PER SITE. Your budget is ${role.cap} findings, counted in classes.`,
    '',
    'If the page is clean, return an empty `findings` list and a NON-EMPTY `checked` list naming it. An',
    'empty `checked` reads as a reader that did nothing, and is treated as one.',
  ].join('\n');
}

function brief(role) {
  if (role.kind === 'verifier') return verifierBrief(role);
  if (role.kind === 'tagger') return taggerBrief(role);
  const surfaces = (role.reads || [])
    .map((name) => `${name}:\n${(args.surfaces[name] || []).join('\n')}`)
    .join('\n\n');

  const withheld = [];
  if (role.kept_from_code) {
    withheld.push(
      'The SOURCE and the design documents are withheld from you. Do not open them, and do not infer ' +
      'their contents. Your whole value is that you cannot: a reader who can see the code cannot judge ' +
      'whether the prose stands without it.',
    );
  }
  if (role.site) {
    // The pages the walk kept — every page whose source is a target — and no other. The directory
    // alone would hand this reader the rendered working notes beside them, which nobody reads.
    const kept = args.site_pages || [];
    withheld.push(
      kept.length
        ? 'Read the BUILT site as a reader meets it, and not only the source it was built from — these ' +
          'pages and NO other file under the site:\n' + kept.join('\n')
        : `Read the BUILT site, at ${args.site || `${args.root}/docs/build`}, as a reader meets it, and not ` +
          'only the source it was built from.',
    );
  }
  // MATERIAL is what a reader may open to judge the targets and never report on: the package's own
  // working notes, listed by it. A defect found only there is still reported — with its location — and
  // is routed to the owner by the collect, never to the fixer; the reader is told so, not told to
  // stay silent. A reader kept from the code is kept from these too.
  if (!role.kept_from_code && (args.material || []).length) {
    withheld.push(
      'MATERIAL, which you may open to judge the surfaces above and which is NOT under review: ' +
      args.material.join(', ') + '. Report a defect you find only there with its file and quote; it ' +
      'goes to the owner and is never fixed by this run.',
    );
  }

  // The rules this reader checks are named, never quoted. Their statements live in the rendered
  // rulebook under `.gbg/policy/`, written from the rule values themselves, so a reworded rule reaches
  // every reader without a second copy of its text being edited here.
  const checks = (role.rules || []).length
    ? `\n\nYou are checking these rules, as they are stated in ${args.root}/.gbg/policy/ — read them there:\n` +
      role.rules.map((r) => `- ${r}`).join('\n')
    : '\n\nYou check NO rule in particular. You are an open reader: report what is wrong even where no ' +
      'rule names it, which is the half a rule cannot reach.';

  const settled = (args.settled || []).length
    ? '\n\nALREADY SETTLED by the owner — do not report these again:\n' +
      args.settled.map((s) => `- ${s.text}`).join('\n')
    : '';

  if (role.unit) return unitBrief(role, checks, settled);

  return [
    `You are reading the Julia package ${args.package} for a ${args.instrument.replace(/_/g, ' ')}.`,
    '',
    standpoint(role),
    '',
    withheld.join(' '),
    '',
    `Your surfaces, at ${args.root}:`,
    surfaces,
    checks,
    settled,
    '',
    'REPORT CLASSES, NEVER ONE FINDING PER SITE. When the same mistake recurs, report it ONCE and list',
    `every site in \`locations\`. Your budget is ${role.cap} findings, counted in classes; \`locations\``,
    'is unbounded, so a class with forty sites costs one.',
    '',
    'For each place, give the FILE, the QUOTE you read (at most 25 words, exactly as it appears) and the',
    'node it sits in where you can name one. Do not give line numbers: they are filled in from the file.',
    '',
    'If your surface is clean, return an empty `findings` list and a NON-EMPTY `checked` list saying what',
    'you examined. An empty `checked` reads as a reader that did nothing, and is treated as one.',
  ].join('\n');
}

phase('Read');

// Every marked reader of the stage is launched: nothing caps launches (ruled 2026-09-21) — the panel
// over the units, one relaunch each, and the pass cap bound them by design. A stage continued after
// an interruption carries the mark only on the roles whose result did not arrive.
// A role on the wire carries only what is its own: its key, the name of its kind, its unit and its
// finding. Everything shared by the roles of one shape sits once under `args.kinds`, and the three
// paths are the key with a directory around it. Rehydrated here, once, so the rest of this file reads
// a whole role — and so the arguments the session types stay the size of the stage's VARIETY, not of
// its findings (measured at 435 bytes per role before, 57 of them the role's own).
const whole = (role) => {
  const kind = (args.kinds || {})[role.kind] || {};
  return {
    ...kind,
    ...role,
    kind: kind.kind,
    result_file: `${args.dirs.results}/${role.key}.json`,
    finding_file: role.finding ? `${args.dirs.material}/${role.key}.json` : '',
    diff_file: kind.diff ? `${args.dirs.material}/${role.key}.diff` : '',
  };
};
const roles = args.roles.filter((role) => role.launch !== false).map(whole);
log(
  `${args.stage}: ${roles.length} of ${args.roles.length} role(s) to launch, ` +
  `${args.sequential ? 'one at a time' : 'together'}, at commit ${String(args.commit).slice(0, 8)}`,
);

// The model each strength runs on. `full` empty means the session's own model, which is what a run
// that named none records: naming a model it did not choose would be a record of something else.
function modelFor(role) {
  const named = role.strength === 'full' ? args.models.full : args.models.economy;
  return !named || named === 'session' ? undefined : named;
}

const one = async (role) => {
  const launch = (again) => agent(`${brief(role)}\n\n${deliver(role)}`, {
    label: `${args.stage}:${role.key}${again ? ':again' : ''}`,
    phase: 'Read',
    schema: role.kind === 'verifier' ? VERDICT : role.kind === 'tagger' ? TAGS : FINDINGS,
    model: modelFor(role),
  });
  // A silent agent is relaunched ONCE; what is still silent is named by the collect.
  let out = await launch(false);
  if (!out) { log(`${role.key} wrote nothing; launching it once more`); out = await launch(true); }
  if (!out) return { key: role.key, wrote: false };
  return { key: role.key, wrote: true };
};

// Together by default; ONE AT A TIME when the run asked for it, so an outage costs one agent's work
// rather than the whole stage's.
const wrote = [];
if (args.sequential) {
  for (const role of roles) wrote.push(await one(role));
} else {
  wrote.push(...(await parallel(roles.map((role) => () => one(role)))));
}

// A reader that wrote nothing is NAMED. A crashed agent and a careful one that found nothing are the
// same empty set to whoever reads the report, and the run refuses to treat silence as a clean result.
const silent = wrote.filter((w) => !w || !w.wrote).map((w) => (w ? w.key : 'unknown'));
if (silent.length) log(`silent after a relaunch: ${silent.join(', ')} — the collect names them`);

return {
  run: args.run,
  stage: args.stage,
  launched: roles.length,
  results_dir: args.results_dir,
  silent,
};

// The result files are what `gbg run collect` reads, and the AGENT writes its own. This script cannot:
// a workflow script has no filesystem and no Node API, and `import()` is refused outright, so there is
// no spelling of a write that works here — found at v2.0.0-rc.8, which parsed and then failed at the
// next step (GBGPeriodicFields, 2026-09-22).
//
// The property the old comment protected is kept, and it is the reason not to return the findings up to
// the session instead: the collector is a separate program reading files minutes later, and a session
// that carried every finding from a workflow's return value into a file would be the courier for the
// thing the guard exists to check. The agent has file tools; this script hands it the path.
//
// The agent both WRITES the file and RETURNS the object. The return is what `schema` validates, so a
// role that returns nothing is still named as silent even if it wrote something unreadable, and a file
// that never appeared is named by the collect. Two statements of the same result, and the run believes
// the file.
function deliver(role) {
  return [
    'BEFORE you finish, write your answer as JSON to this exact path, creating the directories if they',
    'are not there:',
    '',
    `    ${role.result_file}`,
    '',
    'It must be the SAME object you return, in the shape you were given, and nothing else in the file —',
    'no prose around it, no code fence. That file is what the run reads; your return value is only',
    'checked against it. A file that is not there is read as an agent that did nothing, and is treated',
    'as one.',
  ].join('\n');
}
