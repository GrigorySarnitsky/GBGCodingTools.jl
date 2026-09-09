# Schema.jl — the ONE JSON-Schema-subset validator, over the Dict `TOML.parsefile` (or JSON3) returns.
# Keywords understood: type, properties, required, additionalProperties, items, enum, const, pattern,
# minLength, minItems, minimum, maximum, default, allOf, $ref (to #/$defs/<name>), $defs, description;
# the type names object, array, boolean, integer, number, string, null, date.

"""
    SchemaError <: Exception

A document that does not validate. The fields are:

- `messages` — one message per violation, each naming the JSON path.
"""
struct SchemaError <: Exception
    messages::Vector{String}
end
Base.showerror(io::IO, e::SchemaError) = print(io, "schema validation failed:\n  ", join(e.messages, "\n  "))

"""
    schema_dir() -> String

The directory of the shipped schemas, `schema/` inside the running copy. Returns the path.
"""
schema_dir() = joinpath(pkgdir(GBGCodingTools), "schema")

"""
    load_schema(name) -> Dict

Reads `schema/<name>.schema.json` from the running copy into a `Dict` (JSON3, mutable copy). Returns
the schema; a missing file is an `ArgumentError` naming it.
"""
function load_schema(name::AbstractString)
    path = joinpath(schema_dir(), name * ".schema.json")
    isfile(path) || throw(ArgumentError("no schema $path"))
    return JSON3.read(read(path, String), Dict{String,Any})
end

"""
    instrument_schema(name) -> Dict

`instruments/<name>/schema.json` of the running copy: the instrument's Workflow `args` object, its
lane-file wrapper and (for check-consistency) the `seeds` definition. A Workflow is the instrument's
`workflow/*.js` script and a lane is one agent's share of the round it runs, both bound in
[`GBGCodingTools`](@ref). Returns the parsed document.
"""
function instrument_schema(name::AbstractString)
    path = joinpath(pkgdir(GBGCodingTools), "instruments", name, "schema.json")
    isfile(path) || throw(ArgumentError("no instrument schema $path"))
    return JSON3.read(read(path, String), Dict{String,Any})
end

# A `$ref` with sibling keys (`default`, `minItems`, `description`) means the referenced node with those
# siblings applied on top — the way the config schema writes `{"$ref": "#/$defs/strlist", "default": []}`.
function _resolve(root, s)
    haskey(s, "\$ref") || return s
    merged = Dict{String,Any}(_deref(root, s["\$ref"]))
    for (k, v) in s
        k == "\$ref" || (merged[k] = v)
    end
    return merged
end
function _deref(root, ref::AbstractString)
    startswith(ref, "#/") || throw(ArgumentError("only local \$ref is supported: $ref"))
    node = root
    for seg in split(ref[3:end], '/')
        node = node[String(seg)]
    end
    return node
end

_typename(v) = v isa AbstractDict ? "object" : v isa AbstractVector ? "array" : v isa Bool ? "boolean" :
    v isa Integer ? "integer" : v isa Real ? "number" : v isa AbstractString ? "string" :
    v isa Dates.Date ? "date" : v isa Dates.DateTime ? "date-time" : v === nothing ? "null" : string(typeof(v))

function _type_ok(want::AbstractString, v)
    want == "number" && return v isa Real && !(v isa Bool)
    want == "integer" && return v isa Integer && !(v isa Bool)
    want == "string" && return v isa AbstractString
    want == "date" && return v isa Dates.Date
    return _typename(v) == want
end

