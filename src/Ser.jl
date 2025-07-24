# BEVE Serialization Module

# Serialization interface functions (can be overridden)
(ser_name(::Type{T}, ::Val{x})::Symbol) where {T,x} = x
(ser_value(::Type{T}, ::Val{x}, v::V)::V) where {T,x,V} = v
(ser_type(::Type{T}, v::V)::V) where {T,V} = v
(ser_ignore_field(::Type{T}, ::Val{x})::Bool) where {T,x} = false
(ser_ignore_field(::Type{T}, k::Val{x}, v::V)::Bool) where {T,x,V} = ser_ignore_field(T, k)

mutable struct BeveSerializer
    io::IO
    
    function BeveSerializer(io::IO)
        new(io)
    end
end

# Compressed size encoding as per BEVE spec
function write_size(io::IO, size::Int)
    if size >= 2^62
        error("Size too large: $size")
    end
    
    # Shift left by 2 to make room for size indicator
    encoded_size = size << 2
    
    if encoded_size < 2^6
        # 1 byte
        write(io, UInt8(encoded_size))
    elseif encoded_size < 2^14
        # 2 bytes
        write(io, htol(UInt16(encoded_size | 1)))
    elseif encoded_size < 2^30
        # 4 bytes
        write(io, htol(UInt32(encoded_size | 2)))
    else
        # 8 bytes
        write(io, htol(UInt64(encoded_size | 3)))
    end
end

function write_string_data(io::IO, str::String)
    bytes = Vector{UInt8}(str)
    write_size(io, length(bytes))
    write(io, bytes)
end

function beve_value!(ser::BeveSerializer, val::Nothing)
    write(ser.io, NULL)
end

function beve_value!(ser::BeveSerializer, val::Bool)
    write(ser.io, val ? TRUE : FALSE)
end

function beve_value!(ser::BeveSerializer, val::Int8)
    write(ser.io, I8)
    write(ser.io, htol(val))
end

function beve_value!(ser::BeveSerializer, val::Int16)
    write(ser.io, I16)
    write(ser.io, htol(val))
end

function beve_value!(ser::BeveSerializer, val::Int32)
    write(ser.io, I32)
    write(ser.io, htol(val))
end


function beve_value!(ser::BeveSerializer, val::Int128)
    write(ser.io, I128)
    write(ser.io, htol(val))
end

function beve_value!(ser::BeveSerializer, val::UInt8)
    write(ser.io, U8)
    write(ser.io, val)
end

function beve_value!(ser::BeveSerializer, val::UInt16)
    write(ser.io, U16)
    write(ser.io, htol(val))
end

function beve_value!(ser::BeveSerializer, val::UInt32)
    write(ser.io, U32)
    write(ser.io, htol(val))
end


function beve_value!(ser::BeveSerializer, val::UInt128)
    write(ser.io, U128)
    write(ser.io, htol(val))
end

function beve_value!(ser::BeveSerializer, val::Float32)
    write(ser.io, F32)
    write(ser.io, htol(val))
end

function beve_value!(ser::BeveSerializer, val::Float64)
    write(ser.io, F64)
    write(ser.io, htol(val))
end

# Handle Julia's Int type (which can be Int32 or Int64 depending on platform)
function beve_value!(ser::BeveSerializer, val::Int)
    if sizeof(Int) == 8
        write(ser.io, I64)
        write(ser.io, htol(Int64(val)))
    else
        write(ser.io, I32)
        write(ser.io, htol(Int32(val)))
    end
end

# Handle Julia's UInt type  
function beve_value!(ser::BeveSerializer, val::UInt)
    if sizeof(UInt) == 8
        write(ser.io, U64)
        write(ser.io, htol(UInt64(val)))
    else
        write(ser.io, U32)
        write(ser.io, htol(UInt32(val)))
    end
end

function beve_value!(ser::BeveSerializer, val::String)
    write(ser.io, STRING)
    write_string_data(ser.io, val)
end

function beve_value!(ser::BeveSerializer, val::Symbol)
    beve_value!(ser, string(val))
end

function beve_value!(ser::BeveSerializer, val::AbstractString)
    beve_value!(ser, String(val))
end

