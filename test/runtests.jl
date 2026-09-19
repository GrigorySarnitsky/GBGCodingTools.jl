# test/runtests.jl — GBGCodingTools. `Pkg.test()` IS `gbg selftest`: every arm of ARCHITECTURE §8 the
# tool can run without an agent, over `fixture/GBG Fixture/` and its defects corpus, then the tool's own
# regressions loop and closure gate (D15). Every file is included into its own module.
using Test, GBGCodingTools

const TOOL = normpath(joinpath(@__DIR__, ".."))
const FIXTURE = joinpath(TOOL, "fixture", "GBG Fixture")
# The scratch of the whole suite: a system temporary directory, removed by the process that made it —
# never inside this repository, which Dropbox syncs (test/helpers.jl says what that cost).
const TMP = mktempdir(; prefix = "gbg-selftest-", cleanup = true)

module ArchitectureTests; include("architecture.jl"); end
module AnchorTests;      include("anchors.jl");      end
module ConfigIOTests;    include("configio.jl");     end
module GuardTests;       include("guard.jl");        end
module DocfixTests;      include("docfix.jl");       end
module RulesTests;       include("rules.jl");        end
module ConversionTests;  include("conversion.jl");   end
module WiringTests;      include("wiring.jl");       end
module QuestionTests;    include("questions.jl");    end
module RehearseTests;    include("rehearse.jl");     end
module DriverTests;      include("driver.jl");       end
module SchemaTests;      include("schemas.jl");      end
module ConfigTests;      include("config.jl");       end
module ScanTests;        include("scans.jl");        end
module WitnessTests;     include("witnesses.jl");    end
module TreeHashTests;    include("treehash.jl");     end
module CoverageTests;    include("coverage.jl");     end

rm(TMP; recursive = true, force = true)   # cleanup = true would do it at exit; this is the tidy path

# Promoted witnesses of the tool's own hunts.
GBGCodingTools.TestHarness.run_regressions(@__DIR__)

# And then this package under its own rulebook: the code rules, and the wiring check handed in, exactly
# as a consumer's suite runs them. It is the line `Render.runtests_call` writes into a consumer, and it
# is here for the same reason — a package whose suite does not call the harness runs no rule and is
# green about it.
GBGCodingTools.Engine.Harness.test(dirname(@__DIR__); checks = (GBGCodingTools.Render.wiring,))
