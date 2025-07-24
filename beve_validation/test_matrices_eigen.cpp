#include <glaze/glaze.hpp>
#include <glaze/beve.hpp>
#include <glaze/ext/eigen.hpp>
#include <Eigen/Core>
#include <iostream>
#include <fstream>
#include <vector>
#include <complex>
#include <map>

// Test structures to hold our matrices
struct MatrixSamples {
    Eigen::Matrix<float, 3, 3, Eigen::RowMajor> row_major_2d;
    Eigen::Matrix<float, 3, 3, Eigen::ColMajor> col_major_2d;
    Eigen::Matrix<std::complex<float>, 2, 2, Eigen::RowMajor> complex_matrix;
    // For higher dimensional and dynamic matrices, we'll read as raw data
    std::map<std::string, glz::json_t> other_matrices;
};

template <>
struct glz::meta<MatrixSamples> {
    using T = MatrixSamples;
    static constexpr auto value = object(
        "row_major_2d", &T::row_major_2d,
        "col_major_2d", &T::col_major_2d,
        "complex_matrix", &T::complex_matrix
    );
};

int main() {
    std::cout << "Testing Julia-generated BEVE matrices with Eigen\n";
    std::cout << "==============================================\n\n";
    
    // Read the file
    std::ifstream file("julia_generated/matrices.beve", std::ios::binary);
    if (!file) {
        std::cerr << "Failed to open julia_generated/matrices.beve\n";
        return 1;
    }
    
    std::string buffer((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    file.close();
    
    // First, let's parse as generic json_t to see all matrices
    glz::json_t all_data;
    auto ec = glz::read_beve(all_data, buffer);
    
    if (ec) {
        std::cerr << "Failed to parse BEVE data: " << glz::format_error(ec) << "\n";
        return 1;
    }
    
    // Print what we got
    if (all_data.is_object()) {
        auto& obj = all_data.get_object();
        std::cout << "Found " << obj.size() << " matrix samples:\n";
        for (const auto& [key, value] : obj) {
            std::cout << "  - " << key << "\n";
        }
        std::cout << "\n";
    }
    
    // Now try to parse specific matrices with Eigen types
    // We'll need to manually extract the ones we can handle with fixed-size Eigen matrices
    
    // Test 1: Read a simple 3x3 row-major matrix
    std::cout << "Test 1: Reading 3x3 row-major matrix\n";
    if (all_data.is_object()) {
        auto& obj = all_data.get_object();
        auto it = obj.find("row_major_2d");
        if (it != obj.end()) {
            // For now, let's just verify the structure
            std::string json_str;
            auto json_ec = glz::write_json(it->second, json_str);
            if (!json_ec) {
                std::cout << "  JSON representation: " << json_str << "\n";
            }
            
            // Check if it looks like matrix data
            if (it->second.is_object()) {
                auto& matrix_obj = it->second.get_object();
                auto layout_it = matrix_obj.find("layout");
                auto extents_it = matrix_obj.find("extents");
                auto value_it = matrix_obj.find("value");
                
                if (layout_it != matrix_obj.end() && extents_it != matrix_obj.end() && value_it != matrix_obj.end()) {
                    std::cout << "  ✓ Found matrix structure with layout, extents, and value\n";
                    
                    if (extents_it->second.is_array()) {
                        auto& extents = extents_it->second.get_array();
                        std::cout << "  Dimensions: ";
                        for (const auto& dim : extents) {
                            if (dim.is_number()) {
                                std::cout << dim.get_number() << " ";
                            }
                        }
                        std::cout << "\n";
                    }
                    
                    if (value_it->second.is_array()) {
                        auto& values = value_it->second.get_array();
                        std::cout << "  Number of elements: " << values.size() << "\n";
                        std::cout << "  First few elements: ";
                        for (size_t i = 0; i < std::min(size_t(5), values.size()); ++i) {
                            if (values[i].is_number()) {
                                std::cout << values[i].get_number() << " ";
                            }
                        }
                        std::cout << "...\n";
                    }
                }
            }
        }
    }
    
    std::cout << "\n";
    
    // Test 2: Try to write and read back a matrix
    std::cout << "Test 2: Writing and reading back an Eigen matrix\n";
    Eigen::Matrix<float, 2, 3, Eigen::RowMajor> test_matrix;
    test_matrix << 1.0f, 2.0f, 3.0f,
                   4.0f, 5.0f, 6.0f;
    
    std::string test_buffer;
    auto write_ec = glz::write_beve(test_matrix, test_buffer);
    if (write_ec) {
        std::cerr << "  Failed to write matrix: " << glz::format_error(write_ec) << "\n";
    } else {
        std::cout << "  Wrote matrix, size: " << test_buffer.size() << " bytes\n";
        std::cout << "  Hex: ";
        for (size_t i = 0; i < std::min(size_t(20), test_buffer.size()); ++i) {
            std::cout << std::hex << std::setw(2) << std::setfill('0') 
                      << static_cast<int>(static_cast<unsigned char>(test_buffer[i]));
        }
        std::cout << "...\n" << std::dec;
        
        // Read it back
        Eigen::Matrix<float, 2, 3, Eigen::RowMajor> read_matrix;
        auto read_ec = glz::read_beve(read_matrix, test_buffer);
        if (read_ec) {
            std::cerr << "  Failed to read matrix back: " << glz::format_error(read_ec) << "\n";
        } else {
            std::cout << "  ✓ Successfully read matrix back\n";
            std::cout << "  Values:\n" << read_matrix << "\n";
        }
    }
    
    std::cout << "\n✅ Matrix validation completed\n";
    
    return 0;
}