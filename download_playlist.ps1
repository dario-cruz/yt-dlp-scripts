param (
    [string]$PlaylistUrl,
    [string]$DestinationDir = "G:\My Drive\01 - DJ Files\Tracks",
    [switch]$AutoMove,
    [switch]$NoMove,
    [switch]$SkipUpdate
)

if ([string]::IsNullOrWhiteSpace($PlaylistUrl)) {
    $PlaylistUrl = Read-Host "Please enter the YouTube playlist URL"
}

if ([string]::IsNullOrWhiteSpace($PlaylistUrl)) {
    Write-Host "No URL provided. Exiting." -ForegroundColor Red
    exit 1
}

# Set the working directory to the script's directory so it finds the exe and js files
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location -Path $ScriptDir

Write-Host "Downloading playlist: $PlaylistUrl" -ForegroundColor Cyan

# Locate or automatically download yt-dlp executable
$ytDlpCmd = $null
if (Test-Path -LiteralPath "$ScriptDir\yt-dlp.exe") {
    $ytDlpCmd = "$ScriptDir\yt-dlp.exe"
} elseif (Get-Command yt-dlp -ErrorAction SilentlyContinue) {
    $ytDlpCmd = "yt-dlp"
} elseif (Test-Path -LiteralPath "C:\yt-dlp\yt-dlp.exe") {
    $ytDlpCmd = "C:\yt-dlp\yt-dlp.exe"
} else {
    Write-Host "yt-dlp executable not found. Downloading the latest version from GitHub..." -ForegroundColor Yellow
    try {
        $ProgressPreference = 'SilentlyContinue'
        $downloadUrl = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
        Invoke-WebRequest -Uri $downloadUrl -OutFile "$ScriptDir\yt-dlp.exe" -UseBasicParsing
        Write-Host "Downloaded latest yt-dlp.exe successfully into '$ScriptDir'." -ForegroundColor Green
        $ytDlpCmd = "$ScriptDir\yt-dlp.exe"
    } catch {
        Write-Host "Error: Could not download yt-dlp.exe: $_" -ForegroundColor Red
        Write-Host "Please place yt-dlp.exe in '$ScriptDir' or install it to your system PATH." -ForegroundColor Yellow
        exit 1
    }
}

