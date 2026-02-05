# Convert PNG to ICO using .NET System.Drawing
Add-Type -AssemblyName System.Drawing

$inputFile = "assets/images/roulette.png"
$outputFile = "windows/runner/resources/app_icon.ico"

try {
    $bitmap = New-Object System.Drawing.Bitmap($inputFile)
    
    # Create a MemoryStream to hold the ICO data
    $icoStream = New-Object System.IO.MemoryStream
    
    # Create ICO header
    $icoStream.Write([byte[]](0, 0, 1, 0, 6, 0), 0, 6) # ICO header: reserved(2), type(2), count(2)
    
    $offset = 22 # Header size + 6 entries * 16 bytes each
    
    # Write directory entries for different sizes
    $sizes = @(16, 32, 48, 64, 128, 256)
    foreach ($size in $sizes) {
        $resized = New-Object System.Drawing.Bitmap($bitmap, $size, $size)
        $pngStream = New-Object System.IO.MemoryStream
        $resized.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
        $pngBytes = $pngStream.ToArray()
        $pngStream.Dispose()
        $resized.Dispose()
        
        # Write directory entry (use 0 for width/height if size is 256)
        $widthByte = if ($size -eq 256) { [byte]0 } else { [byte]$size }
        $heightByte = if ($size -eq 256) { [byte]0 } else { [byte]$size }
        $icoStream.Write([byte[]]($widthByte, $heightByte, 0, 0, 1, 0, 32, 0), 0, 8)
        $icoStream.Write([System.BitConverter]::GetBytes([int32]$pngBytes.Length), 0, 4)
        $icoStream.Write([System.BitConverter]::GetBytes([int32]$offset), 0, 4)
        
        $offset += $pngBytes.Length
    }
    
    # Write PNG data for each size
    foreach ($size in $sizes) {
        $resized = New-Object System.Drawing.Bitmap($bitmap, $size, $size)
        $pngStream = New-Object System.IO.MemoryStream
        $resized.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
        $pngBytes = $pngStream.ToArray()
        $icoStream.Write($pngBytes, 0, $pngBytes.Length)
        $pngStream.Dispose()
        $resized.Dispose()
    }
    
    # Save ICO file
    [System.IO.File]::WriteAllBytes($outputFile, $icoStream.ToArray())
    $icoStream.Dispose()
    $bitmap.Dispose()
    
    Write-Host "Successfully converted $inputFile to $outputFile"
} catch {
    Write-Host "Error: $_"
    exit 1
}
