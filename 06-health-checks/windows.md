# Enterprise Device Audit Report
> Excel via COM Automation (NO modules required)

## Overview
This PowerShell script generates a comprehensive enterprise device audit report in Excel format, collecting system, hardware, security, and software information without requiring any external modules.

## Usage

```powershell
$Date = Get-Date -Format "yyyyMMdd_HHmmss"
$Computer = $env:COMPUTERNAME
$Path = "$env:USERPROFILE\Desktop\IT_Audit_$Computer`_$Date.xlsx"

# ================================
# START EXCEL
# ================================
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$workbook = $excel.Workbooks.Add()

function Add-Sheet {
    param(
        $Workbook,
        [string]$Name
    )

    $sheet = $Workbook.Sheets.Add()
    $sheet.Name = $Name
    return $sheet
}

function Write-DataToSheet {
    param(
        $Sheet,
        $Data
    )

    if (-not $Data) { return }

    # Convert single object to array
    if ($Data -isnot [System.Collections.IEnumerable] -or $Data -is [string]) {
        $Data = @($Data)
    }

    $row = 1

    # Get headers
    $properties = $Data[0].PSObject.Properties.Name

    # Write headers
    $col = 1
    foreach ($prop in $properties) {
        $Sheet.Cells.Item($row, $col) = $prop
        $col++
    }

    # Write rows
    $row = 2
    foreach ($item in $Data) {
        $col = 1
        foreach ($prop in $properties) {
            $Sheet.Cells.Item($row, $col) = $item.$prop
            $col++
        }
        $row++
    }

    $Sheet.Columns.AutoFit() | Out-Null
}

# ================================
# SYSTEM / BIOS
# ================================
$computerInfo = Get-ComputerInfo
$bios = Get-CimInstance Win32_BIOS
$baseboard = Get-CimInstance Win32_BaseBoard

$systemSheet = [PSCustomObject]@{
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
}

# ================================
# CPU / RAM / GPU
# ================================
$cpu = Get-CimInstance Win32_Processor
$ram = Get-CimInstance Win32_ComputerSystem
$gpu = Get-CimInstance Win32_VideoController

$hardware = [PSCustomObject]@{
    CPU               = $cpu.Name
    Cores             = $cpu.NumberOfCores
    LogicalProcessors = $cpu.NumberOfLogicalProcessors
    RAM_GB            = [math]::Round($ram.TotalPhysicalMemory/1GB)
    GPU               = ($gpu | Select-Object -First 1).Name
}

# ================================
# STORAGE
# ================================
$storage = Get-PhysicalDisk | Select FriendlyName, MediaType, Size, HealthStatus

$volumes = Get-Volume | Select DriveLetter,
FileSystemLabel,
FileSystem,
@{Name="SizeGB";Expression={[math]::Round($_.Size/1GB,2)}},
@{Name="FreeGB";Expression={[math]::Round($_.SizeRemaining/1GB,2)}}

# ================================
# SECURITY
# ================================
$bitlocker = Get-BitLockerVolume -ErrorAction SilentlyContinue
$tpm = Get-Tpm -ErrorAction SilentlyContinue
$secureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
$defender = Get-MpComputerStatus -ErrorAction SilentlyContinue

$security = [PSCustomObject]@{
    TPM_Present        = $tpm.TpmPresent
    TPM_Ready          = $tpm.TpmReady
    TPM_Version        = $tpm.SpecVersion
    SecureBoot         = $secureBoot
    DefenderEnabled    = $defender.AntivirusEnabled
    RealTimeProtection = $defender.RealTimeProtectionEnabled
}

$bitlockerTable = $bitlocker | Select MountPoint, VolumeStatus, ProtectionStatus, EncryptionPercentage

# ================================
# NETWORK
# ================================
$networkAdapters = Get-NetAdapter | Select Name, Status, MacAddress, LinkSpeed
$ipConfig = Get-NetIPConfiguration | Select InterfaceAlias, IPv4Address, IPv6Address

# ================================
# USERS / ADMINS
# ================================
$localUsers = Get-LocalUser | Select Name, Enabled, LastLogon
$admins = Get-LocalGroupMember Administrators | Select Name, ObjectClass

# ================================
# SOFTWARE
# ================================
$software = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
Select DisplayName, DisplayVersion, Publisher, InstallDate |
Where-Object {$_.DisplayName -ne $null}

# ================================
# STARTUP
# ================================
$startup = Get-CimInstance Win32_StartupCommand | Select Name, Command, Location, User

# ================================
# UPDATES
# ================================
$hotfix = Get-HotFix | Sort InstalledOn -Descending | Select -First 20
$lastPatch = $hotfix | Select-Object -First 1

# ================================
# OFFICE
# ================================
$office = Get-ItemProperty HKLM:\Software\Microsoft\Office\ClickToRun\Configuration -ErrorAction SilentlyContinue

