#!/bin/bash

echo "Building C++ benchmark..."
cd build
cmake ..
make beve_benchmark
cd ..

if [ $? -ne 0 ]; then
    echo "Failed to build C++ benchmark"
    exit 1
fi

echo -e "\n=== Running C++ Benchmark ==="
./build/beve_benchmark

if [ $? -ne 0 ]; then
    echo "C++ benchmark failed"
    exit 1
fi

echo -e "\n=== Running Julia Benchmark ==="
julia benchmark.jl

if [ $? -ne 0 ]; then
    echo "Julia benchmark failed"
    exit 1
fi

echo -e "\n=== Analyzing Results ==="
julia analyze_benchmarks.jl

if [ $? -ne 0 ]; then
    echo "Analysis failed"
    exit 1
fi

echo -e "\nBenchmark complete!"
echo "Results generated:"
echo "  - benchmark_results.md - Detailed comparison report"
echo "  - benchmark_write_performance.png - Write speedup comparison"
echo "  - benchmark_read_performance.png - Read speedup comparison"  
echo "  - benchmark_combined_performance.png - Combined performance view"
echo "  - benchmark_performance_vs_size.png - Performance vs data size"