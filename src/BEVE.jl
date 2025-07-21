module BEVE

function deser end
function parse_value end

# Exports for serialization
export to_beve

# Exports for deserialization  
export from_beve, deser_beve

include("Headers.jl")
include("Ser.jl")
include("De.jl")

end
