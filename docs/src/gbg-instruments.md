# [The instruments](@id gbg-instruments)

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

An instrument is one procedure with one question, run only when the owner asks for it. Each is a value
in GBGCodingTools carrying its purpose, what ends it and how many times it may hand a finding back to
be fixed; `gbg run <instrument>` executes one, a stage at a time, and `.claude/skills/` holds the
file that tells a session the order of the steps.

| Instrument | Finds a defect in | Decided by | Fixed by | Fix passes | Here |
|---|---|---|---|---|---|
| `documentation-review` | documentation | an agent | documentation fixer | 4 | switched off |
| `bug-hunt` | code | a failing test | code fixer | 0 | runs |
| `change-audit` | code | an agent | code fixer | 0 | runs |

## `documentation-review`

Documentation is true to the code, correct, consistent and self-contained; the change guard, the checks and a verifier agent check each fix.

- **Starts**: owner's request.
- **Ends**: nothing is open after its last pass, or the owner ended it.
- **Switched off here**: The review reads a package's documentation with the rulebook this package writes; running it here while the rulebook and the run machinery are still being built would grade the tool against rules it is in the middle of changing. It is switched on in Phase 8, when the tool reviews itself last.

## `bug-hunt`

The code does what its documentation says.

- **Starts**: owner's request.
- **Ends**: every candidate is confirmed or discarded, once.

## `change-audit`

A code change is no wider than the defect and the owner's direction and still accepts input that worked before; it grades the fix and changes nothing.

- **Starts**: after each approved code fix, and on request.
- **Ends**: one pass over the change.

