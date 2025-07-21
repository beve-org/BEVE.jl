# BEVE.jl

BEVE serialization and deserialization library for Julia. BEVE (Binary Efficient Versatile Encoding) provides fast and compact serialization of Julia data structures including primitives, collections, and custom structs.

## Installation

Add BEVE.jl to your Julia project:

```julia
using Pkg
Pkg.add(url="https://github.com/beve-org/BEVE.jl.git")
```

Or in your `Project.toml`:

```toml
[deps]
BEVE = "e4b2c2d1-1234-5678-9abc-123456789abc"
```

## Usage

Import the library:

```julia
using BEVE
```

## Basic Usage

### Serialization and Deserialization

```julia
# Serialize data to BEVE format
data = "Hello, World!"
beve_data = to_beve(data)

# Deserialize back to Julia objects
result = from_beve(beve_data)
println(result) # "Hello, World!"
```

### Supported Types

BEVE.jl supports all basic Julia types:

```julia
# Basic types
to_beve(nothing)           # null
to_beve(true)             # boolean
to_beve(42)               # integers (Int8, Int16, Int32, Int64)
to_beve(UInt8(255))       # unsigned integers
to_beve(3.14)             # floats (Float32, Float64)
to_beve("text")           # strings

# Arrays
to_beve([1, 2, 3, 4])                    # numeric arrays
to_beve(["hello", "world"])              # string arrays
to_beve([true, false, true])             # boolean arrays
to_beve([1, "hello", true, 3.14])        # mixed arrays

# Dictionaries
to_beve(Dict("name" => "Alice", "age" => 30))
```

### Working with Custom Structs

BEVE.jl can serialize and deserialize custom Julia structs:

```julia
# Define a struct
struct Person
    name::String
    age::Int
end

# Create and serialize
person = Person("Alice", 30)
beve_data = to_beve(person)

# Deserialize as generic data
parsed = from_beve(beve_data)
println(parsed["name"])  # "Alice"
println(parsed["age"])   # 30

# Deserialize back to original struct type
reconstructed = deser_beve(Person, beve_data)
println(reconstructed.name)  # "Alice"
println(reconstructed.age)   # 30
```

### Complex Nested Structures

BEVE.jl handles deeply nested data structures:

```julia
struct Address
    street::String
    city::String
    zipcode::String
end

struct Employee
    name::String
    age::Int
    salary::Float64
    address::Address
    active::Bool
end

# Create nested data
address = Address("123 Main St", "New York", "10001")
employee = Employee("John Doe", 30, 75000.0, address, true)

# Serialize and deserialize
beve_data = to_beve(employee)
reconstructed = deser_beve(Employee, beve_data)

println(reconstructed.name)                    # "John Doe"
println(reconstructed.address.street)          # "123 Main St"
```

### Arrays of Structs

```julia
struct Product
    id::Int
    name::String
    price::Float64
    in_stock::Bool
end

products = [
    Product(1, "Laptop", 999.99, true),
    Product(2, "Mouse", 25.50, false),
    Product(3, "Keyboard", 75.00, true)
]

# Serialize array of structs
beve_data = to_beve(products)
parsed = from_beve(beve_data)

# Access individual products
println(parsed[1]["name"])    # "Laptop"
println(parsed[2]["price"])   # 25.50
```

### Optional and Union Fields

BEVE.jl supports optional fields and Union types:

```julia
struct OptionalData
    required_field::String
    optional_number::Union{Int, Nothing}
    optional_string::Union{String, Nothing}
end

# With values present
data1 = OptionalData("required", 42, "optional")
beve_data1 = to_beve(data1)
result1 = from_beve(beve_data1)

# With nothing values
data2 = OptionalData("required", nothing, nothing)
beve_data2 = to_beve(data2)
result2 = from_beve(beve_data2)
```

## API Reference

### Main Functions

- `to_beve(data)` - Serialize Julia data to BEVE format
- `from_beve(beve_data)` - Deserialize BEVE data to Julia objects (as dictionaries for structs)
- `deser_beve(Type, beve_data)` - Deserialize BEVE data back to specific struct type

## Running Tests

To run the test suite:

```bash
julia --project=. -e "import Pkg; Pkg.test()"
```

## Compatibility

- Julia 1.8+