# Complex numbers
function beve_value!(ser::BeveSerializer, val::ComplexF32)
    write(ser.io, COMPLEX)
    # Complex header byte per BEVE spec:
    # - Bits 0-2: single/array (0 = single complex number)
    # - Bits 3-4: type (0 = floating point)
    # - Bits 5-7: byte count index (2 = 4 bytes for Float32)
    # Result: 0b010'00'000 = 0x40
    write(ser.io, UInt8(0x40))
    write(ser.io, htol(real(val)))
    write(ser.io, htol(imag(val)))
end

function beve_value!(ser::BeveSerializer, val::ComplexF64)
    write(ser.io, COMPLEX)
    # Complex header byte per BEVE spec:
    # - Bits 0-2: single/array (0 = single complex number)
    # - Bits 3-4: type (0 = floating point)
    # - Bits 5-7: byte count index (3 = 8 bytes for Float64)
    # Result: 0b011'00'000 = 0x60
    write(ser.io, UInt8(0x60))
    write(ser.io, htol(real(val)))
    write(ser.io, htol(imag(val)))
end

function beve_value!(ser::BeveSerializer, val::Complex{T}) where T
    if T == Float32
        beve_value!(ser, ComplexF32(val))
    elseif T == Float64
        beve_value!(ser, ComplexF64(val))
    else
        error("Unsupported complex type: Complex{$T}")
    end
end

# Arrays
function beve_value!(ser::BeveSerializer, val::Vector{Bool})
    write(ser.io, BOOL_ARRAY)
    write_size(ser.io, length(val))
    
    # Pack booleans into bits
    byte_count = (length(val) + 7) ÷ 8
    packed_bytes = zeros(UInt8, byte_count)
    
    for (i, b) in enumerate(val)
        if b
            byte_idx = (i - 1) ÷ 8 + 1
            bit_idx = (i - 1) % 8
            packed_bytes[byte_idx] |= (1 << bit_idx)
        end
    end
    
    write(ser.io, packed_bytes)
end

function beve_value!(ser::BeveSerializer, val::Vector{String})
    write(ser.io, STRING_ARRAY)
    write_size(ser.io, length(val))
    for str in val
        write_string_data(ser.io, str)
    end
end

# Typed numeric arrays
function beve_value!(ser::BeveSerializer, val::Vector{Float32})
    write(ser.io, F32_ARRAY)
    write_size(ser.io, length(val))
    for v in val
        write(ser.io, htol(v))
    end
end

function beve_value!(ser::BeveSerializer, val::Vector{Float64})
    write(ser.io, F64_ARRAY)
    write_size(ser.io, length(val))
    for v in val
        write(ser.io, htol(v))
    end
end

function beve_value!(ser::BeveSerializer, val::Vector{Int8})
    write(ser.io, I8_ARRAY)
    write_size(ser.io, length(val))
    for v in val
        write(ser.io, htol(v))
    end
end

function beve_value!(ser::BeveSerializer, val::Vector{Int16})
    write(ser.io, I16_ARRAY)
    write_size(ser.io, length(val))
    for v in val
        write(ser.io, htol(v))
    end
end

function beve_value!(ser::BeveSerializer, val::Vector{Int32})
    write(ser.io, I32_ARRAY)
    write_size(ser.io, length(val))
    for v in val
        write(ser.io, htol(v))
    end
end

function beve_value!(ser::BeveSerializer, val::Vector{Int64})
    write(ser.io, I64_ARRAY)
    write_size(ser.io, length(val))
    for v in val
        write(ser.io, htol(v))
    end
end

function beve_value!(ser::BeveSerializer, val::Vector{UInt8})
    write(ser.io, U8_ARRAY)
    write_size(ser.io, length(val))
    write(ser.io, val)
end

function beve_value!(ser::BeveSerializer, val::Vector{UInt16})
    write(ser.io, U16_ARRAY)
    write_size(ser.io, length(val))
    for v in val
        write(ser.io, htol(v))
    end
end

function beve_value!(ser::BeveSerializer, val::Vector{UInt32})
    write(ser.io, U32_ARRAY)
    write_size(ser.io, length(val))
    for v in val
        write(ser.io, htol(v))
    end
end

function beve_value!(ser::BeveSerializer, val::Vector{UInt64})
    write(ser.io, U64_ARRAY)
    write_size(ser.io, length(val))
    for v in val
        write(ser.io, htol(v))
    end
