#include <glaze/glaze.hpp>
#include <glaze/beve.hpp>
#include <iostream>
#include <fstream>
#include <vector>
#include <complex>
#include <chrono>
#include <numeric>
#include <iomanip>
#include <unordered_map>
#include <cmath>

struct BenchmarkResult {
   std::string name;
   double write_time_ms;
   double read_time_ms;
   double write_stddev_ms;
   double read_stddev_ms;
   size_t data_size_bytes;
   int iterations;
};

// Test structures
struct SmallData {
   int32_t id = 42;
   double value = 3.14159;
   std::string name = "benchmark";
};

template <>
struct glz::meta<SmallData> {
   using T = SmallData;
   static constexpr auto value = object("id", &T::id, "value", &T::value, "name", &T::name);
};

struct MediumData {
   std::vector<double> values;
   std::unordered_map<std::string, int32_t> lookup;
   std::vector<std::string> tags;
   
   MediumData() {
      for (int i = 0; i < 100; ++i) {
         values.push_back(i * 0.1);
         lookup["key" + std::to_string(i)] = i;
         tags.push_back("tag" + std::to_string(i));
      }
   }
};

template <>
struct glz::meta<MediumData> {
   using T = MediumData;
   static constexpr auto value = object("values", &T::values, "lookup", &T::lookup, "tags", &T::tags);
};

struct LargeFloatArray {
   std::vector<float> data;
   
   explicit LargeFloatArray(size_t size = 10000) {
      data.reserve(size);
      for (size_t i = 0; i < size; ++i) {
         data.push_back(static_cast<float>(i) * 0.1f);
      }
   }
};

template <>
struct glz::meta<LargeFloatArray> {
   using T = LargeFloatArray;
   static constexpr auto value = object("data", &T::data);
};

struct LargeComplexArray {
   std::vector<std::complex<float>> data;
   
   explicit LargeComplexArray(size_t size = 10000) {
      data.reserve(size);
      for (size_t i = 0; i < size; ++i) {
         data.push_back({static_cast<float>(i), static_cast<float>(i) * 0.5f});
      }
   }
};

template <>
struct glz::meta<LargeComplexArray> {
   using T = LargeComplexArray;
   static constexpr auto value = object("data", &T::data);
};

template <typename T>
BenchmarkResult benchmark_type(const std::string& name, const T& data, int iterations = 100) {
   BenchmarkResult result;
   result.name = name;
   result.iterations = iterations;
   
   // Warm up
   std::string buffer;
   auto ec = glz::write_beve(data, buffer);
   if (ec) {
      std::cerr << "Warm up write error: " << glz::format_error(ec) << std::endl;
   }
   T temp;
   ec = glz::read_beve(temp, buffer);
   if (ec) {
      std::cerr << "Warm up read error: " << glz::format_error(ec) << std::endl;
   }
   
   result.data_size_bytes = buffer.size();
   
   // Benchmark write
   std::vector<double> write_times;
   write_times.reserve(iterations);
   
   for (int i = 0; i < iterations; ++i) {
      auto start = std::chrono::high_resolution_clock::now();
      auto ec = glz::write_beve(data, buffer);
      auto end = std::chrono::high_resolution_clock::now();
      
      if (ec) {
         std::cerr << "Write error: " << glz::format_error(ec) << std::endl;
         break;
      }
      
      auto duration = std::chrono::duration<double, std::milli>(end - start).count();
      write_times.push_back(duration);
   }
   
   // Benchmark read
   std::vector<double> read_times;
   read_times.reserve(iterations);
   
   T loaded;
   for (int i = 0; i < iterations; ++i) {
      auto start = std::chrono::high_resolution_clock::now();
      auto ec = glz::read_beve(loaded, buffer);
      auto end = std::chrono::high_resolution_clock::now();
      
      if (ec) {
         std::cerr << "Read error: " << glz::format_error(ec) << std::endl;
         break;
      }
      
      auto duration = std::chrono::duration<double, std::milli>(end - start).count();
      read_times.push_back(duration);
   }
   
   // Calculate average times
   result.write_time_ms = std::accumulate(write_times.begin(), write_times.end(), 0.0) / write_times.size();
   result.read_time_ms = std::accumulate(read_times.begin(), read_times.end(), 0.0) / read_times.size();
   
   // Calculate standard deviations
   double write_variance = 0.0;
   double read_variance = 0.0;
   
   for (double t : write_times) {
      write_variance += (t - result.write_time_ms) * (t - result.write_time_ms);
   }
   write_variance /= write_times.size();
   result.write_stddev_ms = std::sqrt(write_variance);
   
   for (double t : read_times) {
      read_variance += (t - result.read_time_ms) * (t - result.read_time_ms);
   }
   read_variance /= read_times.size();
   result.read_stddev_ms = std::sqrt(read_variance);
   
   return result;
}

