# Ensure required packages are available
using Pkg
pkgs = ["CSV", "DataFrames", "Plots", "StatsPlots"]
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
using Plots
using StatsPlots
gr()

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

function generate_plots(results)
    # Create speedup plots
    println("Generating performance comparison plots...")
    
    # Prepare data
    test_names = results.Name
    write_speedup = results.WriteSpeedRatio
    read_speedup = results.ReadSpeedRatio
    
    # Convert speedup ratios to absolute values
    # All values will be positive, showing the speedup factor
    write_comparison = Float64[]
    read_comparison = Float64[]
    write_labels = String[]
    read_labels = String[]
    
    for i in 1:length(write_speedup)
        if write_speedup[i] > 1
            push!(write_comparison, write_speedup[i])
            push!(write_labels, "C++")
        else
            push!(write_comparison, 1/write_speedup[i])
            push!(write_labels, "Julia")
        end
        
        if read_speedup[i] > 1
            push!(read_comparison, read_speedup[i])
            push!(read_labels, "C++")
        else
            push!(read_comparison, 1/read_speedup[i])
            push!(read_labels, "Julia")
        end
    end
    
    # Plot 1: Write Performance Comparison
    p1 = bar(test_names, write_comparison, 
        title="Write Performance: C++ vs Julia\n\n",
        ylabel="Speedup Factor",
        xlabel="Test Case",
        legend=false,
        rotation=45,
        color=ifelse.(write_labels .== "C++", :blue, :green),
        ylims=(0, maximum(write_comparison)+2),
        grid=true,
        size=(1000, 600),
        bottom_margin=20Plots.mm,
        left_margin=15Plots.mm,
        right_margin=15Plots.mm,
        top_margin=10Plots.mm,
        titlefontsize=14
    )
    
    # Plot 2: Read Performance Comparison
    p2 = bar(test_names, read_comparison,
        title="Read Performance: C++ vs Julia\n\n",
        ylabel="Speedup Factor",
        xlabel="Test Case",
        legend=false,
        rotation=45,
        color=ifelse.(read_labels .== "C++", :blue, :green),
        ylims=(0, maximum(read_comparison)+2),
        grid=true,
        size=(1000, 600),
        bottom_margin=20Plots.mm,
        left_margin=15Plots.mm,
        right_margin=15Plots.mm,
        top_margin=10Plots.mm,
        titlefontsize=14
    )
    
    # Plot 3: Combined Performance Comparison
    p3 = groupedbar(test_names,
        [write_comparison read_comparison],
        label=["Write" "Read"],
        title="Combined Performance Comparison: C++ vs Julia\n\n",
        ylabel="Speedup Factor",
        xlabel="Test Case",
        rotation=45,
        color=[:orange :purple],
        ylims=(0, maximum([write_comparison; read_comparison])+2),
        grid=true,
        size=(1200, 600),
        bottom_margin=20Plots.mm,
        left_margin=15Plots.mm,
        right_margin=15Plots.mm,
        top_margin=10Plots.mm,
        titlefontsize=14
    )
    
    # Plot 4: Performance by Data Size
    p4 = scatter(results.DataSizeBytes ./ 1024,  # Convert to KB
        write_comparison,
        label="Write",
        xlabel="Data Size (KB)",
        ylabel="Speedup Factor",
        title="Performance vs Data Size\n\n",
        xscale=:log10,
        markersize=8,
        markershape=:circle,
        color=:orange,
        ylims=(0, maximum([write_comparison; read_comparison])+2),
        size=(1000, 600),
        bottom_margin=20Plots.mm,
        left_margin=15Plots.mm,
        right_margin=15Plots.mm,
        top_margin=10Plots.mm,
        titlefontsize=14
    )
    scatter!(p4, results.DataSizeBytes ./ 1024,
        read_comparison,
        label="Read",
        markersize=8,
        markershape=:square,
        color=:purple
    )
    
    # Save plots
    savefig(p1, "benchmark_write_performance.png")
    savefig(p2, "benchmark_read_performance.png")
    savefig(p3, "benchmark_combined_performance.png")
    savefig(p4, "benchmark_performance_vs_size.png")
    
    println("Plots saved:")
    println("  - benchmark_write_performance.png")
    println("  - benchmark_read_performance.png")
    println("  - benchmark_combined_performance.png")
    println("  - benchmark_performance_vs_size.png")
end

# Main execution
if !isfile("cpp_benchmark_results.csv") || !isfile("julia_benchmark_results.csv")
    println("Error: Benchmark result files not found. Please run both benchmarks first.")
    exit(1)
end

results = read_benchmark_results()
generate_markdown_report(results)
generate_plots(results)
println("Benchmark analysis complete. Results written to benchmark_results.md and plots generated.")