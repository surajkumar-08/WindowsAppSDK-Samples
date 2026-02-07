# Windows ML EP Catalog Sample (CMake/Native C API)

This sample demonstrates the **WinMLEpCatalog Native C API** for discovering and managing hardware-accelerated execution providers (EPs) for machine learning inference on Windows. The sample uses CMake and vcpkg for cross-platform-style builds without Visual Studio project files.

## Overview

The WinMLEpCatalog API is a native C API that provides low-level access to Windows ML's execution provider infrastructure. Unlike the WinRT/COM interfaces, this API:

- **Has no WinRT dependencies** — pure C function calls with handle-based resource management
- **Is easy to integrate** — single header file (`WinMLEpCatalog.h`) with simple function signatures
- **Supports async operations** — progress callbacks and cancellation for long-running operations
- **Works with any build system** — CMake, Makefiles, or direct compiler invocation

This sample showcases:

- Creating an ONNX Runtime environment (OrtEnv)
- Creating and releasing a catalog handle
- Enumerating all registered execution providers
- Inspecting provider metadata (name, version, state, certification)
- Preparing providers with `EnsureReady` (sync)
- Registering prepared providers with ONNX Runtime
- Verifying registered EP devices

## Key Features

### ONNX Runtime Integration

This sample demonstrates the complete workflow for registering certified execution providers with ONNX Runtime, matching the behavior of the `ExecutionProviderCatalog::RegisterCertifiedProviders` WinRT API:

```cpp
// Initialize ORT API
const OrtApiBase* ortApiBase = OrtGetApiBase();
const OrtApi* ortApi = ortApiBase->GetApi(ORT_API_VERSION);
Ort::InitApi(ortApi);

// Create ORT environment
Ort::Env ortEnv(ORT_LOGGING_LEVEL_WARNING, "MyApp");

// Register provider library after EnsureReady
std::wstring libraryPath = Utf8ToWide(provider.libraryPath);
ortEnv.RegisterExecutionProviderLibrary(provider.name.c_str(), libraryPath);

// Verify registered providers
auto epDevices = ortEnv.GetEpDevices();
```

### Execution Provider Discovery

Enumerate all available execution providers registered on the system:

```cpp
WinMLEpCatalogEnumProviders(catalog, callback, context);
```

The callback receives information about each provider including:
- Provider name (e.g., `ContosoExecutionProvider`, `DmlExecutionProvider`)
- Version string
- Package family name
- Ready state (`Ready`, `NotReady`, `NotPresent`)
- Certification status

### Provider Preparation

Before using an execution provider, it must be prepared. This may involve downloading and installing the provider package:

```cpp
// Synchronous (blocking)
WinMLEpEnsureReady(epHandle, &result);

// Asynchronous (with progress)
WinMLEpEnsureReadyAsync(epHandle, &asyncBlock);
```

### Path Retrieval

After preparation, retrieve the paths needed to load the provider:

```cpp
WinMLEpGetLibraryPath(epHandle, bufferSize, buffer, &used);
WinMLEpGetPackageRootPath(epHandle, bufferSize, buffer, &used);
```

## When to Use This Approach

**Choose the Native C API when:**

- Integrating with C codebases or C-compatible FFI boundaries
- Building cross-platform applications that target Windows
- Requiring minimal dependencies (no WinRT/COM overhead)
- Working with build systems that don't easily support WinRT
- Need precise control over async operation lifetime and cancellation

## Project Structure

```
WinMLEpCatalog/
├── main.cpp                 # Sample implementation (all code in one file)
├── CMakeLists.txt           # CMake build configuration
├── CMakePresets.json        # Build presets (x64/arm64, Debug/Release)
├── vcpkg.json               # Package manifest
├── vcpkg-configuration.json # vcpkg registry configuration
├── vcpkg_ports/             # Local vcpkg port overlay
│   └── microsoft-windows-ai-machinelearning/
│       ├── portfile.cmake   # Package download and install script
│       ├── vcpkg.json       # Port metadata
│       └── usage            # CMake integration instructions
├── build.ps1                # Build helper script
├── build.cmd                # Batch wrapper for build.ps1
└── README.md                # This file
```

## Prerequisites

- **Visual Studio 2022** with C++ development workload
- **CMake** 3.21 or later
- **vcpkg** (will be configured automatically if `VCPKG_ROOT` is set)
- **Ninja** (optional; required only when using the Ninja generator)

### Installing Prerequisites

```powershell
# Install CMake
winget install Kitware.CMake

# Install Ninja (optional)
winget install Ninja-build.Ninja

# Clone and bootstrap vcpkg
git clone https://github.com/microsoft/vcpkg.git C:\vcpkg
C:\vcpkg\bootstrap-vcpkg.bat
$env:VCPKG_ROOT = "C:\vcpkg"
```

## Building

### Using the Build Script (Recommended)

The included PowerShell script handles all build steps:

```powershell
# Build Debug for current platform (auto-detected)
.\build.ps1

# Build with the Visual Studio generator (no Ninja required)
.\build.ps1 -Generator VisualStudio

# Require Ninja (fails if Ninja is not installed)
.\build.ps1 -Generator Ninja

# Build Release for x64
.\build.ps1 -Configuration Release -Platform x64

# Build Debug for ARM64
.\build.ps1 -Configuration Debug -Platform arm64

# Clean and rebuild
.\build.ps1 -Clean
```

