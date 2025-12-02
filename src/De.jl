# BEVE Deserialization Module

mutable struct BeveDeserializer{IOType<:IO}
    io::IOType
    peek_byte::Union{Nothing, UInt8}
    read_buffer::Vector{UInt8}  # Pre-allocated buffer for reading
    temp_buffer::Vector{UInt8}  # Temporary working buffer

    preserve_matrices::Bool

    function BeveDeserializer(io::IO; preserve_matrices::Bool = false)
        new{typeof(io)}(io, nothing, Vector{UInt8}(undef, 8192), Vector{UInt8}(undef, 64), preserve_matrices)
    end
end

# Function lookup table for fast header dispatch
const HEADER_PARSERS = Dict{UInt8, Function}(
    NULL => (deser) -> nothing,
    FALSE => (deser) -> false,
    TRUE => (deser) -> true,
    I8 => (deser) -> ltoh(read(deser.io, Int8)),
    I16 => (deser) -> ltoh(read(deser.io, Int16)),
    I32 => (deser) -> ltoh(read(deser.io, Int32)),
    I64 => (deser) -> ltoh(read(deser.io, Int64)),
    I128 => (deser) -> ltoh(read(deser.io, Int128)),
    U8 => (deser) -> read(deser.io, UInt8),
    U16 => (deser) -> ltoh(read(deser.io, UInt16)),
    U32 => (deser) -> ltoh(read(deser.io, UInt32)),
    U64 => (deser) -> ltoh(read(deser.io, UInt64)),
    U128 => (deser) -> ltoh(read(deser.io, UInt128)),
    F32 => (deser) -> ltoh(read(deser.io, Float32)),
    F64 => (deser) -> ltoh(read(deser.io, Float64)),
    STRING => (deser) -> read_string_data(deser),
    STRING_OBJECT => (deser) -> parse_string_object(deser),
    I8_OBJECT => (deser) -> parse_integer_object(deser, Int8),
    I16_OBJECT => (deser) -> parse_integer_object(deser, Int16),
    I32_OBJECT => (deser) -> parse_integer_object(deser, Int32),
    I64_OBJECT => (deser) -> parse_integer_object(deser, Int64),
    I128_OBJECT => (deser) -> parse_integer_object(deser, Int128),
    U8_OBJECT => (deser) -> parse_integer_object(deser, UInt8),
    U16_OBJECT => (deser) -> parse_integer_object(deser, UInt16),
    U32_OBJECT => (deser) -> parse_integer_object(deser, UInt32),
    U64_OBJECT => (deser) -> parse_integer_object(deser, UInt64),
    U128_OBJECT => (deser) -> parse_integer_object(deser, UInt128),
    BOOL_ARRAY => (deser) -> parse_bool_array(deser),
    STRING_ARRAY => (deser) -> parse_string_array(deser),
    F32_ARRAY => (deser) -> parse_f32_array(deser),
    F64_ARRAY => (deser) -> parse_f64_array(deser),
    I8_ARRAY => (deser) -> parse_i8_array(deser),
    I16_ARRAY => (deser) -> parse_i16_array(deser),
    I32_ARRAY => (deser) -> parse_i32_array(deser),
    I64_ARRAY => (deser) -> parse_i64_array(deser),
    U8_ARRAY => (deser) -> parse_u8_array(deser),
    U16_ARRAY => (deser) -> parse_u16_array(deser),
    U32_ARRAY => (deser) -> parse_u32_array(deser),
    U64_ARRAY => (deser) -> parse_u64_array(deser),
    GENERIC_ARRAY => (deser) -> parse_generic_array(deser),
    COMPLEX => (deser) -> parse_complex(deser),
    TAG => (deser) -> parse_type_tag(deser),
    MATRIX => (deser) -> parse_matrix(deser)
)

struct BeveError <: Exception
    msg::String
end

