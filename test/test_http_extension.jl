# Tests for HTTP extension functionality
# These tests require HTTP.jl to be loaded

using Test
using BEVE
using HTTP

@testset "HTTP Extension Tests" begin
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
    
    # Access the extension module for internal function testing
    # The extension is loaded as a submodule when HTTP is available
    HTTPExt = Base.get_extension(BEVE, :HTTPExt)
    
    @testset "JSON Pointer Parsing" begin
        @test HTTPExt.parse_json_pointer("/") == String[]
        @test HTTPExt.parse_json_pointer("/employees") == ["employees"]
        @test HTTPExt.parse_json_pointer("/employees/0") == ["employees", "0"]
        @test HTTPExt.parse_json_pointer("/employees/0/name") == ["employees", "0", "name"]
        
        # Test escaping
        @test HTTPExt.parse_json_pointer("/field~0name") == ["field~name"]
        @test HTTPExt.parse_json_pointer("/field~1name") == ["field/name"]
    end
    
    @testset "JSON Pointer Resolution" begin
        # Create test data
        employees = [
            TestEmployee(1, "Alice", true),
            TestEmployee(2, "Bob", false)
        ]
        company = TestCompany("ACME Corp", employees, 2020)
        
        # Test resolving on struct
        @test HTTPExt.resolve_json_pointer(company, ["name"]) == "ACME Corp"
        @test HTTPExt.resolve_json_pointer(company, ["founded"]) == 2020
        @test HTTPExt.resolve_json_pointer(company, ["employees"]) == employees
        @test HTTPExt.resolve_json_pointer(company, ["employees", "0"]) == employees[1]
        @test HTTPExt.resolve_json_pointer(company, ["employees", "0", "name"]) == "Alice"
        @test HTTPExt.resolve_json_pointer(company, ["employees", "1", "active"]) == false
        
        # Test resolving on dictionary (what we get from BEVE deserialization)
        beve_data = to_beve(company)
        parsed_company = from_beve(beve_data)
        
        @test HTTPExt.resolve_json_pointer(parsed_company, ["name"]) == "ACME Corp"
        @test HTTPExt.resolve_json_pointer(parsed_company, ["founded"]) == 2020
        @test HTTPExt.resolve_json_pointer(parsed_company, ["employees", "0", "name"]) == "Alice"
        @test HTTPExt.resolve_json_pointer(parsed_company, ["employees", "1", "active"]) == false
        
        # Test error cases
        @test_throws ArgumentError HTTPExt.resolve_json_pointer(company, ["nonexistent"])
        @test_throws ArgumentError HTTPExt.resolve_json_pointer(company, ["employees", "10"])
        @test_throws ArgumentError HTTPExt.resolve_json_pointer(company, ["employees", "invalid"])
    end
    
    @testset "Object Registration" begin
        # Create test data
        employees = [TestEmployee(1, "Alice", true)]
        company = TestCompany("Test Corp", employees, 2021)
        
        # Test registration
        register_object("/test/company", company)
        @test haskey(HTTPExt.GLOBAL_REGISTRY.registered_objects, "/test/company")
        @test HTTPExt.GLOBAL_REGISTRY.registered_objects["/test/company"] === company
        @test HTTPExt.GLOBAL_REGISTRY.type_mappings["/test/company"] === TestCompany
        
        # Test path normalization
        register_object("test/employee", employees[1])
        @test haskey(HTTPExt.GLOBAL_REGISTRY.registered_objects, "/test/employee")
        
        # Test unregistration
        unregister_object("/test/company")
        @test !haskey(HTTPExt.GLOBAL_REGISTRY.registered_objects, "/test/company")
        @test !haskey(HTTPExt.GLOBAL_REGISTRY.type_mappings, "/test/company")
        
        # Clean up
        unregister_object("/test/employee")
        
        # Test re-registration
        register_object("/api/test-company", company)
        @test HTTPExt.GLOBAL_REGISTRY.registered_objects["/api/test-company"] === company
        
        # Clean up
        unregister_object("/api/test-company")
    end
    
    @testset "HTTP Request Handling" begin
        # Create and register test data
        employees = [
            TestEmployee(1, "Alice", true),
            TestEmployee(2, "Bob", false)
        ]
        company = TestCompany("ACME Corp", employees, 2020)
        
        # Register for testing
        register_object("/api/test-company", company)
        
        try
            # Test GET request for entire object
            response = HTTPExt.handle_get_request("/api/test-company")
            @test response.status == 200
            @test response.headers[1][2] == "application/x-beve"
            
            # Verify the response body is valid BEVE
            decoded = from_beve(response.body)
            @test decoded["name"] == "ACME Corp"
            @test decoded["founded"] == 2020
            @test length(decoded["employees"]) == 2
            
            # Test GET with JSON pointer for specific field
            response = HTTPExt.handle_get_request("/api/test-company", "/name")
            @test response.status == 200
            decoded = from_beve(response.body)
            @test decoded == "ACME Corp"
            
            # Test GET with nested JSON pointer
            response = HTTPExt.handle_get_request("/api/test-company", "/employees/0/name")
            @test response.status == 200
            decoded = from_beve(response.body)
            @test decoded == "Alice"
            
            # Test 404 for non-existent path
            response = HTTPExt.handle_get_request("/api/nonexistent")
            @test response.status == 404
            
            # Test 400 for invalid JSON pointer
            response = HTTPExt.handle_get_request("/api/test-company", "/nonexistent")
            @test response.status == 400
            
        finally
            # Clean up
            unregister_object("/api/test-company")
        end
    end
    
    @testset "BeveHttpClient" begin
        # Test client creation
        client = BeveHttpClient("http://localhost:8080")
        @test isa(client, HTTPExt.BeveHttpClientImpl)
        @test client.base_url == "http://localhost:8080"
        @test haskey(client.headers, "User-Agent")
        @test client.headers["User-Agent"] == "BEVE.jl HTTP Client"
        
        # Test with custom headers
        custom_headers = Dict("Authorization" => "Bearer token123")
        client2 = BeveHttpClient("http://api.example.com/", headers=custom_headers)
        @test client2.base_url == "http://api.example.com"  # Trailing slash removed
        @test client2.headers["Authorization"] == "Bearer token123"
        @test haskey(client2.headers, "User-Agent")  # Default headers still included
    end
end