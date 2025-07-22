# BEVE HTTP Module
# Provides HTTP server and client functionality with BEVE serialization

using HTTP

# Registry to store registered struct instances and their paths
struct BeveHttpRegistry
    registered_objects::Dict{String, Any}
    type_mappings::Dict{String, Type}
    
    function BeveHttpRegistry()
        new(Dict{String, Any}(), Dict{String, Type}())
    end
end

const GLOBAL_REGISTRY = BeveHttpRegistry()

"""
    register_object(path::String, obj::T) where T

Register a struct instance under a specific HTTP path.

## Examples

```julia
struct Company
    name::String
    employees::Vector{Employee}
end

company = Company("ACME Corp", employees)
register_object("/api/company", company)
```
"""
function register_object(path::String, obj::T) where T
    # Normalize path to ensure it starts with /
    normalized_path = startswith(path, "/") ? path : "/" * path
    
    GLOBAL_REGISTRY.registered_objects[normalized_path] = obj
    GLOBAL_REGISTRY.type_mappings[normalized_path] = T
    
    @info "Registered $(T) at path: $(normalized_path)"
end

"""
    unregister_object(path::String)

Unregister an object from the given path.
"""
function unregister_object(path::String)
    normalized_path = startswith(path, "/") ? path : "/" * path
    
    delete!(GLOBAL_REGISTRY.registered_objects, normalized_path)
    delete!(GLOBAL_REGISTRY.type_mappings, normalized_path)
    
    @info "Unregistered object at path: $(normalized_path)"
end

"""
    parse_json_pointer(pointer::String) -> Vector{String}

Parse a JSON pointer string into path segments.

## Examples

```julia
parse_json_pointer("/employees/0/name") # Returns ["employees", "0", "name"]
parse_json_pointer("/") # Returns []
```
"""
function parse_json_pointer(pointer::String)::Vector{String}
    if pointer == "/"
        return String[]
    end
    
    # Remove leading slash and split by '/'
    segments = split(pointer[2:end], '/')
    
    # Unescape JSON pointer special characters
    return [replace(replace(segment, "~1" => "/"), "~0" => "~") for segment in segments]
end

"""
    resolve_json_pointer(obj, pointer_segments::Vector{String})

Resolve a JSON pointer path against an object.
"""
function resolve_json_pointer(obj, pointer_segments::Vector{String})
    current = obj
    
    for segment in pointer_segments
        if current isa Dict
            if haskey(current, segment)
                current = current[segment]
            else
                throw(ArgumentError("Key '$segment' not found in object"))
            end
        elseif current isa Vector || current isa Array
            try
                index = parse(Int, segment) + 1  # JSON pointer uses 0-based indexing
                if 1 <= index <= length(current)
                    current = current[index]
                else
                    throw(BoundsError(current, index))
                end
            catch e
                throw(ArgumentError("Invalid array index '$segment': $(e)"))
            end
        elseif hasfield(typeof(current), Symbol(segment))
            current = getfield(current, Symbol(segment))
        else
            throw(ArgumentError("Cannot access field/key '$segment' on object of type $(typeof(current))"))
        end
    end
    
    return current
end

"""
    set_json_pointer(obj, pointer_segments::Vector{String}, value)

Set a value at the given JSON pointer path in an object (for mutable objects).
"""
function set_json_pointer!(obj, pointer_segments::Vector{String}, value)
    if isempty(pointer_segments)
        throw(ArgumentError("Cannot set root object"))
    end
    
    current = obj
    
    # Navigate to the parent of the target
    for segment in pointer_segments[1:end-1]
        if current isa Dict
            if haskey(current, segment)
                current = current[segment]
            else
                throw(ArgumentError("Key '$segment' not found in object"))
            end
        elseif current isa Vector || current isa Array
            try
                index = parse(Int, segment) + 1
                if 1 <= index <= length(current)
                    current = current[index]
                else
                    throw(BoundsError(current, index))
                end
            catch e
                throw(ArgumentError("Invalid array index '$segment': $(e)"))
            end
        elseif hasfield(typeof(current), Symbol(segment))
            current = getfield(current, Symbol(segment))
        else
            throw(ArgumentError("Cannot access field/key '$segment' on object of type $(typeof(current))"))
        end
    end
    
    # Set the final value
    final_segment = pointer_segments[end]
    
    if current isa Dict
        current[final_segment] = value
    elseif current isa Vector || current isa Array
        try
            index = parse(Int, final_segment) + 1
            if 1 <= index <= length(current)
                current[index] = value
            else
                throw(BoundsError(current, index))
            end
        catch e
            throw(ArgumentError("Invalid array index '$final_segment': $(e)"))
        end
    else
        # For structs, we can't modify fields directly since they're immutable
        throw(ArgumentError("Cannot modify field '$final_segment' on immutable struct of type $(typeof(current))"))
    end
end

