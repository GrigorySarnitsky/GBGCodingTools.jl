# Self.jl — `gbg self verify`: the running copy re-hashed against the manifests (PIN.SELF), and git's
# content hashing on the SHA stdlib that the re-hash needs (harvested from `TreeHash.jl`, Phase 5).

"""
    blob_hash(path) -> String

The git blob id of the file at `path`: SHA-1 over `"blob <size>\\0"` followed by the content (a symlink
hashes its target path, as git does). Returns the 40-character lowercase hex id.
"""
function blob_hash(path::AbstractString)
    data = islink(path) ? Vector{UInt8}(readlink(path)) : read(path)
    ctx = SHA1_CTX()
    update!(ctx, Vector{UInt8}("blob $(length(data))\0"))
    update!(ctx, data)
    return bytes2hex(digest!(ctx))
end

# The OWNER's execute bit alone, as git and Pkg's `gitmode` read it: a file with only a group or other
# bit is `100644` to both, and hashing it as `100755` failed `self verify` on an unedited tree.
_mode(path) = islink(path) ? "120000" : (filemode(path) & 0o100) != 0 ? "100755" : "100644"
_sortkey(name, isdir) = isdir ? name * "/" : name

"""
    tree_hash(dir; skip = (".git",)) -> String

The git tree id of a directory, computed as `git write-tree` would over every file below it: entries
sorted by git's rule (a directory name compares with a trailing `/`), modes `100644`, `100755`,
`120000` and `40000`, empty directories omitted. It is what Pkg records as `git-tree-sha1` in a manifest
and reports as `tree_hash` from `Pkg.dependencies()`, so the running copy can re-hash itself without
`git`.

# Arguments

- `dir` — the directory to hash.
- `skip` — entry names ignored at any level, `.git` by default, so a working tree hashes the same as
  the tree its `HEAD` names when it is clean.

Returns the hex id; an empty tree returns git's well-known empty-tree id.
"""
function tree_hash(dir::AbstractString; skip = (".git",))
    entries = Tuple{String,Bool,String}[]              # (name, isdir, hexid)
    for name in readdir(dir)
        name in skip && continue
        path = joinpath(dir, name)
        if isdir(path) && !islink(path)
            _nonempty(path, skip) || continue                # git tracks no empty directory
            push!(entries, (name, true, tree_hash(path; skip)))
        else
            push!(entries, (name, false, blob_hash(path)))
        end
    end
    sort!(entries; by = e -> _sortkey(e[1], e[2]))
    body = IOBuffer()
    for (name, isdir_, hex) in entries
        write(body, isdir_ ? "40000" : _mode(joinpath(dir, name)), ' ', name, '\0', hex2bytes(hex))
    end
    payload = take!(body)
    ctx = SHA1_CTX()
    update!(ctx, Vector{UInt8}("tree $(length(payload))\0"))
    update!(ctx, payload)
    return bytes2hex(digest!(ctx))
end

# true when `dir` holds at least one file that is not skipped (git records no empty directories, and a
# directory holding only a nested `.git` is empty to it)
function _nonempty(dir, skip)
    for name in readdir(dir)
        name in skip && continue
        path = joinpath(dir, name)
        (isdir(path) && !islink(path)) ? (_nonempty(path, skip) && return true) : return true
    end
    return false
end

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
    self_verify(root = ConfigIO.find_root(); io = stdout) -> Int

Recomputes the git tree hash of the copy this process runs from (`pkgdir(GBGCodingTools)`, through
[`tree_hash`](@ref)) and compares it with what `Pkg.dependencies()` reports for the tool in the
active environment and with the `git-tree-sha1` every sub-environment manifest under `root` records;
asserts the dependency entry is `is_tracking_repo && !is_tracking_path` (a `Pkg.develop`'d copy lives
inside the depot, so only the flags tell it apart).

# Arguments

- `root` — the consumer root whose sub-environment manifests are compared; `nothing` (no root found)
  leaves only the active environment's entry to compare against.
- `io` — where the one line per comparison is printed.

Returns 0 when every comparison agrees, 0 with a WARN when the running copy is a working tree (pinned
at `dev`) or no manifest exists to compare against, and 2 for a disagreement or a developed copy — an
edited pinned tree is never allowed to grade a round.
"""
function self_verify(root = ConfigIO.find_root(); io::IO = stdout)
    dir = pkgdir(GBGCodingTools)
    if running_dev()
        println(io, "PIN.SELF  WARN  dev pin: running from the working tree $dir ($(tool_version())); nothing to verify against")
        return 0
    end
    computed = tree_hash(dir)
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

`gbg self verify`: the command-line face of [`self_verify`](@ref). Returns its code: 0, or 2 for an
edited or developed pinned copy.
"""
cmd_self_verify(args) = self_verify()
VERBS["self verify"] = cmd_self_verify
