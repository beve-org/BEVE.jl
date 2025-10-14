using Pkg
Pkg.activate("..")
using BEVE

raw_from_beve(data) = from_beve(data; preserve_matrices = true)

println("Testing BEVE Matrices")
println("====================")

# Test 1: Basic 2D matrix (row-major)
println("\nTest 1: Basic 2D matrix (row-major)")
matrix1 = BeveMatrix(LayoutRight, [3, 3], Float32[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0])
data1 = to_beve(matrix1)
println("  Serialized $(length(data1)) bytes")
println("  Bytes: ", bytes2hex(data1))

# Deserialize and verify
result1 = raw_from_beve(data1)
println("  Layout: $(result1.layout == LayoutRight ? "row-major" : "column-major")")
println("  Extents: $(result1.extents)")
println("  Data: $(result1.data)")
@assert result1.layout == LayoutRight
@assert result1.extents == [3, 3]
@assert result1.data ≈ Float32[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0]
println("  ✓ Basic 2D matrix test passed")

# Test 2: Column-major matrix
println("\nTest 2: Column-major matrix")
matrix2 = BeveMatrix(LayoutLeft, [2, 4], Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0])
data2 = to_beve(matrix2)
println("  Serialized $(length(data2)) bytes")

result2 = raw_from_beve(data2)
println("  Layout: $(result2.layout == LayoutRight ? "row-major" : "column-major")")
println("  Extents: $(result2.extents)")
@assert result2.layout == LayoutLeft
@assert result2.extents == [2, 4]
@assert result2.data == [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
println("  ✓ Column-major matrix test passed")

# Test 3: 3D matrix with integers
println("\nTest 3: 3D matrix with integers")
matrix3 = BeveMatrix(LayoutRight, [2, 3, 4], Int32[i for i in 1:24])
data3 = to_beve(matrix3)
println("  Serialized $(length(data3)) bytes")

result3 = raw_from_beve(data3)
println("  Extents: $(result3.extents)")
println("  Total elements: $(prod(result3.extents))")
@assert result3.layout == LayoutRight
@assert result3.extents == [2, 3, 4]
@assert result3.data == Int32[i for i in 1:24]
println("  ✓ 3D integer matrix test passed")

# Test 4: Matrix with complex numbers
println("\nTest 4: Matrix with complex numbers")
complex_data = ComplexF32[ComplexF32(i, i*0.5) for i in 1:6]
matrix4 = BeveMatrix(LayoutRight, [2, 3], complex_data)
data4 = to_beve(matrix4)
println("  Serialized $(length(data4)) bytes")

result4 = raw_from_beve(data4)
println("  Extents: $(result4.extents)")
println("  First element: $(result4.data[1])")
@assert result4.layout == LayoutRight
@assert result4.extents == [2, 3]
@assert result4.data ≈ complex_data
println("  ✓ Complex matrix test passed")

# Test 5: 1D matrix (vector)
println("\nTest 5: 1D matrix (vector)")
matrix5 = BeveMatrix(LayoutRight, [10], Float32[i*0.1f0 for i in 1:10])
data5 = to_beve(matrix5)
println("  Serialized $(length(data5)) bytes")

result5 = raw_from_beve(data5)
println("  Extents: $(result5.extents)")
@assert result5.extents == [10]
@assert length(result5.data) == 10
println("  ✓ 1D matrix test passed")

# Test 6: Large extents requiring different sized integers
println("\nTest 6: Large extents")
# Small extents (fit in UInt8)
matrix6a = BeveMatrix(LayoutRight, [10, 20], zeros(Float32, 200))
data6a = to_beve(matrix6a)
println("  Small extents: serialized $(length(data6a)) bytes")

# Medium extents (require UInt16)
matrix6b = BeveMatrix(LayoutRight, [300, 400], zeros(Float32, 120000))
data6b = to_beve(matrix6b)
println("  Medium extents: serialized $(length(data6b)) bytes")

# Check that different extent sizes work
result6a = raw_from_beve(data6a)
result6b = raw_from_beve(data6b)
@assert result6a.extents == [10, 20]
@assert result6b.extents == [300, 400]
println("  ✓ Large extents test passed")

# Test 7: Matrix validation error
println("\nTest 7: Matrix validation")
try
    # This should throw an error - data length doesn't match extents
    invalid_matrix = BeveMatrix(LayoutRight, [2, 3], Float32[1.0, 2.0, 3.0])
    @assert false  # Should not reach here
catch e
    println("  ✓ Correctly caught validation error: $(e.msg)")
end

# Test 8: Empty dimensions
println("\nTest 8: High-dimensional matrix")
matrix8 = BeveMatrix(LayoutRight, [2, 2, 2, 2, 2], Float32[i for i in 1:32])
data8 = to_beve(matrix8)
println("  5D matrix serialized $(length(data8)) bytes")

result8 = raw_from_beve(data8)
@assert result8.extents == [2, 2, 2, 2, 2]
@assert prod(result8.extents) == 32
println("  ✓ High-dimensional matrix test passed")

println("\n✅ All matrix tests passed!")

# Write sample matrices for C++ validation
println("\nWriting matrix samples for C++ validation...")
samples = Dict(
    "row_major_2d" => BeveMatrix(LayoutRight, [3, 3], Float32[i for i in 0:8]),
    "col_major_2d" => BeveMatrix(LayoutLeft, [3, 3], Float32[i for i in 0:8]),
    "complex_matrix" => BeveMatrix(LayoutRight, [2, 2], 
        ComplexF32[ComplexF32(1, 2), ComplexF32(3, 4), ComplexF32(5, 6), ComplexF32(7, 8)]),
    "int_3d_matrix" => BeveMatrix(LayoutRight, [2, 3, 4], Int32[i for i in 0:23]),
    "large_matrix" => BeveMatrix(LayoutRight, [100, 100], Float64[i*0.01 for i in 1:10000])
)

mkpath("julia_generated")
open("julia_generated/matrices.beve", "w") do io
    write(io, to_beve(samples))
end
println("✓ Written matrix samples to julia_generated/matrices.beve")
