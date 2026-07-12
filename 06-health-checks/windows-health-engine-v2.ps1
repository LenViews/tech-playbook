$Date = Get-Date -Format "yyyyMMdd_HHmmss"
$Computer = $env:COMPUTERNAME
$Path = "$env:USERPROFILE\Desktop\AUDIT_HEALTH_${Computer}_${Date}.json"

# ================================
# SYSTEM / BIOS
# ================================
$computerInfo = Get-ComputerInfo
$bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
$baseboard = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue

$system = [PSCustomObject]@{
    ComputerName   = $Computer
    Manufacturer   = $computerInfo.CsManufacturer
    Model          = $computerInfo.CsModel
    OS             = $computerInfo.WindowsProductName
    Version        = $computerInfo.WindowsVersion
    Architecture   = $computerInfo.OsArchitecture
    SerialNumber   = $bios.SerialNumber
    BIOSVersion    = $bios.SMBIOSBIOSVersion
    BIOSDate = if ($bios.ReleaseDate) {
        try {
            (Get-Date $bios.ReleaseDate).ToString("yyyy-MM-dd")
        }
        catch {
            $bios.ReleaseDate.ToString()
        }
    }
    else {
        $null
    }
    Motherboard    = $baseboard.Product
}

# ================================
# CPU / RAM / GPU
# ================================
$cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
$ram = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue

$hardware = [PSCustomObject]@{
    CPU               = ($cpu.Name -replace '\s+', ' ').Trim()
    Cores             = $cpu.NumberOfCores
    LogicalProcessors = $cpu.NumberOfLogicalProcessors
    RAM_GB            = [math]::Round($ram.TotalPhysicalMemory / 1GB)
    GPU               = ($gpu | Select-Object -First 1).Name
}

# ================================
# STORAGE (Physical disks + Volumes)
# ================================
$storage = Get-PhysicalDisk -ErrorAction SilentlyContinue |
ForEach-Object {
    [PSCustomObject]@{
        FriendlyName = $_.FriendlyName
        MediaType    = $_.MediaType.ToString()
        SizeGB       = [math]::Round($_.Size / 1GB, 2)
        HealthStatus = $_.HealthStatus.ToString()
    }
}

$volumes = Get-Volume -ErrorAction SilentlyContinue |
    Select-Object DriveLetter,
        FileSystemLabel,
        FileSystem,
        @{Name="SizeGB";Expression={[math]::Round($_.Size/1GB,2)}},
        @{Name="FreeGB";Expression={[math]::Round($_.SizeRemaining/1GB,2)}},
        @{Name="FreePercent";Expression={if ($_.Size) { [math]::Round(($_.SizeRemaining/$_.Size)*100,1) } else { 0 }}}

# ================================
# SECURITY (TPM, SecureBoot, Defender)
# ================================
$tpm = Get-Tpm -ErrorAction SilentlyContinue
try {
    $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
}
catch {
    $secureBoot = $null
}
$defender = Get-MpComputerStatus -ErrorAction SilentlyContinue

$security = [PSCustomObject]@{
    TPM_Present        = $tpm.TpmPresent
    TPM_Ready          = $tpm.TpmReady
    TPM_Version        = $tpm.SpecVersion
    SecureBoot         = $secureBoot
    DefenderEnabled    = $defender.AntivirusEnabled
    RealTimeProtection = $defender.RealTimeProtectionEnabled
}

# ================================
# NETWORK (Adapters + IP config)
# ================================
$networkAdapters = Get-NetAdapter |
ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Name
        Status = $_.Status.ToString()
        MacAddress = $_.MacAddress
        LinkSpeed = $_.LinkSpeed.ToString()
    }
}
$ipConfig = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
ForEach-Object {
    [PSCustomObject]@{
        InterfaceAlias = $_.InterfaceAlias
        IPv4Address = ($_.IPv4Address |
            ForEach-Object { $_.IPAddress }) -join ", "

        IPv6Address = ($_.IPv6Address |
            ForEach-Object { $_.IPAddress }) -join ", "
    }
}

$internetReachable = (Test-NetConnection google.com -WarningAction SilentlyContinue).PingSucceeded

# ================================
# USERS & ADMINISTRATORS
# ================================
$localUsers = Get-LocalUser -ErrorAction SilentlyContinue |
ForEach-Object {
    [PSCustomObject]@{
        Name      = $_.Name
        Enabled   = $_.Enabled
        LastLogon = if ($_.LastLogon) {
            $_.LastLogon.ToString("yyyy-MM-dd HH:mm:ss")
        }
        else {
            $null
        }
    }
}
$localAdmins = Get-LocalGroupMember -Group Administrators -ErrorAction SilentlyContinue |
ForEach-Object {
    [PSCustomObject]@{
        Name        = $_.Name
        ObjectClass = $_.ObjectClass.ToString()
    }
}

