// ---- gbg prelude — instruments/prelude.js ----------------------------------------------------------------
// The helpers every Workflow script shares. A Workflow script cannot import, so the CLI splices this file
// into each script at its one prelude marker line when it copies the script into a round or a design-check
// record (Preflight.install_script); this text never repeats the marker, so an assembled script holds none. Before this the same helpers lived in up to eleven copies, and a fix
// to one — the id stamp, the nonce stamp — had to be made in each. No script declares a name below again.
const A = typeof args === 'string' ? JSON.parse(args) : (args || {})
const STRENGTH = A.strength === 'full' ? 'full' : 'economy'
const ECONOMY = (A.models || {}).economy
// a lane runs on the economy model unless the round runs at full strength or the lane is an anchor
const laneModel = (lane) => (STRENGTH === 'economy' && !lane.anchor) ? { model: ECONOMY } : {}

// The scribe. A lane's own Write happens BEFORE its object is validated against SCHEMA, so the file can
// carry a value outside a closed set while the returned object cannot (the rc.1 round's built-html lane
// wrote `type: "formatted"` and was quarantined twice). The validated object is therefore written again,
// verbatim, by a cheap agent; the lane's own Write stays as the durable fallback when a return is lost.
const DONE = { type: 'object', properties: { done: { type: 'boolean' } }, required: ['done'] }
const scribe = (r, path, label, phase) => !r ? null :
  agent(`Use the Write tool to write EXACTLY this JSON to ${path} and return {done: true}. No other text.\n\n${JSON.stringify(r, null, 2)}`,
        { label, phase, schema: DONE, model: ECONOMY }).then(w => { if (!(w && w.done)) log(`${label}: the scribe did not confirm; the lane's own file stands`); return r })

// A verifier's two binding fields reach the scribe's file from args, never from the model's retyping: a
// one-character slip (…ec5662 for …ed5662) once REJECTED two lanes. A lane that returned other values is
// logged, because a copy-forward from an earlier pass shows there too.
const stamped = (r, lane) => {
  if (!r) return r
  if (r.pass_nonce !== A.nonce || r.graded_sha256 !== A.graded_sha256) log(`${lane}: returned a pass_nonce or graded_sha256 other than this pass's — stamped from args; read the lane if a copy-forward is possible`)
  return { ...r, pass_nonce: A.nonce, graded_sha256: A.graded_sha256 }
}

// One agent per item, its result given the item's own id by position — never the model's retyping, since
// a paraphrased id once read as a DEAD auditor. A dead agent stays dead (dropped).
const stampIds = (out, items) => out.map((v, i) => v && { ...v, id: items[i].id }).filter(Boolean)
// ---- end of the gbg prelude --------------------------------------------------------------------------------
