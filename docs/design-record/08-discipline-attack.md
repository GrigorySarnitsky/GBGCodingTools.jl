# 08 — The six disciplines attacked (Phase 4f, 2026-09-21)

The six discipline descriptions in `src/Roles/documentation_review.jl` — the standpoint an open expert
reader is given, printed on each declaring package's readers page — were put to three lenses until a
round had no objection of substance, as `IMPLEMENTATION.md` Phase 4f asks; the owner then judged the
survivors auditors rather than experts, the six were rewritten as experts, and a blind comparison chose
the rewrite in every field. This file is the record of what each round found, what was changed, how the
rewrite was tested, and what the owner adopted as decision 28. Nothing in a consumer package was
touched; the attackers and the judges read PF, HT, CP and SS for evidence only.

## The lenses

Eight agents per round, launched together, each told to refute and not to praise, each returning
objections graded SUBSTANTIVE (the reader would miss or misreport something real, or misdescribe itself
to a package owner), MINOR or NIT, with a complete replacement text per objection:

- **A scientist of that field** — six agents, one per discipline, each with the declaring package's
  documentation open for evidence: a differential geometer on PF, a spectral analyst on PF and HT, a
  turbulence theorist on HT, a cloud microphysicist on CP, a statistician on SS, a Julia architect on
  PF's and the tool's design pages.
- **A reader of the rules** — one agent over all six with the rulebook open, asking whether a "Reports"
  clause restates a rule the reader is not bound to, whether two disciplines or a discipline and a
  standpoint would file one defect twice, and whether each clause is judgeable from documentation with
  the code as context only.
- **A plain-language reader** — one agent with no field and no files, asking whether a package owner
  outside the field could decide from the text alone whether to declare the discipline, and whether the
  reviewer could tell what to look for.

## Round one — 32 substantive objections

The same finding from five lenses independently: **four of the six "Reports" clauses restated a rule
that had been ruled a generalist's.** The geometer's "a formula whose stated objects are not the objects
the operation acts on" and the analyst's "a normalization or an adjoint stated in the prose that the
discrete operation does not have" were `RULE.DOC.VERIFIED` — true of the code, by expansion — which the
owner ruled on 2026-09-21 belongs to the careful generalist with the source open. The statistician's "an
identity sentence that names a computation where it should name what is being estimated" was
`RULE.DOC.LEADING_IDENTITY` with `leading_identity = estimand`, and would have reported as a defect
what a package choosing `physical meaning` is required to write. The architect's "contradicts itself
across pages" and "incoherent" were the logician's and plain_sense's. A package declaring any of these
would have received one defect twice, once anchored to a rule and once not.

What an expert has that no rule has is **the field's theory and literature**; the code is the
generalist's oracle. Every specialist, reading its package, found the real class the old text missed
and the old text did not send it to:

- *Geometry.* PF never states the orientation of its frame, though `curl`, `cross` and `det` change
  sign under a reflection of it; the grid origin is bound two ways. The old text hunted for
  "flattening", which PF rules out on page one by declaring Cartesian tensors. "A fibre kept distinct
  from its coordinates" is not how the field speaks (a fibre has components in a frame; coordinates
  belong to the base), and PF spells "fiber".
- *Spectral.* The object list was a textbook chapter list; the live defects sit elsewhere: a shell sum
  called a density, the κ = 0 half-width shell, the inclusive two-thirds boundary that aliases one mode
  when the grid size divides by three, an "isotropic 2/3 rule" cited to Orszag whose per-axis rule it is
  not, the time stepping of the spectral system, which no reader owned.
- *Turbulence.* The check against the **cited paper** was absent: Lundgren's correction stated for all r
  in a forced, stationary package; C₂ left free beside C_K when the theory ties them; eponyms carrying
  another author's value; "dissipation anomaly" for a coefficient. "Closures" named something HT has none
  of.
- *Cloud.* The old text named a warm-rain bulk scheme's objects — collisions, parameterizations — which
  CP does not have, and not the mixed-phase physics it does: ice, deposition, the supersaturation budget
  over water and over ice, glaciation. The class missed was unstated assumptions and regimes: Magnus fits
  without a temperature range, spherical ice stated once, no ventilation or sedimentation, e ≪ p, a
  Köhler equilibrium accepted on ice.
- *Statistics.* Every standard error in SS assumes independent samples while the package is advertised
  for time-marching solvers; weighted merges turn counts into total weight, which the standard errors
  divide by as if it were a sample size; the old triad "estimand, bias, convergence" was SS's own
  docstring template, so a reader sent to look for it would find it on every page and pass.
