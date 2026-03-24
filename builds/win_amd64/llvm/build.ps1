# Build LLVM 21.1.8 from source for win_amd64.
# Installs to C:\hugrverse\llvm.
[CmdletBinding()]
param()
$ErrorActionPreference = "Stop"

$LlvmVersion = "21.1.8"
$LlvmTag = "llvmorg-$LlvmVersion"
$InstallPrefix = "C:\hugrverse\llvm"
$BuildDir = "C:\Temp\llvm-build"
$Tarball = "llvm-project-$LlvmVersion.src.tar.xz"

Write-Host "=== Installing build dependencies ==="
# cmake and ninja are available in the Visual Studio environment;
# ensure they are on the PATH via the VS Developer Shell.
if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
    choco install cmake --installargs 'ADD_CMAKE_TO_PATH=System' -y
}
if (-not (Get-Command ninja -ErrorAction SilentlyContinue)) {
    choco install ninja -y
}

Write-Host "=== Downloading LLVM $LlvmVersion source ==="
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
Push-Location $BuildDir

if (-not (Test-Path $Tarball)) {
    $Url = "https://github.com/llvm/llvm-project/releases/download/$LlvmTag/$Tarball"
    Invoke-WebRequest -Uri $Url -OutFile $Tarball
}

Write-Host "=== Extracting source ==="
$SourceDir = "llvm-project-$LlvmVersion.src"
if (-not (Test-Path $SourceDir)) {
    & tar xf $Tarball
}

Write-Host "=== Configuring LLVM ==="
$BuildSubDir = Join-Path $BuildDir "build"
New-Item -ItemType Directory -Force -Path $BuildSubDir | Out-Null

$LlvmSrc = Join-Path $BuildDir "$SourceDir\llvm"
cmake `
    -S $LlvmSrc `
    -B $BuildSubDir `
    -G Ninja `
    -DCMAKE_BUILD_TYPE=Release `
    -DCMAKE_INSTALL_PREFIX="$InstallPrefix" `
    -DLLVM_TARGETS_TO_BUILD="AArch64;X86" `
    -DLLVM_BUILD_TOOLS=ON `
    -DLLVM_INCLUDE_TESTS=OFF `
    -DLLVM_INCLUDE_EXAMPLES=OFF `
    -DLLVM_INCLUDE_BENCHMARKS=OFF `
    -DLLVM_ENABLE_ASSERTIONS=OFF `
    -DLLVM_ENABLE_ZLIB=OFF `
    -DLLVM_ENABLE_ZSTD=OFF `
    -DLLVM_ENABLE_LIBXML2=OFF

if ($LASTEXITCODE -ne 0) { throw "cmake configure failed" }

Write-Host "=== Building and installing LLVM (this may take a while) ==="
$Jobs = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
cmake --build $BuildSubDir --target install -- -j $Jobs
if ($LASTEXITCODE -ne 0) { throw "cmake build failed" }

Pop-Location
Write-Host "=== LLVM $LlvmVersion installed to $InstallPrefix ==="
