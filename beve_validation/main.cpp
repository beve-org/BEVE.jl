#include <glaze/glaze.hpp>
#include <glaze/beve.hpp>
#include <iostream>
#include <fstream>
#include <filesystem>
#include <vector>
#include <complex>
#include <map>
#include <optional>
#include <variant>
#include <array>

namespace fs = std::filesystem;

struct BasicTypes {
   bool b = true;
   int8_t i8 = -42;
   uint8_t u8 = 200;
   int16_t i16 = -1234;
   uint16_t u16 = 45678;
   int32_t i32 = -2147483647;
   uint32_t u32 = 3000000000;
   int64_t i64 = -9223372036854775807LL;
   uint64_t u64 = 18446744073709551615ULL;
   float f32 = 3.14159f;
   double f64 = 2.718281828459045;
   std::string str = "Hello, BEVE!";
};

template <>
struct glz::meta<BasicTypes> {
   using T = BasicTypes;
   static constexpr auto value = object(
      "b", &T::b,
      "i8", &T::i8,
      "u8", &T::u8,
      "i16", &T::i16,
      "u16", &T::u16,
      "i32", &T::i32,
      "u32", &T::u32,
      "i64", &T::i64,
      "u64", &T::u64,
      "f32", &T::f32,
      "f64", &T::f64,
      "str", &T::str
   );
};

struct ArrayTypes {
   std::vector<int32_t> int_vec = {1, 2, 3, 4, 5};
   std::vector<double> double_vec = {1.1, 2.2, 3.3};
   std::vector<std::string> string_vec = {"alpha", "beta", "gamma"};
   std::vector<bool> bool_vec = {true, false, true, true, false};
   std::array<int32_t, 5> int_array = {10, 20, 30, 40, 50};
};

template <>
struct glz::meta<ArrayTypes> {
   using T = ArrayTypes;
   static constexpr auto value = object(
      "int_vec", &T::int_vec,
      "double_vec", &T::double_vec,
      "string_vec", &T::string_vec,
      "bool_vec", &T::bool_vec,
      "int_array", &T::int_array
   );
};

struct ComplexTypes {
   std::complex<float> cf = {1.5f, 2.5f};
   std::complex<double> cd = {3.7, 4.8};
   std::vector<std::complex<float>> complex_vec = {{1.0f, 2.0f}, {3.0f, 4.0f}, {5.0f, 6.0f}};
};

template <>
struct glz::meta<ComplexTypes> {
   using T = ComplexTypes;
   static constexpr auto value = object(
      "cf", &T::cf,
      "cd", &T::cd,
      "complex_vec", &T::complex_vec
   );
};

struct MapTypes {
   std::map<std::string, int32_t> string_int_map = {{"one", 1}, {"two", 2}, {"three", 3}};
   std::map<int32_t, std::string> int_string_map = {{1, "first"}, {2, "second"}, {3, "third"}};
   std::unordered_map<std::string, double> unordered_map = {{"pi", 3.14159}, {"e", 2.71828}};
};

template <>
struct glz::meta<MapTypes> {
   using T = MapTypes;
   static constexpr auto value = object(
      "string_int_map", &T::string_int_map,
      "int_string_map", &T::int_string_map,
      "unordered_map", &T::unordered_map
   );
};

struct OptionalTypes {
   std::optional<int32_t> opt_int = 42;
   std::optional<std::string> opt_string = "optional value";
   std::optional<double> opt_empty = std::nullopt;
};

template <>
struct glz::meta<OptionalTypes> {
   using T = OptionalTypes;
   static constexpr auto value = object(
      "opt_int", &T::opt_int,
      "opt_string", &T::opt_string,
      "opt_empty", &T::opt_empty
   );
};

struct VariantTypes {
   using var_t = std::variant<int32_t, double, std::string>;
   var_t var_int = 42;
   var_t var_double = 3.14;
   var_t var_string = std::string("variant string");
};

template <>
struct glz::meta<VariantTypes> {
   using T = VariantTypes;
   static constexpr auto value = object(
      "var_int", &T::var_int,
      "var_double", &T::var_double,
      "var_string", &T::var_string
   );
};

struct NestedStruct {
   BasicTypes basic;
   ArrayTypes arrays;
   int32_t extra = 999;
};

