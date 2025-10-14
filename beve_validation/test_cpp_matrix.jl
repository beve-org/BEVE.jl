using Pkg
Pkg.activate("..")
using BEVE

println("Testing C++ generated matrix")
println("===========================\n")

# Read the C++ generated matrix
data = read("julia_generated/matrices/cpp_2x3_matrix.beve")
println("Read $(length(data)) bytes from cpp_2x3_matrix.beve")
println("Hex: ", bytes2hex(data))

# Parse it
matrix = from_beve(data; preserve_matrices = true)
println("\nParsed matrix:")
println("  Type: $(typeof(matrix))")
println("  Layout: $(matrix.layout == LayoutRight ? "row-major" : "column-major")")
println("  Extents: $(matrix.extents)")
println("  Data type: $(eltype(matrix.data))")
println("  Data: $(matrix.data)")

# Verify the values
expected = Float32[10.0, 20.0, 30.0, 40.0, 50.0, 60.0]
if matrix.data ≈ expected
    println("\n✅ Values match expected: [10, 20, 30, 40, 50, 60]")
else
    println("\n❌ Values don't match expected!")
end

# Test round-trip
roundtrip_data = to_beve(matrix)
if roundtrip_data == data
    println("✅ Round-trip successful - Julia output matches C++ input")
else
    println("❌ Round-trip failed")
    println("  Original size: $(length(data))")
    println("  Round-trip size: $(length(roundtrip_data))")
    if length(data) != length(roundtrip_data)
        println("  Size difference detected")
    end
end
