$Date = Get-Date -Format "yyyyMMdd_HHmmss"
$Computer = $env:COMPUTERNAME
$Path = "$env:USERPROFILE\Desktop\IT_Audit_$Computer`_$Date.json"

# ================================
# SYSTEM INFO
# ================================
$computerInfo = Get-ComputerInfo
$bios = Get-CimInstance Win32_BIOS
$baseboard = Get-CimInstance Win32_BaseBoard

$system = [PSCustomObject]@{
    ComputerName = $Computer
    Manufacturer = $computerInfo.CsManufacturer
    Model = $computerInfo.CsModel
    OS = $computerInfo.WindowsProductName
    Version = $computerInfo.WindowsVersion
    Architecture = $computerInfo.OsArchitecture
    SerialNumber = $bios.SerialNumber
    BIOSVersion = $bios.SMBIOSBIOSVersion
    BIOSDate = $bios.ReleaseDate
    Motherboard = $baseboard.Product
}

# ================================
# HARDWARE
# ================================
$cpu = Get-CimInstance Win32_Processor
$ram = Get-CimInstance Win32_ComputerSystem
$gpu = Get-CimInstance Win32_VideoController

$hardware = [PSCustomObject]@{
    CPU = $cpu.Name
    Cores = $cpu.NumberOfCores
    LogicalProcessors = $cpu.NumberOfLogicalProcessors
    RAM_GB = [math]::Round($ram.TotalPhysicalMemory / 1GB)
    GPU = ($gpu | Select-Object -First 1).Name
}

# ================================
# STORAGE
# ================================
$storage = Get-PhysicalDisk | Select-Object FriendlyName, MediaType, Size, HealthStatus

$volumes = Get-Volume | Select-Object `
    DriveLetter,
    FileSystemLabel,
    FileSystem,
    @{Name="SizeGB";Expression={[math]::Round($_.Size/1GB,2)}},
    @{Name="FreeGB";Expression={[math]::Round($_.SizeRemaining/1GB,2)}}

# ================================
# SECURITY
# ================================
$tpm = Get-Tpm -ErrorAction SilentlyContinue
$secureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
$defender = Get-MpComputerStatus -ErrorAction SilentlyContinue

$security = [PSCustomObject]@{
    TPM_Present = $tpm.TpmPresent
    TPM_Ready = $tpm.TpmReady
    TPM_Version = $tpm.SpecVersion
    SecureBoot = $secureBoot
    DefenderEnabled = $defender.AntivirusEnabled
    RealTimeProtection = $defender.RealTimeProtectionEnabled
}

# ================================
# NETWORK
# ================================
$network = Get-NetAdapter | Select-Object Name, Status, MacAddress, LinkSpeed
$ipconfig = Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv6Address

# ================================
# USERS / ADMINS
# ================================
$users = Get-LocalUser | Select-Object Name, Enabled, LastLogon
$admins = Get-LocalGroupMember Administrators | Select-Object Name, ObjectClass

# ================================
# SOFTWARE (LIMITED FOR SAFETY)
# ================================
$software = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
Where-Object { $_.DisplayName } |
Select-Object DisplayName, DisplayVersion, Publisher, InstallDate -First 200

# ================================
# STARTUP
# ================================
$startup = Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User

# ================================
# UPDATES
# ================================
$hotfix = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 20

# ================================
# MONITORS
# ================================
$monitors = Get-CimInstance WmiMonitorID -Namespace root\wmi |
Select-Object ManufacturerName, UserFriendlyName, SerialNumberID

# ================================
# SUMMARY
# ================================
$summary = [PSCustomObject]@{
    ComputerName = $Computer
    CPU = $cpu.Name
    RAM_GB = [math]::Round($ram.TotalPhysicalMemory/1GB)
    GPU = ($gpu | Select-Object -First 1).Name
    StorageCount = ($storage | Measure-Object).Count
    LastPatch = ($hotfix | Select-Object -First 1).HotFixID
    TPM = $tpm.TpmPresent
    SecureBoot = $secureBoot
}

# ================================
# FINAL REPORT OBJECT
# ================================
$report = [PSCustomObject]@{
    GeneratedAt = (Get-Date).ToString("s")
    System = $system
    Hardware = $hardware
    Storage = $storage
    Volumes = $volumes
    Security = $security
    Network = $network
    IPConfig = $ipconfig
    Users = $users
    Admins = $admins
    Software = $software
    Startup = $startup
    Updates = $hotfix
    Monitors = $monitors
    Summary = $summary
}

# ================================
# EXPORT JSON
# ================================
$report | ConvertTo-Json -Depth 5 | Out-File -Encoding UTF8 $Path

Write-Host "`nAudit complete!"
Write-Host "JSON saved to:"
Write-Host $Path