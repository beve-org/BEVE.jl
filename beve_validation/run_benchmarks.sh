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

echo -e "\nBenchmark complete! See benchmark_results.md for the comparison report."