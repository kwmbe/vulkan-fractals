cmake_minimum_required(VERSION 3.29)
project(HelloTriangleApplication)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/CMake")

find_package (glfw3 REQUIRED)
find_package (Vulkan REQUIRED)

add_executable(HelloTriangleApplication main.cpp)

target_link_libraries(HelloTriangleApplication PRIVATE
    glfw
    Vulkan::Vulkan
)

target_compile_features(HelloTriangleApplication PRIVATE cxx_std_20)

target_compile_definitions(HelloTriangleApplication PRIVATE
  VULKAN_HPP_DISPATCH_LOADER_DYNAMIC
  VULKAN_HPP_NO_STRUCT_CONSTRUCTORS
)

function (add_slang_shader_target TARGET)
  cmake_parse_arguments ("SHADER" "" "" "SOURCES" ${ARGN})
  set (SHADERS_DIR ${CMAKE_CURRENT_LIST_DIR}/shaders)
  set (ENTRY_POINTS -entry vertMain -entry fragMain)
  add_custom_command (
          OUTPUT ${SHADERS_DIR}
          COMMAND ${CMAKE_COMMAND} -E make_directory ${SHADERS_DIR}
  )
  add_custom_command (
          OUTPUT  ${SHADERS_DIR}/slang.spv
          COMMAND ${SLANGC_EXECUTABLE} ${SHADER_SOURCES} -target spirv -profile spirv_1_4 -emit-spirv-directly -fvk-use-entrypoint-name ${ENTRY_POINTS} -o slang.spv
          WORKING_DIRECTORY ${SHADERS_DIR}
          DEPENDS ${SHADERS_DIR} ${SHADER_SOURCES}
          COMMENT "Compiling Slang Shaders"
          VERBATIM
  )
  add_custom_target (${TARGET} DEPENDS ${SHADERS_DIR}/slang.spv)
endfunction()

add_slang_shader_target( Shaders SOURCES ${SHADER_SLANG_SOURCES})
add_dependencies(HelloTriangleApplication Shaders)
