# Windows ML EP Catalog Sample (CMake/WinML C API)

This sample demonstrates the **WinMLEpCatalog WinML C API** for discovering and managing hardware-accelerated execution providers (EPs) for machine learning inference on Windows.

The CMake project is configured to use the Windows ML NuGet package directly and auto-extract it during configure.

## Overview

This sample showcases:

- Creating an ONNX Runtime environment (`Ort::Env`)
- Creating and releasing a catalog handle
- Enumerating registered execution providers
- Inspecting provider metadata (name, version, state, certification)
- Preparing providers with `EnsureReady`
- Registering prepared providers with ONNX Runtime

## Prerequisites

- **Visual Studio 2022** with C++ workload
- **CMake** 3.21 or later
- **Ninja** (optional; only needed when using Ninja generator)
- `Microsoft.WindowsAppSDK.ML.2.0.246-experimental.nupkg` in this folder

Example install commands:

```powershell
winget install --exact --id Kitware.CMake
winget install --exact --id Ninja-build.Ninja
```

## Build (Recommended)

Use the helper script:

```powershell
# RelWithDebInfo for host architecture
.\build.ps1

# Debug with Visual Studio generator
.\build.ps1 -Generator VisualStudio -Configuration Debug

# Release for ARM64
.\build.ps1 -Configuration Release -Platform arm64

# Clean and rebuild
.\build.ps1 -Clean
```

During configure, CMake automatically:

1. Finds the local `.nupkg`
2. Extracts it to `local_packages/<nupkg-name>/` (if not already extracted)
3. Sets `microsoft.windows.ai.machinelearning_DIR` to the extracted `build/cmake` folder

## Manual Build

```powershell
# Configure (auto-extracts nupkg if needed)
cmake --preset nuget

# Build
cmake --build out/build/nuget --config RelWithDebInfo

# Run
.\out\build\nuget\WinMLEpCatalogSample.exe
```

## Package Version Override

To use a different package file:

```powershell
cmake --preset nuget -DWINML_NUGET_PACKAGE=.\Microsoft.WindowsAppSDK.ML.<new-version>.nupkg
```

For a full refresh, delete `local_packages/` and `out/` and configure again.

## Troubleshooting

### "Windows ML NuGet package not found"

Ensure the package exists in this directory, or pass `-DWINML_NUGET_PACKAGE=<path-to-nupkg>`.

### "Failed to create EP catalog"

Check that runtime DLLs were copied to the executable output directory and the target OS is supported.

## License

Copyright (C) Microsoft Corporation. All rights reserved.
