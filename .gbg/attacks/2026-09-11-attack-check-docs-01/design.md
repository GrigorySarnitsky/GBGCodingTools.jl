# The lens set of /check-docs over GBGCodingTools — every lane or hat of its current roster

## rationale (surface)

reads: docs/ARCHITECTURE.md

RUN EACH CHECK AS A POSITIVE PROCEDURE: enumerate the items, then verify each one. A defect that is absent-by-omission — an unbound symbol, a false-but-plausible formula, an argument that is never documented — does not announce itself on a read-through, so passive reading is NOT a check. GROUND TRUTH is the package's `src/`: verify every claim against the code and quote the decisive line.

The checks on your surface:
1. CORRECT — every formula, normalization constant, conservation or adjoint relation, complexity claim and quantifier (exact / all / never / bit-for-bit) true and precise, verified against the code or by derivation; free of CATEGORY/TYPE ERRORS (an object vs its representation, an operator vs its parameter, a rate vs its integral, a scalar vs the field it reduces). Type every object from the code.
2. SELF-CONTAINED — every symbol bound at first use (or on the notation page); every signature argument documented, enumerated FROM THE SIGNATURE (positional and keyword), each its own entry; a term of art explained or `@ref`-linked. The package's terms are consumer; instrument; round; lane; hat; anchor; gate; pin; managed file; ledger.
3. NOTATION — one symbol per concept and one concept per symbol; the house glyphs as the rendered policy states them for this package; math variables symbolic, storage descriptive.
4. FORMATTED — math is LaTeX never backticks; every code identifier backticked never bare; no code name inside a math span; no formula split across a math/code boundary; the TeX idiom of the rendered policy `latex-idiom.md`.
5. CURRENT & COMPLETE — every claim matches the code's PRESENT state. A docstring that names only a SUBSET of what the code now provides is stale even if literally true; check each summary against the current exports and method set.
6. CITED — author-year consistent, matching the package's references entry (or the whole rationale document where it keeps no references heading); no inaccessible source.

OUTPUT: report only GENUINE findings, each with file:line, the decisive quote (<= 25 words) and a concrete fix. Do NOT report style preferences, and do NOT report things the rulebook explicitly permits — the package's deliberate absences are no layering in config; no consumer copies in the tool; no Python. Cap at your 20 most significant, and report `candidates_found`, the number you weighed before the cap. If a surface is clean, return an empty findings list with a non-empty `checked[]` — that is a real and useful result; an empty `checked[]` reads as a dead lane.

YOUR SURFACE IS THE `rationale` SURFACE: the files listed in your prompt, every one read fully.

## pages (surface)

reads: docs/src/api/CLI.md, docs/src/api/Config.md, docs/src/api/Reflection.md, docs/src/api/TestHarness.md, docs/src/api/Witnesses.md, docs/src/guide/config.md, docs/src/guide/install.md, docs/src/guide/ledger.md, docs/src/guide/rounds.md, docs/src/guide/verbs.md, docs/src/index.md

RUN EACH CHECK AS A POSITIVE PROCEDURE: enumerate the items, then verify each one. A defect that is absent-by-omission — an unbound symbol, a false-but-plausible formula, an argument that is never documented — does not announce itself on a read-through, so passive reading is NOT a check. GROUND TRUTH is the package's `src/`: verify every claim against the code and quote the decisive line.

