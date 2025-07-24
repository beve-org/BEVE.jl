#include <glaze/glaze.hpp>
#include <glaze/beve.hpp>
#include <glaze/ext/eigen.hpp>
#include <Eigen/Core>
#include <iostream>
#include <fstream>
#include <filesystem>
#include <vector>

namespace fs = std::filesystem;

bool validate_matrix_file(const std::string& filepath) {
    std::cout << "\nValidating: " << fs::path(filepath).filename().string() << "\n";
    
    // Read file
    std::ifstream file(filepath, std::ios::binary);
    if (!file) {
        std::cerr << "  ✗ Failed to open file\n";
        return false;
    }
    
    std::string buffer((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    file.close();
    
    // Try to parse as dynamic matrix (most general case)
    Eigen::Matrix<double, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor> matrix;
    auto ec = glz::read_beve(matrix, buffer);
    
    if (!ec) {
        std::cout << "  ✓ Parsed as dynamic double matrix\n";
        std::cout << "  Dimensions: " << matrix.rows() << "x" << matrix.cols() << "\n";
        return true;
    }
    
    // Try float matrix
    Eigen::Matrix<float, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor> float_matrix;
    ec = glz::read_beve(float_matrix, buffer);
    
    if (!ec) {
        std::cout << "  ✓ Parsed as dynamic float matrix\n";
        std::cout << "  Dimensions: " << float_matrix.rows() << "x" << float_matrix.cols() << "\n";
        return true;
    }
    
    // Try int32 matrix
    Eigen::Matrix<int32_t, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor> int_matrix;
    ec = glz::read_beve(int_matrix, buffer);
    
    if (!ec) {
        std::cout << "  ✓ Parsed as dynamic int32 matrix\n";
        std::cout << "  Dimensions: " << int_matrix.rows() << "x" << int_matrix.cols() << "\n";
        return true;
    }
    
    // Try complex float matrix
    Eigen::Matrix<std::complex<float>, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor> complex_matrix;
    ec = glz::read_beve(complex_matrix, buffer);
    
    if (!ec) {
        std::cout << "  ✓ Parsed as dynamic complex float matrix\n";
        std::cout << "  Dimensions: " << complex_matrix.rows() << "x" << complex_matrix.cols() << "\n";
        return true;
    }
    
    std::cerr << "  ✗ Failed to parse as any known matrix type\n";
    return false;
}

int main() {
    std::cout << "Validating all Julia-generated matrices\n";
    std::cout << "======================================\n";
    
    std::vector<std::string> directories = {
        "julia_generated/matrices",
        "julia_generated/validation"
    };
    
    int total = 0;
    int passed = 0;
    
    for (const auto& dir : directories) {
        if (!fs::exists(dir)) {
            std::cout << "\nSkipping " << dir << " (not found)\n";
            continue;
        }
        
        std::cout << "\nChecking " << dir << ":\n";
        
        for (const auto& entry : fs::directory_iterator(dir)) {
            if (entry.path().extension() == ".beve") {
                total++;
                if (validate_matrix_file(entry.path().string())) {
                    passed++;
                }
            }
        }
    }
    
    std::cout << "\n" << std::string(50, '=') << "\n";
    std::cout << "Summary: " << passed << "/" << total << " matrices validated successfully\n";
    std::cout << (passed == total ? "✅ All tests passed!" : "❌ Some tests failed") << "\n";
    
    return passed == total ? 0 : 1;
}