# Copyright (C) Microsoft Corporation. All rights reserved.

# Package name is the same for stable and experimental
# Experimental versions are prerelease versions (e.g., 2.0.169-experimental)
set(WINML_PACKAGE_NAME "Microsoft.WindowsAppSDK.ML")

#
# VERSION CONFIGURATION
# =====================
# Update this version when a new experimental build is available.
# This is the NuGet package version to download from nuget.org.
#
set(WINML_EXPERIMENTAL_VERSION "2.0.233-experimental-gfb98279532")

# Stable version placeholder (not used when experimental feature is enabled)
set(WINML_STABLE_VERSION "2.0.0")

# Select version based on feature
if("experimental" IN_LIST FEATURES)
    set(WINML_SDK_VERSION "${WINML_EXPERIMENTAL_VERSION}")
else()
    set(WINML_SDK_VERSION "${WINML_STABLE_VERSION}")
endif()

# Support local package override for development
# Option 1: Set environment variable WINML_LOCAL_PACKAGE to the .nupkg path
# Option 2: Place the .nupkg file in the sample's local_packages/ directory
set(WINML_LOCAL_PACKAGE_PATH "$ENV{WINML_LOCAL_PACKAGE}")

# Check for local packages directory relative to the overlay port
if(NOT WINML_LOCAL_PACKAGE_PATH OR NOT EXISTS "${WINML_LOCAL_PACKAGE_PATH}")
    # Look in sample's local_packages folder (sibling to vcpkg_ports)
    get_filename_component(SAMPLE_DIR "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    set(LOCAL_PKG_DIR "${SAMPLE_DIR}/local_packages")
    set(LOCAL_PKG_FILE "${LOCAL_PKG_DIR}/${WINML_PACKAGE_NAME}.${WINML_SDK_VERSION}.nupkg")
    if(EXISTS "${LOCAL_PKG_FILE}")
        set(WINML_LOCAL_PACKAGE_PATH "${LOCAL_PKG_FILE}")
    endif()
endif()

if(WINML_LOCAL_PACKAGE_PATH AND EXISTS "${WINML_LOCAL_PACKAGE_PATH}")
    file(TO_CMAKE_PATH "${WINML_LOCAL_PACKAGE_PATH}" WINML_LOCAL_PACKAGE_PATH)
    set(WINML_SDK_NUGET_URL "file://${WINML_LOCAL_PACKAGE_PATH}")
    message(STATUS "WINML: Using local package: ${WINML_LOCAL_PACKAGE_PATH}")
    set(WINML_SKIP_HASH TRUE)
else()
    set(WINML_SDK_NUGET_URL "https://www.nuget.org/api/v2/package/${WINML_PACKAGE_NAME}/${WINML_SDK_VERSION}")
    # Skip hash for experimental versions (they change frequently during development)
    if("experimental" IN_LIST FEATURES)
        set(WINML_SKIP_HASH TRUE)
    else()
        set(WINML_SKIP_HASH FALSE)
    endif()
endif()

# Download the NuGet package
if(WINML_SKIP_HASH)
    vcpkg_download_distfile(
        WINML_ARCHIVE
        URLS "${WINML_SDK_NUGET_URL}"
        FILENAME "${WINML_PACKAGE_NAME}.${WINML_SDK_VERSION}.zip"
        SKIP_SHA512
    )
else()
    # SHA512 hash for stable version (update when stable version changes)
    set(WINML_SDK_SHA512 "0")
    
    vcpkg_download_distfile(
        WINML_ARCHIVE
        URLS "${WINML_SDK_NUGET_URL}"
        FILENAME "${WINML_PACKAGE_NAME}.${WINML_SDK_VERSION}.zip"
        SHA512 ${WINML_SDK_SHA512}
    )
endif()

vcpkg_extract_source_archive(
    WINML_EXTRACTED_FILES
    ARCHIVE "${WINML_ARCHIVE}"
    NO_REMOVE_ONE_LEVEL
)

# Architecture mapping
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(WINML_ARCH "x64")
    set(WINML_NUGET_ARCH "win-x64")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(WINML_ARCH "arm64")
    set(WINML_NUGET_ARCH "win-arm64")
else()
    message(FATAL_ERROR "Unsupported architecture: ${VCPKG_TARGET_ARCHITECTURE}")
endif()

# Install headers
file(INSTALL "${WINML_EXTRACTED_FILES}/include/winml/" DESTINATION "${CURRENT_PACKAGES_DIR}/include/winml")
file(INSTALL "${WINML_EXTRACTED_FILES}/include/WinMLEpCatalog.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

# Install import libraries
file(INSTALL "${WINML_EXTRACTED_FILES}/lib/native/${WINML_ARCH}/onnxruntime.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
if(EXISTS "${WINML_EXTRACTED_FILES}/lib/native/${WINML_ARCH}/Microsoft.Windows.AI.MachineLearning.lib")
    file(INSTALL "${WINML_EXTRACTED_FILES}/lib/native/${WINML_ARCH}/Microsoft.Windows.AI.MachineLearning.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
endif()

# Install runtime DLLs
file(INSTALL
    "${WINML_EXTRACTED_FILES}/runtimes-framework/${WINML_NUGET_ARCH}/native/onnxruntime.dll"
    "${WINML_EXTRACTED_FILES}/runtimes-framework/${WINML_NUGET_ARCH}/native/onnxruntime_providers_shared.dll"
    "${WINML_EXTRACTED_FILES}/runtimes-framework/${WINML_NUGET_ARCH}/native/Microsoft.Windows.AI.MachineLearning.dll"
    "${WINML_EXTRACTED_FILES}/runtimes-framework/${WINML_NUGET_ARCH}/native/DirectML.dll"
    DESTINATION "${CURRENT_PACKAGES_DIR}/bin"
)

# Debug configuration
if(NOT VCPKG_BUILD_TYPE)
    file(INSTALL "${WINML_EXTRACTED_FILES}/lib/native/${WINML_ARCH}/onnxruntime.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
    if(EXISTS "${WINML_EXTRACTED_FILES}/lib/native/${WINML_ARCH}/Microsoft.Windows.AI.MachineLearning.lib")
        file(INSTALL "${WINML_EXTRACTED_FILES}/lib/native/${WINML_ARCH}/Microsoft.Windows.AI.MachineLearning.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
    endif()
    file(INSTALL
        "${WINML_EXTRACTED_FILES}/runtimes-framework/${WINML_NUGET_ARCH}/native/onnxruntime.dll"
        "${WINML_EXTRACTED_FILES}/runtimes-framework/${WINML_NUGET_ARCH}/native/onnxruntime_providers_shared.dll"
        "${WINML_EXTRACTED_FILES}/runtimes-framework/${WINML_NUGET_ARCH}/native/Microsoft.Windows.AI.MachineLearning.dll"
        "${WINML_EXTRACTED_FILES}/runtimes-framework/${WINML_NUGET_ARCH}/native/DirectML.dll"
        DESTINATION "${CURRENT_PACKAGES_DIR}/debug/bin"
    )
endif()

# Install CMake config files
file(INSTALL
    "${WINML_EXTRACTED_FILES}/cmake/microsoft-windows-ai-machinelearning-config.cmake"
    "${WINML_EXTRACTED_FILES}/cmake/microsoft-windows-ai-machinelearning-targets.cmake"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

file(READ "${CURRENT_PACKAGES_DIR}/share/${PORT}/microsoft-windows-ai-machinelearning-config.cmake" CONFIG_CONTENT)
string(REPLACE "@WINML_VERSION@" "${WINML_SDK_VERSION}" CONFIG_CONTENT "${CONFIG_CONTENT}")
file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/microsoft-windows-ai-machinelearning-config.cmake" "${CONFIG_CONTENT}")

file(RENAME
    "${CURRENT_PACKAGES_DIR}/share/${PORT}/microsoft-windows-ai-machinelearning-config.cmake"
    "${CURRENT_PACKAGES_DIR}/share/${PORT}/${PORT}-config.cmake"
)

# Install documentation and license
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
file(INSTALL "${WINML_EXTRACTED_FILES}/license.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)

if(EXISTS "${WINML_EXTRACTED_FILES}/ThirdPartyNotices.txt")
    file(INSTALL "${WINML_EXTRACTED_FILES}/ThirdPartyNotices.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
endif()
