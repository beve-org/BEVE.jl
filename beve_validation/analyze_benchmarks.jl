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
    
    # Calculate speed ratios
    results.WriteSpeedRatio = results.WriteTimeMs_1 ./ results.WriteTimeMs
    results.ReadSpeedRatio = results.ReadTimeMs_1 ./ results.ReadTimeMs
    
    # Calculate percent deviation (std dev / mean * 100) for both implementations
    results.WriteStdDevPercent_CPP = (results.WriteStdDevMs ./ results.WriteTimeMs) .* 100
    results.ReadStdDevPercent_CPP = (results.ReadStdDevMs ./ results.ReadTimeMs) .* 100
    results.WriteStdDevPercent_Julia = (results.WriteStdDevMs_1 ./ results.WriteTimeMs_1) .* 100
    results.ReadStdDevPercent_Julia = (results.ReadStdDevMs_1 ./ results.ReadTimeMs_1) .* 100
    
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
        avg_write_ratio = mean(results.WriteSpeedRatio)
        avg_read_ratio = mean(results.ReadSpeedRatio)
        
        if avg_write_ratio > 1
            println(io, "- **Average Write Performance**: C++ is $(round(avg_write_ratio, digits=1))x faster than Julia")
        else
            println(io, "- **Average Write Performance**: Julia is $(round(1/avg_write_ratio, digits=1))x faster than C++")
        end
        
        if avg_read_ratio > 1
            println(io, "- **Average Read Performance**: C++ is $(round(avg_read_ratio, digits=1))x faster than Julia")
        else
            println(io, "- **Average Read Performance**: Julia is $(round(1/avg_read_ratio, digits=1))x faster than C++")
        end
        println(io, "")
        
        println(io, "## Detailed Results")
        println(io, "")
        println(io, "| Test | Data Size | C++ Write (ms ± %) | Julia Write (ms ± %) | Write Speed | C++ Read (ms ± %) | Julia Read (ms ± %) | Read Speed |")
        println(io, "|------|-----------|-------------------|---------------------|-------------|------------------|-------------------|------------|")
        
        for row in eachrow(results)
            size_kb = row.DataSizeBytes / 1024
            size_str = size_kb < 1 ? "$(row.DataSizeBytes) B" : 
                       size_kb < 1024 ? "$(round(size_kb, digits=1)) KB" : 
                       "$(round(size_kb/1024, digits=1)) MB"
            
            # Format speed comparisons
            if row.WriteSpeedRatio > 1.1
                write_speed_str = "C++ $(round(row.WriteSpeedRatio, digits=1))x faster"
            elseif row.WriteSpeedRatio < 0.91
                write_speed_str = "Julia $(round(1/row.WriteSpeedRatio, digits=1))x faster"
            else
                write_speed_str = "Similar"
            end
            
            if row.ReadSpeedRatio > 1.1
                read_speed_str = "C++ $(round(row.ReadSpeedRatio, digits=1))x faster"
            elseif row.ReadSpeedRatio < 0.91
                read_speed_str = "Julia $(round(1/row.ReadSpeedRatio, digits=1))x faster"
            else
                read_speed_str = "Similar"
            end
            
            cpp_write_str = "$(round(row.WriteTimeMs, digits=3)) ± $(round(row.WriteStdDevPercent_CPP, digits=1))%"
            julia_write_str = "$(round(row.WriteTimeMs_1, digits=3)) ± $(round(row.WriteStdDevPercent_Julia, digits=1))%"
            cpp_read_str = "$(round(row.ReadTimeMs, digits=3)) ± $(round(row.ReadStdDevPercent_CPP, digits=1))%"
            julia_read_str = "$(round(row.ReadTimeMs_1, digits=3)) ± $(round(row.ReadStdDevPercent_Julia, digits=1))%"
            
            println(io, "| $(row.Name) | $(size_str) | $(cpp_write_str) | $(julia_write_str) | $(write_speed_str) | $(cpp_read_str) | $(julia_read_str) | $(read_speed_str) |")
        end
        
        println(io, "")
        println(io, "## Performance Analysis")
        println(io, "")
        
        # Find best and worst cases
        best_write = results[argmin(results.WriteSpeedRatio), :]
        worst_write = results[argmax(results.WriteSpeedRatio), :]
        best_read = results[argmin(results.ReadSpeedRatio), :]
        worst_read = results[argmax(results.ReadSpeedRatio), :]
        
        println(io, "### Write Performance")
        if best_write.WriteSpeedRatio > 1
            println(io, "- **Best Case**: $(best_write.Name) - C++ is $(round(best_write.WriteSpeedRatio, digits=1))x faster")
        else
            println(io, "- **Best Case**: $(best_write.Name) - Julia is $(round(1/best_write.WriteSpeedRatio, digits=1))x faster")
        end
        if worst_write.WriteSpeedRatio > 1
            println(io, "- **Worst Case**: $(worst_write.Name) - C++ is $(round(worst_write.WriteSpeedRatio, digits=1))x faster")
        else
            println(io, "- **Worst Case**: $(worst_write.Name) - Julia is $(round(1/worst_write.WriteSpeedRatio, digits=1))x faster")
        end
        println(io, "")
        
        println(io, "### Read Performance")
        if best_read.ReadSpeedRatio > 1
            println(io, "- **Best Case**: $(best_read.Name) - C++ is $(round(best_read.ReadSpeedRatio, digits=1))x faster")
        else
            println(io, "- **Best Case**: $(best_read.Name) - Julia is $(round(1/best_read.ReadSpeedRatio, digits=1))x faster")
        end
        if worst_read.ReadSpeedRatio > 1
            println(io, "- **Worst Case**: $(worst_read.Name) - C++ is $(round(worst_read.ReadSpeedRatio, digits=1))x faster")
        else
            println(io, "- **Worst Case**: $(worst_read.Name) - Julia is $(round(1/worst_read.ReadSpeedRatio, digits=1))x faster")
        end
        println(io, "")
        
        println(io, "## Performance Variability")
        println(io, "")
        println(io, "Standard deviation as percentage of mean (lower is more consistent):")
        println(io, "")
        
        # Calculate average standard deviations
        avg_write_stddev_cpp = mean(results.WriteStdDevPercent_CPP)
        avg_read_stddev_cpp = mean(results.ReadStdDevPercent_CPP)
        avg_write_stddev_julia = mean(results.WriteStdDevPercent_Julia)
        avg_read_stddev_julia = mean(results.ReadStdDevPercent_Julia)
        
        println(io, "- **C++ Write**: Average ±$(round(avg_write_stddev_cpp, digits=1))% deviation")
        println(io, "- **C++ Read**: Average ±$(round(avg_read_stddev_cpp, digits=1))% deviation")
        println(io, "- **Julia Write**: Average ±$(round(avg_write_stddev_julia, digits=1))% deviation")
        println(io, "- **Julia Read**: Average ±$(round(avg_read_stddev_julia, digits=1))% deviation")
        println(io, "")
        
        println(io, "## Notes")
        println(io, "")
        println(io, "- **Speed comparisons**: Shows which implementation is faster and by how many times")
        println(io, "- **Standard deviation**: Shown as ± percentage of mean time (e.g., \"1.5 ± 10.2%\" means 1.5ms average with 10.2% variability)")
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