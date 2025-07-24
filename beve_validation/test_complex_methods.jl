# Test which method is being called for complex numbers
push!(LOAD_PATH, "../src")
using BEVE

# Check available methods for beve_value!
println("Methods for ComplexF32:")
methods(BEVE.beve_value!, (BEVE.BeveSerializer, ComplexF32))

println("\nMethods for Complex{Float32}:")
methods(BEVE.beve_value!, (BEVE.BeveSerializer, Complex{Float32}))

# Check if Complex has fieldnames
println("\nFieldnames of ComplexF32: ", fieldnames(ComplexF32))
println("Is ComplexF32 empty fieldnames? ", isempty(fieldnames(ComplexF32)))