"""
    validate(schema, value; root = schema, path = "\$") -> Vector{String}

Validates `value` against `schema` (a `Dict` in the JSON-Schema subset above). The arguments are:

- `schema` — the schema node to apply.
- `value` — the parsed document (`TOML.parsefile` or `JSON3.read` into a `Dict`).
- `root` — the document the `\$ref`s resolve against; callers pass `schema` itself.
- `path` — the JSON path of `value` in the messages (`\$` at the top).

Returns every violation as a message naming its path; an empty vector means valid.
"""
function validate(schema::AbstractDict, value; root = schema, path::String = "\$")
    errs = String[]
    s = _resolve(root, schema)
    if haskey(s, "const") && value != s["const"]
        push!(errs, "$path: must be $(repr(s["const"]))")
    end
    if haskey(s, "type")
        types = s["type"] isa AbstractVector ? String.(s["type"]) : [String(s["type"])]
        if !any(t -> _type_ok(t, value), types)
            push!(errs, "$path: expected $(join(types, " | ")), got $(_typename(value))")
            return errs
        end
    end
    if haskey(s, "enum") && !(value in s["enum"])
        push!(errs, "$path: $(repr(value)) is not one of $(join(repr.(s["enum"]), ", "))")
    end
    if value isa AbstractString
        haskey(s, "pattern") && !occursin(Regex(s["pattern"]), value) &&
            push!(errs, "$path: $(repr(value)) does not match /$(s["pattern"])/")
        haskey(s, "minLength") && length(value) < s["minLength"] &&
            push!(errs, "$path: shorter than $(s["minLength"]) characters")
    elseif value isa Real && !(value isa Bool)
        haskey(s, "minimum") && value < s["minimum"] && push!(errs, "$path: below minimum $(s["minimum"])")
        haskey(s, "maximum") && value > s["maximum"] && push!(errs, "$path: above maximum $(s["maximum"])")
    elseif value isa AbstractVector
        haskey(s, "minItems") && length(value) < s["minItems"] &&
            push!(errs, "$path: fewer than $(s["minItems"]) items")
        if haskey(s, "items")
            for (i, v) in enumerate(value)
                append!(errs, validate(s["items"], v; root, path = "$path[$i]"))
            end
        end
    elseif value isa AbstractDict
        for (i, sub) in enumerate(get(s, "allOf", Any[]))   # every member schema must hold
            append!(errs, validate(sub, value; root, path))
        end
        props = get(s, "properties", Dict{String,Any}())
        for r in get(s, "required", String[])
            haskey(value, r) || push!(errs, "$path: missing required key $(repr(r))")
        end
        for (k, v) in value
            if haskey(props, k)
                append!(errs, validate(props[k], v; root, path = "$path.$k"))
            else
                ap = get(s, "additionalProperties", true)
                if ap === false
                    push!(errs, "$path: unknown key $(repr(k))")
                elseif ap isa AbstractDict
                    append!(errs, validate(ap, v; root, path = "$path.$k"))
                end
            end
        end
    end
    return errs
end

"""
    materialize!(schema, value; root = schema) -> value

Writes every `default` the schema declares into `value` where the key is absent, recursively through
objects and array items. The arguments are:

- `schema` — the node to apply.
- `value` — the document to fill in place.
- `root` — the document the `\$ref`s resolve against.

Returns `value`.
"""
function materialize!(schema::AbstractDict, value; root = schema)
    s = _resolve(root, schema)
    if value isa AbstractDict && haskey(s, "properties")
        for (k, ps) in s["properties"]
            pr = _resolve(root, ps)
            if !haskey(value, k) && haskey(pr, "default")
                value[k] = deepcopy(pr["default"])
            end
            haskey(value, k) && materialize!(ps, value[k]; root)
        end
    elseif value isa AbstractVector && haskey(s, "items")
        for v in value
            materialize!(s["items"], v; root)
        end
    end
    return value
end

"""
    assert_valid(schema, value; what = "document")

Throws a [`SchemaError`](@ref) naming `what` when `value` does not validate against `schema`; returns
`nothing` otherwise. The arguments are:

- `schema` — the schema.
- `value` — the document.
- `what` — the noun the error message uses for it.
"""
function assert_valid(schema::AbstractDict, value; what::AbstractString = "document")
    errs = validate(schema, value)
    isempty(errs) || throw(SchemaError(["$what: " * e for e in errs]))
    return nothing
end

"""
    cmd_schema(args) -> Int

`gbg schema <name>`: prints `schema/<name>.schema.json` of the running copy with its defaults, as JSON.
Returns 0; an unknown name lists the available schemas to `stderr` and returns 2.
"""
function cmd_schema(args)
    o = parse_options(args)
    names = sort!([replace(f, ".schema.json" => "") for f in readdir(schema_dir()) if endswith(f, ".schema.json")])
    if length(o.positional) != 1 || !(o.positional[1] in names)
        println(stderr, "gbg schema <name>; available: ", join(names, ", ")); return 2
    end
    JSON3.pretty(stdout, JSON3.write(load_schema(o.positional[1]))); println()
    return 0
end
VERBS["schema"] = cmd_schema