The checks on your surface:
1. CORRECT — every formula, normalization constant, conservation or adjoint relation, complexity claim and quantifier (exact / all / never / bit-for-bit) true and precise, verified against the code or by derivation; free of CATEGORY/TYPE ERRORS (an object vs its representation, an operator vs its parameter, a rate vs its integral, a scalar vs the field it reduces). Type every object from the code.
2. SELF-CONTAINED — every symbol bound at first use (or on the notation page); every signature argument documented, enumerated FROM THE SIGNATURE (positional and keyword), each its own entry; a term of art explained or `@ref`-linked. The package's terms are consumer; instrument; round; lane; hat; anchor; gate; pin; managed file; ledger.
3. NOTATION — one symbol per concept and one concept per symbol; the house glyphs as the rendered policy states them for this package; math variables symbolic, storage descriptive.
4. FORMATTED — math is LaTeX never backticks; every code identifier backticked never bare; no code name inside a math span; no formula split across a math/code boundary; the TeX idiom of the rendered policy `latex-idiom.md`.
5. CURRENT & COMPLETE — every claim matches the code's PRESENT state. A docstring that names only a SUBSET of what the code now provides is stale even if literally true; check each summary against the current exports and method set.
6. CITED — author-year consistent, matching the package's references entry (or the whole rationale document where it keeps no references heading); no inaccessible source.

OUTPUT: report only GENUINE findings, each with file:line, the decisive quote (<= 25 words) and a concrete fix. Do NOT report style preferences, and do NOT report things the rulebook explicitly permits — the package's deliberate absences are no layering in config; no consumer copies in the tool; no Python. Cap at your 20 most significant, and report `candidates_found`, the number you weighed before the cap. If a surface is clean, return an empty findings list with a non-empty `checked[]` — that is a real and useful result; an empty `checked[]` reads as a dead lane.

YOUR SURFACE IS THE `pages` SURFACE: the files listed in your prompt, every one read fully.

## src (surface)

reads: src/CLI/Audit.jl, src/CLI/Bump.jl, src/CLI/Config.jl, src/CLI/Consolidate.jl, src/CLI/Demote.jl, src/CLI/Design.jl, src/CLI/Doctor.jl, src/CLI/Fleet.jl, src/CLI/Gate.jl, src/CLI/Git.jl, src/CLI/Hunt.jl, src/CLI/Init.jl, src/CLI/Install.jl, src/CLI/Ledger.jl, src/CLI/Main.jl, src/CLI/Passes.jl, src/CLI/Preflight.jl, src/CLI/Recall.jl, src/CLI/Release.jl, src/CLI/RoundFiles.jl, src/CLI/Rounds.jl, src/CLI/Schema.jl, src/CLI/Seed.jl, src/CLI/Self.jl, src/CLI/Selftest.jl, src/CLI/Sync.jl, src/DocLints.jl, src/GBGCodingTools.jl, src/HtmlWalker.jl, src/Reflection.jl, src/Scan.jl, src/Scans/abutting_spans.jl, src/Scans/ai_banner.jl, src/Scans/api_page_structure.jl, src/Scans/arg_bullet_bold.jl, src/Scans/argcov.jl, src/Scans/args_form.jl, src/Scans/boldsymbol_unbraced.jl, src/Scans/citation_crammed.jl, src/Scans/code_in_math.jl, src/Scans/dead_ref.jl, src/Scans/doi_crosscheck.jl, src/Scans/dupref.jl, src/Scans/field_docs.jl, src/Scans/formula_in_backticks.jl, src/Scans/frac_unbraced.jl, src/Scans/html_base_leak.jl, src/Scans/html_docstring_once.jl, src/Scans/html_public_home.jl, src/Scans/html_rendered_markup.jl, src/Scans/html_stray_math.jl, src/Scans/inline_math_split.jl, src/Scans/leftright.jl, src/Scans/link_uniformity.jl, src/Scans/manual_spacing.jl, src/Scans/mathbb_digit.jl, src/Scans/mathbf.jl, src/Scans/neg_thin_bigl.jl, src/Scans/neg_thin_double.jl, src/Scans/partial_bare.jl, src/Scans/prose_shape.jl, src/Scans/ref_abut_code.jl, src/Scans/register.jl, src/Scans/retired_claims.jl, src/Scans/sentence_opener.jl, src/Scans/sibling_link.jl, src/Scans/signature_fidelity.jl, src/Scans/signature_wide.jl, src/Scans/stray_tex_dollar.jl, src/Scans/swallowed_escape.jl, src/Scans/table_indented.jl, src/Scans/thin_space.jl, src/Scans/xlink.jl, src/TestHarness.jl, src/TreeHash.jl, src/Witnesses.jl

