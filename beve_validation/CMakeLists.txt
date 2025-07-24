cmake_minimum_required(VERSION 3.21)
project(beve_validation LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)

FetchContent_Declare(
  glaze
  GIT_REPOSITORY https://github.com/stephenberry/glaze.git
  GIT_TAG main
  GIT_SHALLOW TRUE
)

FetchContent_MakeAvailable(glaze)

add_executable(beve_validator main.cpp)
target_link_libraries(beve_validator PRIVATE glaze::glaze)

add_executable(beve_benchmark benchmark.cpp)
target_link_libraries(beve_benchmark PRIVATE glaze::glaze)

add_executable(test_matrices test_matrices.cpp)
target_link_libraries(test_matrices PRIVATE glaze::glaze)

add_executable(test_integer_objects test_integer_objects.cpp)
target_link_libraries(test_integer_objects PRIVATE glaze::glaze)

# Find Eigen3 package
find_package(Eigen3 QUIET)

if(Eigen3_FOUND)
    add_executable(test_matrices_eigen test_matrices_eigen.cpp)
    target_link_libraries(test_matrices_eigen PRIVATE glaze::glaze Eigen3::Eigen)
    target_compile_features(test_matrices_eigen PRIVATE cxx_std_23)
    
    add_executable(test_single_matrix test_single_matrix.cpp)
    target_link_libraries(test_single_matrix PRIVATE glaze::glaze Eigen3::Eigen)
    target_compile_features(test_single_matrix PRIVATE cxx_std_23)
    
    add_executable(test_eigen_matrices test_eigen_matrices.cpp)
    target_link_libraries(test_eigen_matrices PRIVATE glaze::glaze Eigen3::Eigen)
    target_compile_features(test_eigen_matrices PRIVATE cxx_std_23)
    
    add_executable(validate_all_matrices validate_all_matrices.cpp)
    target_link_libraries(validate_all_matrices PRIVATE glaze::glaze Eigen3::Eigen)
    target_compile_features(validate_all_matrices PRIVATE cxx_std_23)
    
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(test_matrices_eigen PRIVATE -Wall -Wextra -Wpedantic)
        target_compile_options(test_single_matrix PRIVATE -Wall -Wextra -Wpedantic)
        target_compile_options(test_eigen_matrices PRIVATE -Wall -Wextra -Wpedantic)
        target_compile_options(validate_all_matrices PRIVATE -Wall -Wextra -Wpedantic)
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
        target_compile_options(test_matrices_eigen PRIVATE /W4)
        target_compile_options(test_single_matrix PRIVATE /W4)
        target_compile_options(test_eigen_matrices PRIVATE /W4)
        target_compile_options(validate_all_matrices PRIVATE /W4)
    endif()
    message(STATUS "Eigen3 found - building test_matrices_eigen and test_single_matrix")
else()
    message(STATUS "Eigen3 not found - skipping test_matrices_eigen and test_single_matrix")
endif()

target_compile_features(beve_validator PRIVATE cxx_std_23)
target_compile_features(beve_benchmark PRIVATE cxx_std_23)
target_compile_features(test_matrices PRIVATE cxx_std_23)
target_compile_features(test_integer_objects PRIVATE cxx_std_23)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(beve_validator PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(beve_benchmark PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(test_matrices PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(test_integer_objects PRIVATE -Wall -Wextra -Wpedantic)
elseif(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
    target_compile_options(beve_validator PRIVATE /W4)
    target_compile_options(beve_benchmark PRIVATE /W4)
    target_compile_options(test_matrices PRIVATE /W4)
    target_compile_options(test_integer_objects PRIVATE /W4)
endif()