template <>
struct glz::meta<NestedStruct> {
   using T = NestedStruct;
   static constexpr auto value = object(
      "basic", &T::basic,
      "arrays", &T::arrays,
      "extra", &T::extra
   );
};

struct AllTypes {
   BasicTypes basic;
   ArrayTypes arrays;
   ComplexTypes complex;
   MapTypes maps;
   OptionalTypes optionals;
   VariantTypes variants;
   NestedStruct nested;
};

template <>
struct glz::meta<AllTypes> {
   using T = AllTypes;
   static constexpr auto value = object(
      "basic", &T::basic,
      "arrays", &T::arrays,
      "complex", &T::complex,
      "maps", &T::maps,
      "optionals", &T::optionals,
      "variants", &T::variants,
      "nested", &T::nested
   );
};

template <typename T>
bool write_beve_file(const T& obj, const std::string& filename) {
   std::string buffer;
   auto ec = glz::write_beve(obj, buffer);
   if (ec) {
      std::cerr << "Failed to serialize to BEVE: " << glz::format_error(ec) << std::endl;
      return false;
   }
   
   std::ofstream file(filename, std::ios::binary);
   if (!file) {
      std::cerr << "Failed to open file for writing: " << filename << std::endl;
      return false;
   }
   
   file.write(buffer.data(), buffer.size());
   file.close();
   
   std::cout << "Wrote " << buffer.size() << " bytes to " << filename << std::endl;
   return true;
}