RUN EACH CHECK AS A POSITIVE PROCEDURE: enumerate the items, then verify each one. A defect that is absent-by-omission — an unbound symbol, a false-but-plausible formula, an argument that is never documented — does not announce itself on a read-through, so passive reading is NOT a check. GROUND TRUTH is the package's `src/`: verify every claim against the code and quote the decisive line.

The checks on your surface:
1. CORRECT — every formula, normalization constant, conservation or adjoint relation, complexity claim and quantifier (exact / all / never / bit-for-bit) true and precise, verified against the code or by derivation; free of CATEGORY/TYPE ERRORS (an object vs its representation, an operator vs its parameter, a rate vs its integral, a scalar vs the field it reduces). Type every object from the code.
2. SELF-CONTAINED — every symbol bound at first use (or on the notation page); every signature argument documented, enumerated FROM THE SIGNATURE (positional and keyword), each its own entry; a term of art explained or `@ref`-linked. The package's terms are consumer; instrument; round; lane; hat; anchor; gate; pin; managed file; ledger.
3. NOTATION — one symbol per concept and one concept per symbol; the house glyphs as the rendered policy states them for this package; math variables symbolic, storage descriptive.
4. FORMATTED — math is LaTeX never backticks; every code identifier backticked never bare; no code name inside a math span; no formula split across a math/code boundary; the TeX idiom of the rendered policy `latex-idiom.md`.
5. CURRENT & COMPLETE — every claim matches the code's PRESENT state. A docstring that names only a SUBSET of what the code now provides is stale even if literally true; check each summary against the current exports and method set.
6. CITED — author-year consistent, matching the package's references entry (or the whole rationale document where it keeps no references heading); no inaccessible source.

OUTPUT: report only GENUINE findings, each with file:line, the decisive quote (<= 25 words) and a concrete fix. Do NOT report style preferences, and do NOT report things the rulebook explicitly permits — the package's deliberate absences are no layering in config; no consumer copies in the tool; no Python. Cap at your 20 most significant, and report `candidates_found`, the number you weighed before the cap. If a surface is clean, return an empty findings list with a non-empty `checked[]` — that is a real and useful result; an empty `checked[]` reads as a dead lane.

YOUR SURFACE IS THE `src` SURFACE: the files listed in your prompt, every one read fully.

## ext (surface)

reads: ext/GBGCodingToolsDocumenterExt.jl

RUN EACH CHECK AS A POSITIVE PROCEDURE: enumerate the items, then verify each one. A defect that is absent-by-omission — an unbound symbol, a false-but-plausible formula, an argument that is never documented — does not announce itself on a read-through, so passive reading is NOT a check. GROUND TRUTH is the package's `src/`: verify every claim against the code and quote the decisive line.

The checks on your surface:
1. CORRECT — every formula, normalization constant, conservation or adjoint relation, complexity claim and quantifier (exact / all / never / bit-for-bit) true and precise, verified against the code or by derivation; free of CATEGORY/TYPE ERRORS (an object vs its representation, an operator vs its parameter, a rate vs its integral, a scalar vs the field it reduces). Type every object from the code.
2. SELF-CONTAINED — every symbol bound at first use (or on the notation page); every signature argument documented, enumerated FROM THE SIGNATURE (positional and keyword), each its own entry; a term of art explained or `@ref`-linked. The package's terms are consumer; instrument; round; lane; hat; anchor; gate; pin; managed file; ledger.
3. NOTATION — one symbol per concept and one concept per symbol; the house glyphs as the rendered policy states them for this package; math variables symbolic, storage descriptive.
4. FORMATTED — math is LaTeX never backticks; every code identifier backticked never bare; no code name inside a math span; no formula split across a math/code boundary; the TeX idiom of the rendered policy `latex-idiom.md`.
5. CURRENT & COMPLETE — every claim matches the code's PRESENT state. A docstring that names only a SUBSET of what the code now provides is stale even if literally true; check each summary against the current exports and method set.
6. CITED — author-year consistent, matching the package's references entry (or the whole rationale document where it keeps no references heading); no inaccessible source.

