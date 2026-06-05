<#
  Restore-pprc.ps1
  ----------------
  Restaura el index.js ORIGINAL de pprc (deshace el parche del header),
  usando el backup mas reciente que dejo Install-pprc.ps1.

  Uso:
    powershell -ExecutionPolicy Bypass -File .\Restore-pprc.ps1
#>

$ErrorActionPreference = 'Stop'
function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

$npm = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npm) { Fail "npm no disponible." }

$globalRoot = (& npm root -g).Trim()
$pkgDir = Join-Path $globalRoot 'pakon-planar-raw-converter'
$index  = Join-Path $pkgDir 'index.js'
if (-not (Test-Path $index)) { Fail "No encuentro pprc instalado en $pkgDir" }

# backup mas reciente
$backup = Get-ChildItem $pkgDir -Filter 'index.js.bak-preheaderpatch_*' -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $backup) { Fail "No hay backup (index.js.bak-preheaderpatch_*) para restaurar." }

Copy-Item $backup.FullName $index -Force
& node --check $index
if ($LASTEXITCODE -ne 0) { Fail "El index.js restaurado no pasa node --check (raro)." }

Write-Host "Restaurado index.js desde: $($backup.Name)" -ForegroundColor Green
Write-Host "pprc volvio al comportamiento original (necesita --dimensions)." -ForegroundColor DarkGray
