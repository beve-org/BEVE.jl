using Pkg
Pkg.activate("..")
using BEVE

println("Comprehensive Matrix Validation Test")
println("===================================\n")

# Test all combinations of:
# - Layouts: row-major, column-major
# - Types: Float32, Float64, Int32, ComplexF32
# - Sizes: various dimensions

test_cases = [
    ("1x1 Float32 row-major", BeveMatrix(LayoutRight, [1, 1], Float32[42.0])),
    ("1x1 Float32 col-major", BeveMatrix(LayoutLeft, [1, 1], Float32[42.0])),
    ("2x3 Float64 row-major", BeveMatrix(LayoutRight, [2, 3], Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0])),
    ("2x3 Float64 col-major", BeveMatrix(LayoutLeft, [2, 3], Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0])),
    ("4x4 Int32 row-major", BeveMatrix(LayoutRight, [4, 4], Int32[i for i in 1:16])),
    ("3x2 ComplexF32 row-major", BeveMatrix(LayoutRight, [3, 2], 
        ComplexF32[ComplexF32(i, -i) for i in 1:6])),
    ("5x5 Float32 identity-like", BeveMatrix(LayoutRight, [5, 5], 
        Float32[i == j ? 1.0 : 0.0 for i in 1:5 for j in 1:5])),
]

mkpath("julia_generated/validation")

println("Creating test matrices...")
for (name, matrix) in test_cases
    filename = replace(name, " " => "_") * ".beve"
    filepath = "julia_generated/validation/$filename"
    
    # Write the matrix
    data = to_beve(matrix)
    open(filepath, "w") do io
        write(io, data)
    end
    
    # Test round-trip in Julia
    read_data = read(filepath)
    parsed = from_beve(read_data)
    roundtrip_data = to_beve(parsed)
    
    status = read_data == roundtrip_data ? "✓" : "✗"
    println("  $status $name ($(length(data)) bytes)")
    
    if read_data != roundtrip_data
        println("    Size mismatch: $(length(read_data)) vs $(length(roundtrip_data))")
    end
end

# Test edge cases
println("\nTesting edge cases...")

# Empty matrix (0x0) - should fail validation
try
    empty_matrix = BeveMatrix(LayoutRight, [0, 0], Float32[])
    println("  ✗ Empty matrix should have failed validation")
catch e
    println("  ✓ Empty matrix correctly rejected: $(e.msg)")
end

# Very large dimensions
large_dims = BeveMatrix(LayoutRight, [1000, 1000], zeros(Float32, 1000000))
large_data = to_beve(large_dims)
println("  ✓ Large matrix (1000x1000): $(length(large_data)) bytes")

# High-dimensional (>2D) matrix
high_dim = BeveMatrix(LayoutRight, [2, 3, 4, 5], Float32[i for i in 1:120])
high_data = to_beve(high_dim)
println("  ✓ 4D matrix (2x3x4x5): $(length(high_data)) bytes")

# Test parsing C++ matrix with strict validation
println("\nValidating C++ matrix structure...")
cpp_matrix_path = "julia_generated/matrices/cpp_2x3_matrix.beve"
if isfile(cpp_matrix_path)
    cpp_data = read(cpp_matrix_path)
    cpp_matrix = from_beve(cpp_data)
    
    # Validate structure
    checks = [
        ("Layout is row-major", cpp_matrix.layout == LayoutRight),
        ("Dimensions are [2, 3]", cpp_matrix.extents == [2, 3]),
        ("Has 6 elements", length(cpp_matrix.data) == 6),
        ("First element is 10.0", cpp_matrix.data[1] ≈ 10.0),
        ("Last element is 60.0", cpp_matrix.data[end] ≈ 60.0),
    ]
    
    for (desc, result) in checks
        println("  $(result ? "✓" : "✗") $desc")
    end
else
    println("  ⚠ C++ matrix file not found - run C++ tests first")
end

println("\n✅ Comprehensive validation complete!")