"""
    handle_get_request(path::String, json_pointer::String) -> HTTP.Response

Handle GET request for BEVE data.
"""
function handle_get_request(path::String, json_pointer::String = "")::HTTP.Response
    try
        # Handle root path with status/index
        if path == "/"
            available_paths = collect(keys(GLOBAL_REGISTRY.registered_objects))
            if isempty(available_paths)
                response_body = """
                BEVE HTTP Server - No registered objects
                
                To register objects, use:
                register_object(path, object)
                
                Example:
                register_object("/api/data", my_struct)
                """
            else
                response_body = """
                BEVE HTTP Server - Available endpoints:
                
                $(join(["- $path" for path in sort(available_paths)], "\n"))
                
                Usage:
                - GET <path> - retrieve entire object
                - GET <path>?pointer=/field - retrieve specific field using JSON pointer
                
                JSON Pointer examples:
                - ?pointer=/field - access 'field' 
                - ?pointer=/array/0 - access first array element
                - ?pointer=/nested/field/value - access nested fields
                """
            end
            return HTTP.Response(200, 
                               ["Content-Type" => "text/plain"],
                               response_body)
        end
        
        # Find registered object for this path or a parent path
        obj = nothing
        matched_path = ""
        
        # Try exact match first
        if haskey(GLOBAL_REGISTRY.registered_objects, path)
            obj = GLOBAL_REGISTRY.registered_objects[path]
            matched_path = path
        else
            # Try to find parent paths
            for (registered_path, registered_obj) in GLOBAL_REGISTRY.registered_objects
                if startswith(path, registered_path)
                    obj = registered_obj
                    matched_path = registered_path
                    # Update json_pointer to include the remaining path
                    remaining_path = path[length(registered_path)+1:end]
                    if !isempty(remaining_path)
                        remaining_path = startswith(remaining_path, "/") ? remaining_path : "/" * remaining_path
                        json_pointer = remaining_path * json_pointer
                    end
                    break
                end
            end
        end
        
        if obj === nothing
            available_paths_str = join(sort(collect(keys(GLOBAL_REGISTRY.registered_objects))), ", ")
            return HTTP.Response(404, 
                               ["Content-Type" => "text/plain"],
                               "Object not found at path: $path\n\nAvailable paths: $available_paths_str")
        end
        
        # Resolve JSON pointer if provided
        if !isempty(json_pointer)
            pointer_segments = parse_json_pointer(json_pointer)
            try
                obj = resolve_json_pointer(obj, pointer_segments)
            catch e
                return HTTP.Response(400, "JSON pointer resolution error: $(e)")
            end
        end
        
        # Serialize to BEVE
        beve_data = to_beve(obj)
        
        return HTTP.Response(200, 
                           ["Content-Type" => "application/x-beve"],
                           beve_data)
    catch e
        return HTTP.Response(500, "Internal server error: $(e)")
    end
end

"""
    handle_post_request(path::String, body::Vector{UInt8}, json_pointer::String) -> HTTP.Response

Handle POST request to create/update BEVE data.
"""
function handle_post_request(path::String, body::Vector{UInt8}, json_pointer::String = "")::HTTP.Response
    try
        # Deserialize the body
        new_data = from_beve(body)
        
        if isempty(json_pointer)
            # Replace entire object at path
            GLOBAL_REGISTRY.registered_objects[path] = new_data
            return HTTP.Response(201, "Object created/updated at path: $path")
        else
            # Update specific field via JSON pointer
            if haskey(GLOBAL_REGISTRY.registered_objects, path)
                obj = GLOBAL_REGISTRY.registered_objects[path]
                pointer_segments = parse_json_pointer(json_pointer)
                
                try
                    set_json_pointer!(obj, pointer_segments, new_data)
                    return HTTP.Response(200, "Object updated at path: $path$json_pointer")
                catch e
                    return HTTP.Response(400, "JSON pointer update error: $(e)")
                end
            else
                return HTTP.Response(404, "Object not found at path: $path")
            end
        end
    catch e
        return HTTP.Response(500, "Internal server error: $(e)")
    end
end

"""
    request_handler(req::HTTP.Request) -> HTTP.Response

Main HTTP request handler for BEVE server.
"""
function request_handler(req::HTTP.Request)::HTTP.Response
    try
        path = req.target
        method = req.method
        
        # Parse query parameters for JSON pointer
        json_pointer = ""
        if '?' in path
            path_parts = split(path, '?', limit=2)
            path = String(path_parts[1])  # Convert SubString to String
            query_params = HTTP.URIs.queryparams(path_parts[2])
            json_pointer = String(get(query_params, "pointer", ""))  # Ensure String type
        end
        
        if method == "GET"
            return handle_get_request(path, json_pointer)
        elseif method == "POST"
            return handle_post_request(path, req.body, json_pointer)
        elseif method == "OPTIONS"
            # CORS preflight
            return HTTP.Response(200,
                               ["Access-Control-Allow-Origin" => "*",
                                "Access-Control-Allow-Methods" => "GET, POST, PUT, DELETE, OPTIONS",
                                "Access-Control-Allow-Headers" => "Content-Type"],
                               "")
        else
            return HTTP.Response(405, "Method not allowed: $method")
        end
    catch e
        @error "Request handler error" exception=e
        return HTTP.Response(500, "Internal server error: $(e)")
    end
