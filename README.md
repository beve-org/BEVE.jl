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

### File Helpers

Use `write_beve_file(path, data; buffer=...)` to serialize Julia objects straight
to disk via an intermediate contiguous `IOBuffer`. Reusing a buffer avoids
allocations when writing many files. `read_beve_file(path; preserve_matrices)`
and `deser_beve_file(T, path; kwargs...)` load the entire file into memory before
deserializing, which matches the non-streaming performance profile of the
serializer.

```julia
sample = Dict("message" => "hello", "values" => [1, 2, 3])
write_beve_file("sample.beve", sample)

matrix = Float32[1 2; 3 4]
buf = IOBuffer()
write_beve_file("matrix.beve", matrix; buffer = buf)  # buffer reused across writes

read_beve_file("sample.beve")                  # -> Dict
read_beve_file("matrix.beve"; preserve_matrices = true)  # -> BeveMatrix wrapper
deser_beve_file(Matrix{Float32}, "matrix.beve")  # -> Matrix{Float32}
```

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

#### Skipping Struct Fields

Exclude fields from serialization either declaratively with `@skip` or dynamically with `skip(::Type, ::Val, value)`:

```julia
struct Credentials
    username::String
    password::String
    token::Union{String, Nothing}
    session_id::String
end

# Skip password and session_id for every serialization
BEVE.@skip Credentials password session_id

# Skip token only when it is `nothing`
BEVE.skip(::Type{Credentials}, ::Val{:token}, value) = value === nothing

data = Credentials("alice", "secret", nothing, "sess-42")
parsed = from_beve(to_beve(data))

@assert keys(parsed) == ["username"]

# Reconstructing with skipped fields
deser_beve(Credentials, to_beve(data))

# Enforce strict field presence
deser_beve(Credentials, to_beve(data); error_on_missing_fields = true)
```

By default `deser_beve` allows reconstruction even when fields were skipped in the serialized input, making it easy to rely on struct defaults. Set `error_on_missing_fields = true` to throw a `BeveError` whenever a field is absent.

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

### Matrices

Julia `AbstractMatrix` and `Matrix{T}` values automatically use the BEVE matrix extension:

```julia
mat = Float32[1 2 3; 4 5 6]
bytes = to_beve(mat)

parsed = from_beve(bytes)                    # Matrix{Float32}
raw = from_beve(bytes; preserve_matrices = true)  # BeveMatrix wrapper with layout/extents/data
```

Matrix fields inside structs are also reconstructed when using `deser_beve`:

```julia
struct Grid
    values::Matrix{Float64}
end

grid = Grid([1.0 2.0; 3.0 4.0])
roundtrip = deser_beve(Grid, to_beve(grid))
@assert roundtrip.values == grid.values
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

## Optional Zstandard Compression

BEVE ships an optional extension that wraps [CodecZstd.jl](https://github.com/JuliaIO/CodecZstd.jl) so you can read and write `.beve.zst` files. The helpers are no-ops unless `CodecZstd` is available; install it explicitly when you want compressed output:

```julia
using Pkg
Pkg.add("CodecZstd")  # add only when you need compression
```

Once `CodecZstd` is in the environment, the extension activates automatically and provides four new helpers:

- `to_beve_zstd(data; buffer=nothing, level=3)` – compress the result of `to_beve`.
- `from_beve_zstd(bytes; preserve_matrices=false)` – decompress then call `from_beve`.
- `write_beve_zstd_file(path, data; buffer=nothing, level=3)` – write `.beve.zst` files.
- `read_beve_zstd_file(path; preserve_matrices=false)` – read `.beve.zst` files.
- `deser_beve_zstd(::Type{T}, bytes; kwargs...)` and `deser_beve_zstd_file(::Type{T}, path; kwargs...)` mirror their uncompressed counterparts when you want structs back directly.

The helper defaults reuse any `IOBuffer` you pass via `buffer` to avoid reallocations. Files created with `write_beve_zstd_file` (and the struct variant) should use the `.beve.zst` suffix so tools can recognize the codec.

Example:

```julia
using BEVE
using CodecZstd  # activates the extension