void write_results(const std::vector<BenchmarkResult>& results) {
   std::ofstream file("cpp_benchmark_results.csv");
   file << "Name,WriteTimeMs,ReadTimeMs,WriteStdDevMs,ReadStdDevMs,DataSizeBytes,Iterations\n";
   
   for (const auto& r : results) {
      file << r.name << ","
           << r.write_time_ms << ","
           << r.read_time_ms << ","
           << r.write_stddev_ms << ","
           << r.read_stddev_ms << ","
           << r.data_size_bytes << ","
           << r.iterations << "\n";
   }
}

int main() {
   std::cout << "C++ BEVE Benchmark (Glaze)\n";
   std::cout << "==========================\n\n";
   
   std::vector<BenchmarkResult> results;
   
   // Small data
   std::cout << "Benchmarking small data..." << std::endl;
   SmallData small;
   results.push_back(benchmark_type("Small Data", small, 1000));
   
   // Medium data
   std::cout << "Benchmarking medium data..." << std::endl;
   MediumData medium;
   results.push_back(benchmark_type("Medium Data", medium, 500));
   
   // Large float array (10K)
   std::cout << "Benchmarking large float array (10K)..." << std::endl;
   LargeFloatArray large10k(10000);
   results.push_back(benchmark_type("Float Array 10K", large10k, 100));
   
   // Large float array (100K)
   std::cout << "Benchmarking large float array (100K)..." << std::endl;
   LargeFloatArray large100k(100000);
   results.push_back(benchmark_type("Float Array 100K", large100k, 50));
   
   // Large float array (1M)
   std::cout << "Benchmarking large float array (1M)..." << std::endl;
   LargeFloatArray large1m(1000000);
   results.push_back(benchmark_type("Float Array 1M", large1m, 20));
   
   // Complex array (10K)
   std::cout << "Benchmarking complex array (10K)..." << std::endl;
   LargeComplexArray complex10k(10000);
   results.push_back(benchmark_type("Complex Array 10K", complex10k, 100));
   
   // Complex array (100K)
   std::cout << "Benchmarking complex array (100K)..." << std::endl;
   LargeComplexArray complex100k(100000);
   results.push_back(benchmark_type("Complex Array 100K", complex100k, 50));
   
   // Print results
   std::cout << "\nResults:\n";
   std::cout << std::left << std::setw(20) << "Test"
             << std::right << std::setw(15) << "Write (ms)"
             << std::setw(15) << "Read (ms)"
             << std::setw(15) << "Size (bytes)"
             << std::setw(15) << "Iterations\n";
   std::cout << std::string(80, '-') << "\n";
   
   for (const auto& r : results) {
      std::cout << std::left << std::setw(20) << r.name
                << std::right << std::setw(15) << std::fixed << std::setprecision(3) << r.write_time_ms
                << std::setw(15) << r.read_time_ms
                << std::setw(15) << r.data_size_bytes
                << std::setw(15) << r.iterations << "\n";
   }
   
   write_results(results);
   std::cout << "\nResults written to cpp_benchmark_results.csv\n";
   
   return 0;
}