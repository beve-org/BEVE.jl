using Pkg
Pkg.activate("..")
using BEVE
using Test

# Define structures matching C++ types
struct BasicTypes
    b::Bool
    i8::Int8
    u8::UInt8
    i16::Int16
    u16::UInt16
    i32::Int32
    u32::UInt32
    i64::Int64
    u64::UInt64
    f32::Float32
    f64::Float64
    str::String
end

struct ArrayTypes
    int_vec::Vector{Int32}
    double_vec::Vector{Float64}
    string_vec::Vector{String}
    bool_vec::Vector{Bool}
    int_array::Vector{Int32}  # Julia doesn't have fixed-size arrays like C++
end

struct ComplexTypes
    cf::ComplexF32
    cd::ComplexF64
    complex_vec::Vector{ComplexF32}
end

struct MapTypes
    string_int_map::Dict{String, Int32}
    int_string_map::Dict{Int32, String}
    unordered_map::Dict{String, Float64}
end

struct OptionalTypes
    opt_int::Union{Int32, Nothing}
    opt_string::Union{String, Nothing}
    opt_empty::Union{Float64, Nothing}
end

struct NestedStruct
    basic::BasicTypes
    arrays::ArrayTypes
    extra::Int32
end

struct AllTypes
    basic::BasicTypes
    arrays::ArrayTypes
    complex::ComplexTypes
    maps::MapTypes
    optionals::OptionalTypes
    nested::NestedStruct
end

# Create test data
function create_basic_types()
    BasicTypes(
        true,
        Int8(-42),
        UInt8(200),
        Int16(-1234),
        UInt16(45678),
        Int32(-2147483647),
        UInt32(3000000000),
        Int64(-9223372036854775807),
        UInt64(18446744073709551615),
        Float32(3.14159),
        Float64(2.718281828459045),
        "Hello, BEVE!"
    )
end

function create_array_types()
    ArrayTypes(
        Int32[1, 2, 3, 4, 5],
        Float64[1.1, 2.2, 3.3],
        String["alpha", "beta", "gamma"],
        Bool[true, false, true, true, false],
        Int32[10, 20, 30, 40, 50]
    )
end

function create_complex_types()
    ComplexTypes(
        ComplexF32(1.5, 2.5),
        ComplexF64(3.7, 4.8),
        ComplexF32[ComplexF32(1.0, 2.0), ComplexF32(3.0, 4.0), ComplexF32(5.0, 6.0)]
    )
end

function create_map_types()
    MapTypes(
        Dict("one" => Int32(1), "two" => Int32(2), "three" => Int32(3)),
        Dict(Int32(1) => "first", Int32(2) => "second", Int32(3) => "third"),
        Dict("pi" => 3.14159, "e" => 2.71828)
    )
end

function create_optional_types()
    OptionalTypes(
        Int32(42),
        "optional value",
        nothing
    )
end

function create_nested_struct()
    NestedStruct(
        create_basic_types(),
        create_array_types(),
        Int32(999)
    )
end

function create_all_types()
    AllTypes(
        create_basic_types(),
        create_array_types(),
        create_complex_types(),
        create_map_types(),
        create_optional_types(),
        create_nested_struct()
    )
end

# Write BEVE file
function write_beve_file(data, filename)
    println("Writing $filename")
    beve_data = to_beve(data)
    write(filename, beve_data)
    println("  Wrote $(length(beve_data)) bytes")
    return beve_data
end

# Read BEVE file
function read_beve_file(filename)
    println("Reading $filename")
    beve_data = read(filename)
    println("  Read $(length(beve_data)) bytes")
    return beve_data
end