### Manual Build Steps

If you prefer manual control:

```powershell
# 1. Set vcpkg root (if not already in environment)
$env:VCPKG_ROOT = "C:\path\to\vcpkg"

# 2. Configure with CMake preset
cmake --preset x64-debug

# Or configure with Visual Studio generator preset
cmake --preset x64-debug-vs

# 3. Build
cmake --build out/build/x64-debug

# Or for Visual Studio generator:
cmake --build out/build/x64-debug-vs --config Debug

# 4. Run
.\out\build\x64-debug\WinMLEpCatalogSample.exe
```

### Visual Studio

You can also open this folder directly in Visual Studio 2022:

1. Open Visual Studio 2022
2. Select **File > Open > Folder**
3. Navigate to the `WinMLEpCatalog` directory
4. Visual Studio will detect `CMakePresets.json` and configure automatically
5. Select the desired preset from the configuration dropdown
6. Build with **Build > Build All** (Ctrl+Shift+B)

## Running the Sample

After building, run the executable:

```
.\out\build\x64-debug\WinMLEpCatalogSample.exe
```

### Interactive Shell Commands

The sample provides an interactive shell for exploring the API:

| Command | Description |
|---------|-------------|
| `help` | Show available commands |
| `list` | List all registered execution providers |
| `select <#>` | Select a provider by index number |
| `info` | Show detailed info for selected provider |
| `ensure` | Prepare selected provider (async with progress) |
| `ensure-sync` | Prepare selected provider (synchronous) |
| `path` | Show library and package paths |
| `exit` | Exit the program |

### Example Session

```
==========================================
  Windows ML Execution Provider Catalog   
           Flat-C API Sample              
==========================================
Catalog created successfully.

========================================
  WinML EP Catalog - Interactive Shell  
========================================
Type 'help' for available commands.

  #  Name                           State        Version     
------------------------------------------------------------
  0  ContosoExecutionProvider       NotReady     1.0.0       

Total: 1 provider(s)

winml> select 0
Selected: ContosoExecutionProvider

winml [ContosoExecutionProvider]> info

Execution Provider Info:
  Name:                 ContosoExecutionProvider
  Version:              1.0.0
  Package Family Name:  Microsoft.AI.MachineLearning.Contoso_8wekyb3d8bbwe
  Ready State:          NotReady
  Certification:        Certified

winml [ContosoExecutionProvider]> ensure
Ensuring 'ContosoExecutionProvider' is ready (asynchronous)...
  (Press ESC to cancel)
  [==============================] 100%
Result:
  Status: S_OK
  Library Path:      C:\Program Files\WindowsApps\...\onnxruntime_contoso.dll
  Package Root Path: C:\Program Files\WindowsApps\...

winml [ContosoExecutionProvider]> exit
Goodbye.
```

## API Reference

### Catalog Management

| Function | Description |
|----------|-------------|
| `WinMLEpCatalogCreate()` | Create a catalog instance |
| `WinMLEpCatalogRelease()` | Release catalog resources |
| `WinMLEpCatalogEnumProviders()` | Enumerate all providers via callback |
| `WinMLEpCatalogFindProvider()` | Find a specific provider by name |

### Provider Operations

| Function | Description |
|----------|-------------|
| `WinMLEpEnsureReady()` | Synchronously prepare a provider |
| `WinMLEpEnsureReadyAsync()` | Start async preparation |
| `WinMLEpEnsureReadyResult()` | Get async operation result |
| `WinMLEpGetLibraryPath()` | Get provider DLL path |
| `WinMLEpGetPackageRootPath()` | Get package root directory |

### Async Operations

| Function | Description |
|----------|-------------|
| `WinMLAsyncGetStatus()` | Poll async operation status |
| `WinMLAsyncCancel()` | Request cancellation |
| `WinMLAsyncClose()` | Release async operation resources |

## Updating the Package Version

The Windows ML package version is defined in the vcpkg overlay port. To update:

1. Open `vcpkg_ports/microsoft-windows-ai-machinelearning/portfile.cmake`
2. Find the `WINML_EXPERIMENTAL_VERSION` variable near the top
3. Update to the new version:
   ```cmake
   set(WINML_EXPERIMENTAL_VERSION "2.0.228-experimental")
   ```
4. Delete the `out/` directory and rebuild

## Troubleshooting

### "Failed to create EP catalog"

This typically means:
- Windows ML runtime DLLs are not in the application directory
- Windows version is not supported (requires Windows 11 24H2+)
- The `winml_copy_runtime_dlls()` CMake function did not run

**Solution:** Ensure the build completed successfully and DLLs were copied to the output directory.

### "vcpkg not found"

**Solution:** Set the `VCPKG_ROOT` environment variable:
```powershell
$env:VCPKG_ROOT = "C:\path\to\vcpkg"
```

### Build fails with "package not found"

The overlay port may not be found. Ensure you're building from the sample directory:
```powershell
cd samples\WindowsAppSDK-Samples\Samples\WindowsML\cmake\WinMLEpCatalog
.\build.ps1
```
