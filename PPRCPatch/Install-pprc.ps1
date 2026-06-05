<#
  Install-pprc.ps1
  ----------------
  Instalador todo-en-uno para "pprc" (pakon-planar-raw-converter) CON el parche
  que lee las dimensiones (ancho x alto) del header de cada archivo .raw, para que
  funcione con full-frame, half-frame y cualquier ancho SIN tener que pasar --dimensions.

  Qué hace, en orden:
    1. Verifica que existan Node.js y npm.
    2. Si pprc NO esta instalado globalmente -> npm install -g pakon-planar-raw-converter
       (se puede saltear con -SkipInstall).
    3. Hace un backup del index.js original del paquete.
    4. Inyecta el parche del header (idempotente: si ya esta parcheado, no hace nada).
    5. Verifica la sintaxis con "node --check".
    6. Avisa si falta ImageMagick (magick), que pprc necesita para convertir.

  Uso (en una ventana de PowerShell):
    powershell -ExecutionPolicy Bypass -File .\Install-pprc.ps1

  Opciones:
    -SkipInstall    No intenta instalar pprc por npm (solo parchea si ya esta).
#>

param(
  [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'

function Write-Step($msg)  { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "    OK  $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "    !!  $msg" -ForegroundColor Yellow }
function Fail($msg)        { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# --- 1. Node y npm ---
Write-Step "Verificando Node.js y npm..."
$node = Get-Command node -ErrorAction SilentlyContinue
$npm  = Get-Command npm  -ErrorAction SilentlyContinue
if (-not $node) { Fail "Node.js no esta instalado. Instalalo desde https://nodejs.org y volve a correr este script." }
if (-not $npm)  { Fail "npm no esta disponible (viene con Node.js). Reinstala Node.js." }
Write-Ok "node $(& node --version)  /  npm $(& npm --version)"

# --- 2. pprc instalado? ---
Write-Step "Buscando pprc (pakon-planar-raw-converter) global..."
$globalRoot = (& npm root -g).Trim()
$pkgDir = Join-Path $globalRoot 'pakon-planar-raw-converter'
$index  = Join-Path $pkgDir 'index.js'

if (-not (Test-Path $index)) {
  if ($SkipInstall) {
    Fail "pprc no esta instalado y se uso -SkipInstall. Quita la opcion para instalarlo."
  }
  Write-Warn2 "pprc no esta instalado. Instalando con npm (puede tardar)..."
  & npm install -g pakon-planar-raw-converter
  if ($LASTEXITCODE -ne 0) { Fail "npm install -g pakon-planar-raw-converter fallo (codigo $LASTEXITCODE)." }
  # recomputar por si npm root cambia
  $globalRoot = (& npm root -g).Trim()
  $pkgDir = Join-Path $globalRoot 'pakon-planar-raw-converter'
  $index  = Join-Path $pkgDir 'index.js'
  if (-not (Test-Path $index)) { Fail "No encuentro index.js despues de instalar: $index" }
  Write-Ok "pprc instalado en $pkgDir"
} else {
  Write-Ok "pprc ya instalado en $pkgDir"
}

# --- 3 + 4. backup + parche ---
Write-Step "Aplicando el parche del header..."

# Leer y normalizar a LF para que el match no dependa de CRLF/LF.
$txt = [System.IO.File]::ReadAllText($index)
$txt = $txt -replace "`r`n", "`n"

$marker = 'Auto-detect the TLX/PSI planar header'
if ($txt.Contains($marker)) {
  Write-Ok "El index.js YA estaba parcheado. No hago nada."
} else {
  $anchor = (@'
    var sizeInBytes = fs.statSync(filePath).size;
    var dimensionsForConvert;
    if (program.dimensions && program.dimensions.split("x").length === 2) {
'@) -replace "`r`n", "`n"

  $block = (@'
    var sizeInBytes = fs.statSync(filePath).size;
    var dimensionsForConvert;

    // Auto-detect the TLX/PSI planar header (16 bytes: magic 0x10, W, H, 0x30) so
    // each .raw converts using ITS OWN width/height -- works for full frame, half
    // frame, and any per-photo width, with no need to pass --dimensions.
    try {
      var fd = fs.openSync(filePath, "r");
      var hdr = Buffer.alloc(16);
      fs.readSync(fd, hdr, 0, 16, 0);
      fs.closeSync(fd);
      if (hdr.readUInt32LE(0) === 0x10) {
        var hw = hdr.readUInt32LE(4), hh = hdr.readUInt32LE(8);
        if (hw > 0 && hh > 0 && (16 + hw * hh * 6) === sizeInBytes) {
          dimensionsForConvert = hw + "x" + hh + "+16";
        }
      }
    } catch (e) { /* no readable header -> fall through to manual/size-map logic */ }

    if (dimensionsForConvert) {
      // header already gave us the exact dimensions
    } else if (program.dimensions && program.dimensions.split("x").length === 2) {
'@) -replace "`r`n", "`n"

  if (-not $txt.Contains($anchor)) {
    Fail "No encuentro el punto de inyeccion en index.js (quizas una version muy distinta de pprc). No toque nada."
  }

  # Backup con timestamp (antes de escribir).
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $backup = "$index.bak-preheaderpatch_$stamp"
  Copy-Item $index $backup -Force
  Write-Ok "Backup del original -> $backup"

  $patched = $txt.Replace($anchor, $block)
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($index, $patched, $utf8NoBom)
  Write-Ok "Parche aplicado."
}

# --- 5. verificar sintaxis ---
Write-Step "Verificando sintaxis con node --check..."
& node --check $index
if ($LASTEXITCODE -ne 0) { Fail "node --check fallo: el index.js parcheado tiene un error de sintaxis." }
Write-Ok "Sintaxis correcta."

# --- 6. dependencia ImageMagick ---
Write-Step "Verificando ImageMagick (magick)..."
$magick = Get-Command magick -ErrorAction SilentlyContinue
if ($magick) {
  Write-Ok "$((& magick -version | Select-Object -First 1))"
} else {
  Write-Warn2 "No encontre 'magick' (ImageMagick). pprc lo necesita para convertir."
  Write-Warn2 "Instalalo desde https://imagemagick.org/script/download.php#windows"
}

Write-Host ""
Write-Host "LISTO. Ahora podes correr, en la carpeta donde tengas tus .raw:" -ForegroundColor Green
Write-Host "    pprc --no-negfix --e6" -ForegroundColor White
Write-Host "(ya no hace falta --dimensions: cada .raw usa su propio ancho/alto del header)" -ForegroundColor DarkGray
