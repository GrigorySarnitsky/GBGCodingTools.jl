# Brief for a round-2 critic

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.


Three independent architects proposed a shared instrument package for the four GBG Julia packages.
Their proposals are round1-platform.md, round1-measurement.md, round1-consumer.md in this
directory. The evidence base is the same directory: 00-requirements-draft.md,
01-decision-points.md (the D1–D19 frame every proposal answers), the five survey-*.md files,
facts-claude-code-platform.md, theory-patterns.md, and 02-architect-brief.md (the owner's goals).

Your job is adversarial: find where each proposal is wrong, vacuous, over-built, under-built, or
unsupported by the evidence — from your assigned lens. For EVERY decision point D1–D19:
1. State which proposal's answer is best and why (cite evidence file:line where it decides), or
   state that all three are wrong and what the right answer is.
2. Name the failure scenario that breaks the weaker answers (concrete: "on a fresh clone of CP on
   Enteropia with no ~/.gbg, step X reports pass because …").
3. Flag any mechanism that exists in a proposal without a requirement forcing it (over-build), and
   any requirement no proposal satisfies (under-build).
Then give: (a) a ranked list of the 10 most consequential disagreements between the proposals,
each with your verdict; (b) the residual judgment calls that evidence cannot settle and that the
owner must decide; (c) anything all three missed.
Write your critique to the output path you are given. Be specific and terse; no praise. Up to
~600 lines.
