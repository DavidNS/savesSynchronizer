Add-Type -AssemblyName 'System.Windows.Forms'

# Get folder where the EXE is running from (for compiled .exe)
$exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$scriptDirectory = [System.IO.Path]::GetDirectoryName($exePath)
$configFilePath = Join-Path $scriptDirectory "config.txt"

# Load config.txt key=value pairs
function Load-Config {
    $config = @{}
    if (Test-Path $configFilePath) {
        $lines = Get-Content $configFilePath
        foreach ($line in $lines) {
            if ($line -match "^\s*(\S+)\s*=\s*(.+?)\s*$") {
                $config[$matches[1]] = $matches[2]
            }
        }
    } else {
        Write-Host "❌ Config file not found at $configFilePath"
        exit
    }
    return $config
}

$config = Load-Config

# Validate config keys
$requiredKeys = @(
    'baseSaveName',
    'googleDriveFolder',
    'steamSaveFolder',
    'healthCheckInterval',
    'gameProcessName',
    'gameLaunchUri'
)

foreach ($key in $requiredKeys) {
    if (-not $config.ContainsKey($key)) {
        Write-Host "❌ Missing required key in config: $key"
        exit
    }
}

# Assign config variables
$baseSaveName       = $config['baseSaveName']
$googleDriveFolder  = $config['googleDriveFolder']
$steamSaveFolder    = $config['steamSaveFolder']
$healthCheckInterval = [int]$config['healthCheckInterval']
$gameProcessName    = $config['gameProcessName']
$gameLaunchUri      = $config['gameLaunchUri']

Write-Host "`n🔧 Loaded Configuration:"
Write-Host " - baseSaveName: $baseSaveName"
Write-Host " - googleDriveFolder: $googleDriveFolder"
Write-Host " - steamSaveFolder: $steamSaveFolder"
Write-Host " - healthCheckInterval: $healthCheckInterval"
Write-Host " - gameProcessName: $gameProcessName"
Write-Host " - gameLaunchUri: $gameLaunchUri"
Write-Host ""

# Compare and sync cloud save to Steam if needed
$steamSaves = Get-ChildItem -Path $steamSaveFolder -Filter "$baseSaveName*.sav" | Sort-Object LastWriteTime -Descending
$cloudSaves = Get-ChildItem -Path $googleDriveFolder -Filter "$baseSaveName*.sav" | Sort-Object LastWriteTime -Descending

if ($steamSaves.Count -eq 0 -and $cloudSaves.Count -eq 0) {
    Write-Host "❌ No save files found in either Steam or Cloud."
    exit
}

$latestSteamSave = $steamSaves | Select-Object -First 1
$latestCloudSave = $cloudSaves | Select-Object -First 1

if ($latestCloudSave -and $latestSteamSave) {
    if ($latestCloudSave.LastWriteTime -gt $latestSteamSave.LastWriteTime) {
        Write-Host "📥 Cloud save is newer. Syncing to Steam folder..."
        Copy-Item -Path $latestCloudSave.FullName -Destination (Join-Path $steamSaveFolder $latestCloudSave.Name) -Force
    } else {
        Write-Host "📁 Local Steam save is up-to-date."
    }
} elseif ($latestCloudSave -and -not $latestSteamSave) {
    Write-Host "📥 Only cloud save found. Syncing to Steam folder..."
    Copy-Item -Path $latestCloudSave.FullName -Destination (Join-Path $steamSaveFolder $latestCloudSave.Name) -Force
} elseif ($latestSteamSave -and -not $latestCloudSave) {
    Write-Host "📁 Only local save found."
}

# Backup local save to cloud
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$latestSaveToBackup = Get-ChildItem -Path $steamSaveFolder -Filter "$baseSaveName*.sav" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$backupPath = Join-Path $googleDriveFolder "${baseSaveName}_Backup_${timestamp}.sav"
Copy-Item -Path $latestSaveToBackup.FullName -Destination $backupPath -Force
Write-Host "✅ Backup created: $backupPath"

# Launch the game
Write-Host "🚀 Launching Satisfactory..."
Start-Process $gameLaunchUri
Start-Sleep -Seconds 10

# Wait for game to launch
Write-Host "🎮 Waiting for game to launch..."
do {
    Start-Sleep -Seconds $healthCheckInterval
    $process = Get-Process -Name $gameProcessName -ErrorAction SilentlyContinue
} while (-not $process)

Write-Host "🟢 Game is running."

# Show non-modal, non-topmost pop-up during sync
$popup = New-Object Windows.Forms.Form
$popup.Text = "Sync in Progress"
$popup.Size = New-Object Drawing.Size(300,150)
$popup.StartPosition = "CenterScreen"
$popup.TopMost = $false
$popup.ShowInTaskbar = $true

$label = New-Object Windows.Forms.Label
$label.Text = "☁ Synchronizing with the cloud. Please don't close or restart the computer."
$label.Size = New-Object Drawing.Size(280,50)
$label.Location = New-Object Drawing.Point(10,20)
$popup.Controls.Add($label)

$popup.Show()

# Wait for game to close
Write-Host "⏳ Waiting for game to close..."
do {
    Start-Sleep -Seconds $healthCheckInterval
    $process = Get-Process -Name $gameProcessName -ErrorAction SilentlyContinue
} while ($process)

Write-Host "🔴 Game closed."



# Cloud sync: update last write timestamp
$finalCloudSave = Get-ChildItem -Path $googleDriveFolder -Filter "$baseSaveName*.sav" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($finalCloudSave) {
    (Get-Item $finalCloudSave.FullName).LastWriteTime = Get-Date
    Write-Host "✅ Cloud save timestamp updated: $($finalCloudSave.Name)"
} else {
    Write-Host "⚠️ No cloud save found to update timestamp."
}

# Auto-close popup
$popup.Close()
Write-Host "`n✅ Done."
