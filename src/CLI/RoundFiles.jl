# RoundFiles.jl — reading the round store `.gbg/rounds/` (ARCHITECTURE §6.1): shared by the doctor, the
# gate and every `round` verb. Writing is the round verbs' business (Rounds.jl).

"""
    RoundFiles

Readers over `.gbg/rounds/`, the round store: a round is one run of one instrument over one consumer,
recorded as a tracked directory there. [`RoundFiles.round_dirs`](@ref) lists the round directories,
[`RoundFiles.read_round`](@ref) parses a `ROUND.toml`, [`RoundFiles.state`](@ref) classifies a round as
`:open`, `:closed` or `:abandoned`, and [`RoundFiles.sha256_file`](@ref) hashes a round artefact the way
the stamps expect.
"""
module RoundFiles

using TOML, SHA
using ..GBGCodingTools: load_schema, validate

rounds_dir(cfg::AbstractDict) = joinpath(cfg["root"], ".gbg", "rounds")

"""
    round_dirs(cfg) -> Vector{String}

Every directory under `.gbg/rounds/` (sorted; `.keep` and files ignored), as absolute paths. Returns
the list; empty when the store is absent.
"""
function round_dirs(cfg::AbstractDict)
    d = rounds_dir(cfg)
    isdir(d) || return String[]
    return sort!([joinpath(d, x) for x in readdir(d) if isdir(joinpath(d, x))])
end

"""
    read_round(dir) -> Union{Dict,Nothing}

The parsed `ROUND.toml` of a round directory, schema-validated; `nothing` when the marker is absent.
An invalid marker throws with the validation messages.
"""
function read_round(dir::AbstractString)
    p = joinpath(dir, "ROUND.toml")
    isfile(p) || return nothing
    r = TOML.parsefile(p)
    errs = validate(load_schema("round"), r)
    isempty(errs) || error("$(p) is invalid:\n  " * join(errs, "\n  "))
    return r
end

"""
    state(round) -> Symbol

`:abandoned` when the marker carries `abandoned`, `:closed` when it carries `closed`, else `:open`.
"""
state(r::AbstractDict) = haskey(r, "abandoned") ? :abandoned : haskey(r, "closed") ? :closed : :open

"""
    sha256_file(path) -> String

The lowercase hex sha256 of a file's bytes, the form every `*_sha` stamp records.
"""
sha256_file(path::AbstractString) = bytes2hex(sha256(read(path)))

"""
    rounds(cfg) -> Vector{NamedTuple}

Every round as `(dir, name, round, state)` with `round` the parsed marker or `nothing`, `state`
`:open|:closed|:abandoned|:nomarker|:invalid`. Returns the list in name order.
"""
function rounds(cfg::AbstractDict)
    out = NamedTuple[]
    for d in round_dirs(cfg)
        r, st = try
            rr = read_round(d)
            (rr, rr === nothing ? :nomarker : state(rr))
        catch err
            (nothing, :invalid)
        end
        push!(out, (dir = d, name = basename(d), round = r, state = st))
    end
    return out
end

end # module RoundFiles
