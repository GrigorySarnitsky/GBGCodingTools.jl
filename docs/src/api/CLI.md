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
GBGCodingTools.Init.migrate_seeds
GBGCodingTools.Ledger
GBGCodingTools.Doctor
GBGCodingTools.Doctor.select
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