# ================================
# SOFTWARE (Installed applications)
# ================================
$software = Get-ItemProperty `
    HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, `
    HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* `
    -ErrorAction SilentlyContinue |
Where-Object { $_.DisplayName } |
Select-Object -First 200 |
ForEach-Object {
    [PSCustomObject]@{
        DisplayName    = $_.DisplayName
        DisplayVersion = $_.DisplayVersion
        Publisher      = $_.Publisher
        InstallDate    = $_.InstallDate
    }
}

# ================================
# STARTUP COMMANDS
# ================================
$startup = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
ForEach-Object {
    [PSCustomObject]@{
        Name     = $_.Name
        Command  = $_.Command
        Location = $_.Location
        User     = $_.User
    }
}

# ================================
# WINDOWS UPDATES (last 20 hotfixes)
# ================================
$hotfix = Get-HotFix -ErrorAction SilentlyContinue |
Sort-Object InstalledOn -Descending |
Select-Object -First 20 |
ForEach-Object {
    [PSCustomObject]@{
        HotFixID    = $_.HotFixID
        Description = $_.Description
        InstalledOn = if ($_.InstalledOn) {
            $_.InstalledOn.ToString("yyyy-MM-dd")
        }
        else {
            $null
        }
    }
}

# ================================
# MONITORS (WMI)
# ================================
$monitorsRaw = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue
$monitors = foreach ($m in $monitorsRaw) {
    [PSCustomObject]@{
        Manufacturer = if ($m.ManufacturerName) { [System.Text.Encoding]::ASCII.GetString($m.ManufacturerName -ne 0) -replace "`0", "" } else { $null }
        UserFriendlyName = if ($m.UserFriendlyName) { [System.Text.Encoding]::ASCII.GetString($m.UserFriendlyName -ne 0) -replace "`0", "" } else { $null }
        SerialNumberID = if ($m.SerialNumberID) { [System.Text.Encoding]::ASCII.GetString($m.SerialNumberID -ne 0) -replace "`0", "" } else { $null }
    }
}

# ================================
# PROCESSES (Top CPU & Memory)
# ================================
$topCPU = Get-Process |
Sort-Object CPU -Descending |
Select-Object -First 10 |
ForEach-Object {
    [PSCustomObject]@{
        Name         = $_.Name
        CPUSeconds   = [math]::Round($_.CPU, 2)
        Id           = $_.Id
        WorkingSetMB = [math]::Round($_.WorkingSet64 / 1MB, 2)
    }
}
$topMemory = Get-Process |
Sort-Object WorkingSet -Descending |
Select-Object -First 10 |
ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Name
        Id = $_.Id
        WorkingSetMB = [math]::Round($_.WorkingSet64 / 1MB,2)
    }
}

# ================================
# SERVICES (All + failed critical)
# ================================
$allServices = Get-Service |
ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Name
        Status = $_.Status.ToString()
        StartType = $_.StartType.ToString()
    }
}

$knownSafeServices = @(
    'dmwappushservice', 'edgeupdate', 'edgeupdatem', 'GoogleUpdaterInternalService*', 'GoogleUpdaterService*',
    'MapsBroker', 'WbioSrvc', 'WslInstaller', 'HPSysInfoCap', 'MozillaMaintenance', 'OneDrive Updater Service',
    'AdobeARMservice', 'ClickToRunSvc', 'TeamViewer', 'HP*', 'McAfee*', 'McpManagementService', 'XblAuthManager',
    'XblGameSave', 'XboxNetApiSvc', 'WMPNetworkSvc', 'RemoteRegistry', 'RemoteAccess'
)

$failedServicesRaw = $allServices | Where-Object { $_.Status -eq 'Stopped' -and $_.StartType -eq 'Automatic' }
$failedCritical = $failedServicesRaw | Where-Object {
    $name = $_.Name
    -not ($knownSafeServices | Where-Object { $name -like $_ })
}
$ignoredServices = $failedServicesRaw | Where-Object { $_.Name -like '*edgeupdate*' -or $_.Name -like '*GoogleUpdater*' -or $_.Name -like '*MapsBroker*' -or $_.Name -like '*WslInstaller*' }

# ================================
# EVENT LOG (Critical/Errors in last 24h)
# ================================
$lastDay = (Get-Date).AddDays(-1)
$criticalEvents = Get-WinEvent -LogName System -MaxEvents 200 -ErrorAction SilentlyContinue |
    Where-Object { $_.LevelDisplayName -in @('Critical', 'Error') -and $_.TimeCreated -gt $lastDay } |
    ForEach-Object {
    [PSCustomObject]@{
        TimeCreated = $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        Id = $_.Id
        ProviderName = $_.ProviderName
        Message = $_.Message
    }
}
$criticalEventCount = ($criticalEvents | Measure-Object).Count

