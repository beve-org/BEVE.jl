# Ensure required packages are available
using Pkg
pkgs = ["CSV", "DataFrames"]
for pkg in pkgs
    if !haskey(Pkg.project().dependencies, pkg)
        println("Installing $pkg...")
        Pkg.add(pkg)
    end
end

using CSV
using DataFrames
using Printf
using Statistics
using Dates

function read_benchmark_results()
    cpp_results = CSV.read("cpp_benchmark_results.csv", DataFrame)
    julia_results = CSV.read("julia_benchmark_results.csv", DataFrame)
    
    # Join on Name
    results = innerjoin(cpp_results, julia_results, on=:Name, makeunique=true)
    
    # Calculate performance differences
    results.WriteTimeDiff = ((results.WriteTimeMs_1 .- results.WriteTimeMs) ./ results.WriteTimeMs) .* 100
    results.ReadTimeDiff = ((results.ReadTimeMs_1 .- results.ReadTimeMs) ./ results.ReadTimeMs) .* 100
    
    return results
end

function generate_markdown_report(results)
    open("benchmark_results.md", "w") do io
        println(io, "# BEVE Performance Comparison: Julia vs C++ (Glaze)")
        println(io, "")
        println(io, "This report compares the performance of BEVE serialization/deserialization between:")
        println(io, "- **Julia**: BEVE.jl implementation")
        println(io, "- **C++**: Glaze library implementation")
        println(io, "")
        println(io, "## Summary")
        println(io, "")
        
        # Calculate overall averages
        avg_write_diff = mean(results.WriteTimeDiff)
        avg_read_diff = mean(results.ReadTimeDiff)
        
        println(io, "- **Average Write Performance**: Julia is $(abs(round(avg_write_diff, digits=1)))% $(avg_write_diff > 0 ? "slower" : "faster") than C++")
        println(io, "- **Average Read Performance**: Julia is $(abs(round(avg_read_diff, digits=1)))% $(avg_read_diff > 0 ? "slower" : "faster") than C++")
        println(io, "")
        
        println(io, "## Detailed Results")
        println(io, "")
        println(io, "| Test | Data Size | C++ Write (ms) | Julia Write (ms) | Diff % | C++ Read (ms) | Julia Read (ms) | Diff % |")
        println(io, "|------|-----------|----------------|------------------|--------|---------------|-----------------|--------|")
        
        for row in eachrow(results)
            size_kb = row.DataSizeBytes / 1024
            size_str = size_kb < 1 ? "$(row.DataSizeBytes) B" : 
                       size_kb < 1024 ? "$(round(size_kb, digits=1)) KB" : 
                       "$(round(size_kb/1024, digits=1)) MB"
            
            write_diff_str = @sprintf("%+.1f%%", row.WriteTimeDiff)
            read_diff_str = @sprintf("%+.1f%%", row.ReadTimeDiff)
            
            # Color code based on performance
            write_indicator = row.WriteTimeDiff > 10 ? "🔴" : 
                             row.WriteTimeDiff < -10 ? "🟢" : "🟡"
            read_indicator = row.ReadTimeDiff > 10 ? "🔴" : 
                            row.ReadTimeDiff < -10 ? "🟢" : "🟡"
            
            println(io, "| $(row.Name) | $(size_str) | $(round(row.WriteTimeMs, digits=3)) | $(round(row.WriteTimeMs_1, digits=3)) | $(write_diff_str) $(write_indicator) | $(round(row.ReadTimeMs, digits=3)) | $(round(row.ReadTimeMs_1, digits=3)) | $(read_diff_str) $(read_indicator) |")
        end
        
        println(io, "")
        println(io, "## Performance Analysis")
        println(io, "")
        
        # Find best and worst cases
        best_write = results[argmin(results.WriteTimeDiff), :]
        worst_write = results[argmax(results.WriteTimeDiff), :]
        best_read = results[argmin(results.ReadTimeDiff), :]
        worst_read = results[argmax(results.ReadTimeDiff), :]
        
        println(io, "### Write Performance")
        println(io, "- **Best Case**: $(best_write.Name) - Julia is $(abs(round(best_write.WriteTimeDiff, digits=1)))% $(best_write.WriteTimeDiff > 0 ? "slower" : "faster")")
        println(io, "- **Worst Case**: $(worst_write.Name) - Julia is $(abs(round(worst_write.WriteTimeDiff, digits=1)))% $(worst_write.WriteTimeDiff > 0 ? "slower" : "faster")")
        println(io, "")
        
        println(io, "### Read Performance")
        println(io, "- **Best Case**: $(best_read.Name) - Julia is $(abs(round(best_read.ReadTimeDiff, digits=1)))% $(best_read.ReadTimeDiff > 0 ? "slower" : "faster")")
        println(io, "- **Worst Case**: $(worst_read.Name) - Julia is $(abs(round(worst_read.ReadTimeDiff, digits=1)))% $(worst_read.ReadTimeDiff > 0 ? "slower" : "faster")")
        println(io, "")
        
        println(io, "## Notes")
        println(io, "")
        println(io, "- **Positive percentages**: Julia is slower than C++")
        println(io, "- **Negative percentages**: Julia is faster than C++")
        println(io, "- **Legend**: 🟢 Julia >10% faster | 🟡 Within ±10% | 🔴 Julia >10% slower")
        println(io, "- Tests were run with $(results.Iterations[1]) iterations for small data, decreasing for larger datasets")
        println(io, "- All times are averages across the specified number of iterations")
        println(io, "")
        
        println(io, "## Test Environment")
        println(io, "")
        println(io, "- **Platform**: $(Sys.KERNEL) $(Sys.MACHINE)")
        println(io, "- **Julia Version**: $(VERSION)")
        println(io, "- **C++ Compiler**: Compiler information available in build logs")
        println(io, "- **Date**: $(Dates.now())")
    end
end

# Main execution
if !isfile("cpp_benchmark_results.csv") || !isfile("julia_benchmark_results.csv")
    println("Error: Benchmark result files not found. Please run both benchmarks first.")
    exit(1)
end

using Pkg
Pkg.add(["CSV", "DataFrames"])
using CSV
using DataFrames
using Statistics
using Dates

results = read_benchmark_results()
generate_markdown_report(results)
println("Benchmark analysis complete. Results written to benchmark_results.md")