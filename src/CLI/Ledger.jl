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
using ..GBGCodingTools: load_schema, validate, Config

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
    errs = validate(load_schema("exemptions"), doc)
    isempty(errs) || throw(LedgerError("$path is invalid:\n  " * join(errs, "\n  ")))
    return Dict{String,Any}[Dict{String,Any}(e) for e in get(doc, "exemption", Any[])]
end

"""
    Ledger.entries(ledger, id; scope = nothing, live = true) -> Vector

The entries whose `id` equals `id`, optionally restricted to one `scope`; with `live = true` an entry
past its `expires` date is dropped (it no longer exempts anything, and the doctor reports it). Returns
the selection in file order.
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
    Ledger.matches(entry, root; file = "", symbol = "", arg_name = nothing, arg_type = nothing) -> Bool

Whether `entry` covers a trigger: its `target` is `*`, equals `file`, equals `symbol`, or is a glob
matching `file`; and, when the entry carries a `match` table, every present sub-key holds (`path` a glob
over `file`, `symbol` a regex over `symbol`, `arg_name` a regex over the argument name, `arg_type` a
type name tested by `<:` against the argument's declared type). A text scan must pass `arg_type =
nothing` and refuse an entry carrying that key before calling; this function throws on it. Returns
the boolean.
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
