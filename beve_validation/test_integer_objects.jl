using Pkg
Pkg.activate("..")
using BEVE

println("Testing BEVE Integer Keyed Objects")
println("==================================\n")

# Test 1: Basic integer keyed dictionaries
println("Test 1: Basic integer keyed dictionaries")

# Int32 keys
dict_i32 = Dict{Int32, String}(
    Int32(1) => "one",
    Int32(2) => "two",
    Int32(3) => "three"
)
data_i32 = to_beve(dict_i32)
println("  Int32 dict: $(length(data_i32)) bytes")
println("  Hex: ", bytes2hex(data_i32))

# Deserialize and verify
result_i32 = from_beve(data_i32)
println("  Deserialized type: $(typeof(result_i32))")
@assert result_i32 isa Dict{Int32, Any}
@assert length(result_i32) == 3
@assert result_i32[Int32(1)] == "one"
@assert result_i32[Int32(2)] == "two"
@assert result_i32[Int32(3)] == "three"
println("  ✓ Int32 dictionary test passed")

# Test 2: Different integer types
println("\nTest 2: Different integer types")

# UInt8 keys
dict_u8 = Dict{UInt8, Float64}(
    UInt8(0) => 0.0,
    UInt8(128) => 128.5,
    UInt8(255) => 255.9
)
data_u8 = to_beve(dict_u8)
result_u8 = from_beve(data_u8)
@assert result_u8[UInt8(255)] ≈ 255.9
println("  ✓ UInt8 dictionary test passed")

# Int64 keys
dict_i64 = Dict{Int64, Any}(
    Int64(1000000000000) => "large",
    Int64(-1000000000000) => "negative large",
    Int64(0) => [1, 2, 3]
)
data_i64 = to_beve(dict_i64)
result_i64 = from_beve(data_i64)
@assert result_i64[Int64(1000000000000)] == "large"
@assert result_i64[Int64(0)] == [1, 2, 3]
println("  ✓ Int64 dictionary test passed")

# Test 3: Mixed value types
println("\nTest 3: Mixed value types in integer keyed dict")
dict_mixed = Dict{UInt32, Any}(
    UInt32(1) => "string",
    UInt32(2) => 42,
    UInt32(3) => 3.14,
    UInt32(4) => [1, 2, 3],
    UInt32(5) => Dict("nested" => true)
)
data_mixed = to_beve(dict_mixed)
result_mixed = from_beve(data_mixed)
@assert result_mixed[UInt32(1)] == "string"
@assert result_mixed[UInt32(2)] == 42
@assert result_mixed[UInt32(3)] ≈ 3.14
@assert result_mixed[UInt32(4)] == [1, 2, 3]
@assert result_mixed[UInt32(5)]["nested"] == true
println("  ✓ Mixed value types test passed")

# Test 4: Round-trip with type preservation
println("\nTest 4: Round-trip with type preservation")
original = Dict{Int16, String}(
    Int16(-100) => "negative",
    Int16(0) => "zero",
    Int16(100) => "positive"
)
serialized = to_beve(original)
deserialized = deser_beve(Dict{Int16, String}, serialized)
@assert typeof(deserialized) == Dict{Int16, String}
@assert deserialized == original
println("  ✓ Type preservation test passed")

# Test 5: Nested integer keyed dictionaries
println("\nTest 5: Nested integer keyed dictionaries")
nested = Dict{Int32, Dict{UInt16, String}}(
    Int32(1) => Dict{UInt16, String}(
        UInt16(10) => "ten",
        UInt16(20) => "twenty"
    ),
    Int32(2) => Dict{UInt16, String}(
        UInt16(30) => "thirty",
        UInt16(40) => "forty"
    )
)
data_nested = to_beve(nested)
result_nested = from_beve(data_nested)
@assert result_nested[Int32(1)][UInt16(10)] == "ten"
@assert result_nested[Int32(2)][UInt16(40)] == "forty"
println("  ✓ Nested dictionaries test passed")

# Test 6: Empty integer dictionary
println("\nTest 6: Empty integer dictionary")
empty_dict = Dict{Int32, String}()
data_empty = to_beve(empty_dict)
result_empty = from_beve(data_empty)
@assert result_empty isa Dict{Int32, Any}
@assert isempty(result_empty)
println("  ✓ Empty dictionary test passed")

# Test 7: Large integer keys (Int128, UInt128)
println("\nTest 7: Large integer keys")
dict_i128 = Dict{Int128, String}(
    Int128(2)^100 => "large positive",
    -Int128(2)^100 => "large negative"
)
data_i128 = to_beve(dict_i128)
result_i128 = from_beve(data_i128)
@assert result_i128[Int128(2)^100] == "large positive"
println("  ✓ Int128 dictionary test passed")

dict_u128 = Dict{UInt128, String}(
    UInt128(2)^120 => "very large"
)
data_u128 = to_beve(dict_u128)
result_u128 = from_beve(data_u128)
@assert result_u128[UInt128(2)^120] == "very large"
println("  ✓ UInt128 dictionary test passed")

# Test 8: Automatic type detection
println("\nTest 8: Automatic type detection for generic dicts")
generic_dict = Dict(
    1 => "auto int",
    2 => "detected"
)
data_generic = to_beve(generic_dict)
println("  Generic dict serialized to $(length(data_generic)) bytes")
result_generic = from_beve(data_generic)
# Should be detected as Int64 on 64-bit systems
@assert result_generic isa Dict{<:Integer, Any}
@assert result_generic[1] == "auto int"
println("  ✓ Automatic type detection test passed")

println("\n✅ All integer keyed object tests passed!")

# Write test files for C++ validation
println("\nWriting integer object samples for C++ validation...")
mkpath("julia_generated/integer_objects")

samples = Dict(
    "int32_dict.beve" => Dict{Int32, String}(
        Int32(1) => "first",
        Int32(2) => "second",
        Int32(3) => "third"
    ),
    "uint16_dict.beve" => Dict{UInt16, Float64}(
        UInt16(100) => 100.5,
        UInt16(200) => 200.5,
        UInt16(300) => 300.5
    ),
    "int64_complex.beve" => Dict{Int64, Any}(
        Int64(1) => Dict("nested" => "object"),
        Int64(2) => [1, 2, 3, 4, 5],
        Int64(3) => 3.14159
    )
)

for (filename, dict) in samples
    open("julia_generated/integer_objects/$filename", "w") do io
        write(io, to_beve(dict))
    end
    println("  ✓ Written $filename")
end

println("\nInteger object test files created!")