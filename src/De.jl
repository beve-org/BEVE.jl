# BEVE Deserialization Module

mutable struct BeveDeserializer
    io::IO
    peek_byte::Union{Nothing, UInt8}
    
    function BeveDeserializer(io::IO)
        new(io, nothing)
    end
end

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

function read_size(deser::BeveDeserializer)::Int
    first = read_byte!(deser)
    n_bytes = 2^(first & 0b11)
    
    if n_bytes == 1
        return Int(first >> 2)
    end
    
    # Read the remaining bytes
    remaining = n_bytes - 1
    bytes = zeros(UInt8, 8)  # Maximum size for UInt64
    bytes[1] = first
    
    if remaining > 7
        throw(BeveError("Size too large"))
    end
    
    read!(deser.io, @view bytes[2:remaining+1])
    
    if sizeof(Int) == 8
        size_val = ltoh(reinterpret(UInt64, bytes)[1]) >> 2
    else
        size_val = ltoh(reinterpret(UInt32, bytes[1:4])[1]) >> 2
    end
    
    return Int(size_val)
end

function read_string_data(deser::BeveDeserializer)::String
    size = read_size(deser)
    bytes = Vector{UInt8}(undef, size)
    read!(deser.io, bytes)
    return String(bytes)
end

function parse_value(deser::BeveDeserializer)
    header = read_byte!(deser)
    
    if header == NULL
        return nothing
    elseif header == FALSE
        return false
    elseif header == TRUE
        return true
    elseif header == I8
        return ltoh(read(deser.io, Int8))
    elseif header == I16
        return ltoh(read(deser.io, Int16))
    elseif header == I32
        return ltoh(read(deser.io, Int32))
    elseif header == I64
        return ltoh(read(deser.io, Int64))
    elseif header == I128
        return ltoh(read(deser.io, Int128))
    elseif header == U8
        return read(deser.io, UInt8)
    elseif header == U16
        return ltoh(read(deser.io, UInt16))
    elseif header == U32
        return ltoh(read(deser.io, UInt32))
    elseif header == U64
        return ltoh(read(deser.io, UInt64))
    elseif header == U128
        return ltoh(read(deser.io, UInt128))
    elseif header == F32
        return ltoh(read(deser.io, Float32))
    elseif header == F64
        return ltoh(read(deser.io, Float64))
    elseif header == STRING
        return read_string_data(deser)
    elseif header == STRING_OBJECT
        return parse_string_object(deser)
    elseif header == BOOL_ARRAY
        return parse_bool_array(deser)
    elseif header == STRING_ARRAY
        return parse_string_array(deser)
    elseif header == F32_ARRAY
        return parse_f32_array(deser)
    elseif header == F64_ARRAY
        return parse_f64_array(deser)
    elseif header == I8_ARRAY
        return parse_i8_array(deser)
    elseif header == I16_ARRAY
        return parse_i16_array(deser)
    elseif header == I32_ARRAY
        return parse_i32_array(deser)
    elseif header == I64_ARRAY
        return parse_i64_array(deser)
    elseif header == U8_ARRAY
        return parse_u8_array(deser)
    elseif header == U16_ARRAY
        return parse_u16_array(deser)
    elseif header == U32_ARRAY
        return parse_u32_array(deser)
    elseif header == U64_ARRAY
        return parse_u64_array(deser)
    elseif header == GENERIC_ARRAY
        return parse_generic_array(deser)
    elseif header == COMPLEX
        return parse_complex(deser)
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
            for i in 1:size
                real = ltoh(read(deser.io, Float32))
                imag = ltoh(read(deser.io, Float32))
                result[i] = ComplexF32(real, imag)
            end
            return result
        else  # byte_count == 8
            result = Vector{ComplexF64}(undef, size)
            for i in 1:size
                real = ltoh(read(deser.io, Float64))
                imag = ltoh(read(deser.io, Float64))
                result[i] = ComplexF64(real, imag)
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
    
    for i in 1:size
        result[i] = ltoh(read(deser.io, Float32))
    end
    
    return result
end

