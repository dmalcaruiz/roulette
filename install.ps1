# Installation script for wheel app
# This installs the app to a proper location on your PC

$sourceDir = "build\windows\x64\runner\Release"
$installDir = "$env:LOCALAPPDATA\wheel"

Write-Host "Installing wheel to: $installDir"

# Create installation directory
if (Test-Path $installDir) {
    Write-Host "Removing existing installation..."
    Remove-Item $installDir -Recurse -Force
}
New-Item -ItemType Directory -Path $installDir | Out-Null

# Copy all files from Release folder
Write-Host "Copying files..."
Copy-Item "$sourceDir\*" -Destination $installDir -Recurse -Force

Write-Host ""
Write-Host "Installation complete!"
Write-Host "App installed to: $installDir"
Write-Host ""
Write-Host "To run the app, execute: $installDir\wheel.exe"
Write-Host ""
Write-Host "Would you like to create a desktop shortcut? (Y/N)"
$response = Read-Host
if ($response -eq "Y" -or $response -eq "y") {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\wheel.lnk")
    $Shortcut.TargetPath = "$installDir\wheel.exe"
    $Shortcut.WorkingDirectory = $installDir
    $Shortcut.Save()
    Write-Host "Desktop shortcut created!"
}
