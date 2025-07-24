#include <glaze/glaze.hpp>
#include <glaze/beve.hpp>
#include <iostream>
#include <fstream>
#include <vector>
#include <complex>

// Test reading Julia-generated matrix samples
int main() {
    std::cout << "Testing Julia-generated BEVE matrices\n";
    std::cout << "=====================================\n\n";
    
    // Read the file
    std::ifstream file("julia_generated/matrices.beve", std::ios::binary);
    if (!file) {
        std::cerr << "Failed to open julia_generated/matrices.beve\n";
        return 1;
    }
    
    std::string buffer((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    file.close();
    
    // Parse as a generic glz::json_t to inspect the structure
    glz::json_t data;
    auto ec = glz::read_beve(data, buffer);
    
    if (ec) {
        std::cerr << "Failed to parse BEVE data: " << glz::format_error(ec) << "\n";
        return 1;
    }
    
    // Print what we got
    std::string json_output;
    auto json_ec = glz::write_json(data, json_output);
    if (!json_ec) {
        std::cout << "Parsed data as JSON:\n" << json_output << "\n\n";
    }
    
    // Check if it's an object by attempting to access it as such
    if (data.is_object()) {
        auto& obj = data.get_object();
        std::cout << "Successfully parsed as object with " << obj.size() << " entries\n";
        
        // List all keys
        for (const auto& [key, value] : obj) {
            std::cout << "  Key: " << key << "\n";
            
            // Try to identify matrix structure
            if (value.is_object()) {
                const auto& matrix_obj = value.get_object();
                if (matrix_obj.contains("layout") && matrix_obj.contains("extents") && matrix_obj.contains("value")) {
                    std::cout << "    -> Appears to be a matrix\n";
                    auto layout_it = matrix_obj.find("layout");
                    auto extents_it = matrix_obj.find("extents");
                    if (layout_it != matrix_obj.end() && layout_it->second.is_string()) {
                        std::cout << "       Layout: " << layout_it->second.get_string() << "\n";
                    }
                    if (extents_it != matrix_obj.end() && extents_it->second.is_array()) {
                        std::cout << "       Dimensions: " << extents_it->second.get_array().size() << "\n";
                    }
                }
            }
        }
    } else {
        std::cout << "Data is not an object\n";
    }
    
    std::cout << "\n✅ Matrix reading test completed\n";
    
    return 0;
}