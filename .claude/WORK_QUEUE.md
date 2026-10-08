# Session work queue

What is still to do, one line per committed item, `- [ ]`. `.claude/hooks/queue-guard.sh` is a Stop
hook that refuses to let the session end while any item is open, or while a done line is left, so "am
I finished?" is answered by a program rather than by the session's judgement.

Delete an item's line ONLY when it is done and verified, in the commit that finishes it; git keeps the
history. An item removed to end the turn is the defect the hook exists to prevent. A genuinely blocked
item stays open with `BLOCKED:` and the reason on its line, which the hook does not count.
