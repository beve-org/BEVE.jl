# Quick test to debug complex number issue
using Pkg
Pkg.activate("..")
using BEVE

# Test if COMPLEX constant is available
println("COMPLEX constant: ", BEVE.COMPLEX)

# Test complex number serialization
cf = ComplexF32(1.5, 2.5)
println("Serializing ComplexF32: ", cf)
beve_data = to_beve(cf)
println("Serialized to $(length(beve_data)) bytes")
println("Bytes: ", beve_data)

# Test deserialization
result = from_beve(beve_data)
println("Deserialized: ", result)
println("Type: ", typeof(result))