function read_byte!(deser::BeveDeserializer)::UInt8
    if deser.peek_byte !== nothing
        b = deser.peek_byte
        deser.peek_byte = nothing
        return b
    end
    
    if eof(deser.io)
        throw(BeveError("Unexpected end of data"))
    end
    
    return read(deser.io, UInt8)
end

function peek_byte!(deser::BeveDeserializer)::UInt8
    if deser.peek_byte !== nothing
        return deser.peek_byte
    end
    
    if eof(deser.io)
        throw(BeveError("Unexpected end of data"))
    end
    
    deser.peek_byte = read(deser.io, UInt8)
    return deser.peek_byte
end

# Optimized size reading function
@inline function read_size(deser::BeveDeserializer)::Int
    first = read_byte!(deser)
    n_bytes = 1 << (first & 0b11)  # Faster than 2^(first & 0b11)
    
    if n_bytes == 1
        return Int(first >> 2)
    end
    
    if n_bytes == 2
        second = read_byte!(deser)
        val = UInt16(first) | (UInt16(second) << 8)
        return Int(ltoh(val) >> 2)
    elseif n_bytes == 4
        # Read 3 more bytes
        val = UInt32(first)
        val |= UInt32(read_byte!(deser)) << 8
        val |= UInt32(read_byte!(deser)) << 16
        val |= UInt32(read_byte!(deser)) << 24
        return Int(ltoh(val) >> 2)
    else  # n_bytes == 8
        # Read 7 more bytes
        val = UInt64(first)
        for i in 1:7
            val |= UInt64(read_byte!(deser)) << (8 * i)
        end
        return Int(ltoh(val) >> 2)
    end
end

function read_string_data(deser::BeveDeserializer)::String
    size = read_size(deser)
    if size == 0
        return ""
    end
    
    # Use pre-allocated buffer if string is small enough
    if size <= length(deser.temp_buffer)
        bytes = @view deser.temp_buffer[1:size]
        read!(deser.io, bytes)
        return String(copy(bytes))  # Copy needed since we're reusing buffer
    else
        # Allocate new buffer for large strings
        bytes = Vector{UInt8}(undef, size)
        read!(deser.io, bytes)
        return String(bytes)
    end
end

# Helper function for bulk array reads with endianness conversion
@inline function read_array_data!(io::IO, result::Vector{T}) where T <: Union{Int8, UInt8}
    # Int8 and UInt8 don't need endianness conversion
    if length(result) > 0
        read!(io, result)
    end
end

@inline function read_array_data!(io::IO, result::Vector{T}) where T <: Union{Int16, Int32, Int64, UInt16, UInt32, UInt64, Float32, Float64}
    if length(result) == 0
        return
    end
    
    if ENDIAN_BOM == 0x04030201  # Little endian system
        # Direct read without conversion
        read!(io, result)
    else
        # Big endian system - read then convert
        read!(io, result)
        @inbounds for i in 1:length(result)
            result[i] = ltoh(result[i])
        end
    end
end

# Optimized version with deserializer buffer management
@inline function read_array_data!(deser::BeveDeserializer, result::Vector{T}) where T <: Union{Int8, UInt8}
    if length(result) > 0
        read!(deser.io, result)
    end
end

@inline function read_array_data!(deser::BeveDeserializer, result::Vector{T}) where T <: Union{Int16, Int32, Int64, UInt16, UInt32, UInt64, Float32, Float64}
    if length(result) == 0
        return
    end
    
    if ENDIAN_BOM == 0x04030201  # Little endian system
        # Direct read without conversion
        read!(deser.io, result)
    else
        # Big endian system - read then convert
        read!(deser.io, result)
        @inbounds for i in 1:length(result)
            result[i] = ltoh(result[i])
        end
    end
end

# Optimized parse_value using lookup table
function parse_value(deser::BeveDeserializer)
    header = read_byte!(deser)
    
    parser = get(HEADER_PARSERS, header, nothing)
    if parser !== nothing
        return parser(deser)
    else
        throw(BeveError("Unsupported header: $(header_name(header)) (0x$(string(header, base=16)))"))
    end
