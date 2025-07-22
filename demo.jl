# BEVE HTTP Demo
# This file demonstrates how to use BEVE with HTTP functionality

using BEVE
using HTTP

# Define example structs
struct Employee
    id::Int
    name::String
    email::String
    active::Bool
end

struct Department
    name::String
    manager::String
    employees::Vector{Employee}
end

struct Company
    name::String
    founded::Int
    departments::Vector{Department}
    headquarters::String
end

# Create sample data
employees_engineering = [
    Employee(1, "Alice Johnson", "alice@company.com", true),
    Employee(2, "Bob Smith", "bob@company.com", true),
    Employee(3, "Charlie Brown", "charlie@company.com", false)
]

employees_marketing = [
    Employee(4, "Diana Prince", "diana@company.com", true),
    Employee(5, "Eve Adams", "eve@company.com", true)
]

engineering_dept = Department("Engineering", "Alice Johnson", employees_engineering)
marketing_dept = Department("Marketing", "Diana Prince", employees_marketing)

company = Company("ACME Corporation", 2010, [engineering_dept, marketing_dept], "San Francisco, CA")

println("=== BEVE HTTP Demo ===")
println()

# Demo 1: Register objects and start server
println("1. Registering company data...")
register_object("/api/company", company)
register_object("/api/employees", employees_engineering)

println("   Registered company at /api/company")
println("   Registered employees at /api/employees")
println()

# Demo 2: Start server in a separate task
println("2. Starting HTTP server on localhost:8080...")
server_task = @async begin
    try
        start_server("127.0.0.1", 8080)
    catch e
        println("Server error: ", e)
    end
end

# Give server time to start
sleep(1)

# Demo 3: Create client and make requests
println("3. Creating HTTP client...")
client = BeveHttpClient("http://127.0.0.1:8080")

try
    # Demo 3a: Get entire company (as raw data to avoid conversion issues)
    println("   3a. Getting entire company...")
    company_data = get(client, "/api/company")
    println("      Company name: $(company_data["name"])")
    println("      Founded: $(company_data["founded"])")
    println("      Headquarters: $(company_data["headquarters"])")
    println("      Number of departments: $(length(company_data["departments"]))")
    println()

    # Demo 3b: Get specific department using JSON pointer
    println("   3b. Getting first department (Engineering)...")
    dept_data = get(client, "/api/company", json_pointer="/departments/0")
    println("      Department: $(dept_data["name"])")
    println("      Manager: $(dept_data["manager"])")
    println("      Employees: $(length(dept_data["employees"]))")
    println()

    # Demo 3c: Get specific employee
    println("   3c. Getting first employee from Engineering...")
    employee_data = get(client, "/api/company", json_pointer="/departments/0/employees/0")
    println("      Employee: $(employee_data["name"]) (ID: $(employee_data["id"]))")
    println("      Email: $(employee_data["email"])")
    println("      Active: $(employee_data["active"])")
    println()

    # Demo 3d: Get just employee names from marketing
    println("   3d. Getting marketing department employees...")
    marketing_employees = get(client, "/api/company", json_pointer="/departments/1/employees")
    println("      Marketing employees:")
    for emp in marketing_employees
        println("        - $(emp["name"]) ($(emp["email"]))")
    end
    println()

    # Demo 3e: Get company name only
    println("   3e. Getting just company name...")
    company_name = get(client, "/api/company", json_pointer="/name")
    println("      Company name: $company_name")
    println()

    # Demo 4: POST requests (updates)
    println("4. Demonstrating POST requests...")
    
    # Demo 4a: Update company name
    println("   4a. Updating company name...")
    post(client, "/api/company", "ACME Industries Inc.", json_pointer="/name")
    
    # Verify the update
    updated_name = get(client, "/api/company", json_pointer="/name")
    println("      Updated company name: $updated_name")
    println()

    # Demo 4b: Add new employee to employees array
    println("   4b. Creating new employee...")
    new_employee = Employee(6, "Frank Wilson", "frank@company.com", true)
    
    # We'll post to a separate employees endpoint for this demo
    println("      Current employees count: $(length(get(client, "/api/employees")))")
    
    # Note: For arrays, we'd typically use a different endpoint or implement array modification
    println("      (Array modification would require additional server logic)")
    println()

catch e
    println("Error during client demo: ", e)
end

# Demo 5: Show different access patterns
println("5. Demonstrating various access patterns...")
try
    # Get all department names
    println("   5a. All department names:")
    company_data = get(client, "/api/company")
    for (i, dept) in enumerate(company_data["departments"])
        println("      Department $i: $(dept["name"])")
    end
    println()

    # Get employee count per department
    println("   5b. Employee count per department:")
    for (i, dept) in enumerate(company_data["departments"])
        emp_count = length(dept["employees"])
        println("      $(dept["name"]): $emp_count employees")
    end
    println()

    # Get all active employees across departments
    println("   5c. All active employees:")
    active_employees = []
    for dept in company_data["departments"]
        for emp in dept["employees"]
            if emp["active"]
                push!(active_employees, "$(emp["name"]) ($(dept["name"]))")
            end
        end
    end
    
    for emp in active_employees
        println("      - $emp")
    end
    println()

catch e
    println("Error in access patterns demo: ", e)
end

println("6. JSON Pointer examples:")
println("   /api/company                           -> entire company")
println("   /api/company?pointer=/name             -> company name")
println("   /api/company?pointer=/departments      -> all departments")
println("   /api/company?pointer=/departments/0    -> first department")
println("   /api/company?pointer=/departments/0/employees/1/name -> second employee's name in first dept")
println()

println("=== Demo Complete ===")
println()
println("Server is running on http://127.0.0.1:8080")
println("You can test these endpoints:")
println("  curl http://127.0.0.1:8080/api/company")
println("  curl 'http://127.0.0.1:8080/api/company?pointer=/name'")
println("  curl 'http://127.0.0.1:8080/api/company?pointer=/departments/0/employees'")
println()
println("Press Ctrl+C to stop the server")

# Keep server running for manual testing
try
    wait(server_task)
catch InterruptException
    println("\nServer stopped.")
end
