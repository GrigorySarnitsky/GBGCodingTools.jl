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

function brief(role) {
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
    withheld.push('Read the BUILT site as a reader meets it, not only the source it was built from.');
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

  return [
    `You are reading the Julia package ${args.package} for a ${args.instrument.replace(/_/g, ' ')}.`,
    '',
    role.description,
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

const roles = args.roles.slice(0, Math.max(0, args.launches_left));
if (roles.length < args.roles.length) {
  log(`budget: ${args.roles.length - roles.length} reader(s) not launched — ${args.launches_left} launches left`);
}

const wrote = await parallel(
  roles.map((role) => async () => {
    const out = await agent(brief(role), {
      label: `${args.stage}:${role.key}`,
      phase: 'Read',
      schema: FINDINGS,
      model: role.strength === 'full' ? undefined : 'sonnet',
    });
    if (!out) return { key: role.key, wrote: false };
    await writeResult(role.result_file, out);
    return { key: role.key, wrote: true };
  }),
);

// A reader that wrote nothing is NAMED. A crashed agent and a careful one that found nothing are the
// same empty set to whoever reads the report, and the run refuses to treat silence as a clean result.
const silent = wrote.filter((w) => !w || !w.wrote).map((w) => (w ? w.key : 'unknown'));
if (silent.length) log(`silent: ${silent.join(', ')} — relaunch once, then name them`);

return {
  run: args.run,
  stage: args.stage,
  launched: roles.length,
  results_dir: args.results_dir,
  silent,
};

// The result files are what `gbg run collect` reads. Written here rather than returned, because the
// return value of a workflow is read by a session and the collector is a separate program minutes later.
async function writeResult(path, value) {
  const fs = await import('node:fs/promises');
  await fs.mkdir(path.replace(/\/[^/]+$/, ''), { recursive: true });
  await fs.writeFile(path, JSON.stringify(value, null, 2));
}
