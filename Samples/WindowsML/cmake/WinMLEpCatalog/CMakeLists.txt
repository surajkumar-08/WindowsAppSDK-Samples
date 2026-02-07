# Copyright (C) Microsoft Corporation. All rights reserved.
cmake_minimum_required(VERSION 3.21)

project(WinMLEpCatalogSample
    VERSION 1.0.0
    DESCRIPTION "Windows ML Execution Provider Catalog Sample with ONNX Runtime Integration"
    LANGUAGES CXX
)

# Find the Windows ML package installed via vcpkg
find_package(microsoft-windows-ai-machinelearning CONFIG REQUIRED)

# C++20 standard for modern features (std::format, etc.)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Create the executable
add_executable(WinMLEpCatalogSample
    main.cpp
)

# Link against the Windows ML API and ONNX Runtime
# WindowsML::Api provides the WinMLEpCatalog* functions
# WindowsML::OnnxRuntime provides access to the ONNX Runtime C/C++ API for creating OrtEnv and registering providers
target_link_libraries(WinMLEpCatalogSample
    PRIVATE
        WindowsML::Api
        WindowsML::OnnxRuntime
)

# Copy runtime DLLs to the build output directory
# This is required because the Windows ML DLLs must be present alongside the executable
winml_copy_runtime_dlls(WinMLEpCatalogSample)

# Set Windows-specific compiler options
if(MSVC)
    target_compile_options(WinMLEpCatalogSample PRIVATE
        /W4             # Warning level 4
        /permissive-    # Strict C++ conformance
        /Zc:__cplusplus # Report correct __cplusplus value
        /EHsc           # Enable C++ exception handling
    )
    
    # Use static runtime for easier deployment (no MSVC runtime dependency)
    set_property(TARGET WinMLEpCatalogSample PROPERTY
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>"
    )
endif()

# Set subsystem to console (not Windows GUI)
if(WIN32)
    set_target_properties(WinMLEpCatalogSample PROPERTIES
        WIN32_EXECUTABLE FALSE
    )
endif()