end

function parse_complex(deser::BeveDeserializer)
    # Read the complex header byte
    complex_header = read_byte!(deser)
    
    # Extract fields from complex header byte per BEVE spec:
    # - Bits 0-2: single/array indicator (0 = single, 1 = array)
    # - Bits 3-4: type (0 = float, 1 = signed int, 2 = unsigned int)
    # - Bits 5-7: byte count index (0=1, 1=2, 2=4, 3=8, etc.)
    
    is_array = complex_header & 0x01  # Bit 0 indicates array
    type_bits = (complex_header >> 3) & 0x03  # Bits 3-4 for type
    byte_count_idx = (complex_header >> 5) & 0x07  # Bits 5-7 for byte count
    
    # Only floating point complex numbers are currently supported
    if type_bits != 0
        throw(BeveError("Only floating point complex numbers are supported"))
    end
    
    # Calculate byte count from index: 1 << byte_count_idx
    byte_count = 1 << byte_count_idx
    
    # Validate expected byte counts for complex floats
    if byte_count != 4 && byte_count != 8
        throw(BeveError("Unsupported complex float size: $byte_count bytes"))
    end
    
    if is_array != 0
        # Handle complex arrays
        size = read_size(deser)
        
        if byte_count == 4
            result = Vector{ComplexF32}(undef, size)
            if ENDIAN_BOM == 0x04030201  # Little endian system
                # Direct read of complex array as interleaved real/imag values
                if size > 0
                    unsafe_read(deser.io, pointer(result), size * sizeof(ComplexF32))
                end
            else
                # Big endian - need conversion using working buffer
                if size > 0
                    buffer_size = 2 * size * sizeof(Float32)
                    if buffer_size > length(deser.read_buffer)
                        resize!(deser.read_buffer, buffer_size)
                    end
                    
                    # Read interleaved float data
                    buffer_ptr = reinterpret(Ptr{Float32}, pointer(deser.read_buffer))
                    unsafe_read(deser.io, buffer_ptr, buffer_size)
                    
                    # Convert with endianness correction
                    @inbounds for i in 1:size
                        real_val = ltoh(unsafe_load(buffer_ptr, 2i-1))
                        imag_val = ltoh(unsafe_load(buffer_ptr, 2i))
                        result[i] = ComplexF32(real_val, imag_val)
                    end
                end
            end
            return result
        else  # byte_count == 8
            result = Vector{ComplexF64}(undef, size)
            if ENDIAN_BOM == 0x04030201  # Little endian system
                # Direct read of complex array as interleaved real/imag values
                if size > 0
                    unsafe_read(deser.io, pointer(result), size * sizeof(ComplexF64))
                end
            else
                # Big endian - need conversion using working buffer
                if size > 0
                    buffer_size = 2 * size * sizeof(Float64)
                    if buffer_size > length(deser.read_buffer)
                        resize!(deser.read_buffer, buffer_size)
                    end
                    
                    # Read interleaved double data
                    buffer_ptr = reinterpret(Ptr{Float64}, pointer(deser.read_buffer))
                    unsafe_read(deser.io, buffer_ptr, buffer_size)
                    
                    # Convert with endianness correction
                    @inbounds for i in 1:size
                        real_val = ltoh(unsafe_load(buffer_ptr, 2i-1))
                        imag_val = ltoh(unsafe_load(buffer_ptr, 2i))
                        result[i] = ComplexF64(real_val, imag_val)
                    end
                end
            end
            return result
        end
    end
    
    # Single complex number
    if byte_count == 4
        real = ltoh(read(deser.io, Float32))
        imag = ltoh(read(deser.io, Float32))
        return ComplexF32(real, imag)
    else  # byte_count == 8
        real = ltoh(read(deser.io, Float64))
        imag = ltoh(read(deser.io, Float64))
        return ComplexF64(real, imag)
    end
end

