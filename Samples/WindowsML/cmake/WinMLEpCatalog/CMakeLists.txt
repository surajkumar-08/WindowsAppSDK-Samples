# Copyright (C) Microsoft Corporation. All rights reserved.
cmake_minimum_required(VERSION 3.21)

project(WinMLEpCatalogSample
    VERSION 1.0.0
    DESCRIPTION "Windows ML Execution Provider Catalog Sample with ONNX Runtime Integration"
    LANGUAGES CXX
)

# Local NuGet package configuration
set(WINML_NUGET_PACKAGE "${CMAKE_CURRENT_SOURCE_DIR}/Microsoft.WindowsAppSDK.ML.2.0.246-experimental.nupkg"
    CACHE FILEPATH "Path to Microsoft.WindowsAppSDK.ML nupkg")
set(WINML_LOCAL_PACKAGES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/local_packages"
    CACHE PATH "Directory where the nupkg is extracted")

# Auto-extract the local nupkg (if needed) and wire CMake package discovery.
# Users can still override microsoft.windows.ai.machinelearning_DIR directly.
if(NOT DEFINED microsoft.windows.ai.machinelearning_DIR)
    if(EXISTS "${WINML_NUGET_PACKAGE}")
        get_filename_component(_winml_nupkg_filename "${WINML_NUGET_PACKAGE}" NAME)
        string(REGEX REPLACE "\\.nupkg$" "" _winml_nupkg_name "${_winml_nupkg_filename}")
        set(_winml_extract_dir "${WINML_LOCAL_PACKAGES_DIR}/${_winml_nupkg_name}")
        set(_winml_config_file "${_winml_extract_dir}/build/cmake/microsoft.windows.ai.machinelearning-config.cmake")

        if(NOT EXISTS "${_winml_config_file}")
            file(MAKE_DIRECTORY "${WINML_LOCAL_PACKAGES_DIR}")
            message(STATUS "Extracting ${WINML_NUGET_PACKAGE} -> ${_winml_extract_dir}")
            file(ARCHIVE_EXTRACT
                INPUT "${WINML_NUGET_PACKAGE}"
                DESTINATION "${_winml_extract_dir}")
        endif()

        set(microsoft.windows.ai.machinelearning_DIR "${_winml_extract_dir}/build/cmake"
            CACHE PATH "Path to microsoft.windows.ai.machinelearning CMake config" FORCE)
    else()
        message(FATAL_ERROR
            "Windows ML NuGet package not found: ${WINML_NUGET_PACKAGE}. "
            "Place the nupkg at that location or set microsoft.windows.ai.machinelearning_DIR.")
    endif()
endif()

# Find the Windows ML package from the extracted NuGet package CMake config.
find_package(microsoft.windows.ai.machinelearning CONFIG REQUIRED)

# C++20 standard for modern features (std::format, etc.)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Create the executable
add_executable(WinMLEpCatalogSample
    main.cpp
)

# WindowsML::Api       - WinMLEpCatalog* C API for discovering execution providers
# WindowsML::OnnxRuntime - ONNX Runtime C/C++ API (OrtEnv, session creation, etc.)
target_link_libraries(WinMLEpCatalogSample
    PRIVATE
        WindowsML::Api
        WindowsML::OnnxRuntime
)

# Copy runtime DLLs (onnxruntime.dll, Microsoft.Windows.AI.MachineLearning.dll)
# to the executable output directory so the sample can run in-place.
add_custom_command(TARGET WinMLEpCatalogSample POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_RUNTIME_DLLS:WinMLEpCatalogSample> $<TARGET_FILE_DIR:WinMLEpCatalogSample>
    COMMAND_EXPAND_LISTS
    VERBATIM
)

# DirectML.dll has no import library, so it is not included in TARGET_RUNTIME_DLLS.
# Copy it explicitly if your application uses the DirectML execution provider.
add_custom_command(TARGET WinMLEpCatalogSample POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${WINML_DIRECTML_DLL}" $<TARGET_FILE_DIR:WinMLEpCatalogSample>
)

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