sample = Dict("message" => "hello")
compressed = to_beve_zstd(sample, level = 5)
@assert from_beve_zstd(compressed) == sample

struct Person
    name::String
    age::Int
end

person = Person("Ada", 37)
bytes = to_beve_zstd(person)
@assert deser_beve_zstd(Person, bytes) == person

write_beve_zstd_file("person.beve.zst", person)
@assert deser_beve_zstd_file(Person, "person.beve.zst") == person
```

## Optional HTTP Support

BEVE.jl includes optional HTTP server and client functionality through a package extension. HTTP.jl is now an optional dependency - you only need it if you want to use HTTP features.

### Enabling HTTP Features

HTTP functionality is provided through a Julia package extension (available since Julia 1.9). To use HTTP features, simply load HTTP.jl:

```julia
using BEVE
using HTTP  # This automatically loads the HTTP extension

# Now HTTP functions are available
```

Without HTTP.jl, core BEVE serialization works normally, but HTTP functions will not be available.

### HTTP Server

Once HTTP.jl is loaded, you can register struct instances at HTTP paths and serve them:

```julia
using BEVE
using HTTP  # Required for HTTP functionality

# Define your structs
struct Employee
    id::Int
    name::String
    email::String
    active::Bool
end

struct Company
    name::String
    employees::Vector{Employee}
    founded::Int
end

# Create data
employees = [
    Employee(1, "Alice", "alice@company.com", true),
    Employee(2, "Bob", "bob@company.com", false)
]
company = Company("ACME Corp", employees, 2020)

# Register objects at HTTP paths
register_object("/api/company", company)

# Start HTTP server
server = start_server("127.0.0.1", 8080)
```

The server supports JSON pointer syntax for accessing nested data:

- `GET /api/company` - Returns entire company object
- `GET /api/company?pointer=/name` - Returns just the company name
- `GET /api/company?pointer=/employees` - Returns the employees array
- `GET /api/company?pointer=/employees/0` - Returns first employee
- `GET /api/company?pointer=/employees/0/name` - Returns first employee's name

### HTTP Client

Make requests to BEVE HTTP servers:

```julia
using BEVE
using HTTP  # Required for HTTP functionality

# Create client
client = BeveHttpClient("http://localhost:8080")

# Get entire company and deserialize to struct
company = get(client, "/api/company", as_type=Company)

# Get specific fields using JSON pointers
company_name = get(client, "/api/company", json_pointer="/name")
employees = get(client, "/api/company", json_pointer="/employees")
first_employee = get(client, "/api/company", json_pointer="/employees/0", as_type=Employee)

# Update data via POST
post(client, "/api/company", "New Company Name", json_pointer="/name")
```

### JSON Pointer Support

JSON pointers follow RFC 6901 standard:

- `/` - Root object
- `/field` - Access field named "field"
- `/array/0` - Access first element of array
- `/nested/field/value` - Access nested fields
- Special characters: `~0` for `~`, `~1` for `/`

### API Reference

#### Server Functions (requires HTTP.jl)

- `register_object(path::String, obj)` - Register an object at the given HTTP path
- `unregister_object(path::String)` - Remove an object from the given path
- `start_server(host::String, port::Int)` - Start HTTP server

#### Client Functions (requires HTTP.jl)

- `BeveHttpClient(base_url::String; headers::Dict)` - Create HTTP client
- `get(client::BeveHttpClient, path::String; json_pointer::String, as_type::Type)` - GET request
- `post(client::BeveHttpClient, path::String, data; json_pointer::String)` - POST request

## Compatibility

- Julia 1.9+ (required for package extensions)
- HTTP.jl (optional, only needed for HTTP functionality)
