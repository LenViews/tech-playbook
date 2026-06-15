# Enterprise Device Audit Report
> JSON Export via PowerShell (NO modules required)

## Overview
This PowerShell script generates a comprehensive enterprise device audit report in JSON format, collecting system, hardware, security, and software information without requiring any external modules. Perfect for programmatic processing and integration with other tools.

## Usage

```powershell
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
```

## JSON Output Structure

The script generates a JSON file with the following top-level sections:

| Section | Contents |
|---------|----------|
| **GeneratedAt** | ISO 8601 timestamp of report generation |
| **System** | BIOS, OS, and motherboard information |
| **Hardware** | CPU, cores, RAM, and GPU specs |
| **Storage** | Physical disk details and health status |
| **Volumes** | Drive letters, filesystem, capacity, and free space |
| **Security** | TPM, SecureBoot, and Defender status |
| **Network** | Network adapters and connectivity status |
| **IPConfig** | IPv4 and IPv6 addresses by interface |
| **Users** | Local user accounts and logon info |
| **Admins** | Administrator group membership |
| **Software** | Installed applications (limited to first 200 for safety) |
| **Startup** | Startup programs and commands |
| **Updates** | Last 20 installed Windows hotfixes |
| **Monitors** | Connected monitors and serial numbers |
| **Summary** | Quick overview of key system details |

## Benefits

✅ **No Excel Required** - Outputs to JSON for broader compatibility  
✅ **Programmatic Processing** - Easy to parse and integrate with other tools  
✅ **Safe Software Enumeration** - Limited to first 200 entries to avoid performance issues  
✅ **ISO 8601 Timestamps** - Machine-readable date format  
✅ **UTF-8 Encoding** - Universal character support  

## Requirements

- Windows 10/11 or Windows Server 2016+
- Administrator privileges
- PowerShell 5.0+
