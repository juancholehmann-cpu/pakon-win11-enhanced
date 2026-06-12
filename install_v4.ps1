# Pakon F135 PSI - Windows 11 + RAW16 Installer
# Run as Administrator: right-click -> "Run with PowerShell"

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step($msg) { Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "   OK: $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "   WARNING: $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "`n   ERROR: $msg" -ForegroundColor Red; Read-Host "Press Enter to exit"; exit 1 }

function Find-PackageFile([string[]]$names, [string]$label) {
    foreach ($name in $names) {
        $p = Join-Path $scriptDir $name
        if (Test-Path $p) { return $p }
    }
    Write-Fail "$label not found next to the script. Expected one of: $($names -join ', ')"
}

function Backup-File([string]$path) {
    if (Test-Path $path) {
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        Copy-Item $path "$path.backup_$stamp" -Force
        Copy-Item $path "$path.backup" -Force
    }
}

# Check for Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Fail "This script must be run as Administrator. Right-click -> Run with PowerShell."
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Yellow
Write-Host "  Pakon F135 PSI - Windows 11 + RAW16 Fix" -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Yellow

$psiDir = "C:\Program Files (x86)\Pakon\PSI"
$tlbDir = "C:\Program Files (x86)\Pakon\F-X35 COM SERVER"
$psiDst = Join-Path $psiDir "PSI.exe"
$tlbDst = Join-Path $tlbDir "TLB.dll"
$odbcDst = "C:\Windows\SysWOW64\odbcjt32.dll"

# --- 1. PSI.exe ---
Write-Step "Installing patched PSI.exe..."
$psiSrc = Find-PackageFile @("PSI.exe", "PSI(1).exe", "PSI_menufix.exe") "PSI.exe"

if (-not (Test-Path $psiDir)) { Write-Fail "Pakon PSI folder not found. Install the original Pakon software first: $psiDir" }

Backup-File $psiDst
Copy-Item $psiSrc $psiDst -Force

$md5psi = (Get-FileHash $psiDst -Algorithm MD5).Hash
if ($md5psi -ne "f85c303f5af5e002766eb2d04f6d721f") { Write-Fail "PSI.exe MD5 mismatch after copy. Expected f85c303f5af5e002766eb2d04f6d721f, got $md5psi" }
Write-OK "PSI.exe replaced and verified."

# --- 2. TLB.dll ---
Write-Step "Installing patched TLB.dll..."
$tlbSrc = Find-PackageFile @("TLB.dll", "TLB(1).dll", "TLB_psi_save_raw16_multiframe_framefile_hfinit.dll") "TLB.dll"

if (-not (Test-Path $tlbDir)) { Write-Fail "Pakon F-X35 COM SERVER folder not found. Install the original Pakon software first: $tlbDir" }

Backup-File $tlbDst
Copy-Item $tlbSrc $tlbDst -Force

$md5tlb = (Get-FileHash $tlbDst -Algorithm MD5).Hash
if ($md5tlb -ne "2289EF6AA4AD7599DD6D910CA525EB11") { Write-Fail "TLB.dll MD5 mismatch after copy. Expected 2289EF6AA4AD7599DD6D910CA525EB11, got $md5tlb" }
Write-OK "TLB.dll replaced and verified."

# --- 3. odbcjt32.dll ---
Write-Step "Installing patched odbcjt32.dll..."
$odbcSrc = Find-PackageFile @("odbcjt32_patched_v10.dll") "odbcjt32_patched_v10.dll"

# Take ownership and grant access
if (Test-Path $odbcDst) {
    takeown /f $odbcDst /a 2>$null | Out-Null
    icacls $odbcDst /grant "*S-1-5-32-544:F" 2>$null | Out-Null
    Backup-File $odbcDst
}

