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
export to_beve, to_beve!, BeveTypeTag, BeveMatrix, MatrixLayout, LayoutRight, LayoutLeft

# Exports for deserialization  
export from_beve, deser_beve

# Exports for HTTP functionality
export register_object, unregister_object, start_server, BeveHttpClient

include("Headers.jl")
include("Ser.jl")
include("De.jl")
include("Http.jl")

end