OUTPUT: report only GENUINE findings, each with file:line, the decisive quote (<= 25 words) and a concrete fix. Do NOT report style preferences, and do NOT report things the rulebook explicitly permits — the package's deliberate absences are no layering in config; no consumer copies in the tool; no Python. Cap at your 20 most significant, and report `candidates_found`, the number you weighed before the cap. If a surface is clean, return an empty findings list with a non-empty `checked[]` — that is a real and useful result; an empty `checked[]` reads as a dead lane.

YOUR SURFACE IS THE `ext` SURFACE: the files listed in your prompt, every one read fully.

## built-html (surface)

reads: docs/build

RUN EACH CHECK AS A POSITIVE PROCEDURE: enumerate the items, then verify each one. A defect that is absent-by-omission — an unbound symbol, a false-but-plausible formula, an argument that is never documented — does not announce itself on a read-through, so passive reading is NOT a check. GROUND TRUTH is the package's `src/`: verify every claim against the code and quote the decisive line.

The checks on your surface:
1. CORRECT — every formula, normalization constant, conservation or adjoint relation, complexity claim and quantifier (exact / all / never / bit-for-bit) true and precise, verified against the code or by derivation; free of CATEGORY/TYPE ERRORS (an object vs its representation, an operator vs its parameter, a rate vs its integral, a scalar vs the field it reduces). Type every object from the code.
2. SELF-CONTAINED — every symbol bound at first use (or on the notation page); every signature argument documented, enumerated FROM THE SIGNATURE (positional and keyword), each its own entry; a term of art explained or `@ref`-linked. The package's terms are consumer; instrument; round; lane; hat; anchor; gate; pin; managed file; ledger.
3. NOTATION — one symbol per concept and one concept per symbol; the house glyphs as the rendered policy states them for this package; math variables symbolic, storage descriptive.
4. FORMATTED — math is LaTeX never backticks; every code identifier backticked never bare; no code name inside a math span; no formula split across a math/code boundary; the TeX idiom of the rendered policy `latex-idiom.md`.
5. CURRENT & COMPLETE — every claim matches the code's PRESENT state. A docstring that names only a SUBSET of what the code now provides is stale even if literally true; check each summary against the current exports and method set.
6. CITED — author-year consistent, matching the package's references entry (or the whole rationale document where it keeps no references heading); no inaccessible source.

OUTPUT: report only GENUINE findings, each with file:line, the decisive quote (<= 25 words) and a concrete fix. Do NOT report style preferences, and do NOT report things the rulebook explicitly permits — the package's deliberate absences are no layering in config; no consumer copies in the tool; no Python. Cap at your 20 most significant, and report `candidates_found`, the number you weighed before the cap. If a surface is clean, return an empty findings list with a non-empty `checked[]` — that is a real and useful result; an empty `checked[]` reads as a dead lane.

YOUR SURFACE IS THE BUILT HTML under `docs/build`: what each `@docs`/`@autodocs` block actually collected is visible only here — read every API page's rendered content, and check each page blurb against what its block holds.

## workflow-scripts (surface)

reads: instruments/prelude.js, instruments/check-docs/workflow, instruments/check-consistency/workflow, instruments/bug-hunt/workflow, instruments/audit-changes/workflow

RUN EACH CHECK AS A POSITIVE PROCEDURE: enumerate the items, then verify each one. A defect that is absent-by-omission — an unbound symbol, a false-but-plausible formula, an argument that is never documented — does not announce itself on a read-through, so passive reading is NOT a check. GROUND TRUTH is the package's `src/`: verify every claim against the code and quote the decisive line.

