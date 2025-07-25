using Pkg
Pkg.activate("..")
using BEVE
using Statistics
using Printf

struct BenchmarkResult
    name::String
    write_time_ms::Float64
    read_time_ms::Float64
    data_size_bytes::Int
    iterations::Int
end

# Test structures matching C++
struct SmallData
    id::Int32
    value::Float64
    name::String
end

struct MediumData
    values::Vector{Float64}
    lookup::Dict{String, Int32}
    tags::Vector{String}
end

function create_medium_data()
    values = Float64[i * 0.1 for i in 0:99]
    lookup = Dict{String, Int32}("key$i" => Int32(i) for i in 0:99)
    tags = String["tag$i" for i in 0:99]
    MediumData(values, lookup, tags)
end

struct LargeFloatArray
    data::Vector{Float32}
end

function create_large_float_array(size::Int)
    data = Float32[Float32(i) * 0.1f0 for i in 0:size-1]
    LargeFloatArray(data)
end

struct LargeComplexArray
    data::Vector{ComplexF32}
end

function create_large_complex_array(size::Int)
    data = ComplexF32[ComplexF32(Float32(i), Float32(i) * 0.5f0) for i in 0:size-1]
    LargeComplexArray(data)
end

function benchmark_type(name::String, data, iterations::Int)
    # Warm up
    buffer = to_beve(data)
    _ = deser_beve(typeof(data), buffer)
    
    data_size_bytes = length(buffer)
    
    # Benchmark write
    write_times = Float64[]
    sizehint!(write_times, iterations)
    
    # Pre-allocate IOBuffer for better performance
    io_buffer = IOBuffer()
    
    for i in 1:iterations
        t0 = time()
        buffer = to_beve!(io_buffer, data)
        t1 = time()
        push!(write_times, (t1 - t0) * 1000)  # Convert to ms
    end
    
    # Benchmark read
    read_times = Float64[]
    sizehint!(read_times, iterations)
    
    for i in 1:iterations
        t0 = time()
        _ = deser_beve(typeof(data), buffer)
        t1 = time()
        push!(read_times, (t1 - t0) * 1000)  # Convert to ms
    end
    
    BenchmarkResult(
        name,
        mean(write_times),
        mean(read_times),
        data_size_bytes,
        iterations
    )
end

function write_results(results::Vector{BenchmarkResult})
    open("julia_benchmark_results.csv", "w") do io
        println(io, "Name,WriteTimeMs,ReadTimeMs,DataSizeBytes,Iterations")
        for r in results
            println(io, "$(r.name),$(r.write_time_ms),$(r.read_time_ms),$(r.data_size_bytes),$(r.iterations)")
        end
    end
end

function main()
    println("Julia BEVE Benchmark")
    println("====================\n")
    
    results = BenchmarkResult[]
    
    # Small data
    println("Benchmarking small data...")
    small = SmallData(Int32(42), 3.14159, "benchmark")
    push!(results, benchmark_type("Small Data", small, 1000))
    
    # Medium data
    println("Benchmarking medium data...")
    medium = create_medium_data()
    push!(results, benchmark_type("Medium Data", medium, 500))
    
    # Large float array (10K)
    println("Benchmarking large float array (10K)...")
    large10k = create_large_float_array(10000)
    push!(results, benchmark_type("Float Array 10K", large10k, 100))
    
    # Large float array (100K)
    println("Benchmarking large float array (100K)...")
    large100k = create_large_float_array(100000)
    push!(results, benchmark_type("Float Array 100K", large100k, 50))
    
    # Large float array (1M)
    println("Benchmarking large float array (1M)...")
    large1m = create_large_float_array(1000000)
    push!(results, benchmark_type("Float Array 1M", large1m, 20))
    
    # Complex array (10K)
    println("Benchmarking complex array (10K)...")
    complex10k = create_large_complex_array(10000)
    push!(results, benchmark_type("Complex Array 10K", complex10k, 100))
    
    # Complex array (100K)
    println("Benchmarking complex array (100K)...")
    complex100k = create_large_complex_array(100000)
    push!(results, benchmark_type("Complex Array 100K", complex100k, 50))
    
    # Print results
    println("\nResults:")
    @printf("%-20s %15s %15s %15s %15s\n", "Test", "Write (ms)", "Read (ms)", "Size (bytes)", "Iterations")
    println("-" ^ 80)
    
    for r in results
        @printf("%-20s %15.3f %15.3f %15d %15d\n", 
                r.name, r.write_time_ms, r.read_time_ms, r.data_size_bytes, r.iterations)
    end
    
    write_results(results)
    println("\nResults written to julia_benchmark_results.csv")
end

# Run the benchmark
main()