- *Architecture.* Nothing in the text was distinctly an architect's. The reader is built on the full
  bundle, source included, while the text said "as documented, not as implemented".

Two defects in the **tool** rather than the texts: the sentence `derive` appended to every discipline
said "whether or not a rule names it", against the module's own definition and licensing the double
reporting above; and no text said what the source in front of the reader was for.

**Changed after round one:** all six texts rewritten around the field's theory as oracle; each first
sentence given a main verb; objects named as the packages have them; boundaries drawn (theorist says what
a spectrum should be, analyst whether the number returned is the estimator claimed; statistician owns
sampling models); the appended sentence rewritten.

## Round two — 25 substantive objections, of a different kind

No lens found a rule restated. What remained was words and boundaries, and the eight lenses converged
on the same points from different sides:

- The spectral clause "a numerical claim the code does not contradict but the discretization does" is
  a riddle on a public page, and read literally requires auditing the code (rule-reader and plain reader
  independently). The referent is real — the inclusive dealiasing boundary — so the clause was reworded
  to say it plainly: "a property the scheme is said to have and lacks though code and formula agree".
- "Parseval weights" is PF's coinage, not the field's; spectral differentiation and the grid-to-point
  transfer had been left to nobody.
- The theorist's closed list of three hypotheses missed scale separation and reflection symmetry; its
  textual trigger "where the text has only homogeneity" never fires when page one says "isotropic"; no
  axis existed for attribution; "the ensemble" belongs to the statistician's sampling model; and the
  appended sentence's "the source" (code) collided with the description's "cited source" (a paper).
- The geometer's "takes the declared geometry as given" exempted a structure declared twice or wrongly
  — PF's grid origin is declared in two places. "Value" swallowed the analyst's normalizations.
- The statistician's "nonparametric and streaming" and "bandwidth" would misdescribe the reviewer on a
  batch or parametric package; streaming round-off claims had been excluded by construction; "against
  theory, not code" replanted the round-one question of whether the others read code.
- The microphysicist's checklist of four package-specific gaps read as exhaustive, one item was already
  stated in CP, and "a quantity named against the field's convention" could not reach "glaciation" used
  for evaporation, a process not a quantity.
- The architect's own source clause ("with the source open to show a promise is keepable") disagreed
  with the appended one; "unit" would read as a physical unit on a physics package's site where the
  defect is a grain; "two strengths" collided with the tool's `Strength`; "two guarantees that cannot
  both hold" drew no line with the logician; and the text still had no object that was the architect's
  rather than an API-contract reviewer's.
- The appended sentence told the reader to withhold a finding "a listed rule already covers" — a list
  it is not shown, and a withholding on its own guess, which the module's own docstring calls the pass
  indistinguishable from not looking. Deduplication is the program's, by rule id.

**Changed after round two:** every text reworded per the lenses' agreed proposals; the appended sentence
now says a defect a rule names is reported under that rule's id, and calls the code "the code".

## Round three — nine substantive objections, each a phrase

Every lens found at most one thing of substance, and each was an addition to a list or a single word:

- The geometer: the coordinate chart and origin were not among "these", so the grid origin declared two
  ways was not reportable; a slot convention declared twice is a "convention", not a "structure".
- The analyst: "the grid-to-point transfer" is not the field's word and names one direction of two; PF
  says interpolation and deposition, and reserves "transfer" for the restriction operator and a filter's
  transfer function, while on a turbulence page "transfer" reads as energy transfer.
- The theorist: "unstated at its site" collides with this tool's glossary, where "site" is the built
  documentation site, so a reader would ask whether isotropy is stated anywhere on the site rather than
  where the law is invoked.
- The microphysicist: activation and ice nucleation open the field's own sequence and were absent; an
  aerosol-activation package's owner would not have known the reader was theirs.
- The statistician: a readout that states no estimand at all is not "a claim stated without its
  assumption" and could not be reached.
- The architect: "grain is unnamed" lets a grain that is named but ambiguous pass — PF's invariant 9 is
  exactly that; "per fiber" is PF's word.
- The rule-reader: the architect's clause about an invariant a type or a dispatch could keep is judged on
  the code's design and its only fix is a code change, which a documentation review cannot make, so it
  contradicted "never the thing under review"; and the microphysicist's closures and the theorist's
  hypotheses shared a defect, a turbulence law inside a cloud package with its hypothesis unstated.