function parse_type_tag(deser::BeveDeserializer)
    # Per BEVE spec: Type tags store a type index and a value
    # Layout: HEADER | SIZE (type tag index) | VALUE
    
    # Read the type index using compressed size format
    type_index = read_size(deser)
    
    # Read the value (can be any BEVE type)
    value = parse_value(deser)
    
    # Return as a BeveTypeTag struct
    return BEVE.BeveTypeTag(type_index, value)
end

const NUMERIC_MATRIX_HEADERS = UInt8[
    F32_ARRAY, F64_ARRAY,
    I8_ARRAY, I16_ARRAY, I32_ARRAY, I64_ARRAY,
    U8_ARRAY, U16_ARRAY, U32_ARRAY, U64_ARRAY
]

@inline is_numeric_matrix_header(header::UInt8) = header in NUMERIC_MATRIX_HEADERS

function parse_matrix(deser::BeveDeserializer)
    # Per BEVE spec: Matrices have a matrix header byte, extents, and value
    # Layout: HEADER | MATRIX HEADER | EXTENTS | VALUE
    
    matrix_header = read_byte!(deser)
    layout = matrix_header == 0 ? BEVE.LayoutRight : BEVE.LayoutLeft
    
    extents_header = read_byte!(deser)
    extents = parse_matrix_extents(deser, extents_header)

    if any(==(0), extents)
        throw(BeveError("Matrix dimensions cannot be zero"))
    end
    
    value_header = peek_byte!(deser)

    if deser.preserve_matrices
        data = parse_matrix_value(deser, value_header)
        return BEVE.BeveMatrix(layout, extents, data)
    end
    
    if length(extents) == 2
        rows, cols = extents
        if is_numeric_matrix_header(value_header)
            return parse_numeric_matrix(deser, layout, rows, cols, value_header)
        elseif value_header == COMPLEX
            return parse_complex_matrix(deser, layout, rows, cols)
        else
            data = parse_matrix_value(deser, value_header)
            return matrix_from_beve(layout, rows, cols, data)
        end
    else
        data = parse_matrix_value(deser, value_header)
        return BEVE.BeveMatrix(layout, extents, data)
    end
end

function parse_matrix_extents(deser::BeveDeserializer, header::UInt8)
    if header == U8_ARRAY
        return Int.(parse_u8_array(deser))
    elseif header == U16_ARRAY
        return Int.(parse_u16_array(deser))
    elseif header == U32_ARRAY
        return Int.(parse_u32_array(deser))
    elseif header == U64_ARRAY
        return Int.(parse_u64_array(deser))
    elseif header == I8_ARRAY
        return Int.(parse_i8_array(deser))
    elseif header == I16_ARRAY
        return Int.(parse_i16_array(deser))
    elseif header == I32_ARRAY
        return Int.(parse_i32_array(deser))
    elseif header == I64_ARRAY
        return Int.(parse_i64_array(deser))
    else
        throw(BeveError("Matrix extents must be a typed integer array, got: $(header_name(header))"))
    end
end

function parse_numeric_matrix(deser::BeveDeserializer, layout::MatrixLayout, rows::Int, cols::Int, header::UInt8)
    read_byte!(deser)  # consume value header
    count = read_size(deser)
    expected = rows * cols
    if count != expected
        throw(BeveError("Matrix data length $count does not match product of extents $expected"))
    end

    T = matrix_element_type(header)
    T === nothing && throw(BeveError("Unsupported numeric matrix type: $(header_name(header))"))

    if layout == BEVE.LayoutLeft
        matrix = Matrix{T}(undef, rows, cols)
        if count > 0
            GC.@preserve matrix begin
                linear = unsafe_wrap(Vector{T}, pointer(matrix), count; own=false)
                read_array_data!(deser, linear)
            end
        end
        return matrix
    else
        buffer = Vector{T}(undef, count)
        read_array_data!(deser, buffer)
        return matrix_from_beve(BEVE.LayoutRight, rows, cols, buffer)
    end
end

