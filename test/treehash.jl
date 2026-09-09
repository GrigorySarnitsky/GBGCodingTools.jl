using Test, GBGCodingTools
include("helpers.jl")

# TreeHash reproduces git's tree id, empty directories included in the comparison: git tracks none, so a
# tree with an empty subdirectory must hash as if it were absent (rc.1 round, src#1 / operational-claims#1).
@testset "tree hash vs git write-tree" begin
    dir = joinpath(TMP, "treehash"); mkpath(joinpath(dir, "sub")); mkpath(joinpath(dir, "empty"))
    write(joinpath(dir, "a.txt"), "alpha\n"); write(joinpath(dir, "sub", "b.txt"), "beta\n")
    mkpath(joinpath(dir, "sub", "deeper-empty"))
    git(args...) = strip(read(setenv(`git -C $dir $args`, "GIT_AUTHOR_NAME" => "t", "GIT_AUTHOR_EMAIL" => "t@t", "GIT_COMMITTER_NAME" => "t", "GIT_COMMITTER_EMAIL" => "t@t", "HOME" => dir, "PATH" => ENV["PATH"]), String))
    git("init", "-q"); git("add", "-A")
    @test G.TreeHash.tree_hash(dir) == git("write-tree")
    # a tag's tree id is what a tag-stamped round is measured against (D16); TreeHash of the clean tree equals it
    git("commit", "-q", "-m", "one"); git("tag", "-a", "v0.0.1", "-m", "v0.0.1")
    @test G.Preflight.tag_tree(dir, "0.0.1") == G.TreeHash.tree_hash(dir)
    @test G.Preflight.tag_tree(dir, "9.9.9") === nothing
    only_empty = joinpath(TMP, "treehash-empty"); mkpath(joinpath(only_empty, "void"))
    @test G.TreeHash.tree_hash(only_empty) == "4b825dc642cb6eb9a060e54bf8d69288fbee4904"   # git's empty tree
end