The checks on your surface:
1. CORRECT — every formula, normalization constant, conservation or adjoint relation, complexity claim and quantifier (exact / all / never / bit-for-bit) true and precise, verified against the code or by derivation; free of CATEGORY/TYPE ERRORS (an object vs its representation, an operator vs its parameter, a rate vs its integral, a scalar vs the field it reduces). Type every object from the code.
2. SELF-CONTAINED — every symbol bound at first use (or on the notation page); every signature argument documented, enumerated FROM THE SIGNATURE (positional and keyword), each its own entry; a term of art explained or `@ref`-linked. The package's terms are consumer; instrument; round; lane; hat; anchor; gate; pin; managed file; ledger.
3. NOTATION — one symbol per concept and one concept per symbol; the house glyphs as the rendered policy states them for this package; math variables symbolic, storage descriptive.
4. FORMATTED — math is LaTeX never backticks; every code identifier backticked never bare; no code name inside a math span; no formula split across a math/code boundary; the TeX idiom of the rendered policy `latex-idiom.md`.
5. CURRENT & COMPLETE — every claim matches the code's PRESENT state. A docstring that names only a SUBSET of what the code now provides is stale even if literally true; check each summary against the current exports and method set.
6. CITED — author-year consistent, matching the package's references entry (or the whole rationale document where it keeps no references heading); no inaccessible source.

OUTPUT: report only GENUINE findings, each with file:line, the decisive quote (<= 25 words) and a concrete fix. Do NOT report style preferences, and do NOT report things the rulebook explicitly permits — the package's deliberate absences are no layering in config; no consumer copies in the tool; no Python. Cap at your 20 most significant, and report `candidates_found`, the number you weighed before the cap. If a surface is clean, return an empty findings list with a non-empty `checked[]` — that is a real and useful result; an empty `checked[]` reads as a dead lane.

