using Pkg
Pkg.activate("..")
using BEVE

println("Testing matrix format details")
println("============================\n")

# Create a simple 2x2 matrix
matrix = BeveMatrix(LayoutRight, [2, 2], Float32[1.0, 2.0, 3.0, 4.0])
data = to_beve(matrix)

println("Matrix data:")
println("  Layout: row-major")
println("  Extents: [2, 2]")
println("  Values: [1.0, 2.0, 3.0, 4.0]")
println("  Serialized size: $(length(data)) bytes")
println("  Hex: ", bytes2hex(data))
println()

# Break down the bytes
println("Byte breakdown:")
println("  Header: 0x$(string(data[1], base=16)) (should be 0x16 for MATRIX)")
println("  Layout: 0x$(string(data[2], base=16)) (should be 0x00 for row-major)")
println("  Extents header: 0x$(string(data[3], base=16))")
println("  Remaining bytes: ", bytes2hex(data[4:end]))

# Try a minimal dictionary with just one matrix
minimal = Dict("test_matrix" => matrix)
minimal_data = to_beve(minimal)
println("\nMinimal dictionary with one matrix:")
println("  Size: $(length(minimal_data)) bytes") 
println("  Hex: ", bytes2hex(minimal_data))

# Save just the matrix data
open("julia_generated/single_matrix.beve", "w") do io
    write(io, data)
end
println("\nWrote single matrix to julia_generated/single_matrix.beve")

# Save the minimal dictionary
open("julia_generated/minimal_matrix_dict.beve", "w") do io
    write(io, minimal_data)
end
println("Wrote minimal dictionary to julia_generated/minimal_matrix_dict.beve")