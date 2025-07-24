using Pkg
Pkg.activate("..")
using BEVE

println("Testing C++ generated integer keyed objects")
println("==========================================\n")

# Test 1: Read C++ uint32 dictionary
println("Test 1: C++ uint32_t dictionary")
if isfile("julia_generated/integer_objects/cpp_uint32_dict.beve")
    data = read("julia_generated/integer_objects/cpp_uint32_dict.beve")
    println("  Read $(length(data)) bytes")
    
    result = from_beve(data)
    println("  Type: $(typeof(result))")
    println("  Contents:")
    for (k, v) in sort(collect(result))
        println("    $k => \"$v\"")
    end
    
    # Check values
    @assert result[UInt32(100)] == "hundred"
    @assert result[UInt32(200)] == "two hundred"
    @assert result[UInt32(300)] == "three hundred"
    println("  ✓ All values correct")
    
    # Test round-trip
    roundtrip = to_beve(result)
    if roundtrip == data
        println("  ✓ Round-trip successful")
    else
        println("  ✗ Round-trip mismatch: $(length(data)) vs $(length(roundtrip)) bytes")
    end
else
    println("  ⚠ File not found - run C++ test first")
end

# Test 2: Read C++ int8 dictionary with negative keys
println("\nTest 2: C++ int8_t dictionary with negative keys")
if isfile("julia_generated/integer_objects/cpp_int8_dict.beve")
    data = read("julia_generated/integer_objects/cpp_int8_dict.beve")
    println("  Read $(length(data)) bytes")
    
    result = from_beve(data)
    println("  Type: $(typeof(result))")
    println("  Contents:")
    for (k, v) in sort(collect(result))
        println("    $k => $v")
    end
    
    # Check negative keys work
    @assert result[Int8(-128)] == -1000
    @assert result[Int8(-1)] == -1
    @assert result[Int8(0)] == 0
    @assert result[Int8(1)] == 1
    @assert result[Int8(127)] == 1000
    println("  ✓ All values correct including negative keys")
else
    println("  ⚠ File not found - run C++ test first")
end

# Test 3: Analyze ordering differences
println("\nTest 3: Analyzing ordering differences")
test_dict = Dict{Int32, String}(
    Int32(3) => "three",
    Int32(1) => "one",
    Int32(2) => "two"
)
julia_bytes = to_beve(test_dict)
println("  Julia serialization of unordered dict: $(length(julia_bytes)) bytes")
println("  First 20 bytes: ", bytes2hex(julia_bytes[1:min(20, end)]))

# Julia Dict iteration order is not guaranteed, but the content should be the same
result = from_beve(julia_bytes)
println("  Deserialized successfully: $(result == test_dict)")

println("\n✅ C++ integer object reading tests complete!")