YOUR SURFACE (a refinement of the engine's lanes): the eleven Workflow scripts that fan every instrument out, and instruments/prelude.js, the helpers the CLI splices into each at its `// gbg:prelude` line (read a script as it runs: prelude first). Read each as CODE, not prose: does the object it Writes match the schema beside it (instruments/<name>/schema.json and schema/*.json); does it validate the args it requires; can a lane die silently; is any prompt it builds self-contradictory or does it state a rule the CLI does not enforce; is there any package name, path or round datum hard-coded where the design says only `args` may carry it.

## catalogues (surface)

reads: catalog

RUN EACH CHECK AS A POSITIVE PROCEDURE: enumerate the items, then verify each one. A defect that is absent-by-omission — an unbound symbol, a false-but-plausible formula, an argument that is never documented — does not announce itself on a read-through, so passive reading is NOT a check. GROUND TRUTH is the package's `src/`: verify every claim against the code and quote the decisive line.

The checks on your surface:
1. CORRECT — every formula, normalization constant, conservation or adjoint relation, complexity claim and quantifier (exact / all / never / bit-for-bit) true and precise, verified against the code or by derivation; free of CATEGORY/TYPE ERRORS (an object vs its representation, an operator vs its parameter, a rate vs its integral, a scalar vs the field it reduces). Type every object from the code.
2. SELF-CONTAINED — every symbol bound at first use (or on the notation page); every signature argument documented, enumerated FROM THE SIGNATURE (positional and keyword), each its own entry; a term of art explained or `@ref`-linked. The package's terms are consumer; instrument; round; lane; hat; anchor; gate; pin; managed file; ledger.
3. NOTATION — one symbol per concept and one concept per symbol; the house glyphs as the rendered policy states them for this package; math variables symbolic, storage descriptive.
4. FORMATTED — math is LaTeX never backticks; every code identifier backticked never bare; no code name inside a math span; no formula split across a math/code boundary; the TeX idiom of the rendered policy `latex-idiom.md`.
5. CURRENT & COMPLETE — every claim matches the code's PRESENT state. A docstring that names only a SUBSET of what the code now provides is stale even if literally true; check each summary against the current exports and method set.
6. CITED — author-year consistent, matching the package's references entry (or the whole rationale document where it keeps no references heading); no inaccessible source.

OUTPUT: report only GENUINE findings, each with file:line, the decisive quote (<= 25 words) and a concrete fix. Do NOT report style preferences, and do NOT report things the rulebook explicitly permits — the package's deliberate absences are no layering in config; no consumer copies in the tool; no Python. Cap at your 20 most significant, and report `candidates_found`, the number you weighed before the cap. If a surface is clean, return an empty findings list with a non-empty `checked[]` — that is a real and useful result; an empty `checked[]` reads as a dead lane.

YOUR SURFACE (a refinement of the engine's lanes): the catalogues the engine obeys — hats, lanes, scans, models, seeds. For each row: does its `rule` name a rule that exists in policy/RULES.toml; does its `fixture` class exist in the fixture's defects.toml; do its `surfaces` name real surface keys; is a persona's brief consistent with the substrate it is granted; does any two rows contradict each other.

## rulebook (surface)

reads: policy

RUN EACH CHECK AS A POSITIVE PROCEDURE: enumerate the items, then verify each one. A defect that is absent-by-omission — an unbound symbol, a false-but-plausible formula, an argument that is never documented — does not announce itself on a read-through, so passive reading is NOT a check. GROUND TRUTH is the package's `src/`: verify every claim against the code and quote the decisive line.

The checks on your surface:
1. CORRECT — every formula, normalization constant, conservation or adjoint relation, complexity claim and quantifier (exact / all / never / bit-for-bit) true and precise, verified against the code or by derivation; free of CATEGORY/TYPE ERRORS (an object vs its representation, an operator vs its parameter, a rate vs its integral, a scalar vs the field it reduces). Type every object from the code.
2. SELF-CONTAINED — every symbol bound at first use (or on the notation page); every signature argument documented, enumerated FROM THE SIGNATURE (positional and keyword), each its own entry; a term of art explained or `@ref`-linked. The package's terms are consumer; instrument; round; lane; hat; anchor; gate; pin; managed file; ledger.
3. NOTATION — one symbol per concept and one concept per symbol; the house glyphs as the rendered policy states them for this package; math variables symbolic, storage descriptive.
4. FORMATTED — math is LaTeX never backticks; every code identifier backticked never bare; no code name inside a math span; no formula split across a math/code boundary; the TeX idiom of the rendered policy `latex-idiom.md`.
5. CURRENT & COMPLETE — every claim matches the code's PRESENT state. A docstring that names only a SUBSET of what the code now provides is stale even if literally true; check each summary against the current exports and method set.
6. CITED — author-year consistent, matching the package's references entry (or the whole rationale document where it keeps no references heading); no inaccessible source.

OUTPUT: report only GENUINE findings, each with file:line, the decisive quote (<= 25 words) and a concrete fix. Do NOT report style preferences, and do NOT report things the rulebook explicitly permits — the package's deliberate absences are no layering in config; no consumer copies in the tool; no Python. Cap at your 20 most significant, and report `candidates_found`, the number you weighed before the cap. If a surface is clean, return an empty findings list with a non-empty `checked[]` — that is a real and useful result; an empty `checked[]` reads as a dead lane.

YOUR SURFACE (a refinement of the engine's lanes): the 95 rules as prose. Judge them as rules: is each one a statement a reader can obey and a program could in principle check; does any rule contradict another; does any rule state a requirement that the instruments' own protocols contradict; is every rule's `sentinel` in RULES.toml still the first sentence of its paragraph; is any rule dead — nothing in catalog/scans.toml, src/CLI/Doctor.jl or test/ enforces it and no instrument cites it.

## templates (surface)

reads: templates

RUN EACH CHECK AS A POSITIVE PROCEDURE: enumerate the items, then verify each one. A defect that is absent-by-omission — an unbound symbol, a false-but-plausible formula, an argument that is never documented — does not announce itself on a read-through, so passive reading is NOT a check. GROUND TRUTH is the package's `src/`: verify every claim against the code and quote the decisive line.

The checks on your surface:
1. CORRECT — every formula, normalization constant, conservation or adjoint relation, complexity claim and quantifier (exact / all / never / bit-for-bit) true and precise, verified against the code or by derivation; free of CATEGORY/TYPE ERRORS (an object vs its representation, an operator vs its parameter, a rate vs its integral, a scalar vs the field it reduces). Type every object from the code.
2. SELF-CONTAINED — every symbol bound at first use (or on the notation page); every signature argument documented, enumerated FROM THE SIGNATURE (positional and keyword), each its own entry; a term of art explained or `@ref`-linked. The package's terms are consumer; instrument; round; lane; hat; anchor; gate; pin; managed file; ledger.
3. NOTATION — one symbol per concept and one concept per symbol; the house glyphs as the rendered policy states them for this package; math variables symbolic, storage descriptive.
4. FORMATTED — math is LaTeX never backticks; every code identifier backticked never bare; no code name inside a math span; no formula split across a math/code boundary; the TeX idiom of the rendered policy `latex-idiom.md`.
5. CURRENT & COMPLETE — every claim matches the code's PRESENT state. A docstring that names only a SUBSET of what the code now provides is stale even if literally true; check each summary against the current exports and method set.
6. CITED — author-year consistent, matching the package's references entry (or the whole rationale document where it keeps no references heading); no inaccessible source.

OUTPUT: report only GENUINE findings, each with file:line, the decisive quote (<= 25 words) and a concrete fix. Do NOT report style preferences, and do NOT report things the rulebook explicitly permits — the package's deliberate absences are no layering in config; no consumer copies in the tool; no Python. Cap at your 20 most significant, and report `candidates_found`, the number you weighed before the cap. If a surface is clean, return an empty findings list with a non-empty `checked[]` — that is a real and useful result; an empty `checked[]` reads as a dead lane.

YOUR SURFACE (a refinement of the engine's lanes): what `gbg sync` renders into every consumer. Read each template as the file a consumer will receive: is its prose correct about the tool it describes; does every `{{slot}}` correspond to a slot the renderer fills; would the rendered file be valid in its own right (YAML, JSON, sh, Markdown); does any template state a rule that the rulebook does not.

## schemas (surface)

reads: schema, instruments/check-docs/schema.json, instruments/check-consistency/schema.json, instruments/bug-hunt/schema.json, instruments/audit-changes/schema.json

RUN EACH CHECK AS A POSITIVE PROCEDURE: enumerate the items, then verify each one. A defect that is absent-by-omission — an unbound symbol, a false-but-plausible formula, an argument that is never documented — does not announce itself on a read-through, so passive reading is NOT a check. GROUND TRUTH is the package's `src/`: verify every claim against the code and quote the decisive line.

The checks on your surface:
1. CORRECT — every formula, normalization constant, conservation or adjoint relation, complexity claim and quantifier (exact / all / never / bit-for-bit) true and precise, verified against the code or by derivation; free of CATEGORY/TYPE ERRORS (an object vs its representation, an operator vs its parameter, a rate vs its integral, a scalar vs the field it reduces). Type every object from the code.
2. SELF-CONTAINED — every symbol bound at first use (or on the notation page); every signature argument documented, enumerated FROM THE SIGNATURE (positional and keyword), each its own entry; a term of art explained or `@ref`-linked. The package's terms are consumer; instrument; round; lane; hat; anchor; gate; pin; managed file; ledger.
3. NOTATION — one symbol per concept and one concept per symbol; the house glyphs as the rendered policy states them for this package; math variables symbolic, storage descriptive.
4. FORMATTED — math is LaTeX never backticks; every code identifier backticked never bare; no code name inside a math span; no formula split across a math/code boundary; the TeX idiom of the rendered policy `latex-idiom.md`.
5. CURRENT & COMPLETE — every claim matches the code's PRESENT state. A docstring that names only a SUBSET of what the code now provides is stale even if literally true; check each summary against the current exports and method set.
6. CITED — author-year consistent, matching the package's references entry (or the whole rationale document where it keeps no references heading); no inaccessible source.

OUTPUT: report only GENUINE findings, each with file:line, the decisive quote (<= 25 words) and a concrete fix. Do NOT report style preferences, and do NOT report things the rulebook explicitly permits — the package's deliberate absences are no layering in config; no consumer copies in the tool; no Python. Cap at your 20 most significant, and report `candidates_found`, the number you weighed before the cap. If a surface is clean, return an empty findings list with a non-empty `checked[]` — that is a real and useful result; an empty `checked[]` reads as a dead lane.

YOUR SURFACE (a refinement of the engine's lanes): the schemas every artefact is validated against. For each: is it within the validator's documented keyword subset (src/CLI/Schema.jl states it); is every `$ref` local; is it loaded by any code path at all, or is it dead; does it describe the artefact that is actually written, field for field.

## family (cross)

YOUR LANE IS THE ONE CHECK NO PER-SURFACE AGENT CAN RUN because its grouping is relational rather than per-file. Enumerate every f / f! pair and every getter / set_...! pair (and every physical / spectral variant pair) across the source surface, then verify for EACH pair: the two share ONE HOME for the formula (the in-place ! form owns it and is listed first), the other is a thin @ref-linking wrapper with NO second copy of the formula, and NO NOTATION DRIFTS across the pair (partial-derivative spelling, vector boldness, symbol choice). Report a pair whose formula is duplicated, whose home is the wrong member, or whose notation differs between the two.

## cold-reader (cross)

YOUR LANE IS CHECK 2's AUDIENCE HALF. You are a competent scientist in the package's field (review tooling), at home in Julia, NEW to this package, reading the exported docstrings as a REPL user meets them (`?name`), with the design docs withheld. SUBSTRATE RULE: read the MODULE docstring of each module (`?Module`) and EVERY method docstring of a generic, never one collapsed docstring — a reader sees all of them. Flag every symbol, term of art, or package concept used before it is defined or never defined anywhere — the package's terms are consumer; instrument; round; lane; hat; anchor; gate; pin; managed file; ledger. HUNT ESPECIALLY ORDINARY ENGLISH WORDS CARRYING PACKAGE-SPECIFIC MEANINGS — a register, an advance, a record, something armed, a front door — because they read as plain prose and never trip an undefined-symbol check: you understand the English and silently supply the wrong referent. Your read is ORDERED: report where you FIRST meet a term, since a gloss on a later page does not close a bare use on an earlier one. VERIFY each finding against the source before reporting: a term may be defined on the module docstring or a sibling method you did not open.

## operational-claims (cross)

YOUR LANE IS CHECK 1's OPERATIONAL HALF, over the docstring surface. The per-surface lanes verify CONTENT — formulas, factors, relations, quantifiers. A docstring also makes claims about what the call DOES, and those survived every content lane on a real corpus: a step described as "the CFL value" where the code takes the smallest of three bounds; a keyword bullet saying "no ceiling by default" beside a bound that is exactly one. Neither is a formula, so nothing looked at them. You are the only lane in any instrument that holds a docstring and its body together. Run this as its own positive procedure, docstring by docstring — READ THE BODY FIRST, write down in one sentence what it computes, mutates and returns, and only then discharge the docstring's claims against it:
- a stated DEFAULT that differs from the signature's;
- "THE" value where the body branches, or takes a minimum, a maximum, or a fallback;
- a documented ERROR the code does not throw, or a throw the docs never mention;
- an ORDERING or TIMING claim ("once per step", "after the call") checked against where the call actually sits;
- a claim of NO ALLOCATION, EXACTNESS, or PRESERVATION of a property, checked against the body;
- an ARGUMENT whose documented effect is not the effect the body gives it;
- a claim about what the code DOES NOT do — the hardest, since there is no line to quote and the check is to search for the thing whose absence is asserted.
Quote the docstring claim and the body line that contradicts it.

