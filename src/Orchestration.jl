# The design's §5.1, §6, §12; the coordinates live here rather than in a docstring, which must read complete at the REPL.
"""
    Orchestration

What a run is: the stages in order, the record of one, and the arguments each stage hands to the agents
that read the package.

It is the seventh module of the order, above `Render` and below `CLI`, and it is the boundary the design
draws hardest: **nothing a consumer's docs build, test suite or wiring check runs may reach it**. Review
state that leaked into a test suite turned a science package red, and `test/architecture.jl` fails on any
reference from below rather than trusting that nobody will write one.
"""
module Orchestration

using ..Model
using ..Texts
using ..Catalogue
using ..ConfigIO
using ..Engine

include("Orchestration/Runs.jl")
include("Orchestration/Agents.jl")

end # module Orchestration
