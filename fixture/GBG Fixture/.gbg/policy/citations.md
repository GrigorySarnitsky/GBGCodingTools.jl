<!-- gbg:managed policy/citations.md vdev — rewritten by `gbg sync`; do not edit -->
# Citations (`RULE.CIT.*`)

### RULE.CIT.STYLE
A citation is context-standard author–year: author-prominent with a parenthesized year, a bare year inside
an existing parenthetical, at most three authors named, and `First et al.` for four or more. Keep enough
surnames to disambiguate two works that would otherwise collide. An eponymous method name takes no year
unless the work is actually cited.

### RULE.CIT.FULL_INLINE
A docstring carries its full reference inline, verbatim-identical to the canonical entry under the
package's references heading, title and DOI compared. Doc pages cite short and the canonical full
reference lives in the rationale document; a REPL reader sees the reference without opening another
file, and drift between the copies is the chosen duplication's only risk, so it is the thing checked.

### RULE.CIT.DOI
Every reference carries a clickable DOI on its title, `[*Title*](https://doi.org/…)`, or an Open Library
link for a book with no DOI, identical in every copy. A DOI stays REPL-safe; a link target percent-encodes
`()` and `<>`, and the scan compares DOIs decoded.

### RULE.CIT.BLOCK_LIST
Two or more citations form a bullet list under a `References:` label, one citation per line, and a lone
citation stays inline as `Reference: …`. A semicolon-joined paragraph is unreadable when rendered.

### RULE.CIT.NO_INACCESSIBLE
Never cite an inaccessible source on any user-facing surface: not a gitignored monograph, an accompanying
thesis, an appendix or figure the reader cannot open, nor working notes. A citation the reader cannot
follow is dead weight and implies they are missing something they cannot get; present every result on its
own public terms.
