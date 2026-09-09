# Decision points every architecture proposal must answer (so proposals are comparable)

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.


D1  Unit of distribution: one repo or several; Julia package + Claude plugin + CLI in one repo or split.
D2  Delivery to a machine: git clone in Dropbox (fleet-synced by construction) vs per-machine clone vs Claude plugin marketplace install vs Julia registry.
D3  Binding from a consumer package to the tool: absolute path via ~ symlink / env var / plugin root / [sources] URL+rev / submodule / vendored copy.
D4  Version pinning: fleet-wide single version vs per-consumer pin; where the pin lives; how divergence is detected and by whom.
D5  Config: file format (TOML/JSON/YAML), location in consumer (.gbg/ vs .claude/), schema validation, required vs optional, layering or none, how config reaches Workflow scripts (args only).
D6  Skills/commands: plugin skills (namespaced /gbg:check-docs) vs generated per-consumer .claude/commands/*.md stubs vs both; how a skill finds the tool root.
D7  Workflow scripts: single generic engine per instrument parameterised by args (hats, lanes, surfaces, personas) vs per-consumer scripts; where hat/lane catalogues live (config data vs code).
D8  Deterministic helpers (py/jl/sh): language choice, single CLI entry (`gbg <instrument> <subcommand>`) vs loose scripts; exit-code contract; hard vs triage tiers.
D9  Julia-side library: docs lints as a Julia package used from make.jl; test-side harnesses (method parity, allocation macro, CountingArray, regressions runner, public_surface) as a test dependency; how it's consumed (test/Project.toml [sources]); compatibility with julia 1.11/1.12.
D10 Piles/rounds: layout, tracked vs gitignored, open-round marker, instrument version stamp, closure gate reading them; one layout for all instruments.
D11 Finding/verdict schemas: one shared JSON schema per instrument with fixed vocabularies; extension policy.
D12 Rubric/policy prose: single source in the tool repo imported into CLAUDE.md via @import; per-package deviations as declared exemptions with reasons; how the battery reads the rubric.
D13 Scaffolding/templates: which files must physically exist in a consumer (make.jl wiring, test/regressions, runtests include, settings.json, .gitignore lines, CLAUDE.md skeleton) and how they are rendered/updated/drift-checked ("managed files").
D14 Doctor/conformance: what it checks, exemption mechanism, fleet view across the four consumers.
D15 Self-testing of the tool: fixture consumer package, seeded defects, selftests of every gate ("a check that cannot fail is not a check"), CI for the tool repo.
D16 Instrument change discipline: freeze/release semantics (semver + CHANGELOG), stamping the version into every round, rule for upgrading mid-round.
D17 Migration: order of consumers, per-step verification, what to delete from consumers, handling of owner-ruled deviations (mathbf, bold bullets, steer sentence, main vs master).
D18 Model/cost policy: economy defaults, anchors, where the policy is encoded (config vs script) and how a consumer names its domain anchors.
D19 Naming of the package.
