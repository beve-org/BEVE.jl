#include <glaze/glaze.hpp>
#include <glaze/beve.hpp>
#include <glaze/ext/eigen.hpp>
#include <Eigen/Core>
#include <iostream>
#include <fstream>
#include <iomanip>

int main() {
    std::cout << "Testing single Julia-generated BEVE matrix\n";
    std::cout << "=========================================\n\n";
    
    // Read the single matrix file
    std::ifstream file("julia_generated/single_matrix.beve", std::ios::binary);
    if (!file) {
        std::cerr << "Failed to open julia_generated/single_matrix.beve\n";
        return 1;
    }
    
    std::string buffer((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    file.close();
    
    std::cout << "Read " << buffer.size() << " bytes\n";
    std::cout << "Hex: ";
    for (size_t i = 0; i < buffer.size(); ++i) {
        std::cout << std::hex << std::setw(2) << std::setfill('0') 
                  << static_cast<int>(static_cast<unsigned char>(buffer[i]));
    }
    std::cout << "\n\n" << std::dec;
    
    // Try to parse as a 2x2 row-major matrix
    std::cout << "Attempting to parse as 2x2 row-major matrix...\n";
    Eigen::Matrix<float, 2, 2, Eigen::RowMajor> matrix;
    auto ec = glz::read_beve(matrix, buffer);
    
    if (ec) {
        std::cerr << "Failed to parse matrix: " << glz::format_error(ec) << "\n";
        std::cerr << "Error code value: " << static_cast<int>(ec) << "\n";
        
        // Let's manually inspect the bytes
        std::cout << "\nManual byte inspection:\n";
        if (buffer.size() >= 3) {
            std::cout << "  Byte 0 (header): 0x" << std::hex << static_cast<int>(static_cast<uint8_t>(buffer[0])) << std::dec;
            std::cout << " (expected 0x16 for MATRIX)\n";
            std::cout << "  Byte 1 (layout): 0x" << std::hex << static_cast<int>(static_cast<uint8_t>(buffer[1])) << std::dec;
            std::cout << " (expected 0x00 for row-major)\n";
            std::cout << "  Byte 2 (extents header): 0x" << std::hex << static_cast<int>(static_cast<uint8_t>(buffer[2])) << std::dec << "\n";
        }
        
        return 1;
    }
    
    std::cout << "✓ Successfully parsed matrix!\n";
    std::cout << "Matrix values:\n" << matrix << "\n";
    
    // Test round-trip: write the matrix back
    std::cout << "\nTesting round-trip...\n";
    std::string output_buffer;
    auto write_ec = glz::write_beve(matrix, output_buffer);
    if (write_ec) {
        std::cerr << "Failed to write matrix: " << glz::format_error(write_ec) << "\n";
        return 1;
    }
    
    std::cout << "Wrote " << output_buffer.size() << " bytes\n";
    std::cout << "Hex: ";
    for (size_t i = 0; i < output_buffer.size(); ++i) {
        std::cout << std::hex << std::setw(2) << std::setfill('0') 
                  << static_cast<int>(static_cast<unsigned char>(output_buffer[i]));
    }
    std::cout << "\n\n" << std::dec;
    
    if (buffer == output_buffer) {
        std::cout << "✓ Round-trip successful - output matches input!\n";
    } else {
        std::cout << "✗ Round-trip failed - output differs from input\n";
        std::cout << "Differences at:\n";
        for (size_t i = 0; i < std::min(buffer.size(), output_buffer.size()); ++i) {
            if (buffer[i] != output_buffer[i]) {
                std::cout << "  Position " << i << ": 0x" << std::hex 
                          << static_cast<int>(static_cast<uint8_t>(buffer[i])) 
                          << " vs 0x" 
                          << static_cast<int>(static_cast<uint8_t>(output_buffer[i])) 
                          << std::dec << "\n";
            }
        }
    }
    
    return 0;
}