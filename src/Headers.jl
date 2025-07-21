# BEVE Header Constants
# Based on the BEVE specification v1.0

const NULL = 0x00
const FALSE = 0x08
const TRUE = 0x18

# Brain float and regular floats
const BF16 = 0x01
const F16 = 0x21
const F32 = 0x41
const F64 = 0x61
const F128 = 0x81

# Signed integers
const I8 = 0x09
const I16 = 0x29
const I32 = 0x49
const I64 = 0x69
const I128 = 0x89

# Unsigned integers
const U8 = 0x11
const U16 = 0x31
const U32 = 0x51
const U64 = 0x71
const U128 = 0x91

# Strings
const STRING = 0x02

# Objects with different key types
const STRING_OBJECT = 0x03
const I8_OBJECT = 0x0b
const I16_OBJECT = 0x2b
const I32_OBJECT = 0x4b
const I64_OBJECT = 0x6b
const I128_OBJECT = 0x8b
const U8_OBJECT = 0x13
const U16_OBJECT = 0x33
const U32_OBJECT = 0x53
const U64_OBJECT = 0x73
const U128_OBJECT = 0x93

# Typed arrays
const BF16_ARRAY = 0x04
const F16_ARRAY = 0x24
const F32_ARRAY = 0x44
const F64_ARRAY = 0x64
const F128_ARRAY = 0x84

const I8_ARRAY = 0x0c
const I16_ARRAY = 0x2c
const I32_ARRAY = 0x4c
const I64_ARRAY = 0x6c
const I128_ARRAY = 0x8c

const U8_ARRAY = 0x14
const U16_ARRAY = 0x34
const U32_ARRAY = 0x54
const U64_ARRAY = 0x74
const U128_ARRAY = 0x94

const BOOL_ARRAY = 0x1c
const STRING_ARRAY = 0x3c
const GENERIC_ARRAY = 0x05

# Extensions
const DELIMITER = 0x06
const TAG = 0x0e
const MATRIX = 0x16
const COMPLEX = 0x1e

const RESERVED = 0x07

# Utility functions for headers
function header_name(header::UInt8)
    if header == NULL
        return "null"
    elseif header in (FALSE, TRUE)
        return "boolean"
    elseif header == BF16
        return "brain float"
    elseif header == F16
        return "16-bit float"
    elseif header == F32
        return "32-bit float"
    elseif header == F64
        return "64-bit float"
    elseif header == F128
        return "128-bit float"
    elseif header == I8
        return "8-bit integer"
    elseif header == I16
        return "16-bit integer"
    elseif header == I32
        return "32-bit integer"
    elseif header == I64
        return "64-bit integer"
    elseif header == I128
        return "128-bit integer"
    elseif header == U8
        return "8-bit unsigned integer"
    elseif header == U16
        return "16-bit unsigned integer"
    elseif header == U32
        return "32-bit unsigned integer"
    elseif header == U64
        return "64-bit unsigned integer"
    elseif header == U128
        return "128-bit unsigned integer"
    elseif header == STRING
        return "string"
    elseif header == STRING_OBJECT
        return "string-keyed object"
    elseif header in (I8_OBJECT, I16_OBJECT, I32_OBJECT, I64_OBJECT, I128_OBJECT)
        return "integer-keyed object"
    elseif header in (U8_OBJECT, U16_OBJECT, U32_OBJECT, U64_OBJECT, U128_OBJECT)
        return "unsigned integer-keyed object"
    elseif header in (BF16_ARRAY, F16_ARRAY, F32_ARRAY, F64_ARRAY, F128_ARRAY)
        return "array of floats"
    elseif header in (I8_ARRAY, I16_ARRAY, I32_ARRAY, I64_ARRAY, I128_ARRAY)
        return "array of integers"
    elseif header in (U8_ARRAY, U16_ARRAY, U32_ARRAY, U64_ARRAY, U128_ARRAY)
        return "array of unsigned integers"
    elseif header == BOOL_ARRAY
        return "array of booleans"
    elseif header == STRING_ARRAY
        return "array of strings"
    elseif header == GENERIC_ARRAY
        return "generic array"
    elseif header == DELIMITER
        return "data delimiter"
    elseif header == TAG
        return "type tag"
    elseif header == MATRIX
        return "matrix"
    elseif header == COMPLEX
        return "complex number"
    elseif header == RESERVED
        return "reserved"
    else
        return "unknown type"
    end
end

@enum ArrayKind begin
    GenericArray
    StringArray
    BooleanArray
    I8Array
    I16Array
    I32Array
    I64Array
    I128Array
    U8Array
    U16Array
    U32Array
    U64Array
    U128Array
    BF16Array
    F16Array
    F32Array
    F64Array
    ComplexArray
end

@enum ObjectKind begin
    StringObject
    I8Object
    I16Object
    I32Object
    I64Object
    I128Object
    U8Object
    U16Object
    U32Object
    U64Object
    U128Object
end

function get_array_header(kind::ArrayKind)
    if kind == GenericArray
        return GENERIC_ARRAY
    elseif kind == StringArray
        return STRING_ARRAY
    elseif kind == BooleanArray
        return BOOL_ARRAY
    elseif kind == I8Array
        return I8_ARRAY
    elseif kind == I16Array
        return I16_ARRAY
    elseif kind == I32Array
        return I32_ARRAY
    elseif kind == I64Array
        return I64_ARRAY
    elseif kind == I128Array
        return I128_ARRAY
    elseif kind == U8Array
        return U8_ARRAY
    elseif kind == U16Array
        return U16_ARRAY
    elseif kind == U32Array
        return U32_ARRAY
    elseif kind == U64Array
        return U64_ARRAY
    elseif kind == U128Array
        return U128_ARRAY
    elseif kind == BF16Array
        return BF16_ARRAY
    elseif kind == F16Array
        return F16_ARRAY
    elseif kind == F32Array
        return F32_ARRAY
    elseif kind == F64Array
        return F64_ARRAY
    else
        error("Unsupported array kind: $kind")
    end
end

function get_object_header(kind::ObjectKind)
    if kind == StringObject
        return STRING_OBJECT
    elseif kind == I8Object
        return I8_OBJECT
    elseif kind == I16Object
        return I16_OBJECT
    elseif kind == I32Object
        return I32_OBJECT
    elseif kind == I64Object
        return I64_OBJECT
    elseif kind == I128Object
        return I128_OBJECT
    elseif kind == U8Object
        return U8_OBJECT
    elseif kind == U16Object
        return U16_OBJECT
    elseif kind == U32Object
        return U32_OBJECT
    elseif kind == U64Object
        return U64_OBJECT
    elseif kind == U128Object
        return U128_OBJECT
    else
        error("Unsupported object kind: $kind")
    end
end
