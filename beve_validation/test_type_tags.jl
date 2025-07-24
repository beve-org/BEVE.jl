using Pkg
Pkg.activate("..")
using BEVE

println("Testing BEVE Type Tags (Variants)")
println("=================================")

# Test 1: Basic type tag with string value
println("\nTest 1: Basic type tag with string value")
tag1 = BeveTypeTag(0, "Hello, World!")
data1 = to_beve(tag1)
println("  Serialized $(length(data1)) bytes")
println("  Bytes: ", bytes2hex(data1))

# Deserialize and verify
result1 = from_beve(data1)
println("  Deserialized: index=$(result1.index), value=\"$(result1.value)\"")
@assert result1.index == 0
@assert result1.value == "Hello, World!"
println("  ✓ Basic type tag test passed")

# Test 2: Type tag with integer value
println("\nTest 2: Type tag with integer value")
tag2 = BeveTypeTag(1, Int32(42))
data2 = to_beve(tag2)
println("  Serialized $(length(data2)) bytes")
println("  Bytes: ", bytes2hex(data2))

result2 = from_beve(data2)
println("  Deserialized: index=$(result2.index), value=$(result2.value)")
@assert result2.index == 1
@assert result2.value == 42
println("  ✓ Integer value test passed")

# Test 3: Type tag with complex struct value
println("\nTest 3: Type tag with complex struct value")
struct TestStruct
    name::String
    age::Int32
    scores::Vector{Float32}
end

test_struct = TestStruct("Alice", Int32(25), Float32[95.5, 87.3, 91.0])
tag3 = BeveTypeTag(2, test_struct)
data3 = to_beve(tag3)
println("  Serialized $(length(data3)) bytes")

result3 = from_beve(data3)
println("  Deserialized: index=$(result3.index)")
println("  Value type: $(typeof(result3.value))")
@assert result3.index == 2
@assert result3.value isa Dict
@assert result3.value["name"] == "Alice"
@assert result3.value["age"] == 25
@assert result3.value["scores"] ≈ Float32[95.5, 87.3, 91.0]
println("  ✓ Complex struct value test passed")

# Test 4: Type tag with array value
println("\nTest 4: Type tag with array value")
tag4 = BeveTypeTag(3, [1, 2, 3, 4, 5])
data4 = to_beve(tag4)
println("  Serialized $(length(data4)) bytes")

result4 = from_beve(data4)
println("  Deserialized: index=$(result4.index), value=$(result4.value)")
@assert result4.index == 3
@assert result4.value == [1, 2, 3, 4, 5]
println("  ✓ Array value test passed")

# Test 5: Type tag with nested type tag (variant containing variant)
println("\nTest 5: Nested type tags")
inner_tag = BeveTypeTag(10, "Inner value")
outer_tag = BeveTypeTag(20, inner_tag)
data5 = to_beve(outer_tag)
println("  Serialized $(length(data5)) bytes")

result5 = from_beve(data5)
println("  Outer: index=$(result5.index)")
println("  Inner: index=$(result5.value.index), value=\"$(result5.value.value)\"")
@assert result5.index == 20
@assert result5.value isa BEVE.BeveTypeTag
@assert result5.value.index == 10
@assert result5.value.value == "Inner value"
println("  ✓ Nested type tags test passed")

# Test 6: Large type index
println("\nTest 6: Large type index")
tag6 = BeveTypeTag(1000000, Dict("key" => "value"))
data6 = to_beve(tag6)
println("  Serialized $(length(data6)) bytes")

result6 = from_beve(data6)
println("  Deserialized: index=$(result6.index)")
@assert result6.index == 1000000
@assert result6.value isa Dict
@assert result6.value["key"] == "value"
println("  ✓ Large type index test passed")

println("\n✅ All type tag tests passed!")

# Write a sample file for C++ validation
println("\nWriting type tag samples for C++ validation...")
samples = Dict(
    "simple_string" => BeveTypeTag(0, "Test string"),
    "integer_value" => BeveTypeTag(1, Int32(12345)),
    "float_array" => BeveTypeTag(2, Float32[1.0, 2.0, 3.0, 4.0]),
    "nested_object" => BeveTypeTag(3, Dict("nested" => true, "count" => Int32(5))),
    "variant_array" => [
        BeveTypeTag(0, "First"),
        BeveTypeTag(1, Int32(42)),
        BeveTypeTag(2, Float64(3.14159))
    ]
)

mkpath("julia_generated")
open("julia_generated/type_tags.beve", "w") do io
    write(io, to_beve(samples))
end
println("✓ Written type tag samples to julia_generated/type_tags.beve")