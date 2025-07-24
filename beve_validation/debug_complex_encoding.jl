# Debug complex encoding differences
println("=== Analyzing Complex Number Encoding ===")
println()

# C++ values from hexdump
cpp_float_complex_header = 0x40
cpp_double_complex_header = 0x60
cpp_array_header = 0x41

# Julia expected values
julia_f32_header = 0x41
julia_f64_header = 0x61

println("C++ Glaze encoding:")
println("  Single complex<float>:  0x1e 0x$(string(cpp_float_complex_header, base=16, pad=2))")
println("  Single complex<double>: 0x1e 0x$(string(cpp_double_complex_header, base=16, pad=2))")
println("  Complex array:          0x1e 0x$(string(cpp_array_header, base=16, pad=2))")
println()

println("Julia BEVE expects:")
println("  Single complex<float>:  0x1e 0x$(string(julia_f32_header, base=16, pad=2)) (F32 header)")
println("  Single complex<double>: 0x1e 0x$(string(julia_f64_header, base=16, pad=2)) (F64 header)")
println()

# Analyze bit patterns according to spec
println("Bit pattern analysis (assuming spec format: array[1] | type[2] | bytes[3]):")
println()

function analyze_bits(value, name)
    bits = string(value, base=2, pad=8)
    array_bit = bits[1:3]
    type_bits = bits[4:5]
    byte_bits = bits[6:8]
    
    println("$name (0x$(string(value, base=16, pad=2))) = $bits")
    println("  Array indicator: $array_bit ($(parse(Int, array_bit, base=2)))")
    println("  Type indicator:  $type_bits ($(parse(Int, type_bits, base=2)))")
    println("  Byte count:      $byte_bits ($(parse(Int, byte_bits, base=2)))")
    println()
end

analyze_bits(0x40, "C++ float complex")
analyze_bits(0x41, "Julia F32 / C++ array")
analyze_bits(0x60, "C++ double complex")
analyze_bits(0x61, "Julia F64")

# Let's check what the spec might mean differently
println("Alternative interpretation (3 bits array, 2 bits type, 3 bits size):")
println()

function analyze_alt(value, name)
    bits = string(value, base=2, pad=8)
    # Reinterpret: first bit unused, next 3 for size, next 2 for type, last 2 for array
    unused = bits[1]
    size_bits = bits[2:4]
    type_bits = bits[5:6]
    array_bits = bits[7:8]
    
    println("$name (0x$(string(value, base=16, pad=2))) = $bits")
    println("  Unused:     $unused")
    println("  Size:       $size_bits ($(parse(Int, size_bits, base=2)))")
    println("  Type:       $type_bits ($(parse(Int, type_bits, base=2)))")
    println("  Array/mode: $array_bits ($(parse(Int, array_bits, base=2)))")
    println()
end

println("\nAlternative bit layout:")
analyze_alt(0x40, "C++ float complex")
analyze_alt(0x41, "Julia F32 / C++ array")
analyze_alt(0x60, "C++ double complex")
analyze_alt(0x61, "Julia F64")