- The plain-language reader: the appended sentence had a dangling subject ("An open reader — … — it
  reads"), on every row.

The architect and the rule-reader disagreed on the dispatch clause; the rule-reader's objection stands on
the tool's own terms, and the clause became a documentation defect: a duty put on the caller with no
word on what its breach does.

**Changed after round three:** all nine applied; the appended sentence names no layout ("handed by
id" rather than "named below", since the role is serialised in hash order), names the rulebook's path,
and reads as one sentence.

## Round four — four substantive objections; three lenses return zero

The plain-language reader, the statistician and the architect found nothing of substance. The
rule-reader found nothing. Four specialists each found one, each an addition the specialist supplied:

- The geometer: "measure" was among the structures audited but the Reports clause licensed only sign and
  argument order, and PF's own formalization names a measure defect, an adjoint stated without saying
  against which inner product. "Measure" joined the Reports clause; not "normalization", which is the
  analyst's.
- The analyst: "a cited scheme written in variant form" would report deliberate, documented variants
  as defects, and both packages carry such variants openly with their reasons. It became "a cited scheme
  varied with the departure unmarked". "Deposition" is not the packages' word; PF says anterpolation.
- The theorist: a validity range the package set itself has no paper to depart from, and two of HT's own
  are defective by the package's own arithmetic. "Or, unpublished, from theory" was added, and "a misused
  term" became "a term of the theory misused" to stay off the microphysicist's.
- The microphysicist: the moist-air thermodynamics beneath the processes, the first and largest
  documented surface in CP, was not in the reading list.

The rule-reader also corrected a premise the plain-language lens had been given: the descriptions reach
the agent's prompt and, through `Render.readers_page`, the readers page of a declaring package's site;
both audiences are real.

## Round five — one substantive objection, on a clause added in round four

Six lenses were run: the four specialists whose texts had changed, the rule-reader and the plain-language
reader. Five returned zero. The theorist found that its own round-four addition, "or, unpublished, from
theory", named no standard and would let a reader re-set a validity floor by taste and print it as a
defect; the clause was bound to "what its own algebra or a cited result implies", with an unsupported
floor reported as unsupported and never re-set. The analyst asked, as a minor, that transform
normalization be named in its reading list so an owner can see who owns it; two words were added. The
microphysicist answered the round-four worry about processes the package does not yet have: the text
names the reader's field, not the package's index, and a parcel that says nothing about neglecting
collision is the unsaid assumption the reader should report, not the absence of a module.

## Rounds six and seven — the last clause, and convergence

Round six put the bound clause to the theorist and the rule-reader. The rule-reader passed it; the
theorist found one more thing of substance in its own clause: "if unpublished" qualified the law rather
than the floor, and "what its own algebra implies" left open whether the reader might hunt for the
implication and re-set a floor by the back door. The clause had grown a nested parenthetical with each
pass, which was the wrong direction, so it was restructured rather than refined: the unsupported floor
became its own list item — "a value or validity floor the documentation states but neither cites nor
derives, reported as unsupported and never re-set" — a fact rather than a classification.

Round seven put the restructured sentence to the theorist and the plain-language reader. Both returned
zero. The theorist filed HT's three cases under the text as written — Lundgren's floor of 50 unsupported
(the docstring derives the bound 34, not the margin above it), Li et al.'s G ≈ 0.9 and its floor of 100
unsupported twice, Kolmogorov 1941 nothing — and found each a fact, not a matter of taste.

**Trajectory of substantive objections, by round:** 32, 25, 9, 4, 1, 1, 0.

## What the attack changed in the tool, not only in the texts

- The sentence `derive` appends to every discipline no longer says "whether or not a rule names it". It
  says the reader reports what no rule names, that a defect a rule does name is reported under that
  rule's id as the rulebook in `.gbg/policy/` states it, and that the code is context for reading the
  documentation and never the thing under review.
- The four generalist rules are named as such to every attacker, and the texts now draw their seams
  explicitly: the theorist never judges how the grid estimates a quantity; a spectrum's estimator is the
  analyst's; the turbulence law a closure rests on is the theorist's; the measure a pairing is taken
  against is the geometer's, the transform's scaling the analyst's.

## The owner's redirection of the architect

Put the six, the owner kept the id `spectral_numerics`, asked to discuss the texts, and on the architect
ruled two things. Asked whether that reader would spot the classical bad coding habits — duplication,
premature optimization, control flow long advised against — the answer was no: it reads documentation
with the code as context only. The owner put a CODE-review instrument for those habits on the to-do
beside the leak scan (`IMPLEMENTATION.md` Phase 10). And he restated what the architect is for, in his
words: "its role was supposed to find bad design of the package. Documentation is enough for that. Like
things belonging to a wrong module, bad module structure (splitting code in modules), etc. Not from the
physical domain point of view, but from computer scientist theoretical perspective." The rubric requires
module docstrings to be maps, so structure and responsibilities are documented.

The seven-round text had narrowed to API contracts — ownership, aliasing, grain — because those were
what the lenses could ground in PF's design page. It was redrafted toward module maps, responsibilities,
placement and dependencies and put to three lenses again, twice:

- The computer scientist, reading PF's module maps, found the structural defects the API text could not
  reach — modules coupled through siblings' underscore names as their real interface, a public surface
  wider than any documented operation, no declared dependency order — and struck two clauses: "exposes
  its representation" would fire on every struct docstring the rulebook itself requires, and "could keep
  it" is a counterfactual the reader would have to design. It also caught that the idiom clause misstated
  Julia: a method beside its operation family is as idiomatic as one beside its type.
- The rule-reader held two of the computer scientist's findings to be a program's or the code review's,
  not this reader's: an underscore import and an unused export are visible only in the code. What survives
  is the judgement on what the documentation states — a reach into siblings' unexported names is this
  reader's only where a design page states it as policy, which PF's does — and a dependency is reportable
  only against the place the map states, since no rule asks a map to list dependencies.
- The plain-language reader cut the draft from 106 words, caught a first sentence that did not parse in
  one pass and an item that read as "report every public function", and moved the words toward an owner's.

The code-visible facts the rule-reader excluded — underscore imports across modules, exports nothing uses,
cyclic or out-of-order `using` — are the first concrete items for the code review's list.

The final confirmation of the redirected text returned zero from the rule-reader; the computer scientist
and the plain-language reader each returned word-level objections — "left to the caller's care" narrowed
PF's own unguarded invariant, a maintainer's discipline, out of reach; "map" is this tool's word for a
docstring; "a dependency against the place" did not parse — and their agreed wording was applied without a
further round, since each was the lens's own replacement and the owner was waiting to discuss.

## The owner's verdict: auditors, not experts

Asked what a software architect does in the real world and whether either architect text came close,
the honest answer was that neither did, and that the other five had narrowed the same way. Seven rounds
of lenses asking "is this a fact, not taste", "does it overlap a rule", "is it judgeable from the
documentation alone" and "does it relitigate a reasoned decision" had turned six experts into six
auditors: each checked stated claims against a fixed external standard and none judged whether the
model, method, estimator or decomposition was the right one for the package's purpose. The owner ruled
the texts should be rewritten as experts with an explicit licence to judge appropriateness, made
accountable by requiring every judgement to name the standard applied, the alternative preferred and
what the stated reason fails to answer — so that the owner can disagree — with overlaps routed by rule
id rather than trimmed, the code kept as context, and the lens question changed from "fact, not taste"
to "is this judgement stated so the owner can disagree with it". He then asked for a blind agent to
compare the result to the texts as they stood, and to say whether it was more meaningful.

## The expert set and the blind comparison

Six expert drafts were written to that brief and put once through the six specialists under the new
lens; each came back with a replacement text and a set of referee-grade findings on its package. Those
replacements became the expert set. The comparison was then run blind, twice:

- One judge per discipline was given two texts labelled A and B — provenance hidden, order
  counterbalanced across disciplines and reversed between the rounds — together with the declaring
  package (PF for geometry, spectral numerics and architecture; HT for turbulence; CP for cloud
  microphysics; SS for statistics). Each judge read the package's documentation, filed the findings each
  text would file, then judged which text describes a working expert, whose findings would change what
  the author writes or decides, what each licenses that is harmful, and whether the author can disagree
  with a finding under each. The architect was a three-way: the expert text, the seven-round text and
  the redirected text.
- A seventh judge saw only the two sets of six texts, no package.
- Between the rounds the grafts the first judges asked for were folded in and the sentences shortened.

**Round one:** the expert text won all six, five at confidence 4 and statistics at 3; the sets-only judge
chose it in four fields, a combination in statistics, and the redirected architect for its clause on
Julia's dispatch. **Round two,** orders reversed: the expert text won all six at confidence 4, the
architect again over both alternatives; the sets-only judge chose it in four fields and a combination
in turbulence and architecture on readability alone, with a clear margin overall.

The reason every judge gave was the same. Under the expert texts each finding must name the standard,
the alternative and what the recorded reason leaves unanswered, so a "no" is possible and informed;
under the seven-round texts the verdicts — "undeclared", "unsupported", "left unsaid" — can be answered
only by adding a sentence. And the expert findings change what is computed or decided where the
seven-round findings change a sentence. What the judges filed on the real packages under the expert
texts and could not file under the others: PF's demo applies the two-thirds rule as a sphere where
Orszag's is the cube, and its Heun step has no stability interval on the imaginary axis; PF declares the
gradient's index order one way on the architecture page and the other in the docstring, and presents the
Nyquist zeroing as a convention where it follows from the declared interpolant; PF's reductions module
depends on its convolution module against a recorded decision that says all three depend only on the
foundation; no documented HT run reaches any shipped law's validity range, and isotropy is invoked at
four sites with no diagnostic that could test it; CP's flow conditions claim a single diffusivity where
the growth coefficient uses two, and its README example has no source of supersaturation variance yet
feeds a stochastic model with one; SS divides every standard error by the raw count under a declared
time-marching use, and its default bandwidth loses an order of magnitude to two alternatives in the
package's own tests with no reason recorded.

What the judges asked the winners to keep from the losers was folded in: the concrete sites and the
covector example for the geometer; "though code matches formula" and the estimator-name clause verbatim
for the analyst; "never against how the grid estimates a quantity", attribution and "never re-set" for
the theorist; the named examples and process inventory for the microphysicist, with the package-specific
nouns removed; the closed list of claims and "under weights or dependence" for the statistician; and for
the architect the Julia preamble from the redirected text and "two strictnesses", the grain test and the
caller's duty from the seven-round text. One ask was not folded: the redirected architect's gate "where
no reason is given", because the expert text's closing sentence — a weighed alternative is not reported
unless the reader says why the weighing is wrong — is the more careful form of the same restraint and
the gate would restore the very protection of every defended choice the owner had ruled against. Every
judge still found the texts longer than one pass; the report clauses are what the judges valued, so
length was traded for keeping them.

## Adopted 2026-09-21 (decision 28 resolved)

The owner adopted the expert set with the second round's asks folded in. These are the texts in
`Catalogue.DISCIPLINES`, each shown verbatim to its reader as its whole standpoint and printed on the
readers page of every package that declares it. The id `spectral_numerics` stays.

**`differential_geometry`**

> A differential geometer judges whether the structure the package names — the manifold with its coordinates and origin, frame, orientation, metric and measure, the group its operations are claimed invariant under, and the identifications between objects, such as vector with covector by the metric — is the structure its statements use, and whether each statement keeps to it. It traces each sign, argument order and measure to the structure it rests on, and asks which continuum identities the discretization keeps, where, and which it loses. It reports a structure a statement rests on that no page declares or two declare differently, an identification used where its hypothesis fails, a structure named that nothing uses, and a declared choice whose reason leaves a geometer's objection standing. Each filing names the standard, the alternative and, where a reason is stated, what it leaves unanswered.

**`spectral_numerics`**

> A numerical analyst of Fourier pseudo-spectral methods judges whether the discretization is apt for the use the documentation declares and whether its claims about it hold. It reads the transforms, their normalization and conjugate-symmetric half, the Nyquist planes, dealiasing and the band it leaves against the scales computed, spectral differentiation, shell-binned spectral estimators as lattice quadratures, interpolation and anterpolation between grid and points, time stepping with its stability, order and stiff-term treatment, and the floating-point precision any stated number or equality depends on. A spectrum's sampling variance is the statistician's and the law it is compared with the theorist's. It reports a claimed property the scheme lacks though code matches formula; an estimator given the name of the continuous quantity it approximates with no word on where the two differ; a method that falls short of the declared use, stating that use, the requirement it implies and the measure of the shortfall; an error, convergence or cost claim without its order and regime; a claim made for one precision and true in another; and a scheme cited but varied without saying so. Each names the standard applied and the alternative.

**`turbulence_theory`**

> A theorist of turbulence judges whether the package's physics is stated as the field states it — or, where it departs, says so and converts — never against how the grid estimates a quantity. It reads laws, constants and scales against their papers in value, convention, attribution and validity range; the relations theory fixes between constants; the hypotheses each result rests on — homogeneity, isotropy, stationarity, scale separation, a box average for the ensemble — and whether each is stated, met by the documented runs and testable by the shipped diagnostics; whether those runs reach each law's validity range; and what the forcing does to the statistics measured there. It reports a departure from a source; a relation the theory fixes between constants stated separately; a value or floor neither cited nor derived, placed where its source does not put it, or placed without saying what fails below it, reported as unsupported and never re-set; a hypothesis unstated, unmet or untestable; a diagnostic whose definition is not the quantity its name denotes, its estimator being the analyst's; and a choice whose stated reason a result contradicts, an unmet hypothesis undermines or a different question answers. Each filing names that result, hypothesis or question, the field's alternative, and what the reason leaves unanswered.

**`cloud_microphysics`**

> A cloud microphysicist judges whether the model fits the regime its documentation claims and its examples run. It reads the moist thermodynamics and its linearization, activation, the growth laws and their defaults, the supersaturation budgets over water and ice, the size distribution and its reductions to moments or to one radius, ice nucleation, glaciation and collection, the processes omitted, the microphysical side of each turbulence closure — what the particles do to the supersaturation they see, the turbulence law itself being the theorist's — and whether the package's levels of model, from parcel to resolved simulation, are consistent levels of one hierarchy. It reports an assumption or an omitted process, such as spherical particles or no ventilation, given no reason for the regime; a default or example value implausible at its stated conditions, or given with no conditions to judge it by; a law or constant used outside the phase, size or range its source states; a symbol used against the source the documentation cites or, where it cites none, against the usual one, named; a level of the hierarchy defining a quantity unlike the one it approximates; and a stated reason that leaves a physical question open. Each names the source, the alternative and the open question.

**`statistical_estimation`**

> A statistician judges whether each documented estimator, selector and diagnostic is the right tool for its question under the package's declared use. It reads the sampling model behind every standard error, bias, rate and stability claim — the independence, stationarity and weighting each sample count assumes, or the effective sample size under weights or dependence that replaces it — the regime where each property holds, and the tests as the documentation's evidence for them; a spectrum's estimator is the spectral analyst's. It reports a standard error, bias, rate, stability claim or estimand stated without the assumption it needs or false for the declared use; an estimate with no estimand; an uncertainty the data cannot support; and a choice a named alternative would better serve by a named criterion. Each quotes the package's reason and what it leaves unanswered, an absent reason being the finding.

**`software_architecture`**

> A software architect judges the design as the documentation states it against what the package is for and the changes it expects, in Julia's terms: a method may sit beside its operation family or beside its type, and a generic extended in several modules is not split. It reads the modules and their responsibilities, the interfaces and dependency direction between them, each invariant and the mechanism the documentation says keeps it, the quality attributes the design buys and at what cost, and the reasons recorded for each decision with the alternatives rejected. It reports a module whose parts change for different reasons or whose responsibility is not stated; a responsibility placed where a change the documentation expects would ripple across parts; a dependency against the stated layering, or a declared policy of reaching into siblings' unexported names rather than exporting them; an interface no part states or wider than the parts name; a concept two modules own or two names denote; a contract stated at two strictnesses in two places, or whose grain — entry, aggregate or call — is unfixed; a duty put on the caller with no word on what its breach does; a quality attribute claimed without its cost; a mechanism a simpler design would replace, that design and what it gives up named; an invariant with no stated mechanism, or left to care where a named enforcement would hold it, with its cost; and a decision whose recorded reason does not answer the objection stated. Each names the principle, the alternative and the recorded decision it answers, quoting what the reason leaves unanswered or that none is recorded; an alternative the recorded reason already weighs is not reported unless the reader says why the weighing is wrong.

**Appended to each by the tool:**

> An open reader — bound to no rule beyond those it is handed by id — reads the whole documentation and reports whatever is wrong in its field that no rule names; a defect a rule does name is reported under that rule's id, as the rulebook in .gbg/policy/ states it, not as the field's. The code is context for reading the documentation, never the thing under review.

and, where the package's rules bind the discipline:

> The rule(s) it is handed are this reader's to judge.

## What the method taught

An adversarial round over a standpoint — a reader, a role, an expert — must not ask "is this a fact,
not taste"; it selects for auditors. It asks "is this judgement stated so the owner can disagree with
it", and it routes an overlap with a rule by id rather than trimming it. A blind, package-grounded
comparison is the test that tells the two apart: the auditor texts converged to zero objections and
still lost every field to texts that had been through one round.
