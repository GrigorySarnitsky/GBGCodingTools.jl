# Roadmap — GBGCodingTools

Live plans and open directions; finished work is deleted (git history keeps it). Not a scan surface.

- Phase 1 remainder (IMPLEMENTATION.md): fixture, self-tests, the first release candidate and its /check-docs round.
- Phases 1.9 and 2–8 as the plan states them.
- `SCAN.HTML_RENDERED_MARKUP` should also catch a stray `$` or backtick inside a rendered math span (a
  double-backtick span with a nested backtick renders as broken KaTeX; the rc.1 round found the class by
  reading the build, not by scan). An instrument change: its own commit and release, after the round.