function matrix_element_type(header::UInt8)
    if header == F32_ARRAY
        return Float32
    elseif header == F64_ARRAY
        return Float64
    elseif header == I8_ARRAY
        return Int8
    elseif header == I16_ARRAY
        return Int16
    elseif header == I32_ARRAY
        return Int32
    elseif header == I64_ARRAY
        return Int64
    elseif header == U8_ARRAY
        return UInt8
    elseif header == U16_ARRAY
        return UInt16
    elseif header == U32_ARRAY
        return UInt32
    elseif header == U64_ARRAY
        return UInt64
    else
        return nothing
    end
end

function parse_complex_matrix(deser::BeveDeserializer, layout::MatrixLayout, rows::Int, cols::Int)
    read_byte!(deser)  # consume COMPLEX header
    data = parse_complex(deser)
    if data isa Vector
        return matrix_from_beve(layout, rows, cols, data)
    else
        throw(BeveError("Matrix value must be an array, got single complex number"))
    end
end

function parse_matrix_value(deser::BeveDeserializer, header::UInt8)
    if header == COMPLEX
        read_byte!(deser)
        data = parse_complex(deser)
        if data isa Vector
            return data
        else
            throw(BeveError("Matrix value must be an array, got single complex number"))
        end
    elseif header == BOOL_ARRAY
        read_byte!(deser)
        return parse_bool_array(deser)
    elseif header == F32_ARRAY
        read_byte!(deser)
        return parse_f32_array(deser)
    elseif header == F64_ARRAY
        read_byte!(deser)
        return parse_f64_array(deser)
    elseif header == I8_ARRAY
        read_byte!(deser)
        return parse_i8_array(deser)
    elseif header == I16_ARRAY
        read_byte!(deser)
        return parse_i16_array(deser)
    elseif header == I32_ARRAY
        read_byte!(deser)
        return parse_i32_array(deser)
    elseif header == I64_ARRAY
        read_byte!(deser)
        return parse_i64_array(deser)
    elseif header == U8_ARRAY
        read_byte!(deser)
        return parse_u8_array(deser)
    elseif header == U16_ARRAY
        read_byte!(deser)
        return parse_u16_array(deser)
    elseif header == U32_ARRAY
        read_byte!(deser)
        return parse_u32_array(deser)
    elseif header == U64_ARRAY
        read_byte!(deser)
        return parse_u64_array(deser)
    else
        throw(BeveError("Matrix value must be a typed array of numerical data, got: $(header_name(header))"))
    end
end

function matrix_from_beve(layout::MatrixLayout, rows::Int, cols::Int, data::Vector{T}) where T
    if rows == 0 || cols == 0
        throw(BeveError("Matrix dimensions cannot be zero"))
    end

    total = rows * cols
    if length(data) != total
        throw(BeveError("Matrix data length $(length(data)) does not match product of extents $total"))
    end

    if layout == BEVE.LayoutLeft
        matrix = Matrix{T}(undef, rows, cols)
        if total > 0
            copyto!(matrix, 1, data, 1, total)
        end
        return matrix
    else
        matrix = Matrix{T}(undef, rows, cols)
        idx = 1
        @inbounds for i in 1:rows
            for j in 1:cols
                matrix[i, j] = data[idx]
                idx += 1
            end
        end
        return matrix
    end
end

matrix_from_beve(layout::MatrixLayout, extents::Vector{Int}, data::Vector{T}) where T =
    length(extents) == 2 ? matrix_from_beve(layout, extents[1], extents[2], data) :
    throw(BeveError("Cannot convert matrix with $(length(extents)) dimensions to a 2D Matrix"))

function parse_string_object(deser::BeveDeserializer)::Dict{String, Any}
    size = read_size(deser)
    result = Dict{String, Any}()
    
    for _ in 1:size
        key = read_string_data(deser)
        value = parse_value(deser)
        result[key] = value
    end
    
    return result
end