$replaced = $false
try {
    Copy-Item $odbcSrc $odbcDst -Force -ErrorAction Stop
    $replaced = $true
} catch {
    Write-Warn "Could not replace directly. Scheduling replacement on next reboot..."
    $odbcTmp = "C:\Windows\SysWOW64\odbcjt32_patched.dll"
    Copy-Item $odbcSrc $odbcTmp -Force
    $regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    $pending = "\??\" + $odbcTmp + "`0\??\C:\Windows\SysWOW64\odbcjt32.dll"
    Set-ItemProperty -Path $regKey -Name "PendingFileRenameOperations" -Value $pending -Type MultiString
    Write-Warn "REBOOT REQUIRED before opening PSI."
}

if ($replaced) {
    $md5odbc = (Get-FileHash $odbcDst -Algorithm MD5).Hash
    if ($md5odbc -ne "8A14EA8DBF1A122A45B288164EB8A201") { Write-Fail "odbcjt32.dll MD5 mismatch after copy. Expected 8A14EA8DBF1A122A45B288164EB8A201, got $md5odbc" }
    Write-OK "odbcjt32.dll replaced and verified."
}

# --- 4. Import SaveAsRaw default-off registry file ---
Write-Step "Importing Save As Raw default-off registry values..."
$regSrc = Find-PackageFile @("pakon_saveasraw_default_off.reg", "pakon_saveasraw_default_off(1).reg") "pakon_saveasraw_default_off.reg"
$regResult = Start-Process -FilePath "reg.exe" -ArgumentList @("import", $regSrc) -Wait -PassThru -WindowStyle Hidden
if ($regResult.ExitCode -ne 0) { Write-Fail "Registry import failed with exit code $($regResult.ExitCode)." }
Write-OK "Registry imported: SaveAsEnabled=0."

# --- 5. ODBC DSNs ---
Write-Step "Configuring ODBC DSNs (32-bit)..."
$mdbPath = Join-Path $psiDir "mrd.mdb"
if (-not (Test-Path $mdbPath)) { Write-Fail "mrd.mdb not found at $mdbPath" }

$odbcBase = "HKLM:\SOFTWARE\WOW6432Node\ODBC\ODBC.INI"
$odbcInst = "HKLM:\SOFTWARE\WOW6432Node\ODBC\ODBC.INI\ODBC Data Sources"

foreach ($dsn in @("MRD", "MRD Log")) {
    $key = "$odbcBase\$dsn"
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty $key -Name "Driver"           -Value $odbcDst
    Set-ItemProperty $key -Name "DBQ"              -Value $mdbPath
    Set-ItemProperty $key -Name "Description"      -Value $mdbPath
    Set-ItemProperty $key -Name "DriverId"         -Value 25 -Type DWord
    Set-ItemProperty $key -Name "FIL"              -Value "MS Access;"
    Set-ItemProperty $key -Name "SafeTransactions" -Value 0 -Type DWord
    Set-ItemProperty $key -Name "UID"              -Value ""
    if (-not (Test-Path $odbcInst)) { New-Item -Path $odbcInst -Force | Out-Null }
    Set-ItemProperty $odbcInst -Name $dsn -Value "Microsoft Access Driver (*.mdb)"
    Write-OK "DSN '$dsn' configured."
}

# --- 6. Compatibility flag ---
Write-Step "Setting Windows XP compatibility flag..."
$compatRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
if (-not (Test-Path $compatRegPath)) { New-Item -Path $compatRegPath -Force | Out-Null }
Set-ItemProperty -Path $compatRegPath -Name $psiDst -Value "~ WINXPSP3"
Write-OK "Compatibility flag set."

# --- 7. Disable IQueue auto-launch ---
Write-Step "Disabling IQueue auto-launch..."
$iqKey = "HKLM:\SOFTWARE\WOW6432Node\Pakon\PSI\IQueue II"
if (-not (Test-Path $iqKey)) { New-Item -Path $iqKey -Force | Out-Null }
Set-ItemProperty -Path $iqKey -Name "StartIQueue" -Value 0 -Type DWord
Write-OK "IQueue auto-launch disabled."

# --- 8. Desktop shortcut ---
Write-Step "Creating desktop shortcut..."
$launcherPath = Join-Path $psiDir "PSI_launcher.bat"
$launcherContent = "@echo off`r`ntaskkill /f /im PSI.exe /t 2>nul`r`ntaskkill /f /im `"IQueue III.exe`" /t 2>nul`r`ntimeout /t 1 /nobreak >nul`r`nstart `"`" `"%~dp0PSI.exe`"`r`n"
Set-Content -Path $launcherPath -Value $launcherContent -Encoding ASCII

$desktopPath = [Environment]::GetFolderPath("CommonDesktopDirectory")
$shortcutPath = Join-Path $desktopPath "Pakon PSI.lnk"
$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $launcherPath
$shortcut.WorkingDirectory = $psiDir
$shortcut.Description = "Pakon PSI F135"
$shortcut.Save()
Write-OK "Desktop shortcut created."

# --- 9. Verify VC++ 2003 DLLs ---
Write-Step "Checking Visual C++ 2003 runtime DLLs..."
$dlls = @("mfc71u.dll", "msvcp71.dll", "msvcr71.dll")
$missing = $dlls | Where-Object { -not (Test-Path (Join-Path $psiDir $_)) }
if ($missing) {
    Write-Warn "Missing DLLs in ${psiDir}:"
    $missing | ForEach-Object { Write-Host "     - $_" -ForegroundColor Yellow }
    Write-Warn "Copy them from PakonUpdate.zip (fx35install folder)."
} else {
    Write-OK "All VC++ 2003 runtime DLLs present."
}

# --- Final summary ---
Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "  Installed / verified:" -ForegroundColor Green
Write-Host "  PSI.exe  MD5: $md5psi" -ForegroundColor Green
Write-Host "  TLB.dll  MD5: $md5tlb" -ForegroundColor Green
if ($replaced) {
    Write-Host "  odbcjt32 MD5: $md5odbc" -ForegroundColor Green
    Write-Host "  Open PSI using the 'Pakon PSI' shortcut on your desktop." -ForegroundColor Green
} else {
    Write-Host "  ** REBOOT REQUIRED before opening PSI **" -ForegroundColor Yellow
}
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"
