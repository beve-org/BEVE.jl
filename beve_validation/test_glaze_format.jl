using Pkg
Pkg.activate("..")
using BEVE

println("Testing Glaze-compatible matrix format")
println("=====================================\n")

# Create a test to understand Glaze's format
# From the C++ output: 16006c080200000000000000020000000000000044100000803f000000400000404000008040

glaze_hex = "16006c080200000000000000020000000000000044100000803f000000400000404000008040"
glaze_bytes = hex2bytes(glaze_hex)

println("Glaze format analysis:")
println("  Total size: $(length(glaze_bytes)) bytes")
println("  Header: 0x$(string(glaze_bytes[1], base=16)) (MATRIX)")
println("  Layout: 0x$(string(glaze_bytes[2], base=16)) (row-major)")
println("  Next byte: 0x$(string(glaze_bytes[3], base=16))")
println()

# Try to parse the Glaze-generated data
io = IOBuffer(glaze_bytes)
deser = BEVE.BeveDeserializer(io)

# Read matrix header
header = BEVE.read_byte!(deser)
println("Matrix header: 0x$(string(header, base=16))")

# Read layout
layout = BEVE.read_byte!(deser)
println("Layout: $layout")

# Read next byte (should be array header)
array_header = BEVE.read_byte!(deser)
println("Array header: 0x$(string(array_header, base=16))")

# Remaining bytes
remaining = read(io)
println("Remaining $(length(remaining)) bytes: ", bytes2hex(remaining))
println()

# Let's see what 0x6c means
println("Array header 0x6c analysis:")
println("  Binary: $(bitstring(UInt8(0x6c)))")
println("  As I64_ARRAY: ", BEVE.I64_ARRAY == 0x6c)

# So Glaze uses I64_ARRAY for extents!
# Let's modify our implementation to handle this special case for 2D matrices