function parse_integer_object(deser::BeveDeserializer, ::Type{T}) where T <: Integer
    size = read_size(deser)
    result = Dict{T, Any}()
    
    for _ in 1:size
        # Read the integer key based on type
        key = if T == Int8 || T == UInt8
            read(deser.io, T)
        else
            ltoh(read(deser.io, T))
        end
        value = parse_value(deser)
        result[key] = value
    end
    
    return result
end

function parse_bool_array(deser::BeveDeserializer)::Vector{Bool}
    size = read_size(deser)
    byte_count = (size + 7) ÷ 8
    packed_bytes = Vector{UInt8}(undef, byte_count)
    read!(deser.io, packed_bytes)
    
    result = Vector{Bool}(undef, size)
    for i in 1:size
        byte_idx = (i - 1) ÷ 8 + 1
        bit_idx = (i - 1) % 8
        result[i] = (packed_bytes[byte_idx] & (1 << bit_idx)) != 0
    end
    
    return result
end

function parse_string_array(deser::BeveDeserializer)::Vector{String}
    size = read_size(deser)
    result = Vector{String}(undef, size)
    
    for i in 1:size
        result[i] = read_string_data(deser)
    end
    
    return result
end

function parse_f32_array(deser::BeveDeserializer)::Vector{Float32}
    size = read_size(deser)
    result = Vector{Float32}(undef, size)
    read_array_data!(deser, result)
    return result
end

function parse_f64_array(deser::BeveDeserializer)::Vector{Float64}
    size = read_size(deser)
    result = Vector{Float64}(undef, size)
    read_array_data!(deser, result)
    return result
end

function parse_i8_array(deser::BeveDeserializer)::Vector{Int8}
    size = read_size(deser)
    result = Vector{Int8}(undef, size)
    read_array_data!(deser, result)
    return result
end

function parse_i16_array(deser::BeveDeserializer)::Vector{Int16}
    size = read_size(deser)
    result = Vector{Int16}(undef, size)
    read_array_data!(deser, result)
    return result
end

function parse_i32_array(deser::BeveDeserializer)::Vector{Int32}
    size = read_size(deser)
    result = Vector{Int32}(undef, size)
    read_array_data!(deser, result)
    return result
end

function parse_i64_array(deser::BeveDeserializer)::Vector{Int64}
    size = read_size(deser)
    result = Vector{Int64}(undef, size)
    read_array_data!(deser, result)
    return result
end

function parse_u8_array(deser::BeveDeserializer)::Vector{UInt8}
    size = read_size(deser)
    result = Vector{UInt8}(undef, size)
    read_array_data!(deser, result)
    return result
end

function parse_u16_array(deser::BeveDeserializer)::Vector{UInt16}
    size = read_size(deser)
    result = Vector{UInt16}(undef, size)
    read_array_data!(deser, result)
    return result
end

function parse_u32_array(deser::BeveDeserializer)::Vector{UInt32}
    size = read_size(deser)
    result = Vector{UInt32}(undef, size)
    read_array_data!(deser, result)
    return result
end

function parse_u64_array(deser::BeveDeserializer)::Vector{UInt64}
    size = read_size(deser)
    result = Vector{UInt64}(undef, size)
    read_array_data!(deser, result)
    return result
end

function parse_generic_array(deser::BeveDeserializer)::Vector{Any}
    size = read_size(deser)
    result = Vector{Any}(undef, size)
    
    for i in 1:size
        result[i] = parse_value(deser)
    end
    
    return result
end

"""
    from_beve(data::Vector{UInt8}; preserve_matrices::Bool = false) -> Any

Deserializes BEVE binary data back to Julia objects.

## Examples

```julia
julia> data = UInt8[0x03, 0x08, ...]  # Some BEVE binary data

julia> result = from_beve(data)

julia> raw = from_beve(data; preserve_matrices = true)
```
"""
function from_beve(data::Vector{UInt8}; preserve_matrices::Bool = false)
    io = IOBuffer(data)
    deser = BeveDeserializer(io; preserve_matrices = preserve_matrices)
    return parse_value(deser)
