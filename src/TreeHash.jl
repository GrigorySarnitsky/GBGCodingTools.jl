# TreeHash.jl — git blob and tree hashing on the SHA stdlib; behind `gbg self verify`, PIN.SELF, PIN.TREESHA.

"""
    TreeHash

Git's content hashing, reimplemented on the `SHA` stdlib so the running copy can re-hash itself
without `git`: [`TreeHash.blob_hash`](@ref) and [`TreeHash.tree_hash`](@ref) reproduce the object ids
`git hash-object` and `git write-tree` would give, which is what Pkg records as `git-tree-sha1` in a
manifest and reports as `tree_hash` from `Pkg.dependencies()`. `gbg self verify` compares the two.
"""
module TreeHash

using SHA

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

_mode(path) = islink(path) ? "120000" : (filemode(path) & 0o111) != 0 ? "100755" : "100644"
_sortkey(name, isdir) = isdir ? name * "/" : name

"""
    tree_hash(dir; skip = (".git",)) -> String

The git tree id of a directory, computed as `git write-tree` would over every file below it: entries
sorted by git's rule (a directory name compares with a trailing `/`), modes `100644`, `100755`,
`120000` and `40000`, empty directories omitted. The arguments are:

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

# true when `dir` holds at least one file (git records no empty directories)
function _nonempty(dir, skip)
    for (_, _, files) in walkdir(dir; follow_symlinks = false)
        isempty(files) || return true
    end
    return false
end

end # module TreeHash