template <typename T>
bool read_beve_file(T& obj, const std::string& filename) {
   std::ifstream file(filename, std::ios::binary);
   if (!file) {
      std::cerr << "Failed to open file for reading: " << filename << std::endl;
      return false;
   }
   
   std::string buffer((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
   file.close();
   
   auto ec = glz::read_beve(obj, buffer);
   if (ec) {
      std::cerr << "Failed to deserialize from BEVE: " << glz::format_error(ec) << std::endl;
      return false;
   }
   
   std::cout << "Read " << buffer.size() << " bytes from " << filename << std::endl;
   return true;
}

template <typename T>
void print_json(const T& obj, const std::string& label) {
   std::string json;
   if (auto result = glz::write_json(obj, json); result) {
      std::cout << label << ": " << json << std::endl;
   }
}

void test_basic_types() {
   std::cout << "\n=== Testing Basic Types ===" << std::endl;
   
   BasicTypes original;
   print_json(original, "Original");
   
   std::cout << "Writing to basic_types.beve..." << std::endl;
   if (write_beve_file(original, "basic_types.beve")) {
      BasicTypes loaded;
      std::cout << "Reading from basic_types.beve..." << std::endl;
      if (read_beve_file(loaded, "basic_types.beve")) {
         print_json(loaded, "Loaded");
         
         std::cout << "Verification: " 
                   << (original.b == loaded.b ? "✓" : "✗") << " bool, "
                   << (original.i8 == loaded.i8 ? "✓" : "✗") << " int8, "
                   << (original.u8 == loaded.u8 ? "✓" : "✗") << " uint8, "
                   << (original.i16 == loaded.i16 ? "✓" : "✗") << " int16, "
                   << (original.u16 == loaded.u16 ? "✓" : "✗") << " uint16, "
                   << (original.i32 == loaded.i32 ? "✓" : "✗") << " int32, "
                   << (original.u32 == loaded.u32 ? "✓" : "✗") << " uint32, "
                   << (original.i64 == loaded.i64 ? "✓" : "✗") << " int64, "
                   << (original.u64 == loaded.u64 ? "✓" : "✗") << " uint64, "
                   << (original.f32 == loaded.f32 ? "✓" : "✗") << " float, "
                   << (original.f64 == loaded.f64 ? "✓" : "✗") << " double, "
                   << (original.str == loaded.str ? "✓" : "✗") << " string"
                   << std::endl;
      }
   }
}

void test_array_types() {
   std::cout << "\n=== Testing Array Types ===" << std::endl;
   
   ArrayTypes original;
   print_json(original, "Original");
   
   if (write_beve_file(original, "array_types.beve")) {
      ArrayTypes loaded;
      if (read_beve_file(loaded, "array_types.beve")) {
         print_json(loaded, "Loaded");
         
         std::cout << "Verification: " 
                   << (original.int_vec == loaded.int_vec ? "✓" : "✗") << " int_vec, "
                   << (original.double_vec == loaded.double_vec ? "✓" : "✗") << " double_vec, "
                   << (original.string_vec == loaded.string_vec ? "✓" : "✗") << " string_vec, "
                   << (original.bool_vec == loaded.bool_vec ? "✓" : "✗") << " bool_vec, "
                   << (original.int_array == loaded.int_array ? "✓" : "✗") << " int_array"
                   << std::endl;
      }
   }
}

void test_complex_types() {
   std::cout << "\n=== Testing Complex Types ===" << std::endl;
   
   ComplexTypes original;
   print_json(original, "Original");
   
   if (write_beve_file(original, "complex_types.beve")) {
      ComplexTypes loaded;
      if (read_beve_file(loaded, "complex_types.beve")) {
         print_json(loaded, "Loaded");
         
         std::cout << "Verification: " 
                   << (original.cf == loaded.cf ? "✓" : "✗") << " complex<float>, "
                   << (original.cd == loaded.cd ? "✓" : "✗") << " complex<double>, "
                   << (original.complex_vec == loaded.complex_vec ? "✓" : "✗") << " complex_vec"
                   << std::endl;
      }
   }
}

void test_all_types() {
   std::cout << "\n=== Testing All Types Combined ===" << std::endl;
   
   AllTypes original;
   
   if (write_beve_file(original, "all_types.beve")) {
      AllTypes loaded;
      if (read_beve_file(loaded, "all_types.beve")) {
         std::cout << "Successfully round-tripped all types!" << std::endl;
      }
   }
}

void generate_test_files() {
   std::cout << "\n=== Generating Test Files for Julia ===" << std::endl;
   
   fs::create_directory("cpp_generated");
   
   BasicTypes basic;
   write_beve_file(basic, "cpp_generated/basic_types.beve");
   
   ArrayTypes arrays;
   write_beve_file(arrays, "cpp_generated/array_types.beve");
   
   ComplexTypes complex;
   write_beve_file(complex, "cpp_generated/complex_types.beve");
   
   MapTypes maps;
   write_beve_file(maps, "cpp_generated/map_types.beve");
   
   OptionalTypes optionals;
   write_beve_file(optionals, "cpp_generated/optional_types.beve");
   
   VariantTypes variants;
   write_beve_file(variants, "cpp_generated/variant_types.beve");
   
   NestedStruct nested;
   write_beve_file(nested, "cpp_generated/nested_struct.beve");
   
   AllTypes all;
   write_beve_file(all, "cpp_generated/all_types.beve");
}

void test_julia_generated_files() {
   std::cout << "\n=== Reading Julia Generated Files ===" << std::endl;
   
   if (!fs::exists("julia_generated")) {
      std::cout << "julia_generated directory not found. Run Julia tests first." << std::endl;
      return;
   }
   
   for (const auto& entry : fs::directory_iterator("julia_generated")) {
      if (entry.path().extension() == ".beve") {
         std::cout << "\nReading: " << entry.path().filename() << std::endl;
         
         std::ifstream file(entry.path(), std::ios::binary);
         std::string buffer((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
         file.close();
         
         std::cout << "File size: " << buffer.size() << " bytes" << std::endl;
         
         if (entry.path().filename() == "basic_types.beve") {
            BasicTypes obj;
            if (read_beve_file(obj, entry.path().string())) {
               print_json(obj, "Parsed");
            }
         }
      }
   }
}

int main(int argc, char* argv[]) {
   std::cout << "BEVE Validation Tool" << std::endl;
   std::cout << "===================" << std::endl;
   
   if (argc > 1 && std::string(argv[1]) == "--read-julia") {
      test_julia_generated_files();
      return 0;
   }
   
   test_basic_types();
   test_array_types();
   test_complex_types();
   test_all_types();
   
   generate_test_files();
   
   std::cout << "\nTest files generated in cpp_generated/" << std::endl;
   std::cout << "Run with --read-julia to read Julia generated files" << std::endl;
   
   return 0;
}