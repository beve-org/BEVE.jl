using Test
using BEVE

@testset "BEVE.jl" begin
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
    
    @testset "HTTP Functionality" begin
        using HTTP
        
        # Define test structs
        struct TestEmployee
            id::Int
            name::String
            active::Bool
        end
        
        struct TestCompany
            name::String
            employees::Vector{TestEmployee}
            founded::Int
        end
        
        @testset "JSON Pointer Parsing" begin
            @test BEVE.parse_json_pointer("/") == String[]
            @test BEVE.parse_json_pointer("/employees") == ["employees"]
            @test BEVE.parse_json_pointer("/employees/0") == ["employees", "0"]
            @test BEVE.parse_json_pointer("/employees/0/name") == ["employees", "0", "name"]
            
            # Test escaping
            @test BEVE.parse_json_pointer("/field~0name") == ["field~name"]
            @test BEVE.parse_json_pointer("/field~1name") == ["field/name"]
        end
        
        @testset "JSON Pointer Resolution" begin
            # Create test data
            employees = [
                TestEmployee(1, "Alice", true),
                TestEmployee(2, "Bob", false)
            ]
            company = TestCompany("ACME Corp", employees, 2020)
            
            # Test resolving on struct
            @test BEVE.resolve_json_pointer(company, ["name"]) == "ACME Corp"
            @test BEVE.resolve_json_pointer(company, ["founded"]) == 2020
            @test BEVE.resolve_json_pointer(company, ["employees"]) == employees
            @test BEVE.resolve_json_pointer(company, ["employees", "0"]) == employees[1]
            @test BEVE.resolve_json_pointer(company, ["employees", "0", "name"]) == "Alice"
            @test BEVE.resolve_json_pointer(company, ["employees", "1", "active"]) == false
            
            # Test resolving on dictionary (what we get from BEVE deserialization)
            beve_data = to_beve(company)
            parsed_company = from_beve(beve_data)
            
            @test BEVE.resolve_json_pointer(parsed_company, ["name"]) == "ACME Corp"
            @test BEVE.resolve_json_pointer(parsed_company, ["founded"]) == 2020
            @test BEVE.resolve_json_pointer(parsed_company, ["employees", "0", "name"]) == "Alice"
            @test BEVE.resolve_json_pointer(parsed_company, ["employees", "1", "active"]) == false
            
            # Test error cases
            @test_throws ArgumentError BEVE.resolve_json_pointer(company, ["nonexistent"])
            @test_throws ArgumentError BEVE.resolve_json_pointer(company, ["employees", "10"])
            @test_throws ArgumentError BEVE.resolve_json_pointer(company, ["employees", "invalid"])
        end
        
        @testset "Object Registration" begin
            # Create test data
            employees = [TestEmployee(1, "Alice", true)]
            company = TestCompany("Test Corp", employees, 2021)
            
            # Test registration
            register_object("/test/company", company)
            @test haskey(BEVE.GLOBAL_REGISTRY.registered_objects, "/test/company")
            @test BEVE.GLOBAL_REGISTRY.registered_objects["/test/company"] === company
            @test BEVE.GLOBAL_REGISTRY.type_mappings["/test/company"] === TestCompany
            
            # Test path normalization
            register_object("test/employee", employees[1])
            @test haskey(BEVE.GLOBAL_REGISTRY.registered_objects, "/test/employee")
            
            # Test unregistration
            unregister_object("/test/company")
            @test !haskey(BEVE.GLOBAL_REGISTRY.registered_objects, "/test/company")
            @test !haskey(BEVE.GLOBAL_REGISTRY.type_mappings, "/test/company")
            
            # Clean up
            unregister_object("/test/employee")
        end
        
        @testset "HTTP Request Handling" begin
            # Register test data
            employees = [
                TestEmployee(1, "Alice", true),
                TestEmployee(2, "Bob", false)
            ]
            company = TestCompany("HTTP Test Corp", employees, 2022)
            register_object("/api/test-company", company)
            
            try
                # Test GET request - full object
                response = BEVE.handle_get_request("/api/test-company")
                @test response.status == 200
                @test response.headers[1][1] == "Content-Type"
                @test response.headers[1][2] == "application/x-beve"
                
                # Deserialize and verify
                returned_data = from_beve(response.body)
                @test returned_data["name"] == "HTTP Test Corp"
                @test returned_data["founded"] == 2022
                @test length(returned_data["employees"]) == 2
                
                # Test GET request with JSON pointer
                response = BEVE.handle_get_request("/api/test-company", "/name")
                @test response.status == 200
                returned_name = from_beve(response.body)
                @test returned_name == "HTTP Test Corp"
                
                # Test GET request with array access
                response = BEVE.handle_get_request("/api/test-company", "/employees/0/name")
                @test response.status == 200
                returned_employee_name = from_beve(response.body)
                @test returned_employee_name == "Alice"
                
                # Test 404 for non-existent path
                response = BEVE.handle_get_request("/api/nonexistent")
                @test response.status == 404
                
                # Test 400 for invalid JSON pointer
                response = BEVE.handle_get_request("/api/test-company", "/nonexistent")
                @test response.status == 400
                
            finally
                # Clean up
                unregister_object("/api/test-company")
            end
        end
        
        @testset "BeveHttpClient" begin
            # Test client creation
            client = BeveHttpClient("http://localhost:8080")
            @test client.base_url == "http://localhost:8080"
            @test client.headers["User-Agent"] == "BEVE.jl HTTP Client"
            @test client.headers["Accept"] == "application/x-beve"
            
            # Test URL normalization
            client2 = BeveHttpClient("http://localhost:8080/")
            @test client2.base_url == "http://localhost:8080"
            
            # Test custom headers
            custom_headers = Dict("Authorization" => "Bearer token123")
            client3 = BeveHttpClient("http://localhost:8080", headers=custom_headers)
            @test client3.headers["Authorization"] == "Bearer token123"
            @test client3.headers["User-Agent"] == "BEVE.jl HTTP Client" # Should still have defaults
        end
        
        # Note: Full integration tests with actual HTTP server would require
        # starting a server, making requests, and stopping it. This is complex
        # in a test environment and better suited for manual testing or 
        # dedicated integration test files.
    end
end
