# Self.jl — `gbg self verify`: the running copy re-hashed against the manifests (PIN.SELF).

"""
    tool_sub_envs(root) -> Vector{String}

Every directory under `root` (the consumer) whose `Project.toml` lists `GBGCodingTools` in `[deps]` —
`test/`, `docs/`, `benchmark/` and any further sub-environment — as paths relative to `root`, sorted.
The root `Project.toml` is skipped: the tool is never a dependency of the package proper. Returns the
list.
"""
function tool_sub_envs(root::AbstractString)
    envs = String[]
    for (dir, subdirs, files) in walkdir(root; follow_symlinks = false, onerror = _ -> nothing)
        filter!(d -> !(d in (".git", ".gbg", "node_modules", "build")) && !startswith(d, "."), subdirs)
        dir == root && continue
        "Project.toml" in files || continue
        p = try TOML.parsefile(joinpath(dir, "Project.toml")) catch; continue end
        haskey(get(p, "deps", Dict()), PKG_NAME) && push!(envs, relpath(dir, root))
    end
    return sort!(envs)
end

"""
    manifest_tree_sha(manifest_path) -> Union{String,Nothing}

The `git-tree-sha1` a `Manifest.toml` records for `GBGCodingTools`, or `nothing` when the file is absent
or holds no such entry (a `path`-tracked entry records none). Returns the hex id or `nothing`.
"""
function manifest_tree_sha(manifest_path::AbstractString)
    isfile(manifest_path) || return nothing
    m = try TOML.parsefile(manifest_path) catch; return nothing end
    deps = get(m, "deps", m)
    entries = get(deps, PKG_NAME, nothing)
    entries === nothing && return nothing
    e = entries isa AbstractVector ? first(entries) : entries
    return get(e, "git-tree-sha1", nothing)
end

"""
    self_verify(root = Config.find_root(); io = stdout) -> Int

Recomputes the git tree hash of the copy this process runs from (`pkgdir(GBGCodingTools)`, through
[`TreeHash.tree_hash`](@ref)) and compares it with what `Pkg.dependencies()` reports for the tool in the
active environment and with the `git-tree-sha1` every sub-environment manifest under `root` records;
asserts the dependency entry is `is_tracking_repo && !is_tracking_path` (a `Pkg.develop`'d copy lives
inside the depot, so only the flags tell it apart). The arguments are:

- `root` — the consumer root whose sub-environment manifests are compared; `nothing` (no root found)
  leaves only the active environment's entry to compare against.
- `io` — where the one line per comparison is printed.

Returns 0 when every comparison agrees, 0 with a WARN when the running copy is a working tree (pinned
at `dev`) or no manifest exists to compare against, and 2 for a disagreement or a developed copy — an
edited pinned tree is never allowed to grade a round.
"""
function self_verify(root = Config.find_root(); io::IO = stdout)
    dir = pkgdir(GBGCodingTools)
    if running_dev()
        println(io, "PIN.SELF  WARN  dev pin: running from the working tree $dir ($(tool_version())); nothing to verify against")
        return 0
    end
    computed = TreeHash.tree_hash(dir)
    code = 0
    entry = get(Pkg.dependencies(), PKG_UUID, nothing)
    if entry === nothing
        println(io, "PIN.SELF  WARN  the active environment lists no GBGCodingTools dependency; computed tree $computed")
    else
        if !(entry.is_tracking_repo && !entry.is_tracking_path)
            println(io, "PIN.SELF  FAIL  the copy at $dir is not a fetched repository tree (tracking repo = $(entry.is_tracking_repo), path = $(entry.is_tracking_path))")
            code = 2
        end
        expected = entry.tree_hash === nothing ? nothing : string(entry.tree_hash)
        if expected === nothing
            println(io, "PIN.SELF  WARN  Pkg records no tree hash for the running copy; computed $computed")
        elseif expected != computed
            println(io, "PIN.SELF  FAIL  the running copy's tree is $computed but Pkg fetched $expected — the pinned copy was edited")
            code = 2
        else
            println(io, "PIN.SELF  ok    running copy $computed equals Pkg's tree hash")
        end
    end
    if root !== nothing
        for env in tool_sub_envs(root)
            sha = manifest_tree_sha(joinpath(root, env, "Manifest.toml"))
            if sha === nothing
                println(io, "PIN.SELF  WARN  $env/Manifest.toml absent or without a GBGCodingTools tree hash")
            elseif sha != computed
                println(io, "PIN.SELF  FAIL  $env/Manifest.toml records $sha, the running copy is $computed")
                code = 2
            else
                println(io, "PIN.SELF  ok    $env/Manifest.toml agrees")
            end
        end
    end
    return code
end

"""
    cmd_self_verify(args) -> Int

`gbg self verify`: the command-line face of [`self_verify`](@ref); run by every `gbg round` verb and by
`gbg gate` before anything else. Returns its code: 0, or 2 for an edited or developed pinned copy.
"""
cmd_self_verify(args) = self_verify()
VERBS["self verify"] = cmd_self_verify
