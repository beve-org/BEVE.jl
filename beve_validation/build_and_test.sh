#!/bin/bash

# Build and test BEVE validation

echo "Building C++ BEVE validator..."
mkdir -p build
cd build
cmake ..
make -j

if [ $? -eq 0 ]; then
    echo "Build successful!"
    
    # Run C++ tests and generate files
    echo -e "\n=== Running C++ tests ==="
    ./beve_validator
    
    # Go back to validation directory
    cd ..
    
    # Run Julia tests
    echo -e "\n=== Running Julia tests ==="
    julia test_validation.jl
    
    # Run C++ tests to read Julia files
    echo -e "\n=== C++ reading Julia files ==="
    ./build/beve_validator --read-julia
else
    echo "Build failed!"
    exit 1
fi