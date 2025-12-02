using Test
using BEVE

@testset "BEVE.jl" begin
    @testset "File Helpers" begin
        sample = Dict("message" => "hello", "values" => [1, 2, 3])
        struct FilePerson
            name::String
            age::Int
        end

        struct MissingField
            a::Int
            b::Int
        end

        mktempdir() do tmp
            path = joinpath(tmp, "sample.beve")

            bytes = write_beve_file(path, sample)
            @test read(path) == bytes
            @test bytes == to_beve(sample)
            @test read_beve_file(path) == sample

            matrix = Float32[1 2; 3 4]
            reuse_buffer = IOBuffer()
            matrix_path = joinpath(tmp, "matrix.beve")
            matrix_bytes = write_beve_file(matrix_path, matrix; buffer = reuse_buffer)
            @test matrix_bytes == to_beve(matrix)
            @test read_beve_file(matrix_path) == matrix

            preserved = read_beve_file(matrix_path; preserve_matrices = true)
            @test preserved isa BEVE.BeveMatrix{Float32}
            @test preserved.layout == BEVE.LayoutLeft
            @test preserved.extents == [2, 2]
            @test preserved.data == vec(matrix)

            person = FilePerson("Ada", 37)
            person_path = joinpath(tmp, "person.beve")
            write_beve_file(person_path, person)
            @test deser_beve_file(FilePerson, person_path) == person

            matrix_raw = deser_beve_file(BEVE.BeveMatrix{Float32}, matrix_path; preserve_matrices = true)
            @test matrix_raw isa BEVE.BeveMatrix{Float32}
            @test matrix_raw.layout == preserved.layout
            @test matrix_raw.extents == preserved.extents
            @test matrix_raw.data == preserved.data

            dict_path = joinpath(tmp, "missing.beve")
            write(dict_path, to_beve(Dict("a" => 1)))
            @test_throws BEVE.BeveError deser_beve_file(MissingField, dict_path; error_on_missing_fields = true)
    end
    end

    @testset "Tuple Serialization" begin
        float_tuple = (1.5, 2.5)
        tuple_bytes = to_beve(float_tuple)
        @test from_beve(tuple_bytes) == Any[1.5, 2.5]
        @test deser_beve(Tuple{Float64, Float64}, tuple_bytes) == float_tuple

        struct TupleWrapper
            coords::Tuple{Float64, Float64}
            label::String
        end

        wrapped = TupleWrapper((3.0, 4.0), "pos")
        roundtrip = deser_beve(TupleWrapper, to_beve(wrapped))
        @test roundtrip.label == wrapped.label
        @test roundtrip.coords == wrapped.coords

        struct NTupleHolder
            data::NTuple{2, Float64}
        end

        holder = NTupleHolder((7.0, 9.0))
        parsed_holder = deser_beve(NTupleHolder, to_beve(holder))
        @test parsed_holder.data == holder.data

        named_tuple = (x = 11.0, y = 13.0)
        named_bytes = to_beve(named_tuple)
        @test from_beve(named_bytes) == Dict("x" => 11.0, "y" => 13.0)
        @test deser_beve(NamedTuple{(:x, :y), Tuple{Float64, Float64}}, named_bytes) == named_tuple

        struct NamedTupleHolder
            point::NamedTuple{(:x, :y), Tuple{Float64, Float64}}
        end

        holder = NamedTupleHolder((x = 2.0, y = 5.0))
        @test deser_beve(NamedTupleHolder, to_beve(holder)) == holder
    end

    @testset "Zstd Helpers" begin
        codec_available = try
            Base.require(Base.PkgId(Base.UUID("6b39b394-51ab-5f42-8807-6242bab2b4c2"), "CodecZstd"))
            true
        catch err
            @info "Skipping Zstd tests: CodecZstd not available" exception = err
            false
        end
        codec_available || return

        sample = Dict("message" => "hello", "values" => [1, 2, 3])
        compressed = to_beve_zstd(sample)
        @test from_beve_zstd(compressed) == sample

        matrix = Float32[1 2; 3 4]
        buffer = IOBuffer()
        compressed_matrix = to_beve_zstd(matrix; buffer = buffer, level = 7)
        restored = from_beve_zstd(compressed_matrix; preserve_matrices = true)
        @test restored isa BEVE.BeveMatrix{Float32}
        @test restored.layout == BEVE.LayoutLeft
        @test restored.extents == [2, 2]
        @test restored.data == vec(matrix)

        struct ZstdPerson
            name::String
            age::Int
        end

        person = ZstdPerson("Ada", 37)
        person_bytes = to_beve_zstd(person)
        @test deser_beve_zstd(ZstdPerson, person_bytes) == person

        mktempdir() do tmp
            path = joinpath(tmp, "sample.beve.zst")
            bytes = write_beve_zstd_file(path, sample)
            @test endswith(path, ".beve.zst")
            @test read(path) == bytes
            @test read_beve_zstd_file(path) == sample

            matrix_path = joinpath(tmp, "matrix.beve.zst")
            matrix_bytes = write_beve_zstd_file(matrix_path, matrix; buffer = buffer)
            @test matrix_bytes == compressed_matrix
            matrix_restored = read_beve_zstd_file(matrix_path; preserve_matrices = true)
            @test matrix_restored.layout == restored.layout
            @test matrix_restored.data == restored.data

            person_path = joinpath(tmp, "person.beve.zst")
            write_beve_zstd_file(person_path, person)
            @test deser_beve_zstd_file(ZstdPerson, person_path) == person
            @test deser_beve_zstd_file(BEVE.BeveMatrix{Float32}, matrix_path;
                                       preserve_matrices = true).data == restored.data
        end
    end

    @testset "Basic Types" begin
        # Test null
        data = to_beve(nothing)
        @test from_beve(data) === nothing
        
        # Test booleans
        @test from_beve(to_beve(true)) === true
        @test from_beve(to_beve(false)) === false
        
        # Test integers
        @test from_beve(to_beve(Int8(42))) === Int8(42)
        @test from_beve(to_beve(Int16(1000))) === Int16(1000)
        @test from_beve(to_beve(Int32(100000))) === Int32(100000)
        @test from_beve(to_beve(Int64(1000000000))) === Int64(1000000000)
        
        # Test unsigned integers
        @test from_beve(to_beve(UInt8(255))) === UInt8(255)
        @test from_beve(to_beve(UInt16(65535))) === UInt16(65535)
        @test from_beve(to_beve(UInt32(4294967295))) === UInt32(4294967295)
        
        # Test floats
        @test from_beve(to_beve(Float32(3.14))) ≈ Float32(3.14)
        @test from_beve(to_beve(Float64(3.14159))) ≈ Float64(3.14159)
        
        # Test strings
        @test from_beve(to_beve("Hello, World!")) == "Hello, World!"
        @test from_beve(to_beve("")) == ""
    end
    
    @testset "Arrays" begin
        # Test boolean arrays
        bool_array = [true, false, true, false]
        @test from_beve(to_beve(bool_array)) == bool_array
        
        # Test string arrays
        str_array = ["hello", "world", "test"]
        @test from_beve(to_beve(str_array)) == str_array
        
        # Test numeric arrays
        int_array = Int32[1, 2, 3, 4, 5]
        @test from_beve(to_beve(int_array)) == int_array
        
        float_array = Float64[1.1, 2.2, 3.3]
        @test from_beve(to_beve(float_array)) ≈ float_array
        
        # Test generic arrays
        generic_array = Any[1, "hello", true, 3.14]
        result = from_beve(to_beve(generic_array))
        @test length(result) == length(generic_array)
        @test result[1] == 1
        @test result[2] == "hello" 
        @test result[3] == true
        @test result[4] ≈ 3.14
    end

    @testset "Matrices" begin
        @testset "Column-major defaults" begin
            matrix = Float32[1 2 3; 4 5 6]
            bytes = to_beve(matrix)
            parsed = from_beve(bytes)
            @test parsed isa Matrix{Float32}
            @test parsed == matrix

            raw = from_beve(bytes; preserve_matrices = true)
            @test raw isa BEVE.BeveMatrix
            @test raw.layout == BEVE.LayoutLeft
            @test raw.extents == [2, 3]
            @test raw.data == vec(matrix)

            raw_again = deser_beve(BEVE.BeveMatrix{Float32}, bytes; preserve_matrices = true)
            @test raw_again isa BEVE.BeveMatrix{Float32}
            @test raw_again.data == vec(matrix)
        end

        @testset "Numeric element types" begin
            int_matrix = reshape(Int32(1):Int32(6), 2, 3)
            @test from_beve(to_beve(int_matrix)) == int_matrix

            uint_matrix = reshape(UInt16(1):UInt16(9), 3, 3)
            parsed_uint = from_beve(to_beve(uint_matrix))
            @test parsed_uint isa Matrix{UInt16}
            @test parsed_uint == uint_matrix

            float_matrix = reshape(Float64(1):Float64(9), 3, 3)
            @test from_beve(to_beve(float_matrix)) == float_matrix
        end

        @testset "Row-major roundtrip" begin
            expected = Float64[1 2 3; 4 5 6]
            row_major = BEVE.BeveMatrix(BEVE.LayoutRight, [2, 3], Float64[1, 2, 3, 4, 5, 6])
            parsed_row = from_beve(to_beve(row_major))
            @test parsed_row isa Matrix{Float64}
            @test parsed_row == expected
        end

        @testset "Complex matrices" begin
            complex_matrix = ComplexF64[ComplexF64(i, -i) for i in 1:6]
            complex_matrix = reshape(complex_matrix, 2, 3)
            parsed_complex = from_beve(to_beve(complex_matrix))
            @test parsed_complex isa Matrix{ComplexF64}
            @test parsed_complex == complex_matrix

            raw_complex = from_beve(to_beve(complex_matrix); preserve_matrices = true)
            @test raw_complex isa BEVE.BeveMatrix{ComplexF64}
            @test raw_complex.data == vec(complex_matrix)
        end

        @testset "Strided and view matrices" begin
            base = reshape(Float32.(1:12), 3, 4)
            view_matrix = @view base[:, 1:2:4]
            parsed_view = from_beve(to_beve(view_matrix))
            @test parsed_view isa Matrix{Float32}
            @test parsed_view == Matrix(view_matrix)

            permuted = permutedims(base)
            parsed_permuted = from_beve(to_beve(permuted))
            @test parsed_permuted == Matrix(permuted)
        end

        @testset "Struct reconstruction" begin
            struct MatrixHolder
                weights::Matrix{Float64}
                grads::Matrix{Float32}
            end

            holder = MatrixHolder([1.0 2.0; 3.0 4.0], Float32[0.1 0.2; 0.3 0.4])
            roundtrip_holder = deser_beve(MatrixHolder, to_beve(holder))
            @test roundtrip_holder.weights == holder.weights
            @test roundtrip_holder.grads == holder.grads

            struct NestedContainer
                items::Vector{Matrix{Float32}}
                stats::Dict{String, Matrix{Int}}
            end

            nested = NestedContainer(
                [Float32[1 2; 3 4], Float32[5 6; 7 8]],
                Dict("ones" => ones(Int, 2, 2), "identity" => [1 0; 0 1])
            )

            parsed_nested = deser_beve(NestedContainer, to_beve(nested))
            @test parsed_nested.items == nested.items
            @test parsed_nested.stats == nested.stats
        end

        @testset "Higher-dimensional remains raw" begin
            tensor = BEVE.BeveMatrix(BEVE.LayoutLeft, [2, 2, 2], Float32[1, 2, 3, 4, 5, 6, 7, 8])
            parsed_tensor = from_beve(to_beve(tensor))
            @test parsed_tensor isa BEVE.BeveMatrix
            @test parsed_tensor.extents == [2, 2, 2]
        end
    end

    @testset "SubArray Support" begin
        int_data = collect(1:6)
        int_view = @view int_data[2:5]
        @test from_beve(to_beve(int_view)) == collect(int_view)

        bool_data = Bool[true, false, true, true, false, false]
        bool_view = @view bool_data[1:4]
        @test from_beve(to_beve(bool_view)) == collect(bool_view)

        str_data = ["alpha", "beta", "gamma", "delta"]
        str_view = @view str_data[2:4]
        @test from_beve(to_beve(str_view)) == collect(str_view)
    end

    @testset "Struct With SubArray" begin
        struct SubArrayHolder
            label::String
            slice::SubArray{Int, 1, Vector{Int}, Tuple{UnitRange{Int}}, true}
        end

        base_data = collect(10:20)
        data_view = @view base_data[3:8]
        holder = SubArrayHolder("numbers", data_view)

        roundtrip = from_beve(to_beve(holder))
        @test roundtrip["label"] == "numbers"
        @test roundtrip["slice"] == collect(data_view)
    end

    @testset "Objects" begin
        # Test dictionary
        dict = Dict("name" => "Alice", "age" => 30, "active" => true)
        result = from_beve(to_beve(dict))
        @test result["name"] == "Alice"
        @test result["age"] == 30
        @test result["active"] == true
    end
    
    @testset "Structs" begin
        struct Person
            name::String
            age::Int
        end
        
        person = Person("Bob", 25)
        beve_data = to_beve(person)
        parsed = from_beve(beve_data)
        
        @test parsed isa Dict{String, Any}
        @test parsed["name"] == "Bob"
        @test parsed["age"] == 25
        
        # Test reconstruction
        reconstructed = deser_beve(Person, beve_data)
        @test reconstructed.name == person.name
        @test reconstructed.age == person.age
    end

    @testset "Struct Field Skipping" begin
        Base.@kwdef struct Credentials
            username::String
            password::String = ""
            token::Union{String, Nothing} = nothing
        end

        BEVE.@skip Credentials password

        function BEVE.skip(::Type{Credentials}, ::Val{:token}, value)
            return value === nothing
        end

        credentials = Credentials("alice", "secret", "abc123")
        parsed_credentials = from_beve(to_beve(credentials))

        @test parsed_credentials isa Dict{String, Any}
        @test parsed_credentials["username"] == "alice"
        @test !haskey(parsed_credentials, "password")
        @test parsed_credentials["token"] == "abc123"

        beve_credentials = to_beve(credentials)
        reconstructed_credentials = deser_beve(Credentials, beve_credentials)
        @test reconstructed_credentials.username == "alice"
        @test reconstructed_credentials.password == ""
        @test reconstructed_credentials.token == "abc123"

        @test_throws BEVE.BeveError deser_beve(Credentials, beve_credentials; error_on_missing_fields = true)

        credentials_without_token = Credentials("bob", "hidden", nothing)
        parsed_without_token = from_beve(to_beve(credentials_without_token))

        @test parsed_without_token isa Dict{String, Any}
        @test parsed_without_token["username"] == "bob"
        @test !haskey(parsed_without_token, "password")
        @test !haskey(parsed_without_token, "token")
        @test length(parsed_without_token) == 1

        beve_without_token = to_beve(credentials_without_token)
        roundtrip_without_token = deser_beve(Credentials, beve_without_token)
        @test roundtrip_without_token.username == "bob"
        @test roundtrip_without_token.password == ""
        @test roundtrip_without_token.token === nothing
        @test_throws BEVE.BeveError deser_beve(Credentials, beve_without_token; error_on_missing_fields = true)
    end

    @testset "Multiple Field Skipping" begin
        Base.@kwdef struct Secrets
            public_id::Int
            api_key::String = ""
            private_notes::String = ""
            created_at::String
        end

        BEVE.@skip Secrets api_key private_notes

        secrets = Secrets(101, "API-XYZ", "internal", "2024-01-01")
        parsed_secrets = from_beve(to_beve(secrets))

        @test parsed_secrets isa Dict{String, Any}
        @test parsed_secrets["public_id"] == 101
        @test parsed_secrets["created_at"] == "2024-01-01"
        @test !haskey(parsed_secrets, "api_key")
        @test !haskey(parsed_secrets, "private_notes")
        @test length(parsed_secrets) == 2

        beve_secrets = to_beve(secrets)
        reconstructed_secrets = deser_beve(Secrets, beve_secrets)
        @test reconstructed_secrets.public_id == 101
        @test reconstructed_secrets.api_key == ""
        @test reconstructed_secrets.private_notes == ""
        @test reconstructed_secrets.created_at == "2024-01-01"
        @test_throws BEVE.BeveError deser_beve(Secrets, beve_secrets; error_on_missing_fields = true)
    end
    
    @testset "Complex Nested Structs" begin
        # Define nested struct types
        struct Address
            street::String
            city::String
            zipcode::String
        end
        
        struct Contact
            email::String
            phone::String
        end
        
        struct Employee
            name::String
            age::Int
            salary::Float64
            address::Address
            contact::Contact
            active::Bool
        end
        
        # Create nested data
        address = Address("123 Main St", "New York", "10001")
        contact = Contact("john@example.com", "555-1234")
        employee = Employee("John Doe", 30, 75000.0, address, contact, true)
        
        # Test serialization and deserialization
        beve_data = to_beve(employee)
        parsed = from_beve(beve_data)
        
        @test parsed isa Dict{String, Any}
        @test parsed["name"] == "John Doe"
        @test parsed["age"] == 30
        @test parsed["salary"] ≈ 75000.0
        @test parsed["active"] == true
        
        # Test nested address
        @test parsed["address"] isa Dict{String, Any}
        @test parsed["address"]["street"] == "123 Main St"
        @test parsed["address"]["city"] == "New York"
        @test parsed["address"]["zipcode"] == "10001"
        
        # Test nested contact
        @test parsed["contact"] isa Dict{String, Any}
        @test parsed["contact"]["email"] == "john@example.com"
        @test parsed["contact"]["phone"] == "555-1234"
        
        # Test full reconstruction
        reconstructed = deser_beve(Employee, beve_data)
        @test reconstructed.name == employee.name
        @test reconstructed.age == employee.age
        @test reconstructed.salary ≈ employee.salary
        @test reconstructed.active == employee.active
        @test reconstructed.address.street == employee.address.street
        @test reconstructed.address.city == employee.address.city
        @test reconstructed.address.zipcode == employee.address.zipcode
        @test reconstructed.contact.email == employee.contact.email
        @test reconstructed.contact.phone == employee.contact.phone
    end
    
    @testset "Arrays of Structs" begin
        struct Product
            id::Int
            name::String
            price::Float64
            in_stock::Bool
        end
        
        products = [
            Product(1, "Laptop", 999.99, true),
            Product(2, "Mouse", 25.50, false),
            Product(3, "Keyboard", 75.00, true)
        ]
        
        # Test array of structs
        beve_data = to_beve(products)
        parsed = from_beve(beve_data)
        
        @test parsed isa Vector{Any}
        @test length(parsed) == 3
        
        # Check first product
        @test parsed[1] isa Dict{String, Any}
        @test parsed[1]["id"] == 1
        @test parsed[1]["name"] == "Laptop"
        @test parsed[1]["price"] ≈ 999.99
        @test parsed[1]["in_stock"] == true
        
        # Check second product
        @test parsed[2]["id"] == 2
        @test parsed[2]["name"] == "Mouse"
        @test parsed[2]["price"] ≈ 25.50
        @test parsed[2]["in_stock"] == false
    end
    
    @testset "Deeply Nested Structures" begin
        struct Point
            x::Float64
            y::Float64
        end
        
        struct Shape
            name::String
            center::Point
            vertices::Vector{Point}
        end
        
        struct Drawing
            title::String
            shapes::Vector{Shape}
            metadata::Dict{String, Any}
        end
        
        # Create deeply nested structure
        triangle = Shape("triangle", 
                        Point(0.0, 0.0),
                        [Point(-1.0, -1.0), Point(1.0, -1.0), Point(0.0, 1.0)])
        
        square = Shape("square",
                      Point(5.0, 5.0),
                      [Point(4.0, 4.0), Point(6.0, 4.0), Point(6.0, 6.0), Point(4.0, 6.0)])
        
        drawing = Drawing("My Drawing", 
                         [triangle, square],
                         Dict("author" => "Alice", "version" => 1, "scale" => 2.5))
        
        # Test serialization and deserialization
        beve_data = to_beve(drawing)
        parsed = from_beve(beve_data)
        
        @test parsed isa Dict{String, Any}
        @test parsed["title"] == "My Drawing"
        @test parsed["shapes"] isa Vector{Any}
        @test length(parsed["shapes"]) == 2
        
        # Check triangle
        triangle_parsed = parsed["shapes"][1]
        @test triangle_parsed["name"] == "triangle"
        @test triangle_parsed["center"] isa Dict{String, Any}
        @test triangle_parsed["center"]["x"] ≈ 0.0
        @test triangle_parsed["center"]["y"] ≈ 0.0
        @test triangle_parsed["vertices"] isa Vector{Any}
        @test length(triangle_parsed["vertices"]) == 3
        @test triangle_parsed["vertices"][1]["x"] ≈ -1.0
        @test triangle_parsed["vertices"][1]["y"] ≈ -1.0
        
        # Check metadata
        @test parsed["metadata"] isa Dict{String, Any}
        @test parsed["metadata"]["author"] == "Alice"
        @test parsed["metadata"]["version"] == 1
        @test parsed["metadata"]["scale"] ≈ 2.5
        
        # Test partial reconstruction (just Point)
        point_data = to_beve(Point(3.14, 2.71))
        reconstructed_point = deser_beve(Point, point_data)
        @test reconstructed_point.x ≈ 3.14
        @test reconstructed_point.y ≈ 2.71
    end
    
    @testset "Mixed Container Types" begin
        struct User
            id::Int
            name::String
            tags::Vector{String}
        end
        
        struct Team
            name::String
            members::Vector{User}
            settings::Dict{String, Any}
        end
        
        # Create mixed structure
        users = [
            User(1, "Alice", ["admin", "developer"]),
            User(2, "Bob", ["developer", "tester"]),
            User(3, "Charlie", ["manager"])
        ]
        
        team = Team("Development Team", 
                   users,
                   Dict("max_members" => 10, 
                        "public" => true,
                        "created_date" => "2024-01-01"))
        
        # Test serialization and deserialization
        beve_data = to_beve(team)
        parsed = from_beve(beve_data)
        
        @test parsed isa Dict{String, Any}
        @test parsed["name"] == "Development Team"
        @test parsed["members"] isa Vector{Any}
        @test length(parsed["members"]) == 3
        
        # Check first member
        alice = parsed["members"][1]
        @test alice["id"] == 1
        @test alice["name"] == "Alice"
        @test alice["tags"] isa Vector{String}
        @test alice["tags"] == ["admin", "developer"]
        
        # Check settings
        @test parsed["settings"] isa Dict{String, Any}
        @test parsed["settings"]["max_members"] == 10
        @test parsed["settings"]["public"] == true
        @test parsed["settings"]["created_date"] == "2024-01-01"

        # Ensure struct reconstruction succeeds
        reconstructed_team = deser_beve(Team, beve_data)
        @test reconstructed_team.name == team.name
        @test reconstructed_team.settings == team.settings
        @test length(reconstructed_team.members) == length(team.members)
        @test all(m isa User for m in reconstructed_team.members)
        @test reconstructed_team.members[1].name == team.members[1].name
        @test reconstructed_team.members[1].tags == team.members[1].tags
    end

    @testset "Struct Reconstruction" begin
        struct Measurement
            value::Float64
            unit::String
        end

        struct SensorReading
            id::Int
            readings::Vector{Measurement}
        end

        struct Panel
            label::String
            sensors::Vector{SensorReading}
            notes::Vector{Union{String, Nothing}}
        end

        sensor_data = [
            SensorReading(1, [Measurement(21.5, "C"), Measurement(22.0, "C")]),
            SensorReading(2, [Measurement(55.0, "%"), Measurement(54.5, "%")])
        ]
        panel = Panel("Env Monitor", sensor_data, ["calibrated", nothing, "online"])

        reconstructed_panel = deser_beve(Panel, to_beve(panel))
        @test reconstructed_panel.label == panel.label
        @test length(reconstructed_panel.sensors) == length(sensor_data)
        @test reconstructed_panel.sensors[1].id == sensor_data[1].id
        @test reconstructed_panel.sensors[1].readings[1].value ≈ sensor_data[1].readings[1].value
        @test reconstructed_panel.notes == panel.notes

        struct Payload
            name::String
            payload::Union{Nothing, Vector{Measurement}}
        end

        payload_with_data = Payload("sensor_payload", [Measurement(1.0, "V"), Measurement(2.0, "V")])
        payload_none = Payload("empty_payload", nothing)

        roundtrip_payload = deser_beve(Payload, to_beve(payload_with_data))
        @test roundtrip_payload.name == payload_with_data.name
        @test length(roundtrip_payload.payload) == length(payload_with_data.payload)
        @test roundtrip_payload.payload[2].value ≈ payload_with_data.payload[2].value

        roundtrip_payload_none = deser_beve(Payload, to_beve(payload_none))
        @test roundtrip_payload_none.name == payload_none.name
        @test roundtrip_payload_none.payload === nothing

        struct Grid
            name::String
            rows::Vector{Vector{Int}}
            columns::Vector{String}
        end

        grid = Grid(
            "heatmap",
            [[1, 2, 3], [4, 5, 6], [7, 8, 9]],
            ["X", "Y", "Z"]
        )

        reconstructed_grid = deser_beve(Grid, to_beve(grid))
        @test reconstructed_grid.name == grid.name
        @test reconstructed_grid.rows == grid.rows
        @test reconstructed_grid.columns == grid.columns

        struct CatalogEntry
            title::String
            attributes::Dict{String, Any}
        end

        struct Catalog
            entries::Vector{CatalogEntry}
        end

        catalog = Catalog([
            CatalogEntry("book", Dict("pages" => 200, "authors" => ["Alice", "Bob"])),
            CatalogEntry("gadget", Dict("weight" => 1.2, "tags" => ["electronics", "portable"]))
        ])

        reconstructed_catalog = deser_beve(Catalog, to_beve(catalog))
        @test length(reconstructed_catalog.entries) == 2
        @test reconstructed_catalog.entries[1].title == "book"
        @test reconstructed_catalog.entries[1].attributes["pages"] == 200
        @test reconstructed_catalog.entries[2].attributes["tags"] == ["electronics", "portable"]
    end
    
    @testset "Optional and Union Fields" begin
        struct OptionalData
            required_field::String
            optional_number::Union{Int, Nothing}
            optional_string::Union{String, Nothing}
        end

        # Test with values present
        data1 = OptionalData("required", 42, "optional")
        beve_data1 = to_beve(data1)
        parsed1 = from_beve(beve_data1)

        @test parsed1["required_field"] == "required"
        @test parsed1["optional_number"] == 42
        @test parsed1["optional_string"] == "optional"

        # Test with nothing values
        data2 = OptionalData("required", nothing, nothing)
        beve_data2 = to_beve(data2)
        parsed2 = from_beve(beve_data2)

        @test parsed2["required_field"] == "required"
        @test parsed2["optional_number"] === nothing
        @test parsed2["optional_string"] === nothing
    end

    @testset "Union Type Coercion" begin
        # Test basic Union coercion with Int and String
        struct UnionHolder
            value::Union{Int, String}
        end

        # Int value should coerce correctly
        int_holder = UnionHolder(42)
        roundtrip_int = deser_beve(UnionHolder, to_beve(int_holder))
        @test roundtrip_int.value == 42
        @test roundtrip_int.value isa Int

        # String value should coerce correctly
        str_holder = UnionHolder("hello")
        roundtrip_str = deser_beve(UnionHolder, to_beve(str_holder))
        @test roundtrip_str.value == "hello"
        @test roundtrip_str.value isa String

        # Test Union{Nothing, T} coercion (common pattern)
        struct NullableHolder
            data::Union{Nothing, Vector{Int}}
        end

        with_data = NullableHolder([1, 2, 3])
        roundtrip_with = deser_beve(NullableHolder, to_beve(with_data))
        @test roundtrip_with.data == [1, 2, 3]

        without_data = NullableHolder(nothing)
        roundtrip_without = deser_beve(NullableHolder, to_beve(without_data))
        @test roundtrip_without.data === nothing

        # Test Union with multiple numeric types - exercises try-catch
        # When coercing an Int to Union{Float64, Int}, both should work
        struct MultiNumericUnion
            num::Union{Float64, Int}
        end

        int_num = MultiNumericUnion(10)
        roundtrip_int_num = deser_beve(MultiNumericUnion, to_beve(int_num))
        @test roundtrip_int_num.num == 10

        float_num = MultiNumericUnion(3.14)
        roundtrip_float_num = deser_beve(MultiNumericUnion, to_beve(float_num))
        @test roundtrip_float_num.num ≈ 3.14

        # Test Union with struct types
        struct TypeA
            a::Int
        end

        struct TypeB
            b::String
        end

        struct UnionStructHolder
            item::Union{TypeA, TypeB}
        end

        holder_a = UnionStructHolder(TypeA(100))
        roundtrip_a = deser_beve(UnionStructHolder, to_beve(holder_a))
        @test roundtrip_a.item isa TypeA
        @test roundtrip_a.item.a == 100

        holder_b = UnionStructHolder(TypeB("test"))
        roundtrip_b = deser_beve(UnionStructHolder, to_beve(holder_b))
        @test roundtrip_b.item isa TypeB
        @test roundtrip_b.item.b == "test"

        # Test Union in Vector elements
        struct VectorUnionHolder
            items::Vector{Union{Int, String}}
        end

        mixed_vec = VectorUnionHolder(Union{Int, String}[1, "two", 3, "four"])
        roundtrip_vec = deser_beve(VectorUnionHolder, to_beve(mixed_vec))
        @test roundtrip_vec.items[1] == 1
        @test roundtrip_vec.items[2] == "two"
        @test roundtrip_vec.items[3] == 3
        @test roundtrip_vec.items[4] == "four"

        # Test three-way Union
        struct TripleUnion
            val::Union{Int, String, Float64}
        end

        triple_int = TripleUnion(42)
        @test deser_beve(TripleUnion, to_beve(triple_int)).val == 42

        triple_str = TripleUnion("hello")
        @test deser_beve(TripleUnion, to_beve(triple_str)).val == "hello"

        triple_float = TripleUnion(2.718)
        @test deser_beve(TripleUnion, to_beve(triple_float)).val ≈ 2.718

        # Test Union with Nothing and struct - common API pattern
        struct ApiResponse
            success::Bool
            data::Union{Nothing, Dict{String, Any}}
            error_msg::Union{Nothing, String}
        end

        success_response = ApiResponse(true, Dict("id" => 1, "name" => "test"), nothing)
        roundtrip_success = deser_beve(ApiResponse, to_beve(success_response))
        @test roundtrip_success.success == true
        @test roundtrip_success.data["id"] == 1
        @test roundtrip_success.error_msg === nothing

        error_response = ApiResponse(false, nothing, "Not found")
        roundtrip_error = deser_beve(ApiResponse, to_beve(error_response))
        @test roundtrip_error.success == false
        @test roundtrip_error.data === nothing
        @test roundtrip_error.error_msg == "Not found"

        # Test nested Union types
        struct NestedUnionOuter
            inner::Union{Nothing, Vector{Union{Int, String}}}
        end

        nested_with = NestedUnionOuter(Union{Int, String}[1, "a", 2, "b"])
        roundtrip_nested = deser_beve(NestedUnionOuter, to_beve(nested_with))
        @test roundtrip_nested.inner[1] == 1
        @test roundtrip_nested.inner[2] == "a"

        nested_without = NestedUnionOuter(nothing)
        @test deser_beve(NestedUnionOuter, to_beve(nested_without)).inner === nothing
    end
    
    @testset "HTTP Extension Loading" begin
        # Test that HTTP functions work when HTTP.jl is loaded
        using HTTP
        
        struct TestData
            value::Int
        end
        
        # Test that basic HTTP functions are available
        test_obj = TestData(42)
        
        # Test registration works
        register_object("/test", test_obj)
        unregister_object("/test")
        @test true  # If we got here without errors, the extension loaded
        
        # Test client creation works
        client = BeveHttpClient("http://localhost:8080")
        @test client !== nothing
        
        # Run the full extension test suite if it exists
        extension_test_file = joinpath(@__DIR__, "test_http_extension.jl")
        if isfile(extension_test_file)
            include(extension_test_file)
        end
    end
end