end

"""
    start_server(host::String = "127.0.0.1", port::Int = 8080)

Start a BEVE HTTP server.

## Examples

```julia
# Register some data
struct Company
    name::String
    employees::Vector{String}
end

company = Company("ACME Corp", ["Alice", "Bob", "Charlie"])
register_object("/api/company", company)

# Start server
server = start_server("127.0.0.1", 8080)

# Server will respond to:
# GET /api/company -> entire company object
# GET /api/company/employees -> just the employees array
# GET /api/company/employees/0 -> first employee
```
"""
function start_server(host::String = "127.0.0.1", port::Int = 8080)
    @info "Starting BEVE HTTP server on $host:$port"
    
    server = HTTP.serve(request_handler, host, port)
    
    @info "BEVE HTTP server started successfully"
    return server
end

# BEVE HTTP Client
"""
    BeveHttpClient

HTTP client for making requests to BEVE servers.
"""
struct BeveHttpClient
    base_url::String
    headers::Dict{String, String}
    
    function BeveHttpClient(base_url::String; headers::Dict{String, String} = Dict{String, String}())
        # Ensure base_url doesn't end with /
        normalized_url = endswith(base_url, "/") ? base_url[1:end-1] : base_url
        
        # Set default headers
        default_headers = Dict(
            "User-Agent" => "BEVE.jl HTTP Client",
            "Accept" => "application/x-beve"
        )
        
        merged_headers = merge(default_headers, headers)
        
        new(normalized_url, merged_headers)
    end
end

"""
    get(client::BeveHttpClient, path::String; json_pointer::String = "", as_type::Type = Any)

Make a GET request to retrieve BEVE data.

## Examples

```julia
client = BeveHttpClient("http://localhost:8080")

# Get entire company
company = get(client, "/api/company", as_type=Company)

# Get just employees array  
employees = get(client, "/api/company/employees")

# Get first employee
first_employee = get(client, "/api/company/employees/0")
```
"""
function Base.get(client::BeveHttpClient, path::String; json_pointer::String = "", as_type::Type = Any)
    try
        # Build URL
        url = client.base_url * path
        
        # Add JSON pointer as query parameter if provided
        if !isempty(json_pointer)
            url *= "?pointer=" * HTTP.URIs.escapeuri(json_pointer)
        end
        
        # Make request
        response = HTTP.get(url, client.headers)
        
        if response.status == 200
            # Deserialize BEVE data
            beve_data = response.body
            parsed_data = from_beve(beve_data)
            
            # Convert to specific type if requested
            if as_type != Any && as_type != typeof(parsed_data)
                try
                    if parsed_data isa Dict{String, Any} && !isempty(fieldnames(as_type))
                        return deser_beve(as_type, beve_data)
                    elseif parsed_data isa Vector && as_type <: Vector
                        # Handle arrays - try to deserialize each element if needed
                        element_type = eltype(as_type)
                        if element_type != Any && !isempty(parsed_data) && parsed_data[1] isa Dict{String, Any}
                            # Try to deserialize each element to the target struct type
                            return [deser_beve(element_type, to_beve(item)) for item in parsed_data]
                        end
                        return parsed_data
                    else
                        # For simple types, try direct conversion
                        return convert(as_type, parsed_data)
                    end
                catch e
                    # If type conversion fails, return the raw parsed data
                    @warn "Type conversion failed for $as_type: $e. Returning raw data."
                    return parsed_data
                end
            end
            
            return parsed_data
        else
            throw(HTTP.StatusError(response.status, response.body))
        end
    catch e
        rethrow(e)
    end
end

"""
    post(client::BeveHttpClient, path::String, data; json_pointer::String = "")

Make a POST request to send BEVE data.

## Examples

```julia
client = BeveHttpClient("http://localhost:8080")

# Post entire object
new_company = Company("New Corp", ["John", "Jane"])
post(client, "/api/company", new_company)

# Update specific field
post(client, "/api/company", "Updated Corp", json_pointer="/name")
```
"""
function post(client::BeveHttpClient, path::String, data; json_pointer::String = "")
    try
        # Build URL
        url = client.base_url * path
        
        # Add JSON pointer as query parameter if provided
        if !isempty(json_pointer)
            url *= "?pointer=" * HTTP.URIs.escapeuri(json_pointer)
        end
        
        # Serialize data to BEVE
        beve_data = to_beve(data)
        
        # Set content type header
        headers = merge(client.headers, Dict("Content-Type" => "application/x-beve"))
        
        # Make request
        response = HTTP.post(url, headers, beve_data)
        
        if response.status in [200, 201]
            return String(response.body)
        else
            throw(HTTP.StatusError(response.status, response.body))
        end
    catch e
        rethrow(e)
    end
end

# Export public API
export register_object, unregister_object, start_server, BeveHttpClient