# Check for yt-dlp updates and update automatically
if (-not $SkipUpdate) {
    Write-Host "Checking for yt-dlp updates..." -ForegroundColor Cyan
    try {
        & $ytDlpCmd -U
        # If legacy C:\yt-dlp folder exists, keep it in sync with the updated binary
        if (Test-Path -LiteralPath "C:\yt-dlp\yt-dlp.exe") {
            $localExe = Resolve-Path "$ScriptDir\yt-dlp.exe" -ErrorAction SilentlyContinue
            $legacyExe = Resolve-Path "C:\yt-dlp\yt-dlp.exe" -ErrorAction SilentlyContinue
            if ($localExe -and $legacyExe -and ($localExe.Path -ne $legacyExe.Path)) {
                Copy-Item -LiteralPath "$ScriptDir\yt-dlp.exe" -Destination "C:\yt-dlp\yt-dlp.exe" -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-Host "Warning: Could not check for yt-dlp updates ($($_)). Continuing with current version..." -ForegroundColor Yellow
    }
}

# Run yt-dlp
& $ytDlpCmd -x --audio-format mp3 --audio-quality 0 --embed-metadata --embed-thumbnail --yes-playlist -o "%(title)s - %(uploader)s.%(ext)s" $PlaylistUrl

if ($LASTEXITCODE -ne 0) {
    Write-Host "yt-dlp encountered an error. Exiting." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Download complete. Processing files with Node scripts..." -ForegroundColor Cyan

# Ensure node dependencies are installed
if (-not (Test-Path -LiteralPath "$ScriptDir\node_modules")) {
    Write-Host "Node modules not found. Installing dependencies via npm..." -ForegroundColor Yellow
    npm --prefix "$ScriptDir" install
}

Write-Host "Running update_genres.js..." -ForegroundColor Yellow
node .\update_genres.js

Write-Host "Running crop_covers.js..." -ForegroundColor Yellow
node .\crop_covers.js

Write-Host "Running remove_topic.js..." -ForegroundColor Yellow
node .\remove_topic.js

Write-Host "All processing complete!" -ForegroundColor Green

# -------------------------------------------------------------
# Move tracks to destination folder (for Rekordbox Auto Import)
# -------------------------------------------------------------
$shouldMove = $false

if ($NoMove) {
    $shouldMove = $false
} elseif ($AutoMove) {
    $shouldMove = $true
} else {
    while ($true) {
        Write-Host "`nTrack Processing Complete." -ForegroundColor Cyan
        Write-Host "Current Destination: '$DestinationDir'" -ForegroundColor Gray
        Write-Host "  [Y] Move tracks to destination folder (Default)" -ForegroundColor White
        Write-Host "  [C] Change destination folder" -ForegroundColor White
        Write-Host "  [N] Don't move (keep tracks in working folder)" -ForegroundColor White
        $choice = Read-Host "Choose an option [Y/c/n] (Default: Y)"
        $choice = $choice.Trim().ToLower()

        if ([string]::IsNullOrWhiteSpace($choice) -or $choice -in 'y', 'yes') {
            $shouldMove = $true
            break
        } elseif ($choice -in 'c', 'change') {
            $newDest = Read-Host "Enter new destination folder path"
            if (-not [string]::IsNullOrWhiteSpace($newDest)) {
                $DestinationDir = $newDest.Trim('"', "'").Trim()
                Write-Host "Destination updated to: '$DestinationDir'" -ForegroundColor Green
                $shouldMove = $true
                break
            } else {
                Write-Host "No path entered. Keeping '$DestinationDir'." -ForegroundColor Yellow
            }
        } elseif ($choice -in 'n', 'no') {
            $shouldMove = $false
            break
        } else {
            Write-Host "Invalid option. Please choose Y, C, or N." -ForegroundColor Yellow
        }
    }
}

if ($shouldMove) {
    # Check if destination directory exists or needs creation
    if (-not (Test-Path -LiteralPath $DestinationDir)) {
        $driveQualifier = Split-Path -Path $DestinationDir -Qualifier
        if (-not [string]::IsNullOrWhiteSpace($driveQualifier) -and -not (Test-Path -LiteralPath "$driveQualifier\")) {
            Write-Host "Drive '$driveQualifier\' is not accessible. Please ensure your Google Drive or external drive is connected." -ForegroundColor Red
            Write-Host "Tracks will remain in '$ScriptDir'." -ForegroundColor Yellow
            $shouldMove = $false
        } else {
            try {
                New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
                Write-Host "Created destination folder: $DestinationDir" -ForegroundColor Green
            } catch {
                Write-Host "Could not create destination directory '$DestinationDir': $_" -ForegroundColor Red
                $shouldMove = $false
            }
        }
    }
}

if ($shouldMove) {
    $mp3Files = Get-ChildItem -LiteralPath $ScriptDir -Filter "*.mp3" -File

    if ($mp3Files.Count -eq 0) {
        Write-Host "No MP3 files found in '$ScriptDir' to move." -ForegroundColor Yellow
    } else {
        Write-Host "`nMoving $($mp3Files.Count) track(s) to '$DestinationDir'..." -ForegroundColor Cyan

        $movedCount = 0
        $skippedCount = 0
        $overwriteAll = $false
        $skipAll = $false

        foreach ($file in $mp3Files) {
            $targetPath = Join-Path -Path $DestinationDir -ChildPath $file.Name
            $destinationExists = Test-Path -LiteralPath $targetPath
            $shouldOverwriteFile = $true

            if ($destinationExists) {
                if ($overwriteAll) {
                    $shouldOverwriteFile = $true
                } elseif ($skipAll) {
                    $shouldOverwriteFile = $false
                } else {
                    Write-Host "`nTrack already exists in destination:" -ForegroundColor Yellow
                    Write-Host "  File: $($file.Name)" -ForegroundColor DarkGray
                    $choice = Read-Host "Overwrite existing file? [Y]es / [N]o / [A]ll / [S]kip all (Default: N)"
                    $choice = $choice.Trim().ToLower()

                    switch ($choice) {
                        { $_ -in 'y', 'yes' } {
                            $shouldOverwriteFile = $true
                        }
                        { $_ -in 'a', 'all' } {
                            $shouldOverwriteFile = $true
                            $overwriteAll = $true
                        }
                        { $_ -in 's', 'skip', 'skip all' } {
                            $shouldOverwriteFile = $false
                            $skipAll = $true
                        }
                        default {
                            $shouldOverwriteFile = $false
                        }
                    }
                }
            }

            if ($destinationExists -and -not $shouldOverwriteFile) {
                Write-Host "Skipped: '$($file.Name)' (kept existing in destination)" -ForegroundColor DarkGray
                $skippedCount++
                continue
            }

            try {
                if ($destinationExists) {
                    Remove-Item -LiteralPath $targetPath -Force
                }
                Move-Item -LiteralPath $file.FullName -Destination $targetPath -Force
                Write-Host "Moved: '$($file.Name)'" -ForegroundColor Green
                $movedCount++
            } catch {
                Write-Host "Failed to move '$($file.Name)': $_" -ForegroundColor Red
            }
        }

        Write-Host "`nDone! Summary: $movedCount track(s) moved, $skippedCount skipped." -ForegroundColor Green
    }
} else {
    Write-Host "Tracks will remain in '$ScriptDir'." -ForegroundColor DarkGray
}
