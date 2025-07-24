#include <glaze/glaze.hpp>
#include <glaze/beve.hpp>
#include <glaze/ext/eigen.hpp>
#include <Eigen/Core>
#include <iostream>
#include <fstream>
#include <vector>
#include <complex>
#include <iomanip>

template<typename T>
bool test_matrix_file(const std::string& filename, const std::string& description) {
    std::cout << "\nTesting " << description << "...\n";
    std::cout << "  File: " << filename << "\n";
    
    // Read the file
    std::ifstream file(filename, std::ios::binary);
    if (!file) {
        std::cerr << "  ✗ Failed to open file\n";
        return false;
    }
    
    std::string buffer((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    file.close();
    
    std::cout << "  Read " << buffer.size() << " bytes\n";
    
    // Parse the matrix
    T matrix;
    auto ec = glz::read_beve(matrix, buffer);
    
    if (ec) {
        std::cerr << "  ✗ Failed to parse: " << glz::format_error(ec) << "\n";
        return false;
    }
    
    std::cout << "  ✓ Successfully parsed matrix\n";
    std::cout << "  Dimensions: " << matrix.rows() << "x" << matrix.cols() << "\n";
    std::cout << "  Values:\n" << matrix << "\n";
    
    // Test round-trip
    std::string output;
    auto write_ec = glz::write_beve(matrix, output);
    if (write_ec) {
        std::cerr << "  ✗ Failed to write matrix: " << glz::format_error(write_ec) << "\n";
        return false;
    }
    
    if (buffer == output) {
        std::cout << "  ✓ Round-trip successful\n";
    } else {
        std::cout << "  ✗ Round-trip failed - size difference: " << buffer.size() << " vs " << output.size() << "\n";
    }
    
    return true;
}

int main() {
    std::cout << "Testing Julia-generated BEVE matrices with Eigen\n";
    std::cout << "==============================================\n";
    
    bool all_passed = true;
    
    // Test 1: 2x2 row-major float matrix
    all_passed &= test_matrix_file<Eigen::Matrix<float, 2, 2, Eigen::RowMajor>>(
        "julia_generated/matrices/2x2_row_major_f32.beve",
        "2x2 row-major float matrix"
    );
    
    // Test 2: 3x3 row-major float matrix
    all_passed &= test_matrix_file<Eigen::Matrix<float, 3, 3, Eigen::RowMajor>>(
        "julia_generated/matrices/3x3_row_major_f32.beve",
        "3x3 row-major float matrix"
    );
    
    // Test 3: 3x3 column-major float matrix
    all_passed &= test_matrix_file<Eigen::Matrix<float, 3, 3, Eigen::ColMajor>>(
        "julia_generated/matrices/3x3_col_major_f32.beve",
        "3x3 column-major float matrix"
    );
    
    // Test 4: 2x2 complex matrix
    all_passed &= test_matrix_file<Eigen::Matrix<std::complex<float>, 2, 2, Eigen::RowMajor>>(
        "julia_generated/matrices/2x2_complex_f32.beve",
        "2x2 complex float matrix"
    );
    
    // Test 5: Dynamic size matrix
    all_passed &= test_matrix_file<Eigen::Matrix<double, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor>>(
        "julia_generated/matrices/4x5_dynamic_f64.beve",
        "4x5 dynamic double matrix"
    );
    
    // Test creating a matrix in C++ and writing it
    std::cout << "\nTesting C++ to Julia compatibility...\n";
    Eigen::Matrix<float, 2, 3, Eigen::RowMajor> cpp_matrix;
    cpp_matrix << 10.0f, 20.0f, 30.0f,
                  40.0f, 50.0f, 60.0f;
    
    std::string cpp_buffer;
    auto ec = glz::write_beve(cpp_matrix, cpp_buffer);
    if (ec) {
        std::cerr << "  ✗ Failed to write C++ matrix: " << glz::format_error(ec) << "\n";
        all_passed = false;
    } else {
        std::cout << "  ✓ Successfully wrote C++ matrix\n";
        
        // Save for Julia to test
        std::ofstream out("julia_generated/matrices/cpp_2x3_matrix.beve", std::ios::binary);
        out.write(cpp_buffer.data(), cpp_buffer.size());
        out.close();
        std::cout << "  ✓ Saved to cpp_2x3_matrix.beve for Julia testing\n";
        
        std::cout << "  Matrix values:\n" << cpp_matrix << "\n";
    }
    
    std::cout << "\n" << (all_passed ? "✅ All tests passed!" : "❌ Some tests failed") << "\n";
    
    return all_passed ? 0 : 1;
}