# Generate test files from Julia
function generate_julia_test_files()
    println("\n=== Generating Julia Test Files ===")
    
    # Create output directory
    mkpath("julia_generated")
    
    # Generate basic types
    basic = create_basic_types()
    write_beve_file(basic, "julia_generated/basic_types.beve")
    
    # Generate array types
    arrays = create_array_types()
    write_beve_file(arrays, "julia_generated/array_types.beve")
    
    # Generate complex types
    complex = create_complex_types()
    write_beve_file(complex, "julia_generated/complex_types.beve")
    
    # Generate map types
    maps = create_map_types()
    write_beve_file(maps, "julia_generated/map_types.beve")
    
    # Generate optional types
    optionals = create_optional_types()
    write_beve_file(optionals, "julia_generated/optional_types.beve")
    
    # Generate nested struct
    nested = create_nested_struct()
    write_beve_file(nested, "julia_generated/nested_struct.beve")
    
    # Generate all types
    all = create_all_types()
    write_beve_file(all, "julia_generated/all_types.beve")
end

# Test reading C++ generated files
function test_cpp_generated_files()
    println("\n=== Testing C++ Generated Files ===")
    
    cpp_dir = "build/cpp_generated"
    if !isdir(cpp_dir)
        println("$cpp_dir directory not found. Run C++ tests first.")
        return
    end
    
    # Test basic types
    if isfile("$cpp_dir/basic_types.beve")
        println("\nTesting basic_types.beve")
        beve_data = read_beve_file("$cpp_dir/basic_types.beve")
        try
            # Try generic deserialization first
            result = from_beve(beve_data)
            println("  Generic deserialization: ", typeof(result))
            println("  Data: ", result)
            
            # Try typed deserialization
            typed_result = deser_beve(BasicTypes, beve_data)
            println("  Typed deserialization successful")
            println("  b=$(typed_result.b), i8=$(typed_result.i8), str=$(typed_result.str)")
        catch e
            println("  Error: $e")
        end
    end
    
    # Test array types
    if isfile("$cpp_dir/array_types.beve")
        println("\nTesting array_types.beve")
        beve_data = read_beve_file("$cpp_dir/array_types.beve")
        try
            result = from_beve(beve_data)
            println("  Generic deserialization: ", typeof(result))
            println("  Keys: ", keys(result))
        catch e
            println("  Error: $e")
        end
    end
    
    # Test complex types
    if isfile("$cpp_dir/complex_types.beve")
        println("\nTesting complex_types.beve")
        beve_data = read_beve_file("$cpp_dir/complex_types.beve")
        try
            result = from_beve(beve_data)
            println("  Generic deserialization: ", typeof(result))
            println("  Keys: ", keys(result))
        catch e
            println("  Error: $e")
        end
    end
end

# Test round-trip serialization
function test_round_trip()
    println("\n=== Testing Round-Trip Serialization ===")
    
    # Test basic types
    println("\nTesting BasicTypes round-trip")
    basic = create_basic_types()
    beve_data = to_beve(basic)
    result = from_beve(beve_data)
    println("  Original type: ", typeof(basic))
    println("  Result type: ", typeof(result))
    
    # Test typed deserialization
    typed_result = deser_beve(BasicTypes, beve_data)
    @test typed_result.b == basic.b
    @test typed_result.i8 == basic.i8
    @test typed_result.str == basic.str
    println("  ✓ BasicTypes round-trip successful")
    
    # Test array types
    println("\nTesting ArrayTypes round-trip")
    arrays = create_array_types()
    beve_data = to_beve(arrays)
    typed_result = deser_beve(ArrayTypes, beve_data)
    @test typed_result.int_vec == arrays.int_vec
    @test typed_result.string_vec == arrays.string_vec
    println("  ✓ ArrayTypes round-trip successful")
end

# Main test function
function run_tests()
    println("BEVE Julia Validation Tests")
    println("===========================")
    
    # Generate Julia test files
    generate_julia_test_files()
    
    # Test reading C++ generated files
    test_cpp_generated_files()
    
    # Test round-trip serialization
    test_round_trip()
    
    println("\nTests completed!")
end

# Run tests if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_tests()
end