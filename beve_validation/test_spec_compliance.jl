using Pkg
Pkg.activate("..")
using BEVE

println("Testing BEVE spec interpretation differences")
println("==========================================\n")

# Test matrix header interpretation
println("Matrix header byte interpretation:")
println("  Spec says: 'first bit' (suggests bit flag)")
println("  Glaze uses: entire byte value")
println()

# Example with byte value 0x01
header_byte = 0x01
println("For header byte 0x$(string(header_byte, base=16)):")
println("  As bit flag (spec?): bit 0 = $(header_byte & 0x01) -> $(header_byte & 0x01 == 1 ? "column-major" : "row-major")")
println("  As byte value (Glaze): value = $header_byte -> $(header_byte == 1 ? "column-major" : "row-major")")
println()

# Example with byte value 0x81 (bit 0 set, but other bits too)
header_byte2 = 0x81
println("For header byte 0x$(string(header_byte2, base=16)):")
println("  As bit flag (spec?): bit 0 = $(header_byte2 & 0x01) -> $(header_byte2 & 0x01 == 1 ? "column-major" : "row-major")")
println("  As byte value (Glaze): value = $header_byte2 -> $(header_byte2 == 1 ? "column-major" : "row-major")")
println()

println("This shows why the interpretation matters!")
println("  - Spec interpretation: 0x81 would be column-major (bit 0 is set)")
println("  - Glaze interpretation: 0x81 would be row-major (value ≠ 1)")

# Test what Glaze actually writes
println("\nChecking Glaze's actual output:")
glaze_data = hex2bytes("16006c080200000000000000020000000000000044100000803f000000400000404000008040")
println("  Matrix header: 0x$(string(glaze_data[1], base=16))")
println("  Layout byte: 0x$(string(glaze_data[2], base=16)) ($(glaze_data[2]))")
println("  -> Glaze writes exactly 0 or 1, not using it as a bit field")