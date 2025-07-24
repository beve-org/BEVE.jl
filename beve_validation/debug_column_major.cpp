#include <glaze/glaze.hpp>
#include <glaze/beve.hpp>
#include <glaze/ext/eigen.hpp>
#include <Eigen/Core>
#include <iostream>
#include <fstream>
#include <iomanip>

int main() {
    std::cout << "Debugging column-major matrix parsing\n";
    std::cout << "====================================\n\n";
    
    // Read a column-major matrix file
    std::string filepath = "julia_generated/matrices/3x3_col_major_f32.beve";
    std::ifstream file(filepath, std::ios::binary);
    if (!file) {
        std::cerr << "Failed to open " << filepath << "\n";
        return 1;
    }
    
    std::string buffer((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    file.close();
    
    std::cout << "File: " << filepath << "\n";
    std::cout << "Size: " << buffer.size() << " bytes\n";
    std::cout << "First 10 bytes: ";
    for (size_t i = 0; i < std::min(size_t(10), buffer.size()); ++i) {
        std::cout << std::hex << std::setw(2) << std::setfill('0') 
                  << static_cast<int>(static_cast<unsigned char>(buffer[i])) << " ";
    }
    std::cout << "\n\n" << std::dec;
    
    // Try parsing as column-major explicitly
    std::cout << "Attempting to parse as 3x3 column-major float matrix...\n";
    Eigen::Matrix<float, 3, 3, Eigen::ColMajor> col_matrix;
    auto ec = glz::read_beve(col_matrix, buffer);
    
    if (ec) {
        std::cerr << "Failed: " << glz::format_error(ec) << "\n\n";
    } else {
        std::cout << "✓ Success! Matrix values:\n" << col_matrix << "\n\n";
    }
    
    // Try dynamic column-major
    std::cout << "Attempting to parse as dynamic column-major float matrix...\n";
    Eigen::Matrix<float, Eigen::Dynamic, Eigen::Dynamic, Eigen::ColMajor> dyn_col_matrix;
    ec = glz::read_beve(dyn_col_matrix, buffer);
    
    if (ec) {
        std::cerr << "Failed: " << glz::format_error(ec) << "\n";
    } else {
        std::cout << "✓ Success! Dynamic matrix values:\n" << dyn_col_matrix << "\n";
    }
    
    return 0;
}