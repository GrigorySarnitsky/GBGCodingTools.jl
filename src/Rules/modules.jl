# The design's §5.2 and §7; the coordinates live here rather than in a docstring, which must read
# complete at the REPL.
"""
    Rules.Modules

The rules that need the package LOADED: what a docstring shows against what the module actually holds.
A cross-module name mentioned bare where a reader cannot follow it, and a displayed signature that no
longer matches the method table, are both invisible in the source of any one file.

A check here is handed the loaded package and the package root together, since what it compares is the
module against the source that documents it. Where nothing loaded the package the rule does not run, and
the caller is told so rather than the run reporting clean.
"""
module Modules

using ...Model
using ...Texts

"""
    owners(pkg, cfg) -> Dict{String,Symbol}

Which module of the package owns each name it exports. The arguments are `pkg`, the loaded package, and
`cfg`, the package's config. Returns the map from name to owning module.
"""
function owners(pkg::Module, cfg)
    mods = Module[pkg]
    for n in names(pkg; all = true)
        isdefined(pkg, n) || continue
        v = getfield(pkg, n)
        v isa Module && v !== pkg && push!(mods, v)
    end
    modnames = Set(nameof.(mods))
    out = Dict{String,Symbol}()
    for mod in mods, n in names(mod)
        s = String(n)
        s == String(nameof(mod)) && continue
        isdefined(mod, n) || continue
        v = getfield(mod, n)
        parent = (v isa Function || v isa Type) ? nameof(parentmodule(v)) : nameof(mod)
        out[s] = parent in modnames ? parent : nameof(mod)
    end
    return out
end

"""
    xlink(loaded, cfg) -> Vector{Model.Location}

Every cross-module name mentioned bare in a docstring where a reader would need a link to reach it. The
arguments are `loaded`, the loaded package with the package root, and `cfg`, the package's config, which
names the files. Returns one location per first bare mention.

A name the same module owns needs no link — the reader is already there. A name in the docstring's own
signature, or already linked earlier in the same docstring, is not a mention to be linked either.
"""
function xlink(loaded, cfg)
    own_of = owners(loaded.pkg, cfg)
    out = Model.Location[]
    for f in get(cfg.filesets, Model.FileSet.CODE, String[])
        path = joinpath(loaded.root, f)
        isfile(path) || continue
        src = read(path, String)
        m = match(r"^\s*(?:bare)?module\s+([A-Za-z_][A-Za-z0-9_]*)"m, src)
        m === nothing && continue
        me = Symbol(m.captures[1])
        for d in Texts.docstrings_of(src)
            lines = split(d.text, '\n')
            first_prose = something(findfirst(l -> !startswith(l, "    ") && !isempty(strip(l)), lines), 1)
            signature = join(lines[1:first_prose-1], "\n")
            prose = join(lines[first_prose:end], "\n")
            in_signature = Set(String.(x.captures[1] for x in eachmatch(r"([A-Za-z_][A-Za-z0-9_!]*)\(", signature)))
            for am in eachmatch(r"\(([^)]*)\)", signature)
                for raw in split(am.captures[1], ",")
                    a = strip(split(split(split(raw, "::")[1], "=")[1], ";")[end])
                    isempty(a) || push!(in_signature, String(a))
                end
            end
            linked = Set(String.(x.captures[1] for x in eachmatch(r"\[`([^`]+)`\]\(@", prose)))
            seen = Set{String}()
            for x in eachmatch(r"`([A-Za-z_][A-Za-z0-9_!]*)`", prose)
                name = String(x.captures[1])
                (haskey(own_of, name) && !(name in in_signature) && !(name in linked) && !(name in seen)) || continue
                push!(seen, name)
                own_of[name] === me && continue
                push!(out, Model.Location(; file = f, line = d.line, node = d.node,
                    text = "`$name` is owned by $(own_of[name]) and mentioned here without a link"))
            end
        end
    end
    return out
end

const XLINK = Model.Rule(
    id = Symbol("RULE.DOC.XLINK"),
    statement = "A name another module owns is linked at its first mention in a docstring, qualified so the link resolves.",
    why = "A reader meeting a name from elsewhere has nowhere to go: the docstring in front of him does not define it.",
    intention = Model.Intention.DOCUMENTATION,
    filesets = [Model.FileSet.CODE],
    check = Model.ProgramCheck(Model.Input.LOADED_MODULE, xlink, false),
    examples = [
        Model.ModuleExample("""
            module Example
            module Inner
                export helper
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
            end
            using .Inner
            \"\"\"
                caller(x)

            Calls `helper` on its argument.
            \"\"\"
            caller(x) = Inner.helper(x)
            end
            """, [Model.Location(; file = "src/Example.jl", line = 12)], "linked at its first mention"),
        Model.ModuleExample("""
            module Example
            module Inner
                export helper
                \"\"\"
                    helper(x)

                A helper.
                \"\"\"
                helper(x) = x
            end
            using .Inner
            \"\"\"
                caller(x)

            Calls [`helper`](@ref Example.Inner.helper) on its argument.
            \"\"\"
            caller(x) = Inner.helper(x)
            end
            """, Model.Location[], "linked at its first mention"),
    ])

"""
    RULES

The rules of this batch.
"""
const RULES = Model.Rule[XLINK]

end # module Modules
