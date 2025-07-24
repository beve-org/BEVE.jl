#include <glaze/glaze.hpp>
#include <glaze/beve.hpp>
#include <iostream>
#include <fstream>
#include <map>
#include <unordered_map>
#include <cstdint>
#include <iomanip>

template<typename K, typename V>
void test_integer_dict(const std::string& filename, const std::string& description) {
    std::cout << "\nTesting " << description << "...\n";
    std::cout << "  File: " << filename << "\n";
    
    // Read the file
    std::ifstream file(filename, std::ios::binary);
    if (!file) {
        std::cerr << "  ✗ Failed to open file\n";
        return;
    }
    
    std::string buffer((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    file.close();
    
    std::cout << "  Read " << buffer.size() << " bytes\n";
    
    // Parse as map
    std::map<K, V> result;
    auto ec = glz::read_beve(result, buffer);
    
    if (ec) {
        std::cerr << "  ✗ Failed to parse: " << glz::format_error(ec) << "\n";
        
        // Try unordered_map as fallback
        std::unordered_map<K, V> unordered_result;
        ec = glz::read_beve(unordered_result, buffer);
        if (!ec) {
            std::cout << "  ✓ Parsed as unordered_map instead\n";
            std::cout << "  Size: " << unordered_result.size() << " entries\n";
            for (const auto& [k, v] : unordered_result) {
                std::cout << "    " << k << " => " << v << "\n";
            }
        }
        return;
    }
    
    std::cout << "  ✓ Successfully parsed\n";
    std::cout << "  Size: " << result.size() << " entries\n";
    
    // Print contents
    for (const auto& [k, v] : result) {
        std::cout << "    " << k << " => " << v << "\n";
    }
    
    // Test round-trip
    std::string output;
    auto write_ec = glz::write_beve(result, output);
    if (write_ec) {
        std::cerr << "  ✗ Failed to write: " << glz::format_error(write_ec) << "\n";
    } else {
        if (buffer == output) {
            std::cout << "  ✓ Round-trip successful\n";
        } else {
            std::cout << "  ✗ Round-trip mismatch: " << buffer.size() << " vs " << output.size() << " bytes\n";
        }
    }
}

int main() {
    std::cout << "Testing Julia-generated Integer Keyed Objects\n";
    std::cout << "============================================\n";
    
    // Test int32 dictionary with string values
    test_integer_dict<int32_t, std::string>(
        "julia_generated/integer_objects/int32_dict.beve",
        "int32_t => string dictionary"
    );
    
    // Test uint16 dictionary with double values
    test_integer_dict<uint16_t, double>(
        "julia_generated/integer_objects/uint16_dict.beve",
        "uint16_t => double dictionary"
    );
    
    // Test int64 dictionary with glz::json_t (any) values
    std::cout << "\nTesting int64_t => any dictionary...\n";
    std::cout << "  File: julia_generated/integer_objects/int64_complex.beve\n";
    
    std::ifstream file("julia_generated/integer_objects/int64_complex.beve", std::ios::binary);
    if (!file) {
        std::cerr << "  ✗ Failed to open file\n";
    } else {
        std::string buffer((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
        file.close();
        
        std::cout << "  Read " << buffer.size() << " bytes\n";
        
        // Parse as map with json_t values
        std::map<int64_t, glz::json_t> result;
        auto ec = glz::read_beve(result, buffer);
        
        if (ec) {
            std::cerr << "  ✗ Failed to parse: " << glz::format_error(ec) << "\n";
        } else {
            std::cout << "  ✓ Successfully parsed\n";
            std::cout << "  Size: " << result.size() << " entries\n";
            
            // Print contents as JSON for clarity
            for (const auto& [k, v] : result) {
                std::string json_str;
                auto json_ec = glz::write_json(v, json_str);
                if (!json_ec) {
                    std::cout << "    " << k << " => " << json_str << "\n";
                }
            }
        }
    }
    
    // Test creating integer keyed object in C++
    std::cout << "\nCreating C++ integer keyed objects...\n";
    
    std::map<uint32_t, std::string> cpp_dict = {
        {100, "hundred"},
        {200, "two hundred"},
        {300, "three hundred"}
    };
    
    std::string cpp_buffer;
    auto ec = glz::write_beve(cpp_dict, cpp_buffer);
    if (ec) {
        std::cerr << "  ✗ Failed to write: " << glz::format_error(ec) << "\n";
    } else {
        std::cout << "  ✓ Successfully wrote uint32_t dictionary\n";
        std::cout << "  Size: " << cpp_buffer.size() << " bytes\n";
        
        // Save for Julia testing
        std::ofstream out("julia_generated/integer_objects/cpp_uint32_dict.beve", std::ios::binary);
        out.write(cpp_buffer.data(), cpp_buffer.size());
        out.close();
        std::cout << "  ✓ Saved to cpp_uint32_dict.beve\n";
    }
    
    // Test with negative keys
    std::map<int8_t, int32_t> negative_dict = {
        {-128, -1000},
        {-1, -1},
        {0, 0},
        {1, 1},
        {127, 1000}
    };
    
    std::string neg_buffer;
    ec = glz::write_beve(negative_dict, neg_buffer);
    if (!ec) {
        std::cout << "  ✓ Successfully wrote int8_t dictionary with negative keys\n";
        
        std::ofstream out("julia_generated/integer_objects/cpp_int8_dict.beve", std::ios::binary);
        out.write(neg_buffer.data(), neg_buffer.size());
        out.close();
        std::cout << "  ✓ Saved to cpp_int8_dict.beve\n";
    }
    
    std::cout << "\n✅ Integer object testing complete!\n";
    
    return 0;
}