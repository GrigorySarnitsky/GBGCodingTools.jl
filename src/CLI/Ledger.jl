# Ledger.jl — the one reader of `.gbg/exemptions.toml` (ARCHITECTURE §7.2). Every engine that honours an
# exemption (the scan engine, the doctor, the gate, the harness) reads the ledger through here.

"""
    Ledger

The reader of a consumer's exemption ledger `.gbg/exemptions.toml`: [`Ledger.read`](@ref) validates the
file against `schema/exemptions.schema.json` and returns its entries, [`Ledger.entries`](@ref) selects
the ones naming an id, and [`Ledger.matches`](@ref) applies an entry's optional `match` table to a
trigger. The doctor's `CFG.EXEMPTIONS` check applies the ledger's semantic rules (expiry bounds, the
non-exemptable prefixes); the reader only parses.
"""
module Ledger

using TOML, Dates
using ..GBGCodingTools: Config

struct LedgerError <: Exception
    msg::String
end
Base.showerror(io::IO, e::LedgerError) = print(io, "ledger: ", e.msg)

"""
    Ledger.read(cfg) -> Vector{Dict{String,Any}}

Every `[[exemption]]` of `<root>/.gbg/exemptions.toml`, schema-validated. Returns an empty vector when
the file is absent (an empty ledger is a legal state) and throws a `LedgerError` when it does not parse
or does not validate — an unreadable ledger is never treated as empty.
"""
function read(cfg::AbstractDict)
    path = joinpath(cfg["root"], ".gbg", "exemptions.toml")
    isfile(path) || return Dict{String,Any}[]
    doc = try
        TOML.parsefile(path)
    catch err
        throw(LedgerError("$path does not parse: " * sprint(showerror, err)))
    end
    # The schema that validated this went with `schema/` on 2026-09-17. The ledger itself goes in Phase 5;
    # what a package turns off is a `Switch` in `.gbg/config.jl`, which `ConfigIO.validate` refuses when it
    # names an unknown rule or gives no reason.
    return Dict{String,Any}[Dict{String,Any}(e) for e in get(doc, "exemption", Any[])]
end

"""
    Ledger.entries(ledger, id; scope = nothing, live = true) -> Vector

The entries naming an id. The arguments are:

- `ledger` — the entries [`Ledger.read`](@ref) returned.
- `id` — the id to select.
- `scope` — one scope to restrict to (any when `nothing`).
- `live` — whether to drop an entry past its `expires` date (it no longer exempts anything, and the
  doctor reports it).

Returns the selection in file order.
"""
function entries(ledger::AbstractVector, id::AbstractString; scope = nothing, live::Bool = true)
    out = Dict{String,Any}[]
    for e in ledger
        e["id"] == id || continue
        scope === nothing || e["scope"] == scope || continue
        live && haskey(e, "expires") && e["expires"] < today() && continue
        push!(out, e)
    end
    return out
end

"""
    Ledger.matches(entry, root; file = "", symbol = "",
                   arg_name = nothing, arg_type = nothing) -> Bool

Whether `entry` covers a trigger. The arguments are:

- `entry` — the ledger entry.
- `root` — the consumer root; globs in `target` and `match.path` resolve against the file's relative
  path, so `root` only names the tree.
- `file` — the trigger's file, relative to the root.
- `symbol` — the trigger's owning binding.
- `arg_name` — the argument name, for a reflection scan's trigger.
- `arg_type` — the argument's declared type, for a reflection scan's trigger; a text scan passes
  `nothing` and refuses an entry carrying `match.arg_type` before calling — this function throws on it.

The entry covers the trigger when its `target` is `*`, equals `file` or `symbol`, or is a glob matching
`file`; and, when it carries a `match` table, every present sub-key holds (`path` a glob over `file`,
`symbol` a regex over `symbol`, `arg_name` a regex, `arg_type` a type name tested by `<:`). Returns the
boolean.
"""
function matches(entry::AbstractDict, root::AbstractString; file::AbstractString = "", symbol::AbstractString = "",
                 arg_name = nothing, arg_type = nothing)
    t = entry["target"]
    covered = t == "*" || t == file || t == symbol ||
              (occursin(r"[*?\[]", t) && occursin(Config.glob_to_regex(t), file))
    covered || return false
    m = get(entry, "match", nothing)
    m === nothing && return true
    if haskey(m, "path")
        occursin(Config.glob_to_regex(m["path"]), file) || return false
    end
    if haskey(m, "symbol")
        occursin(Regex(m["symbol"]), symbol) || return false
    end
    if haskey(m, "arg_name")
        arg_name === nothing && return false
        occursin(Regex(m["arg_name"]), String(arg_name)) || return false
    end
    if haskey(m, "arg_type")
        arg_type === nothing && throw(LedgerError("entry for $(entry["id"]) carries match.arg_type, which only a reflection scan can evaluate"))
        arg_type isa Type || return false
        want = try Core.eval(Main, Meta.parse(m["arg_type"])) catch; nothing end
        want isa Type || return false
        arg_type <: want || return false
    end
    return true
end

end # module Ledger