function parse_f64_array(deser::BeveDeserializer)::Vector{Float64}
    size = read_size(deser)
    result = Vector{Float64}(undef, size)
    
    for i in 1:size
        result[i] = ltoh(read(deser.io, Float64))
    end
    
    return result
end

function parse_i8_array(deser::BeveDeserializer)::Vector{Int8}
    size = read_size(deser)
    result = Vector{Int8}(undef, size)
    
    for i in 1:size
        result[i] = read(deser.io, Int8)
    end
    
    return result
end

function parse_i16_array(deser::BeveDeserializer)::Vector{Int16}
    size = read_size(deser)
    result = Vector{Int16}(undef, size)
    
    for i in 1:size
        result[i] = ltoh(read(deser.io, Int16))
    end
    
    return result
end

function parse_i32_array(deser::BeveDeserializer)::Vector{Int32}
    size = read_size(deser)
    result = Vector{Int32}(undef, size)
    
    for i in 1:size
        result[i] = ltoh(read(deser.io, Int32))
    end
    
    return result
end

function parse_i64_array(deser::BeveDeserializer)::Vector{Int64}
    size = read_size(deser)
    result = Vector{Int64}(undef, size)
    
    for i in 1:size
        result[i] = ltoh(read(deser.io, Int64))
    end
    
    return result
end

function parse_u8_array(deser::BeveDeserializer)::Vector{UInt8}
    size = read_size(deser)
    result = Vector{UInt8}(undef, size)
    read!(deser.io, result)
    return result
end

function parse_u16_array(deser::BeveDeserializer)::Vector{UInt16}
    size = read_size(deser)
    result = Vector{UInt16}(undef, size)
    
    for i in 1:size
        result[i] = ltoh(read(deser.io, UInt16))
    end
    
    return result
end

function parse_u32_array(deser::BeveDeserializer)::Vector{UInt32}
    size = read_size(deser)
    result = Vector{UInt32}(undef, size)
    
    for i in 1:size
        result[i] = ltoh(read(deser.io, UInt32))
    end
    
    return result
end

function parse_u64_array(deser::BeveDeserializer)::Vector{UInt64}
    size = read_size(deser)
    result = Vector{UInt64}(undef, size)
    
    for i in 1:size
        result[i] = ltoh(read(deser.io, UInt64))
    end
    
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
    from_beve(data::Vector{UInt8}) -> Any

Deserializes BEVE binary data back to Julia objects.

## Examples

```julia
julia> data = UInt8[0x03, 0x08, ...]  # Some BEVE binary data

julia> result = from_beve(data)
```
"""
function from_beve(data::Vector{UInt8})
    io = IOBuffer(data)
    deser = BeveDeserializer(io)
    return parse_value(deser)
end

"""
    deser_beve(::Type{T}, data::Vector{UInt8}) -> T

Deserializes BEVE binary data into a specific type T.

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
function deser_beve(::Type{T}, data::Vector{UInt8}) where T
    parsed = from_beve(data)
    
    if parsed isa Dict{String, Any}
        # Try to reconstruct the struct from the dictionary
        return reconstruct_struct(T, parsed)
    else
        return T(parsed)
    end
end

function reconstruct_struct(::Type{T}, data::Dict{String, Any}) where T
    field_names = fieldnames(T)
    field_types = fieldtypes(T)
    field_values = []
    
    for (i, fname) in enumerate(field_names)
        fname_str = string(fname)
        if haskey(data, fname_str)
            field_val = data[fname_str]
            field_type = field_types[i]
            
            # Convert if necessary
            if !(field_val isa field_type)
                if field_type <: AbstractString
                    push!(field_values, string(field_val))
                elseif field_type <: Number
                    push!(field_values, field_type(field_val))
                elseif field_val isa Dict{String, Any} && !isempty(fieldnames(field_type))
                    # Recursively reconstruct nested struct
                    push!(field_values, reconstruct_struct(field_type, field_val))
                else
                    push!(field_values, field_val)
                end
            else
                push!(field_values, field_val)
            end
        else
            throw(BeveError("Missing field: $fname_str for type $T"))
        end
    end
    
    return T(field_values...)
end