end

"""
    read_beve_file(path::AbstractString; preserve_matrices::Bool = false) -> Any

Load a BEVE-encoded file from `path` by first reading it into a contiguous
`Vector{UInt8}` buffer and then deserializing it with `from_beve`.
"""
function read_beve_file(path::AbstractString; preserve_matrices::Bool = false)
    data = read(path)
    return from_beve(data; preserve_matrices = preserve_matrices)
end

"""
    deser_beve_file(::Type{T}, path::AbstractString;
                    error_on_missing_fields::Bool = false,
                    preserve_matrices::Bool = false) -> T

Read and deserialize a BEVE-encoded file directly into the Julia type `T`.
Internally the file is loaded into a contiguous buffer before calling
[`deser_beve`](@ref).
"""
function deser_beve_file(::Type{T}, path::AbstractString;
                         error_on_missing_fields::Bool = false,
                         preserve_matrices::Bool = false) where T
    data = read(path)
    return deser_beve(T, data;
                      error_on_missing_fields = error_on_missing_fields,
                      preserve_matrices = preserve_matrices)
end

"""
    deser_beve(::Type{T}, data::Vector{UInt8};
               error_on_missing_fields::Bool = false,
               preserve_matrices::Bool = false) -> T

Deserializes BEVE binary data into a specific type T.

Leave `error_on_missing_fields` at its default (`false`) to allow reconstruction
of structs even when some serialized fields are missing. This is useful when
fields were intentionally skipped during serialization (for example via
`BEVE.@skip`) and the target type can still be constructed via keyword defaults.
Set it to `true` to enforce strict checking and throw a `BeveError` whenever a
field is missing.

## Examples

```julia
julia> struct Person
           name::String
           age::Int
       end

julia> person_data = from_beve(beve_data)
julia> person = deser_beve(Person, beve_data)
```
"""
function deser_beve(::Type{T}, data::Vector{UInt8};
                    error_on_missing_fields::Bool = false,
                    preserve_matrices::Bool = false) where T
    parsed = from_beve(data; preserve_matrices = preserve_matrices)
    
    # If T is a Dict type and parsed is also a Dict, just convert
    if T <: Dict && parsed isa Dict
        return convert(T, parsed)
    elseif parsed isa Dict{String, Any}
        # Try to reconstruct the struct from the string dictionary
        return reconstruct_struct(T, parsed; error_on_missing_fields)
    elseif parsed isa Dict && T <: Dict
        # Handle integer-keyed dictionaries
        return convert(T, parsed)
    elseif parsed isa Dict
        # If parsed is an integer-keyed dict but T is not a Dict, error
        throw(BeveError("Cannot convert integer-keyed dictionary to type $T"))
    elseif parsed isa BEVE.BeveMatrix && T <: BEVE.BeveMatrix
        return parsed
    else
        return T(parsed)
    end
end

# Helper utilities for struct reconstruction
@inline function coerce_value(::Type{Any}, value; error_on_missing_fields::Bool = false)
    return value
end

function coerce_value(field_type::Type, value; error_on_missing_fields::Bool = false)
    if value isa field_type
        return value
    elseif field_type isa Union
        for subtype in Base.uniontypes(field_type)
            converted = coerce_value(subtype, value; error_on_missing_fields)
            if converted isa subtype
                return converted
            end
        end
        return value
    elseif field_type <: AbstractString
        return string(value)
    elseif field_type <: Number && value isa Number
        return convert(field_type, value)
    elseif field_type <: Dict && value isa Dict
        return convert(field_type, value)
    elseif field_type <: AbstractMatrix
        return reconstruct_matrix(field_type, value; error_on_missing_fields)
    elseif field_type <: AbstractVector && value isa AbstractVector
        return reconstruct_vector(field_type, value; error_on_missing_fields)
    elseif field_type <: Tuple
        return reconstruct_tuple(field_type, value; error_on_missing_fields)
    elseif Base.isstructtype(field_type) && value isa Dict{String, Any}
        # Use try-catch for struct reconstruction since field compatibility
        # cannot be reliably determined without knowing which fields have defaults
        try
            return reconstruct_struct(field_type, value; error_on_missing_fields)
        catch
            return value
        end
    else
        return value
    end
