# SCAN.SIBLING_LINK — RULE.DOC.SIBLING_LINK. New with the owner's home-page review (2026-09-09): the
# first mention of a sibling GBG package in a unit — a page, a rationale document, a Literate example, or
# one docstring — is a link to that package's documentation site; later mentions in the unit are bare
# code spans; a package never links its own name. Names and sites come from the fleet registry the tool
# ships (fleet.toml: `github = "Owner/Repo.jl"` gives `https://owner.github.io/Repo.jl/`).
function fleet_sites()
    p = joinpath(pkgdir(GBGCodingTools), "fleet.toml")
    out = Dict{String,String}()
    isfile(p) || return out
    for c in get(TOML.parsefile(p), "consumer", Any[])
        gh = get(c, "github", nothing); gh === nothing && continue
        owner, repo = split(String(gh), '/'; limit = 2)
        out[String(c["name"])] = "https://$(lowercase(owner)).github.io/$repo/"
    end
    return out
end

# `lines` are the (line number, raw text) pairs of ONE unit, in order. Both halves of the rule are
# checked: the first line naming a sibling must carry the mention inside `[`Name`](site…)` or
# `[Name](site…)`, and every later line naming it must NOT.
function sibling_link_hits!(hits, file, lines, sites, own)
    for (name, site) in sites
        name == own && continue
        name_re = Regex("(?<![A-Za-z0-9_])" * name * "(?![A-Za-z0-9_])")
        link_re = Regex("\\[`?" * name * "`?\\]\\(\\Q" * site * "\\E")
        seen = false
        for (n, raw) in lines
            o = findfirst(name_re, raw); o === nothing && continue
            m = match(link_re, raw)
            linked = m !== nothing && m.offset <= first(o) <= m.offset + ncodeunits(m.match)
            if !seen
                seen = true
                linked || push!(hits, Hit(file, n, "first mention of `$name` is not a link to $site: " * strip(raw)))
            elseif linked
                push!(hits, Hit(file, n, "later mention of `$name` is a link, not a bare code span: " * strip(raw)))
            end
        end
    end
end

register_scan!("SCAN.SIBLING_LINK", function (cfg, files)
    sites = fleet_sites(); own = String(cfg["package"]["name"])
    hits = Hit[]; units = 0
    for f in files
        if surface_kind(cfg, f) == :julia
            for b in docstring_blocks(cfg, [f])
                units += 1
                sibling_link_hits!(hits, f, [(b.line + i, String(l)) for (i, l) in enumerate(split(b.body, '\n'))], sites, own)
            end
        else
            units += 1
            sibling_link_hits!(hits, f, [(p.n, p.raw) for p in prose_lines(cfg, f)], sites, own)
        end
    end
    return (hits, units)
end)
