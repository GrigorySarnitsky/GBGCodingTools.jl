# SUMMARY — 2026-09-09-check-docs-01 (a reading aid, never the input to a fix pass)

22 findings banked, 0 seeded (subtracted below), 22 distinct after deduplication by title; ranked by severity × corroboration (k of 8 lanes).

Capped lanes (candidates_found > reported; re-run narrowed if needed): rationale, pages, src, ext, built-html, cold-reader

- **major** (1/8: operational-claims) TreeHash.tree_hash does not actually omit empty directories, contradicting its own docstring — `2026-09-09-check-docs-01/operational-claims#1`
- **major** (1/8: src) TreeHash.tree_hash never omits empty directories (isempty on a Bool) — `2026-09-09-check-docs-01/src#1`
- **major** (1/8: pages) argcov's own docstring never documents its `cfg` or `exempt` parameters in the form its own scan requires — `2026-09-09-check-docs-01/pages#1`
- **major** (1/8: rationale) consolidate.py is described as present/pending across three sections but was already deleted — `2026-09-09-check-docs-01/rationale#1`
- **major** (1/8: cold-reader) 'S-class' and 'class G' file-taxonomy letters are used in docstrings but defined nowhere in them — `2026-09-09-check-docs-01/cold-reader#3`
- **major** (1/8: built-html) Double-backtick escapes meant to show literal backticks render as broken KaTeX math — `2026-09-09-check-docs-01/built-html#1`
- **major** (1/8: cold-reader) 'consumer' and 'pin' are used, undefined, in the very first sentences a REPL reader sees — `2026-09-09-check-docs-01/cold-reader#1`
- **major** (1/8: built-html) Four live CLI verbs (bump, fleet, release, selftest) are documented nowhere on the built site — `2026-09-09-check-docs-01/built-html#2`
- **major** (1/8: src) rescan_alive can crash with StringIndexError on non-ASCII scan text — `2026-09-09-check-docs-01/src#2`
- **major** (1/8: cold-reader) TestHarness's 'element-traffic ledger' collides with the package's own defined term 'Ledger' — `2026-09-09-check-docs-01/cold-reader#2`
- **minor** (1/8: cold-reader) 'round' is used as load-bearing vocabulary in the first files a reader loads, well before any docstring characterizes it — `2026-09-09-check-docs-01/cold-reader#5`
- **minor** (1/8: cold-reader) 'substrate' is used as a field name across three files before it is ever explained as a concept — `2026-09-09-check-docs-01/cold-reader#4`
- **minor** (1/8: rationale) D9's 'minimal' dependency enumeration omits Pkg and Random, both real hard dependencies — `2026-09-09-check-docs-01/rationale#2`
- **minor** (1/8: built-html) The module map on the home page has no entry for the scan engine — `2026-09-09-check-docs-01/built-html#3`
- **minor** (1/8: cold-reader) 'anchor' (a hat/lane running at full strength) is never defined in any docstring — `2026-09-09-check-docs-01/cold-reader#6`
- **minor** (1/8: cold-reader) 'managed file' (a defined package term) is used pervasively via 'managed' but never stated as a concept — `2026-09-09-check-docs-01/cold-reader#7`
- **minor** (1/8: pages) "lane" (a declared package term of art) used throughout the rounds guide with no definition — `2026-09-09-check-docs-01/pages#3`
- **minor** (1/8: operational-claims) Witnesses.run_one can classify a witness :blocked even though it also failed, contradicting "was never seen to fail" — `2026-09-09-check-docs-01/operational-claims#2`
- **minor** (1/8: pages) "hats" (a declared package term of art) used on the landing page with no definition or link — `2026-09-09-check-docs-01/pages#2`
- **minor** (1/8: cold-reader) the act/state verdict channels, and the 'class_surfaces' field that demotes one, are used before (and largely without) explanation — `2026-09-09-check-docs-01/cold-reader#8`
- **minor** (1/8: ext) `Documenter` appears bare (unbacktick­ed) twice in the module docstring, backticked once — `2026-09-09-check-docs-01/ext#1`
- **nit** (1/8: ext) `check`'s `verb` argument is never bound as its own code span (ARGCOV run from the signature) — `2026-09-09-check-docs-01/ext#2`
