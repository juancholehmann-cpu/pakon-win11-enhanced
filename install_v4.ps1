# Pakon F135 PSI - Windows Installer
# Patched build: Positive default + IQueue off + Crop35mm off (+ Save As Raw default-off)
# Run as Administrator: right-click install.bat -> "Run as administrator"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---------- Logging ----------
$logPath = Join-Path $scriptDir "install_log.txt"
try { Start-Transcript -Path $logPath -Force | Out-Null } catch { }

# Remove the "downloaded from the Internet" mark from bundled files (best effort).
try { Get-ChildItem -LiteralPath $scriptDir -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue } catch { }

# ---------- Output helpers ----------
function Write-Step($msg) { Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-Info($msg) { Write-Host "     $msg" -ForegroundColor Gray }
function Write-OK($msg)   { Write-Host "   OK: $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "   WARNING: $msg" -ForegroundColor Yellow }
function Fail($msg)       { throw $msg }

function Find-PackageFile([string[]]$names, [string]$label) {
    foreach ($name in $names) {
        $p = Join-Path $scriptDir $name
        if (Test-Path $p) { return $p }
    }
    Fail "$label not found next to the installer. Expected one of: $($names -join ', '). Make sure every file is in the SAME folder as install.bat."
}

# MD5 helper with a fallback for old PowerShell (pre-4.0, where Get-FileHash is absent).
function Get-Md5([string]$path) {
    if (Get-Command Get-FileHash -ErrorAction SilentlyContinue) {
        return (Get-FileHash $path -Algorithm MD5).Hash.ToUpper()
    }
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $stream = [System.IO.File]::OpenRead($path)
    try { return ([BitConverter]::ToString($md5.ComputeHash($stream))).Replace("-", "").ToUpper() }
    finally { $stream.Dispose() }
}

function Backup-File([string]$path) {
    if (Test-Path $path) {
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        Copy-Item $path "$path.backup_$stamp" -Force
        Copy-Item $path "$path.backup" -Force
        Write-Info "Backup saved: $path.backup_$stamp"
    }
}

# Verify source, back up destination, copy, then verify destination. Verbose.
function Install-Verified([string]$src, [string]$dst, [string]$expectedMd5, [string]$label) {
    Write-Info "Source file: $src"
    Write-Info "Target path: $dst"
    $srcMd5 = Get-Md5 $src
    Write-Info "Source MD5:  $srcMd5"
    Write-Info "Expected:    $expectedMd5"
    if ($srcMd5 -ne $expectedMd5) {
        Fail "$label in the installer folder is the WRONG file or is corrupt (MD5 does not match). Expected $expectedMd5 but got $srcMd5. Replace it with the correct patched $label and run the installer again."
    }
    Backup-File $dst
    try {
        Copy-Item $src $dst -Force -ErrorAction Stop
    } catch {
        Fail "Could not write $label to '$dst'. This usually means PSI is still open, or an antivirus / Controlled Folder Access is blocking the write. Close PSI completely and try again. Details: $($_.Exception.Message)"
    }
    $dstMd5 = Get-Md5 $dst
    Write-Info "Installed MD5: $dstMd5"
    if ($dstMd5 -ne $expectedMd5) {
        Fail "$label MD5 mismatch AFTER copy. Expected $expectedMd5, got $dstMd5."
    }
    return $dstMd5
}

# ===================== MAIN =====================
try {
    # Check for Administrator privileges
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
        Fail "This script must be run as Administrator. Right-click install.bat -> Run as administrator."
    }

    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Yellow
    Write-Host "  Pakon F135 PSI - Patched Installer" -ForegroundColor Yellow
    Write-Host "  Positive default + IQueue off + Crop35mm off" -ForegroundColor Yellow
    Write-Host "====================================================" -ForegroundColor Yellow
    Write-Info "Installer folder: $scriptDir"
    Write-Info "Log file:         $logPath"

    # --- Detect Windows layout (handles 64-bit, 32-bit, and non-C: drives) ---
    Write-Step "Detecting Windows layout..."
    $is64 = [Environment]::Is64BitOperatingSystem
    if ($is64) { $bits = "64-bit" } else { $bits = "32-bit" }
    Write-Info "Operating system: $bits Windows"

    $pakonCandidates = @()
    if (${env:ProgramFiles(x86)}) { $pakonCandidates += (Join-Path ${env:ProgramFiles(x86)} "Pakon") }
    if ($env:ProgramFiles)        { $pakonCandidates += (Join-Path $env:ProgramFiles "Pakon") }
    $pakonCandidates += "C:\Program Files (x86)\Pakon"
    $pakonCandidates += "C:\Program Files\Pakon"
    $pakonCandidates = $pakonCandidates | Select-Object -Unique

    $pakonBase = $null
    foreach ($c in $pakonCandidates) { if (Test-Path (Join-Path $c "PSI")) { $pakonBase = $c; break } }
    if (-not $pakonBase) {
        Fail "Pakon PSI folder not found. Install the ORIGINAL Pakon software first. Looked in: $($pakonCandidates -join '; ')"
    }

    $psiDir = Join-Path $pakonBase "PSI"
    $tlbDir = Join-Path $pakonBase "F-X35 COM SERVER"
    $psiDst = Join-Path $psiDir "PSI.exe"
    $tlbDst = Join-Path $tlbDir "TLB.dll"

    if ($is64) { $sysDir = Join-Path $env:WINDIR "SysWOW64" } else { $sysDir = Join-Path $env:WINDIR "System32" }
    $odbcDst = Join-Path $sysDir "odbcjt32.dll"

    if ($is64) { $pakonReg = "HKLM:\SOFTWARE\WOW6432Node\Pakon\PSI" } else { $pakonReg = "HKLM:\SOFTWARE\Pakon\PSI" }

    Write-OK "Pakon folder: $pakonBase"
    Write-Info "PSI folder:   $psiDir"
    Write-Info "TLB folder:   $tlbDir"
    Write-Info "ODBC target:  $odbcDst"

    # --- Close PSI / IQueue so files are not locked ---
    Write-Step "Closing PSI and IQueue if they are running..."
    $procNames = @("PSI", "IQueue III", "IQueue II", "IQueue")
    $killedAny = $false
    foreach ($pn in $procNames) {
        $procs = Get-Process -Name $pn -ErrorAction SilentlyContinue
        if ($procs) {
            $procs | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-Info "Closed: $pn"
            $killedAny = $true
        }
    }
    if ($killedAny) { Start-Sleep -Seconds 1; Write-OK "Running instances closed." } else { Write-OK "Nothing was running." }

    # --- 1. PSI.exe ---
    Write-Step "Installing patched PSI.exe..."
    $psiSrc = Find-PackageFile @("PSI.exe", "PSIActual_positivo_getter0.exe", "PSI(1).exe", "PSI_menufix.exe") "PSI.exe"
    $md5psi = Install-Verified $psiSrc $psiDst "3BFEF5E2BF596A21E6A866F0472CCDA2" "PSI.exe"
    Write-OK "PSI.exe replaced and verified."

    # --- 2. TLB.dll ---
    Write-Step "Installing patched TLB.dll..."
    $tlbSrc = Find-PackageFile @("TLB.dll", "TLB(1).dll", "TLB_psi_save_raw16_multiframe_framefile_hfinit.dll") "TLB.dll"
    if (-not (Test-Path $tlbDir)) { Fail "Pakon F-X35 COM SERVER folder not found: $tlbDir" }
    $md5tlb = Install-Verified $tlbSrc $tlbDst "CA383B45445D1F5CF4FED9D7CCC1F64F" "TLB.dll"
    Write-OK "TLB.dll replaced and verified."

    # --- 3. odbcjt32.dll ---
    Write-Step "Installing patched odbcjt32.dll..."
    $odbcSrc = Find-PackageFile @("odbcjt32_patched_v10.dll") "odbcjt32_patched_v10.dll"
    $expOdbc = "8A14EA8DBF1A122A45B288164EB8A201"
    Write-Info "Source file: $odbcSrc"
    $srcOdbcMd5 = Get-Md5 $odbcSrc
    Write-Info "Source MD5:  $srcOdbcMd5 (expected $expOdbc)"
    if ($srcOdbcMd5 -ne $expOdbc) { Fail "odbcjt32_patched_v10.dll is the wrong file or is corrupt. Expected $expOdbc, got $srcOdbcMd5." }

    if (Test-Path $odbcDst) {
        Write-Info "Taking ownership of existing $odbcDst ..."
        takeown /f $odbcDst /a 2>$null | Out-Null
        icacls $odbcDst /grant "*S-1-5-32-544:F" 2>$null | Out-Null
        Backup-File $odbcDst
    }

    $replaced = $false
    try {
        Copy-Item $odbcSrc $odbcDst -Force -ErrorAction Stop
        $replaced = $true
    } catch {
        Write-Warn "Could not replace directly (file in use). Scheduling replacement on next reboot..."
        $odbcTmp = Join-Path $sysDir "odbcjt32_patched.dll"
        Copy-Item $odbcSrc $odbcTmp -Force
        $regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
        $pending = "\??\" + $odbcTmp + "`0\??\" + $odbcDst
        Set-ItemProperty -Path $regKey -Name "PendingFileRenameOperations" -Value $pending -Type MultiString
        Write-Warn "REBOOT REQUIRED before opening PSI."
    }

    if ($replaced) {
        $md5odbc = Get-Md5 $odbcDst
        Write-Info "Installed MD5: $md5odbc"
        if ($md5odbc -ne $expOdbc) { Fail "odbcjt32.dll MD5 mismatch after copy. Expected $expOdbc, got $md5odbc." }
        Write-OK "odbcjt32.dll replaced and verified."
    }

    # --- 4. Save As Raw default-off ---
    Write-Step "Setting 'Save As Raw' to default-off..."
    $setupKey = "$pakonReg\Setup"
    if (-not (Test-Path $setupKey)) { New-Item -Path $setupKey -Force | Out-Null }
    Set-ItemProperty -Path $setupKey -Name "SaveAsEnabled" -Value 0 -Type DWord
    Write-Info "$setupKey  ->  SaveAsEnabled = 0"
    Write-OK "Save As Raw default-off set."

    # --- 5. ODBC DSNs (32-bit) ---
    Write-Step "Configuring ODBC DSNs (32-bit)..."
    $mdbPath = Join-Path $psiDir "mrd.mdb"
    if (-not (Test-Path $mdbPath)) { Fail "mrd.mdb not found at $mdbPath" }

    if ($is64) { $odbcBase = "HKLM:\SOFTWARE\WOW6432Node\ODBC\ODBC.INI" } else { $odbcBase = "HKLM:\SOFTWARE\ODBC\ODBC.INI" }
    $odbcInst = "$odbcBase\ODBC Data Sources"

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

    # --- 6. Compatibility flag (Windows XP SP3) ---
    Write-Step "Setting Windows XP compatibility flag..."
    $compatRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
    if (-not (Test-Path $compatRegPath)) { New-Item -Path $compatRegPath -Force | Out-Null }
    Set-ItemProperty -Path $compatRegPath -Name $psiDst -Value "~ WINXPSP3"
    Write-Info "$psiDst  ->  ~ WINXPSP3"
    Write-OK "Compatibility flag set."

    # --- 7. Disable IQueue auto-launch (registry safety net; the EXE also forces this) ---
    Write-Step "Disabling IQueue auto-launch..."
    $iqKey = "$pakonReg\IQueue II"
    if (-not (Test-Path $iqKey)) { New-Item -Path $iqKey -Force | Out-Null }
    Set-ItemProperty -Path $iqKey -Name "StartIQueue" -Value 0 -Type DWord
    Write-Info "$iqKey  ->  StartIQueue = 0"
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
    Write-Info "Shortcut: $shortcutPath"
    Write-OK "Desktop shortcut created."

    # --- 9. Install Visual C++ 2003 runtime DLLs (bundled with the installer) ---
    Write-Step "Checking Visual C++ 2003 runtime DLLs..."
    $dlls = @("mfc71u.dll", "msvcp71.dll", "msvcr71.dll")
    $dllSearchDirs = @(
        (Join-Path $scriptDir "vc2003"),
        (Join-Path $scriptDir "runtime"),
        (Join-Path $scriptDir "redist"),
        $scriptDir
    )
    $stillMissing = @()
    foreach ($dll in $dlls) {
        $target = Join-Path $psiDir $dll
        if (Test-Path $target) { Write-OK "$dll already present."; continue }
        $found = $null
        foreach ($d in $dllSearchDirs) {
            $cand = Join-Path $d $dll
            if (Test-Path $cand) { $found = $cand; break }
        }
        if ($found) {
            try {
                Copy-Item $found $target -Force -ErrorAction Stop
                Write-OK "$dll copied into PSI folder (from $found)."
            } catch {
                Write-Warn "Could not copy ${dll}: $($_.Exception.Message)"
                $stillMissing += $dll
            }
        } else {
            $stillMissing += $dll
        }
    }
    if ($stillMissing.Count -gt 0) {
        Write-Warn "These runtime DLLs are missing and were NOT found in the installer package:"
        $stillMissing | ForEach-Object { Write-Host "     - $_" -ForegroundColor Yellow }
        Write-Warn "Put them in a 'vc2003' subfolder next to install.bat (or copy them from PakonUpdate.zip, fx35install folder) and run again."
    } else {
        Write-OK "All VC++ 2003 runtime DLLs present."
    }

    # --- 10. Install PSIBitmapButtons.dll ---
    Write-Step "Installing PSIBitmapButtons.dll..."
    $pbbName = "PSIBitmapButtons.dll"
    $pbbDirs = @(
        (Join-Path $scriptDir "vc2003"),
        (Join-Path $scriptDir "runtime"),
        (Join-Path $scriptDir "redist"),
        $scriptDir
    )
    $pbbSrc = $null
    foreach ($d in $pbbDirs) { $cand = Join-Path $d $pbbName; if (Test-Path $cand) { $pbbSrc = $cand; break } }
    $pbbDst = Join-Path $psiDir $pbbName
    if (Test-Path $pbbDst) {
        Write-OK "$pbbName already present in PSI folder; left untouched (not overwritten)."
    } elseif ($pbbSrc) {
        try {
            Copy-Item $pbbSrc $pbbDst -Force -ErrorAction Stop
            Write-OK "$pbbName was missing; copied into PSI folder (from $pbbSrc)."
        } catch {
            Write-Warn "Could not copy ${pbbName}: $($_.Exception.Message)"
        }
    } else {
        Write-Warn "$pbbName not found in the installer package and not present in PSI; skipped."
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
}
catch {
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Red
    Write-Host "  INSTALLATION FAILED" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Nothing else was changed after this point." -ForegroundColor Red
    Write-Host "  A full log was saved as: $logPath" -ForegroundColor Red
    Write-Host "====================================================" -ForegroundColor Red
}
finally {
    try { Stop-Transcript | Out-Null } catch { }
    Write-Host ""
    Read-Host "Press Enter to close this window"
}
