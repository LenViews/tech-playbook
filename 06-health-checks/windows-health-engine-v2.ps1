$Date = Get-Date -Format "yyyyMMdd_HHmmss"
$Computer = $env:COMPUTERNAME
$Path = "$env:USERPROFILE\Desktop\AUDIT_HEALTH_${Computer}_${Date}.json"

# ================================
# SYSTEM / BIOS
# ================================
$computerInfo = Get-ComputerInfo
$bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
$baseboard = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue

$systemRaw = [PSCustomObject]@{
    ComputerName   = $Computer
    Manufacturer   = $computerInfo.CsManufacturer
    Model          = $computerInfo.CsModel
    OS             = $computerInfo.WindowsProductName
    Version        = $computerInfo.WindowsVersion
    Architecture   = $computerInfo.OsArchitecture
    SerialNumber   = $bios.SerialNumber
    BIOSVersion    = $bios.SMBIOSBIOSVersion
    BIOSDate       = $bios.ReleaseDate
    Motherboard    = $baseboard.Product
    Uptime_Days    = [math]::Round(((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalDays, 1)
}

# ================================
# CPU / RAM / GPU
# ================================
$cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
$ram = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue

$hardwareRaw = [PSCustomObject]@{
    CPU               = ($cpu.Name -replace '\s+', ' ').Trim()
    Cores             = $cpu.NumberOfCores
    LogicalProcessors = $cpu.NumberOfLogicalProcessors
    RAM_GB            = [math]::Round($ram.TotalPhysicalMemory / 1GB)
    GPU               = ($gpu | Select-Object -First 1).Name
}

# ================================
# STORAGE (Physical disks + Volumes)
# ================================
$storageRaw = Get-PhysicalDisk -ErrorAction SilentlyContinue |
    Select-Object FriendlyName, MediaType, Size, HealthStatus

$volumesRaw = Get-Volume -ErrorAction SilentlyContinue |
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
$secureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
$defender = Get-MpComputerStatus -ErrorAction SilentlyContinue

$securityRaw = [PSCustomObject]@{
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
$networkAdaptersRaw = Get-NetAdapter -ErrorAction SilentlyContinue |
    Select-Object Name, Status, MacAddress, LinkSpeed
$ipConfigRaw = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
    Select-Object InterfaceAlias, IPv4Address, IPv6Address

$internetReachable = (Test-NetConnection google.com -WarningAction SilentlyContinue).PingSucceeded

# ================================
# USERS & ADMINISTRATORS
# ================================
$localUsersRaw = Get-LocalUser -ErrorAction SilentlyContinue |
    Select-Object Name, Enabled, LastLogon
$localAdminsRaw = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue |
    Select-Object Name, ObjectClass

# ================================
# SOFTWARE (Installed applications)
# ================================
$softwareRaw = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
                           HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName } |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate -First 200

# ================================
# STARTUP COMMANDS
# ================================
$startupRaw = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
    Select-Object Name, Command, Location, User

# ================================
# WINDOWS UPDATES (last 20 hotfixes)
# ================================
$hotfixRaw = Get-HotFix -ErrorAction SilentlyContinue |
    Sort-Object InstalledOn -Descending |
    Select-Object -First 20

# ================================
# MONITORS (WMI)
# ================================
$monitorsRaw = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue
$monitorsDecoded = foreach ($m in $monitorsRaw) {
    [PSCustomObject]@{
        Manufacturer = if ($m.ManufacturerName) { [System.Text.Encoding]::ASCII.GetString($m.ManufacturerName -ne 0) -replace "`0", "" } else { $null }
        UserFriendlyName = if ($m.UserFriendlyName) { [System.Text.Encoding]::ASCII.GetString($m.UserFriendlyName -ne 0) -replace "`0", "" } else { $null }
        SerialNumberID = if ($m.SerialNumberID) { [System.Text.Encoding]::ASCII.GetString($m.SerialNumberID -ne 0) -replace "`0", "" } else { $null }
    }
}

# ================================
# PROCESSES (Top CPU & Memory)
# ================================
$topCPURaw = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU, Id, WorkingSet
$topMemoryRaw = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 Name, WorkingSet, Id

# ================================
# SERVICES (All + failed critical)
# ================================
$allServicesRaw = Get-Service | Select-Object Name, Status, StartType

$knownSafeServices = @(
    'dmwappushservice', 'edgeupdate', 'edgeupdatem', 'GoogleUpdaterInternalService*', 'GoogleUpdaterService*',
    'MapsBroker', 'WbioSrvc', 'WslInstaller', 'HPSysInfoCap', 'MozillaMaintenance', 'OneDrive Updater Service',
    'AdobeARMservice', 'ClickToRunSvc', 'TeamViewer', 'HP*', 'McAfee*', 'McpManagementService', 'XblAuthManager',
    'XblGameSave', 'XboxNetApiSvc', 'WMPNetworkSvc', 'RemoteRegistry', 'RemoteAccess'
)

$failedServicesRaw = $allServicesRaw | Where-Object { $_.Status -eq 'Stopped' -and $_.StartType -eq 'Automatic' }
$failedCritical = @($failedServicesRaw | Where-Object {
    $name = $_.Name
    -not ($knownSafeServices | Where-Object { $name -like $_ })
})
$ignoredServices = @($failedServicesRaw | Where-Object { $_.Name -like '*edgeupdate*' -or $_.Name -like '*GoogleUpdater*' -or $_.Name -like '*MapsBroker*' -or $_.Name -like '*WslInstaller*' })

# ================================
# EVENT LOG (Critical/Errors in last 24h)
# ================================
$lastDay = (Get-Date).AddDays(-1)
$criticalEventsRaw = Get-WinEvent -LogName System -MaxEvents 200 -ErrorAction SilentlyContinue |
    Where-Object { $_.LevelDisplayName -in @('Critical', 'Error') -and $_.TimeCreated -gt $lastDay } |
    Select-Object TimeCreated, Id, ProviderName, Message
$criticalEventsArray = @($criticalEventsRaw)

# ================================
# SCHEDULED TASKS (all)
# ================================
$scheduledTasksRaw = Get-ScheduledTask -ErrorAction SilentlyContinue |
    Select-Object TaskName, State

# ================================
# STORAGE HEALTH (for scoring - ignore system partitions)
# ================================
$userVolumes = $volumesRaw | Where-Object { $_.DriveLetter -ne $null -and $_.SizeGB -gt 10 }
$lowDiskDrives = @($userVolumes | Where-Object { $_.FreePercent -lt 10 })

# ================================
# PER-CATEGORY SCORING (start at 100, deduct only)
# ================================

# --- System Score (BIOS age, uptime, missing info) ---
$systemScore = 100
if ($systemRaw.Uptime_Days -gt 30) { $systemScore -= 10 }
if ($systemRaw.Uptime_Days -gt 90) { $systemScore -= 15 }
if ([string]::IsNullOrWhiteSpace($systemRaw.SerialNumber)) { $systemScore -= 15 }
if ([string]::IsNullOrWhiteSpace($systemRaw.BIOSVersion)) { $systemScore -= 10 }
$systemScore = [math]::Max(0, $systemScore)

# --- Hardware Score (no hardware faults detected) ---
$hardwareScore = 100
if (-not $cpu.Name) { $hardwareScore -= 30 }
if ($hardwareRaw.RAM_GB -lt 4) { $hardwareScore -= 25 }
# If no GPU detected (integrated is fine), penalty only if truly missing
if (-not $hardwareRaw.GPU) { $hardwareScore -= 15 }
$hardwareScore = [math]::Max(0, $hardwareScore)

# --- Storage Score (physical disk health, low space) ---
$storageScore = 100
$unhealthyDisks = @($storageRaw | Where-Object { $_.HealthStatus -ne 'Healthy' })
if ($unhealthyDisks.Count -gt 0) { $storageScore -= 40 }
$lowDiskCount = $lowDiskDrives.Count
if ($lowDiskCount -gt 1) { $storageScore -= 20 }
elseif ($lowDiskCount -eq 1) { $storageScore -= 10 }
$storageScore = [math]::Max(0, $storageScore)

# --- Security Score (missing key features = penalty) ---
$securityScore = 100
if ($securityRaw.TPM_Present -ne $true) { $securityScore -= 25 }
if ($securityRaw.SecureBoot -ne $true) { $securityScore -= 25 }
if ($securityRaw.DefenderEnabled -ne $true) { $securityScore -= 25 }
if ($securityRaw.RealTimeProtection -ne $true) { $securityScore -= 25 }
$securityScore = [math]::Max(0, $securityScore)

# --- Network Score (internet, DNS, adapter issues) ---
$networkScore = 100
if (-not $internetReachable) { $networkScore -= 50 }
$downAdapters = @($networkAdaptersRaw | Where-Object { $_.Status -eq 'Disconnected' -and $_.Name -notlike '*Bluetooth*' })
if ($downAdapters.Count -gt 0) { $networkScore -= 15 }
$networkScore = [math]::Max(0, $networkScore)

# --- Stability Score (services, events, tasks, processes) ---
$stabilityScore = 100
# Critical services
$fc = $failedCritical.Count
if ($fc -gt 10) { $stabilityScore -= 30 }
elseif ($fc -gt 5) { $stabilityScore -= 20 }
elseif ($fc -gt 0) { $stabilityScore -= 15 }
# Critical events in last 24h
$ce = $criticalEventsArray.Count
if ($ce -gt 20) { $stabilityScore -= 30 }
elseif ($ce -gt 10) { $stabilityScore -= 20 }
elseif ($ce -gt 2) { $stabilityScore -= 15 }
elseif ($ce -gt 0) { $stabilityScore -= 10 }
# High memory/CPU usage (top process > 80% CPU average over time – we approximate by high CPU time > 500 seconds as warning)
$highCpuProcesses = @($topCPURaw | Where-Object { $_.CPU -gt 500 -and $_.Name -ne 'Idle' -and $_.Name -ne 'System' })
if ($highCpuProcesses.Count -gt 0) { $stabilityScore -= 10 }
$stabilityScore = [math]::Max(0, $stabilityScore)

# --- Software Score (presence of known risky or outdated software) ---
$softwareScore = 100
# Simple heuristic: if any software with "Preview", "Beta", "Alpha" in name (optional)
$previewSoftware = @($softwareRaw | Where-Object { $_.DisplayName -match 'Preview|Beta|Alpha' })
if ($previewSoftware.Count -gt 5) { $softwareScore -= 10 }
$softwareScore = [math]::Max(0, $softwareScore)

# ================================
# OVERALL WEIGHTED SCORE
# ================================
$weights = @{
    Security  = 0.25
    Stability = 0.20
    Storage   = 0.15
    Hardware  = 0.15
    Network   = 0.10
    System    = 0.10
    Software  = 0.05
}

$overallScore = [math]::Round(
    ($systemScore * $weights.System) +
    ($hardwareScore * $weights.Hardware) +
    ($storageScore * $weights.Storage) +
    ($securityScore * $weights.Security) +
    ($networkScore * $weights.Network) +
    ($stabilityScore * $weights.Stability) +
    ($softwareScore * $weights.Software)
)

# ================================
# CATEGORY SCORES OBJECT
# ================================
$categoryScores = [PSCustomObject]@{
    System    = $systemScore
    Hardware  = $hardwareScore
    Storage   = $storageScore
    Security  = $securityScore
    Network   = $networkScore
    Stability = $stabilityScore
    Software  = $softwareScore
}

# ================================
# SUMMARY (includes overall and category scores)
# ================================
$summary = [PSCustomObject]@{
    ComputerName            = $Computer
    OverallScore            = $overallScore
    CategoryScores          = $categoryScores
    TopCPUProcess           = ($topCPURaw | Select-Object -First 1).Name
    TopMemoryProcess        = ($topMemoryRaw | Select-Object -First 1).Name
    FailedCriticalServices  = $failedCritical.Count
    IgnoredSafeServices     = $ignoredServices.Count
    CriticalEventErrors_24h = $criticalEventsArray.Count
    LowDiskWarnings         = $lowDiskCount
    InternetReachable       = $internetReachable
    LastPatch               = ($hotfixRaw | Select-Object -First 1).HotFixID
    StorageCount            = ($storageRaw | Measure-Object).Count
    TPM                     = $securityRaw.TPM_Present
    SecureBoot              = $securityRaw.SecureBoot
}

# ================================
# FINAL JSON REPORT (full raw data + scores)
# ================================
$report = [PSCustomObject]@{
    GeneratedAt      = (Get-Date).ToString("s")
    System           = $systemRaw
    Hardware         = $hardwareRaw
    Storage          = $storageRaw
    Volumes          = $volumesRaw
    Security         = $securityRaw
    Network          = $networkAdaptersRaw
    IPConfig         = $ipConfigRaw
    Users            = $localUsersRaw
    Admins           = $localAdminsRaw
    Software         = $softwareRaw
    Startup          = $startupRaw
    Updates          = $hotfixRaw
    Monitors         = $monitorsDecoded
    Processes        = @{
        TopCPU      = $topCPURaw
        TopMemory   = $topMemoryRaw
    }
    Services         = $allServicesRaw
    FailedCriticalServices = $failedCritical
    CriticalEvents   = $criticalEventsArray
    ScheduledTasks   = $scheduledTasksRaw
    CategoryScores   = $categoryScores
    Summary          = $summary
}

# ================================
# EXPORT TO JSON
# ================================
$report | ConvertTo-Json -Depth 6 | Out-File -Encoding UTF8 $Path

Write-Host "`nAudit & Health Engine v3.2 complete!"
Write-Host "Overall health score: $overallScore / 100"
Write-Host "Category scores:"
Write-Host "  System:    $systemScore"
Write-Host "  Hardware:  $hardwareScore"
Write-Host "  Storage:   $storageScore"
Write-Host "  Security:  $securityScore"
Write-Host "  Network:   $networkScore"
Write-Host "  Stability: $stabilityScore"
Write-Host "  Software:  $softwareScore"
Write-Host "`nFile saved to: $Path"