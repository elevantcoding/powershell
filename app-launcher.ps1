# Load forms assembly
Add-Type -AssemblyName System.Windows.Forms

# Function to get file checksum
function Get-FileChecksum {
    param ([string]$filePath)
    
    $hashOutput = certutil -hashfile $filePath SHA256
    return $hashOutput[1]  # Extract only the hash value
}

# Function to copy file with progress and verification
function Copy-FileWithVerification {
    param (
        [string]$source,
        [string]$destination
    )

    $maxRetries = 3
    $retryCount = 0
    $success = $false

    while (-not $success -and $retryCount -lt $maxRetries) {
        Write-Host "Copying file... (Attempt $($retryCount + 1)/$maxRetries)" -ForegroundColor Yellow

        # File size for progress tracking
        $fileSize = (Get-Item $source).Length
        $bufferSize = 1MB
        $bytesCopied = 0

        # Open file streams
        $sourceStream = [System.IO.File]::OpenRead($source)
        $destStream = [System.IO.File]::Create($destination)

        $buffer = New-Object byte[] $bufferSize
        $read = 0

        while (($read = $sourceStream.Read($buffer, 0, $bufferSize)) -gt 0) {
            $destStream.Write($buffer, 0, $read)
            $bytesCopied += $read

            # Update progress bar
            $percentComplete = ($bytesCopied / $fileSize) * 100
            Write-Progress -Activity "Copying File..." -PercentComplete $percentComplete -Status "$([math]::Round($percentComplete, 2))% Complete"
        }

        # Close file streams
        $sourceStream.Close()
        $destStream.Close()

        # Verify checksum
        if ((Get-FileChecksum -filePath $source) -eq (Get-FileChecksum -filePath $destination)) {
            Write-Host "File copied successfully!" -ForegroundColor Green
            $success = $true
        } else {
            Write-Host "Copy file verification did not succeed, retrying..." -ForegroundColor Red
            $retryCount++
            Start-Sleep -Seconds 2
        }
    }

    return $success
}


# begin 
# define user profile path
$localPath = "$env:USERPROFILE\Documents\SampleApp\"

# Ensure the directory exists
if (!(Test-Path $localPath)) {
    New-Item -ItemType Directory -Path $localPath -Force
    Write-Host "Created Directory: $localPath"
}

# clean up folder on userprofile / housekeeping / optional
$removeFileTypes = @("*.jpg", "*.copied", "*.bat", "*.ps1")
foreach ($file in $removeFileTypes) {
    Get-ChildItem -Path $localPath -Filter $file -ErrorAction SilentlyContinue |
    ForEach-Object {
        try {
                Remove-Item $_.FullName -Force -ErrorAction Stop
                Write-Host "Removed: $($_.Name)" -ForegroundColor Cyan
            }
            catch {
                Write-Host "Could not remove: $($_.Name): $_" -ForegroundColor DarkMagenta
            }
    }
}

# find newest .accde in local folder
$localFile = $null
$localFile = Get-ChildItem -Path $localPath -Filter *.accde |
Sort-Object LastWriteTime -Descending |
Select-Object -First 1
$localFilePath = if ($localFile) { $localFile.FullName } else { $null }

# Get Current UserName
$user = $env:USERNAME

# Determine source directory for update file
$qUsers = @("admin1","admin2", "admin3")

if ($qUsers -contains $user) {
    $sourcePath = "$env:USERPROFILE\OneDrive\SourceFileLocation1\"
} else {
    $sourcePath = "$env:USERPROFILE\OneDrive\SourceFileLocation2\"
}


# Determine availability of $sourcePath and get name of .accde file
$sourceFile = $null
if (Test-Path $sourcePath) {
    $sourceFile = Get-ChildItem -Path $sourcePath -Filter "*.accde" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
    $sourceFilePath = if ($sourceFile) { $sourceFile.FullName } else { $null }
}

if ($localFile -and (-not $sourceFile -or $sourceFile.Name -eq $localFile.Name)) {
    Start-Process -FilePath $localFile.FullName
    Exit
}

if ($sourceFile -and (!$localFile -or $sourceFile.Name -ne $localFile.Name)) {    
    
    #delete any .laccd or .accd files from local
    Remove-Item (Join-Path $localPath "*.accde") -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $localPath "*.laccdb") -ErrorAction SilentlyContinue

        # build the new file path
        $localFileCopy = Join-Path $localPath $sourceFile.Name
        
        #use I/O stream to copy file from $sourceFilePath
        #checksum verify
        #Copy and verify the new file
        
        if (Copy-FileWithVerification -source $sourceFilePath -destination $localFileCopy) {
            Start-Process -FilePath $localFileCopy
            Exit
        } else {
        [System.Windows.Forms.MessageBox]::Show("File copy did not succeed after multiple attempts.  Exiting.", "App Launcher",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Exclamation)
        Exit
        }
}

If (-not $sourceFile -and -not $localFile) {
    [System.Windows.Forms.MessageBox]::Show("No source or local .accde file available.  Exiting.","App Launcher",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Exclamation)
    Exit
}
