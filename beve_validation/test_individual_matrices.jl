using Pkg
Pkg.activate("..")
using BEVE

println("Creating individual matrix files for C++ testing")
println("==============================================\n")

mkpath("julia_generated/matrices")

# Test 1: 2x2 row-major float matrix
matrix1 = BeveMatrix(LayoutRight, [2, 2], Float32[1.0, 2.0, 3.0, 4.0])
open("julia_generated/matrices/2x2_row_major_f32.beve", "w") do io
    write(io, to_beve(matrix1))
end
println("✓ Created 2x2_row_major_f32.beve")

# Test 2: 3x3 row-major float matrix
matrix2 = BeveMatrix(LayoutRight, [3, 3], Float32[i for i in 0:8])
open("julia_generated/matrices/3x3_row_major_f32.beve", "w") do io
    write(io, to_beve(matrix2))
end
println("✓ Created 3x3_row_major_f32.beve")

# Test 3: 3x3 column-major float matrix
matrix3 = BeveMatrix(LayoutLeft, [3, 3], Float32[i for i in 0:8])
open("julia_generated/matrices/3x3_col_major_f32.beve", "w") do io
    write(io, to_beve(matrix3))
end
println("✓ Created 3x3_col_major_f32.beve")

# Test 4: 2x2 complex matrix
matrix4 = BeveMatrix(LayoutRight, [2, 2], 
    ComplexF32[ComplexF32(1, 2), ComplexF32(3, 4), ComplexF32(5, 6), ComplexF32(7, 8)])
open("julia_generated/matrices/2x2_complex_f32.beve", "w") do io
    write(io, to_beve(matrix4))
end
println("✓ Created 2x2_complex_f32.beve")

# Test 5: Dynamic size matrix (4x5)
matrix5 = BeveMatrix(LayoutRight, [4, 5], Float64[i*0.1 for i in 1:20])
open("julia_generated/matrices/4x5_dynamic_f64.beve", "w") do io
    write(io, to_beve(matrix5))
end
println("✓ Created 4x5_dynamic_f64.beve")

println("\nAll individual matrix files created!")