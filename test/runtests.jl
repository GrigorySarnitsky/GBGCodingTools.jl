# test/runtests.jl — GBGCodingTools. `Pkg.test()` IS `gbg selftest`: every arm of ARCHITECTURE §8 the
# tool can run without an agent, over `fixture/GBG Fixture/` and its defects corpus, then the tool's own
# regressions loop and closure gate (D15). Every file is included into its own module.
using Test, GBGCodingTools

const TOOL = normpath(joinpath(@__DIR__, ".."))
const FIXTURE = joinpath(TOOL, "fixture", "GBG Fixture")
const TMP = joinpath(TOOL, "fixture", ".tmp", string(getpid()))   # gitignored; per process, so two concurrent suites never share a copy; inside the repository so a `dev` pin stays legal
isdir(TMP) && rm(TMP; recursive = true, force = true)
mkpath(TMP)

module SchemaTests;      include("schemas.jl");      end
module ConfigTests;      include("config.jl");       end
module ScanTests;        include("scans.jl");        end
module LedgerTests;      include("ledger.jl");       end
module WitnessTests;     include("witnesses.jl");    end
module SyncDoctorTests;  include("sync_doctor.jl");  end
module TreeHashTests;    include("treehash.jl");     end
module CoverageTests;    include("coverage.jl");     end

rm(TMP; recursive = true, force = true)

# Promoted witnesses of the tool's own hunts, then the closure gate on the tool itself (D15).
GBGCodingTools.TestHarness.run_regressions(@__DIR__)
