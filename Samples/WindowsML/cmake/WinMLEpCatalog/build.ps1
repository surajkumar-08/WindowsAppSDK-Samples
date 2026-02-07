# Copyright (C) Microsoft Corporation. All rights reserved.
<#
.SYNOPSIS
    Builds the WinML EP Catalog Sample using CMake and vcpkg.

.DESCRIPTION
    This script automates the build process for the WinMLEpCatalog sample.
    It handles:
    - Checking prerequisites (CMake, vcpkg, Visual Studio)
    - Setting up VCPKG_ROOT if not already configured
    - Configuring and building the project using CMake presets

.PARAMETER Configuration
    Build configuration: Debug or Release. Default: Debug

.PARAMETER Platform
    Target platform: x64 or arm64. Default: Auto-detect from host

.PARAMETER Generator
    Build generator: Auto, Ninja, or VisualStudio. Default: Auto (uses Ninja if installed)

.PARAMETER VcpkgRoot
    Path to vcpkg installation. Default: Uses VCPKG_ROOT environment variable

.PARAMETER Clean
    If specified, removes the build directory before building.

.EXAMPLE
    .\build.ps1
    # Builds Debug configuration for the current platform

.EXAMPLE
    .\build.ps1 -Configuration Release -Platform arm64
    # Builds Release configuration for ARM64

.EXAMPLE
    .\build.ps1 -Generator VisualStudio
    # Builds using the Visual Studio generator (no Ninja required)

.EXAMPLE
    .\build.ps1 -Clean -Configuration Debug
    # Cleans and rebuilds Debug configuration
#>

[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',
    
    [ValidateSet('x64', 'arm64')]
    [string]$Platform,

    [ValidateSet('Auto', 'Ninja', 'VisualStudio')]
    [string]$Generator = 'Auto',
    
    [string]$VcpkgRoot,
    
    [switch]$Clean
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# ============================================================================
# Helper Functions
# ============================================================================

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-HostArchitecture {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    switch ($arch) {
        'X64' { return 'x64' }
        'Arm64' { return 'arm64' }
        default { return 'x64' }
    }
}

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "[*] $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Enter-VsDevEnvironment {
    param([string]$Arch)
    
    # Find Visual Studio installation
    $vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswherePath)) {
        $vswherePath = "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe"
    }
    
    if (-not (Test-Path $vswherePath)) {
        Write-ErrorMessage "vswhere not found. Please install Visual Studio 2022 or later."
        return $false
    }
    
    $vsPath = & $vswherePath -latest -property installationPath
    if (-not $vsPath) {
        Write-ErrorMessage "Visual Studio installation not found."
        return $false
    }
    
    $devShellModule = Join-Path $vsPath "Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
    if (-not (Test-Path $devShellModule)) {
        Write-ErrorMessage "VS DevShell module not found at: $devShellModule"
        return $false
    }
    
    Write-Host "  Visual Studio: $vsPath"
    
    # Import the DevShell module and enter the environment
    Import-Module $devShellModule
    Enter-VsDevShell -VsInstallPath $vsPath -DevCmdArguments "-arch=$Arch" -SkipAutomaticLocation
    
    return $true
}

# ============================================================================
# Main Script
# ============================================================================

Write-Header "WinML EP Catalog Sample Build"

# Auto-detect platform if not specified
if (-not $Platform) {
    $Platform = Get-HostArchitecture
    Write-Host "Auto-detected platform: $Platform"
}

# Select generator
if ($Generator -eq 'Auto') {
    if (Test-CommandExists 'ninja') {
        $Generator = 'Ninja'
    }
    else {
        $Generator = 'VisualStudio'
    }
}

# Determine preset name
$presetSuffix = if ($Generator -eq 'VisualStudio') { '-vs' } else { '' }
$PresetName = "$Platform-$($Configuration.ToLower())$presetSuffix"
Write-Host "Build preset: $PresetName"
Write-Host "Generator: $Generator"

# ============================================================================
# Check Prerequisites
# ============================================================================

Write-Step "Checking prerequisites..."

# Check CMake
if (-not (Test-CommandExists 'cmake')) {
    Write-ErrorMessage "CMake not found. Please install CMake 3.21 or later."
    Write-Host "  Install with: winget install Kitware.CMake" -ForegroundColor Gray
    exit 1
}

$cmakeVersion = (cmake --version | Select-Object -First 1)
Write-Host "  CMake: $cmakeVersion"

# Check Ninja
if ($Generator -eq 'Ninja') {
    if (Test-CommandExists 'ninja') {
        $ninjaVersion = (ninja --version)
        Write-Host "  Ninja: $ninjaVersion"
    }
    else {
        Write-ErrorMessage "Ninja not found. Install Ninja or use -Generator VisualStudio."
        exit 1
    }
}
else {
    if (Test-CommandExists 'ninja') {
        $ninjaVersion = (ninja --version)
        Write-Host "  Ninja: $ninjaVersion (not required for Visual Studio generator)"
    }
    else {
        Write-Host "  Ninja: Not required (using Visual Studio generator)" -ForegroundColor Yellow
    }
}