end

# Complex arrays
function beve_value!(ser::BeveSerializer, val::Vector{ComplexF32})
    write(ser.io, COMPLEX)
    # Complex header byte per BEVE spec:
    # - Bits 0-2: single/array (1 = complex array)
    # - Bits 3-4: type (0 = floating point)
    # - Bits 5-7: byte count index (2 = 4 bytes for Float32)
    # Result: 0b010'00'001 = 0x41
    write(ser.io, UInt8(0x41))
    write_size(ser.io, length(val))
    for v in val
        write(ser.io, htol(real(v)))
        write(ser.io, htol(imag(v)))
    end
end

function beve_value!(ser::BeveSerializer, val::Vector{ComplexF64})
    write(ser.io, COMPLEX)
    # Complex header byte per BEVE spec:
    # - Bits 0-2: single/array (1 = complex array)
    # - Bits 3-4: type (0 = floating point)
    # - Bits 5-7: byte count index (3 = 8 bytes for Float64)
    # Result: 0b011'00'001 = 0x61
    write(ser.io, UInt8(0x61))
    write_size(ser.io, length(val))
    for v in val
        write(ser.io, htol(real(v)))
        write(ser.io, htol(imag(v)))
    end
end

# Handle generic arrays (mixed types)
function beve_value!(ser::BeveSerializer, val::Vector)
    write(ser.io, GENERIC_ARRAY)
    write_size(ser.io, length(val))
    for item in val
        beve_value!(ser, item)
    end
end

# Handle dictionaries as objects
function beve_value!(ser::BeveSerializer, val::Dict{String, T}) where T
    write(ser.io, STRING_OBJECT)
    write_size(ser.io, length(val))
    for (k, v) in val
        write_string_data(ser.io, k)
        beve_value!(ser, v)
    end
end

# Handle generic dictionaries
function beve_value!(ser::BeveSerializer, val::AbstractDict)
    # Convert to string-keyed dict for now
    string_dict = Dict{String, Any}()
    for (k, v) in val
        string_dict[string(k)] = v
    end
    beve_value!(ser, string_dict)
end

# Handle struct serialization
function beve_value!(ser::BeveSerializer, val::T) where T
    # Check if it's a complex number type first
    if T <: Complex
        if T == ComplexF32 || T == Complex{Float32}
            write(ser.io, COMPLEX)
            # Complex header: single=0, float=0, byte_count=2 (4 bytes) => 0x40
            write(ser.io, UInt8(0x40))
            write(ser.io, htol(Float32(real(val))))
            write(ser.io, htol(Float32(imag(val))))
        elseif T == ComplexF64 || T == Complex{Float64}
            write(ser.io, COMPLEX)
            # Complex header: single=0, float=0, byte_count=3 (8 bytes) => 0x60
            write(ser.io, UInt8(0x60))
            write(ser.io, htol(Float64(real(val))))
            write(ser.io, htol(Float64(imag(val))))
        else
            error("Unsupported complex type: $T")
        end
    elseif !isempty(fieldnames(T))
        # Serialize as a string-keyed object
        write(ser.io, STRING_OBJECT)
        fields = fieldnames(T)
        write_size(ser.io, length(fields))
        
        for field_name in fields
            field_val = getfield(val, field_name)
            # Apply serialization transformations
            key = ser_name(T, Val(field_name))
            value = ser_type(T, ser_value(T, Val(field_name), field_val))
            
            if !ser_ignore_field(T, Val(field_name), value)
                write_string_data(ser.io, string(key))
                beve_value!(ser, value)
            end
        end
    else
        error("Cannot serialize type $T to BEVE")
    end
end

"""
    to_beve([f::Function], data) -> Vector{UInt8}

Serializes any `data` into a BEVE binary format.

## Examples

```julia
julia> struct Person
           name::String
           age::Int
       end

julia> person = Person("Alice", 30)

julia> beve_data = to_beve(person)
```
"""
function to_beve(data)::Vector{UInt8}
    io = IOBuffer()
    ser = BeveSerializer(io)
    beve_value!(ser, data)
    return take!(io)
end

function to_beve(f::Function, data)::Vector{UInt8}
    io = IOBuffer()
    ser = BeveSerializer(io)
    beve_value!(ser, data)
    return take!(io)
end