# ================================
# SCHEDULED TASKS (sample)
# ================================
$scheduledTasks = Get-ScheduledTask |
ForEach-Object {
    [PSCustomObject]@{
        TaskName = $_.TaskName
        State = $_.State.ToString()
    }
}

# ================================
# STORAGE HEALTH (for scoring - ignore system partitions)
# ================================
$userVolumes = $volumes | Where-Object { $_.DriveLetter -ne $null -and $_.SizeGB -gt 10 }
$lowDiskDrives = $userVolumes | Where-Object { $_.FreePercent -lt 10 }

# ================================
# HEALTH SCORING ENGINE (refined)
# ================================
$score = 100

# 1. Critical services failed
if ($failedCritical.Count -gt 10) { $score -= 30 }
elseif ($failedCritical.Count -gt 5) { $score -= 20 }
elseif ($failedCritical.Count -gt 0) { $score -= 10 }

# 2. Critical system errors last 24h
if ($criticalEventCount -gt 20) { $score -= 30 }
elseif ($criticalEventCount -gt 10) { $score -= 20 }
elseif ($criticalEventCount -gt 2) { $score -= 10 }
elseif ($criticalEventCount -gt 0) { $score -= 5 }

# 3. Low disk space on user drives
$lowDiskCount = ($lowDiskDrives | Measure-Object).Count
if ($lowDiskCount -gt 1) { $score -= 20 }
elseif ($lowDiskCount -eq 1) { $score -= 10 }

# 4. Internet connectivity
if (-not $internetReachable) { $score -= 15 }

# 5. Security bonuses
if ($security.TPM_Present -eq $true) { $score = [math]::Min(100, $score + 5) }
if ($security.SecureBoot -eq $true) { $score = [math]::Min(100, $score + 5) }
if ($security.DefenderEnabled -eq $true -and $security.RealTimeProtection -eq $true) { $score = [math]::Min(100, $score + 10) }

$score = [math]::Max(0, [math]::Min(100, $score))

# ================================
# SUMMARY (includes health score and audit highlights)
# ================================
$summary = [PSCustomObject]@{
    ComputerName            = $Computer
    HealthScore             = $score
    TopCPUProcess           = ($topCPU | Select-Object -First 1).Name
    TopMemoryProcess        = ($topMemory | Select-Object -First 1).Name
    FailedCriticalServices  = $failedCritical.Count
    IgnoredSafeServices     = $ignoredServices.Count
    CriticalEventErrors_24h = $criticalEventCount
    LowDiskWarnings         = $lowDiskCount
    InternetReachable       = $internetReachable
    LastPatch               = ($hotfix | Select-Object -First 1).HotFixID
    StorageCount            = ($storage | Measure-Object).Count
    TPM                     = $security.TPM_Present
    SecureBoot              = $security.SecureBoot
}

# ================================
# FINAL JSON REPORT (all audit data + health)
# ================================
$report = [PSCustomObject]@{
    GeneratedAt      = (Get-Date).ToString("s")
    System           = $system
    Hardware         = $hardware
    Storage          = $storage
    Volumes          = $volumes
    Security         = $security
    Network          = $networkAdapters
    IPConfig         = $ipConfig
    Users            = $localUsers
    Admins           = $localAdmins
    Software         = $software
    Startup          = $startup
    Updates          = $hotfix
    Monitors         = $monitors
    Processes        = [PSCustomObject]@{
        TopCPU      = $topCPU
        TopMemory   = $topMemory
    }
    Services         = $allServices
    FailedCriticalServices = @($failedCritical)
    CriticalEvents   = $criticalEvents
    ScheduledTasks   = $scheduledTasks
    Summary          = $summary
}

# ================================
# EXPORT & SEND TO KIOTAOPS
# ================================

# Change this to your KiotaOps server
$ServerUrl = "http://localhost:5000/api/device/report"

# Convert report to JSON
$json = $report | ConvertTo-Json -Depth 8

# Optional: keep a local copy for troubleshooting
$json | Out-File -Encoding UTF8 $Path

try {
    Invoke-RestMethod `
        -Uri $ServerUrl `
        -Method POST `
        -Body $json `
        -ContentType "application/json"

    Write-Host ""
    Write-Host "Audit uploaded successfully to KiotaOps." -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "Failed to upload report to KiotaOps." -ForegroundColor Red
    Write-Host $_.Exception.Message
}

Write-Host ""
Write-Host "Health score: $score / 100"
Write-Host "Local copy: $Path"