$officeInfo = [PSCustomObject]@{
    Version  = $office.ClientVersionToReport
    Channel  = $office.UpdateChannel
    Platform = $office.Platform
}

# ================================
# ONEDRIVE
# ================================
$oneDrive = Get-ItemProperty "HKCU:\Software\Microsoft\OneDrive" -ErrorAction SilentlyContinue

$oneDriveStatus = [PSCustomObject]@{
    Installed = $oneDrive -ne $null
}

# ================================
# MONITORS
# ================================
$monitors = Get-CimInstance WmiMonitorID -Namespace root\wmi |
Select ManufacturerName, UserFriendlyName, SerialNumberID

# ================================
# SUMMARY
# ================================
$summary = [PSCustomObject]@{
    ComputerName = $Computer
    CPU          = $cpu.Name
    RAM_GB       = [math]::Round($ram.TotalPhysicalMemory/1GB)
    GPU          = ($gpu | Select-Object -First 1).Name
    StorageCount = ($storage | Measure-Object).Count
    LastPatch    = $lastPatch.HotFixID
    TPM          = $tpm.TpmPresent
    SecureBoot   = $secureBoot
}

# ================================
# CREATE SHEETS
# ================================
$wsSummary   = Add-Sheet $workbook "Summary"
$wsSystem    = Add-Sheet $workbook "System"
$wsHardware  = Add-Sheet $workbook "Hardware"
$wsStorage   = Add-Sheet $workbook "Storage"
$wsVolumes   = Add-Sheet $workbook "Volumes"
$wsSecurity  = Add-Sheet $workbook "Security"
$wsBitlocker = Add-Sheet $workbook "BitLocker"
$wsNetwork   = Add-Sheet $workbook "Network"
$wsIP        = Add-Sheet $workbook "IPConfig"
$wsUsers     = Add-Sheet $workbook "Users"
$wsAdmins    = Add-Sheet $workbook "LocalAdmins"
$wsSoftware  = Add-Sheet $workbook "Software"
$wsStartup   = Add-Sheet $workbook "Startup"
$wsUpdates   = Add-Sheet $workbook "Updates"
$wsOffice    = Add-Sheet $workbook "Office"
$wsOneDrive  = Add-Sheet $workbook "OneDrive"
$wsMonitors  = Add-Sheet $workbook "Monitors"

# ================================
# WRITE DATA
# ================================
Write-DataToSheet $wsSummary   $summary
Write-DataToSheet $wsSystem    $systemSheet
Write-DataToSheet $wsHardware  $hardware
Write-DataToSheet $wsStorage   $storage
Write-DataToSheet $wsVolumes   $volumes
Write-DataToSheet $wsSecurity  $security
Write-DataToSheet $wsBitlocker $bitlockerTable
Write-DataToSheet $wsNetwork   $networkAdapters
Write-DataToSheet $wsIP        $ipConfig
Write-DataToSheet $wsUsers     $localUsers
Write-DataToSheet $wsAdmins    $admins
Write-DataToSheet $wsSoftware  $software
Write-DataToSheet $wsStartup   $startup
Write-DataToSheet $wsUpdates   $hotfix
Write-DataToSheet $wsOffice    $officeInfo
Write-DataToSheet $wsOneDrive  $oneDriveStatus
Write-DataToSheet $wsMonitors  $monitors

# ================================
# SAVE & CLOSE
# ================================
$workbook.SaveAs($Path)
$workbook.Close($true)
$excel.Quit()

# Cleanup COM objects
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null

Write-Host "`nAudit complete!"
Write-Host "File saved to:"
Write-Host $Path
```

## Output Sheets

| Sheet | Contents |
|-------|----------|
| **Summary** | Quick overview of key system details |
| **System** | BIOS, OS, and motherboard information |
| **Hardware** | CPU, cores, RAM, and GPU specs |
| **Storage** | Physical disk details and health status |
| **Volumes** | Drive letters, filesystem, capacity, and free space |
| **Security** | TPM, SecureBoot, Defender, and BitLocker status |
| **BitLocker** | Volume encryption status and percentage |
| **Network** | Network adapters and connectivity status |
| **IPConfig** | IPv4 and IPv6 addresses |
| **Users** | Local user accounts and logon info |
| **LocalAdmins** | Administrator group membership |
| **Software** | Installed applications with versions |
| **Startup** | Startup programs and commands |
| **Updates** | Last 20 installed Windows hotfixes |
| **Office** | Microsoft Office version and channel |
| **OneDrive** | OneDrive installation status |
| **Monitors** | Connected monitors and serial numbers |

## Requirements

- Windows 10/11 or Windows Server 2016+
- Microsoft Excel installed
- Administrator privileges
- PowerShell 5.0+