end

function reconstruct_matrix(field_type::Type, value; error_on_missing_fields::Bool = false)
    if value isa field_type
        return value
    elseif value isa BEVE.BeveMatrix
        matrix = matrix_from_beve(value.layout, value.extents, value.data)
        if isconcretetype(field_type)
            try
                return convert(field_type, matrix)
            catch
                return matrix
            end
        else
            return matrix
        end
    elseif value isa AbstractMatrix
        if isconcretetype(field_type)
            try
                return convert(field_type, value)
            catch
                return value
            end
        else
            return value
        end
    else
        return value
    end
end

function reconstruct_vector(field_type::Type, data::AbstractVector; error_on_missing_fields::Bool = false)
    if data isa field_type
        return data
    end

    element_type = eltype(field_type)
    if element_type === Any
        if isconcretetype(field_type)
            try
                return convert(field_type, data)
            catch
                return data
            end
        else
            return data
        end
    end

    result = Vector{element_type}(undef, length(data))
    @inbounds for (idx, item) in enumerate(data)
        result[idx] = coerce_value(element_type, item; error_on_missing_fields)
    end

    if isconcretetype(field_type)
        try
            return convert(field_type, result)
        catch
            return result
        end
    else
        return result
    end
end

function reconstruct_tuple(field_type::Type, value; error_on_missing_fields::Bool = false)
    if value isa field_type
        return value
    elseif value isa Tuple
        if isconcretetype(field_type)
            try
                return convert(field_type, value)
            catch
                return value
            end
        else
            return value
        end
    elseif value isa AbstractVector
        if isconcretetype(field_type)
            element_types = fieldtypes(field_type)
            if !isempty(element_types) && length(element_types) == length(value)
                converted = ntuple(i -> coerce_value(element_types[i], value[i]; error_on_missing_fields = error_on_missing_fields), length(element_types))
                try
                    return convert(field_type, converted)
                catch
                    return converted
                end
            else
                tuple_value = Tuple(value)
                try
                    return convert(field_type, tuple_value)
                catch
                    return tuple_value
                end
            end
        else
            return Tuple(value)
        end
    else
        return value
    end
end

# Optimized struct reconstruction with pre-allocated arrays
function reconstruct_struct(::Type{T}, data::Dict{String, Any}; error_on_missing_fields::Bool = false) where T
    field_names = fieldnames(T)
    field_types = fieldtypes(T)
    num_fields = length(field_names)
    field_values = Vector{Any}(undef, num_fields)
    present = falses(num_fields)
    missing_fields = Symbol[]
    
    @inbounds for i in 1:num_fields
        fname = field_names[i]
        fname_str = string(fname)
        if haskey(data, fname_str)
            field_val = data[fname_str]
            field_type = field_types[i]
            field_values[i] = coerce_value(field_type, field_val; error_on_missing_fields)

            present[i] = true
        else
            if error_on_missing_fields
                throw(BeveError("Missing field: $fname_str for type $T"))
            else
                push!(missing_fields, fname)
            end
        end
    end
    
    if isempty(missing_fields)
        if T <: NamedTuple
            return T(tuple(field_values...))
        else
            return T(field_values...)
        end
    end

    if T <: NamedTuple
        missing_list = join(string.(missing_fields), ", ")
        throw(BeveError("Missing field(s): $missing_list for type $T"))
    end

    present_indices = findall(present)
    try
        return T(; (field_names[idx] => field_values[idx] for idx in present_indices)...)
    catch err
        missing_list = join(string.(missing_fields), ", ")
        throw(BeveError("Missing field(s): $missing_list for type $T and no compatible keyword constructor found. Original error: $(err)"))
    end
end
