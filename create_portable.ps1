# Script to create a portable distribution of the Flutter Windows app
# This copies all necessary files to a single folder that can be distributed

$sourceDir = "build\windows\x64\runner\Release"
$destDir = "wheel_portable"

Write-Host "Creating portable distribution..."

# Create destination directory
if (Test-Path $destDir) {
    Remove-Item $destDir -Recurse -Force
}
New-Item -ItemType Directory -Path $destDir | Out-Null

# Copy executable
Copy-Item "$sourceDir\wheel.exe" -Destination $destDir

# Copy DLLs
Copy-Item "$sourceDir\*.dll" -Destination $destDir

# Copy data folder
Copy-Item "$sourceDir\data" -Destination $destDir -Recurse

Write-Host "Portable distribution created in: $destDir"
Write-Host "You can distribute this entire folder - all files must stay together!"
