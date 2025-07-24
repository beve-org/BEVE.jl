#include <glaze/glaze.hpp>
#include <glaze/beve.hpp>
#include <iostream>
#include <fstream>
#include <chrono>
#include <bitset>
#include <deque>
#include <list>
#include <set>
#include <unordered_set>

struct ExtensionTypes {
   std::bitset<64> bits{0xDEADBEEFCAFEBABE};
   
   std::deque<int32_t> deque_int = {1, 2, 3, 4, 5};
   std::list<double> list_double = {1.1, 2.2, 3.3};
   
   std::set<std::string> set_string = {"apple", "banana", "cherry"};
   std::unordered_set<int32_t> unset_int = {10, 20, 30, 40};
   
   std::multimap<std::string, int32_t> multimap_data = {
      {"key1", 1}, {"key1", 2}, {"key2", 3}, {"key2", 4}
   };
   
   std::chrono::system_clock::time_point timestamp = std::chrono::system_clock::now();
   std::chrono::nanoseconds duration{1234567890};
};

struct Matrix3x3 {
   std::array<std::array<double, 3>, 3> data = {{
      {1.0, 2.0, 3.0},
      {4.0, 5.0, 6.0},
      {7.0, 8.0, 9.0}
   }};
};

struct TensorData {
   std::vector<size_t> shape = {2, 3, 4};
   std::vector<float> data = {
      1.0f, 2.0f, 3.0f, 4.0f,
      5.0f, 6.0f, 7.0f, 8.0f,
      9.0f, 10.0f, 11.0f, 12.0f,
      13.0f, 14.0f, 15.0f, 16.0f,
      17.0f, 18.0f, 19.0f, 20.0f,
      21.0f, 22.0f, 23.0f, 24.0f
   };
};

struct BinaryData {
   std::vector<uint8_t> raw_bytes = {0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE, 0xFD, 0xFC};
   std::string base64_data = "SGVsbG8gQkVWRSE=";
};

template <typename T>
bool write_and_verify(const T& original, const std::string& filename) {
   std::string buffer;
   auto write_result = glz::write_beve(original, buffer);
   if (!write_result) {
      std::cerr << "Failed to serialize: " << glz::format_error(write_result) << std::endl;
      return false;
   }
   
   std::ofstream file(filename, std::ios::binary);
   file.write(buffer.data(), buffer.size());
   file.close();
   
   T loaded;
   auto read_result = glz::read_beve(loaded, buffer);
   if (!read_result) {
      std::cerr << "Failed to deserialize: " << glz::format_error(read_result) << std::endl;
      return false;
   }
   
   std::cout << "✓ " << filename << " (" << buffer.size() << " bytes)" << std::endl;
   return true;
}

void test_extensions() {
   std::cout << "\n=== Testing BEVE Extensions ===" << std::endl;
   
   ExtensionTypes ext;
   write_and_verify(ext, "cpp_generated/extensions.beve");
   
   Matrix3x3 matrix;
   write_and_verify(matrix, "cpp_generated/matrix.beve");
   
   TensorData tensor;
   write_and_verify(tensor, "cpp_generated/tensor.beve");
   
   BinaryData binary;
   write_and_verify(binary, "cpp_generated/binary.beve");
}

int main() {
   test_extensions();
   return 0;
}