# Check vcpkg
if ($VcpkgRoot) {
    $env:VCPKG_ROOT = $VcpkgRoot
}

# Always try to find the windows-ml submodule vcpkg first (preferred)
$windowsMlVcpkg = Resolve-Path "$PSScriptRoot\..\..\..\..\..\..\external\vcpkg" -ErrorAction SilentlyContinue
if ($windowsMlVcpkg -and (Test-Path "$windowsMlVcpkg\vcpkg.exe")) {
    $env:VCPKG_ROOT = $windowsMlVcpkg.Path
    Write-Host "  Using windows-ml vcpkg: $env:VCPKG_ROOT"
}
elseif (-not $env:VCPKG_ROOT -or -not (Test-Path "$env:VCPKG_ROOT\vcpkg.exe")) {
    # Try to find vcpkg in common locations
    $possiblePaths = @(
        "$env:USERPROFILE\vcpkg",
        "C:\vcpkg",
        "C:\src\vcpkg"
    )
    
    foreach ($path in $possiblePaths) {
        $resolvedPath = Resolve-Path $path -ErrorAction SilentlyContinue
        if ($resolvedPath -and (Test-Path "$resolvedPath\vcpkg.exe")) {
            $env:VCPKG_ROOT = $resolvedPath.Path
            Write-Host "  Found vcpkg at: $env:VCPKG_ROOT"
            break
        }
    }
}

if (-not $env:VCPKG_ROOT -or -not (Test-Path "$env:VCPKG_ROOT\vcpkg.exe")) {
    Write-ErrorMessage "vcpkg not found. Please set VCPKG_ROOT or use -VcpkgRoot parameter."
    Write-Host "  To install vcpkg:" -ForegroundColor Gray
    Write-Host "    git clone https://github.com/microsoft/vcpkg.git" -ForegroundColor Gray
    Write-Host "    .\vcpkg\bootstrap-vcpkg.bat" -ForegroundColor Gray
    Write-Host "    set VCPKG_ROOT=<path-to-vcpkg>" -ForegroundColor Gray
    exit 1
}

Write-Host "  VCPKG_ROOT: $env:VCPKG_ROOT"

# Bootstrap vcpkg if needed
if (-not (Test-Path "$env:VCPKG_ROOT\vcpkg.exe")) {
    Write-Step "Bootstrapping vcpkg..."
    Push-Location $env:VCPKG_ROOT
    try {
        & .\bootstrap-vcpkg.bat
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMessage "Failed to bootstrap vcpkg"
            exit 1
        }
    }
    finally {
        Pop-Location
    }
}

Write-Success "Prerequisites check passed"

# Save VCPKG_ROOT before entering VS environment (VS may override it)
$savedVcpkgRoot = $env:VCPKG_ROOT

# ============================================================================
# Set up Visual Studio Developer Environment
# ============================================================================

Write-Step "Setting up Visual Studio Developer environment..."

if (-not (Enter-VsDevEnvironment -Arch $Platform)) {
    Write-ErrorMessage "Failed to set up Visual Studio environment"
    exit 1
}

# Restore VCPKG_ROOT (VS environment may have changed it)
$env:VCPKG_ROOT = $savedVcpkgRoot
Write-Host "  VCPKG_ROOT: $env:VCPKG_ROOT"

Write-Success "VS Developer environment configured for $Platform"

# ============================================================================
# Clean (if requested)
# ============================================================================

if ($Clean) {
    Write-Step "Cleaning build directory..."
    $buildDir = Join-Path $PSScriptRoot "out"
    if (Test-Path $buildDir) {
        Remove-Item -Recurse -Force $buildDir
        Write-Host "  Removed: $buildDir"
    }
}

# ============================================================================
# Configure
# ============================================================================

Write-Step "Configuring with CMake preset: $PresetName"

Push-Location $PSScriptRoot
try {
    & cmake --preset $PresetName
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "CMake configuration failed"
        exit 1
    }
    Write-Success "Configuration complete"
}
finally {
    Pop-Location
}

# ============================================================================
# Build
# ============================================================================

Write-Step "Building..."

Push-Location $PSScriptRoot
try {
    $buildArgs = @("out/build/$PresetName")
    if ($Generator -eq 'VisualStudio') {
        $buildArgs += @('--config', $Configuration)
    }

    & cmake --build @buildArgs
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Build failed"
        exit 1
    }
    Write-Success "Build complete"
}
finally {
    Pop-Location
}

# ============================================================================
# Output Information
# ============================================================================

Write-Header "Build Successful"

$exePath = if ($Generator -eq 'VisualStudio') {
    Join-Path $PSScriptRoot "out\build\$PresetName\$Configuration\WinMLEpCatalogSample.exe"
} else {
    Join-Path $PSScriptRoot "out\build\$PresetName\WinMLEpCatalogSample.exe"
}
if (Test-Path $exePath) {
    Write-Host ""
    Write-Host "Output: $exePath" -ForegroundColor Green
    Write-Host ""
    Write-Host "To run the sample:" -ForegroundColor Cyan
    Write-Host "  $exePath"
    Write-Host ""
}

exit 0
