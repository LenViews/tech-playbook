$Date = Get-Date -Format "yyyyMMdd_HHmmss"
$Computer = $env:COMPUTERNAME
$Path = "$env:USERPROFILE\Desktop\HEALTH_ENGINE_$Computer`_$Date.json"

# ================================
# SYSTEM BASELINE
# ================================
$computerInfo = Get-ComputerInfo
$cpu = Get-CimInstance Win32_Processor
$ram = Get-CimInstance Win32_ComputerSystem

$system = [PSCustomObject]@{
    ComputerName = $Computer
    OS = $computerInfo.WindowsProductName
    Version = $computerInfo.WindowsVersion
    CPU = $cpu.Name
    RAM_GB = [math]::Round($ram.TotalPhysicalMemory / 1GB)
}

# ================================
# 🧠 LIVE PROCESS HEALTH
# ================================
$topCPU = Get-Process |
Sort-Object CPU -Descending |
Select-Object -First 10 Name, CPU, Id, WorkingSet

$topMemory = Get-Process |
Sort-Object WorkingSet -Descending |
Select-Object -First 10 Name, WorkingSet, Id

# ================================
# ⚙️ SERVICES HEALTH
# ================================
$services = Get-Service |
Select-Object Name, Status, StartType

$failedServices = $services | Where-Object { $_.Status -eq "Stopped" -and $_.StartType -eq "Automatic" }

# ================================
# 🧯 EVENT LOG (LAST 50 ERRORS)
# ================================
$eventErrors = Get-WinEvent -LogName System -MaxEvents 50 -ErrorAction SilentlyContinue |
Where-Object { $_.LevelDisplayName -eq "Error" } |
Select-Object TimeCreated, Id, ProviderName, Message

# ================================
# 🔐 SECURITY SIGNALS
# ================================
$tpm = Get-Tpm -ErrorAction SilentlyContinue
$secureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
$defender = Get-MpComputerStatus -ErrorAction SilentlyContinue

$security = [PSCustomObject]@{
    TPM = $tpm.TpmPresent
    SecureBoot = $secureBoot
    Defender = $defender.AntivirusEnabled
    RealTimeProtection = $defender.RealTimeProtectionEnabled
}

# ================================
# 🌐 NETWORK HEALTH
# ================================
$adapters = Get-NetAdapter | Select Name, Status, LinkSpeed

$dnsTest = Test-NetConnection google.com -WarningAction SilentlyContinue

$network = [PSCustomObject]@{
    Adapters = $adapters
    InternetReachable = $dnsTest.PingSucceeded
    DNSWorking = $dnsTest.NameResolutionSucceeded
}

# ================================
# 💾 STORAGE HEALTH
# ================================
$volumes = Get-Volume | Select DriveLetter,
FileSystemLabel,
@{Name="SizeGB";Expression={[math]::Round($_.Size/1GB,2)}},
@{Name="FreeGB";Expression={[math]::Round($_.SizeRemaining/1GB,2)}}

$lowDisk = $volumes | Where-Object { $_.FreeGB -lt 10 }

# ================================
# 🔧 SCHEDULED TASKS
# ================================
$tasks = Get-ScheduledTask | Select TaskName, State

# ================================
# 📊 HEALTH SCORING ENGINE
# ================================
$score = 100

if ($failedServices.Count -gt 0) { $score -= 20 }
if ($eventErrors.Count -gt 5) { $score -= 20 }
if ($lowDisk.Count -gt 0) { $score -= 25 }
if (-not $dnsTest.PingSucceeded) { $score -= 25 }

if ($score -lt 0) { $score = 0 }

# ================================
# SUMMARY
# ================================
$summary = [PSCustomObject]@{
    ComputerName = $Computer
    HealthScore = $score
    TopCPUProcess = ($topCPU | Select-Object -First 1).Name
    TopMemoryProcess = ($topMemory | Select-Object -First 1).Name
    FailedServices = $failedServices.Count
    EventErrors = $eventErrors.Count
    LowDiskWarnings = $lowDisk.Count
    Internet = $dnsTest.PingSucceeded
}

# ================================
# FINAL REPORT
# ================================
$report = [PSCustomObject]@{
    GeneratedAt = (Get-Date).ToString("s")
    System = $system
    Processes = @{
        TopCPU = $topCPU
        TopMemory = $topMemory
    }
    Services = $services
    FailedServices = $failedServices
    Events = $eventErrors
    Security = $security
    Network = $network
    Storage = $volumes
    ScheduledTasks = $tasks
    Summary = $summary
}

# ================================
# EXPORT JSON
# ================================
$report | ConvertTo-Json -Depth 6 | Out-File -Encoding UTF8 $Path

Write-Host "`nHealth Engine v2 complete!"
Write-Host "Health score: $score / 100"
Write-Host "Saved to: $Path"