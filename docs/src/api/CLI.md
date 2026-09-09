# CLI internals

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

The engines behind the verbs, documented at their homes.

## The wrapper and the dispatcher

```@docs
GBGCodingTools.makedocs
GBGCodingTools.VERBS
```

## Engines

```@docs
GBGCodingTools.Sync
GBGCodingTools.Sync.plan
GBGCodingTools.Sync.status
GBGCodingTools.Sync.render
GBGCodingTools.Sync.managed_block
GBGCodingTools.Sync.subenv_entries
GBGCodingTools.Init
GBGCodingTools.Init.derive_config
GBGCodingTools.Ledger
GBGCodingTools.Doctor
GBGCodingTools.Doctor.select
GBGCodingTools.Preflight
GBGCodingTools.Preflight.resolve_roster
GBGCodingTools.Preflight.write_payloads
GBGCodingTools.Preflight.render_args
GBGCodingTools.Preflight.workflow_call
GBGCodingTools.Rounds
GBGCodingTools.Passes
GBGCodingTools.Seeds
GBGCodingTools.Seeds.select
GBGCodingTools.Seeds.plant
GBGCodingTools.Recall
GBGCodingTools.Recall.mark!
GBGCodingTools.Recall.per_class
GBGCodingTools.Recall.suspect_hats
GBGCodingTools.demote
GBGCodingTools.RoundFiles
GBGCodingTools.RoundFiles.round_dirs
GBGCodingTools.RoundFiles.read_round
GBGCodingTools.RoundFiles.state
GBGCodingTools.RoundFiles.sha256_file
GBGCodingTools.Git
GBGCodingTools.Git.run
GBGCodingTools.Git.head
GBGCodingTools.Git.is_ancestor
GBGCodingTools.Git.porcelain
GBGCodingTools.Git.diff
GBGCodingTools.Git.log
GBGCodingTools.HtmlWalker
GBGCodingTools.HtmlWalker.parse_page
GBGCodingTools.HtmlWalker.tagname
GBGCodingTools.HtmlWalker.classes
GBGCodingTools.HtmlWalker.attr
GBGCodingTools.HtmlWalker.elements
GBGCodingTools.HtmlWalker.text_of
GBGCodingTools.HtmlWalker.article_of
GBGCodingTools.consolidate
GBGCodingTools.Hit
GBGCodingTools.ScanResult
GBGCodingTools.register_scan!
GBGCodingTools.prose_lines
GBGCodingTools.TreeHash
GBGCodingTools.TreeHash.tree_hash
GBGCodingTools.TreeHash.blob_hash
```
