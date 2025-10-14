module BEVE

function deser end
function parse_value end

# Type for representing BEVE type tags (variants)
struct BeveTypeTag
    index::Int
    value::Any
end

# Enum for matrix layout
@enum MatrixLayout begin
    LayoutRight = 0  # row-major
    LayoutLeft = 1   # column-major
end

# Type for representing BEVE matrices
struct BeveMatrix{T}
    layout::MatrixLayout
    extents::Vector{Int}
    data::Vector{T}
    
    function BeveMatrix{T}(layout::MatrixLayout, extents::Vector{Int}, data::Vector{T}) where T
        # Validate that the product of extents matches data length
        expected_size = prod(extents)
        if length(data) != expected_size
            throw(ArgumentError("Matrix data length $(length(data)) does not match product of extents $(expected_size)"))
        end
        # Validate no zero dimensions
        if any(==(0), extents)
            throw(ArgumentError("Matrix dimensions cannot be zero"))
        end
        new{T}(layout, extents, data)
    end
end

# Convenience constructor
BeveMatrix(layout::MatrixLayout, extents::Vector{Int}, data::Vector{T}) where T = BeveMatrix{T}(layout, extents, data)

# Exports for serialization
export to_beve, to_beve!, write_beve_file, BeveTypeTag, BeveMatrix, MatrixLayout, LayoutRight, LayoutLeft, @skip

# Exports for deserialization  
export from_beve, read_beve_file, deser_beve, deser_beve_file

include("Headers.jl")
include("Ser.jl")
include("De.jl")

# HTTP functionality stubs - these will be replaced by the extension when HTTP.jl is loaded
function register_object end
function unregister_object end
function start_server end
function BeveHttpClient end  # Function stub instead of struct

# Export the HTTP functions (they'll only work when HTTP.jl is loaded)
export register_object, unregister_object, start_server, BeveHttpClient

end
