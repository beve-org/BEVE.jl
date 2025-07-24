module BEVE

function deser end
function parse_value end

# Type for representing BEVE type tags (variants)
struct BeveTypeTag
    index::Int
    value::Any
end

# Exports for serialization
export to_beve, BeveTypeTag

# Exports for deserialization  
export from_beve, deser_beve

# Exports for HTTP functionality
export register_object, unregister_object, start_server, BeveHttpClient

include("Headers.jl")
include("Ser.jl")
include("De.jl")
include("Http.jl")

end
