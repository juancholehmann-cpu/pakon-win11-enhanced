@echo off
REM ====================================================
REM  Fix RAW16 - crea la carpeta temporal de frames de PSI
REM  Sintoma que arregla: PSI extrae pero guarda JPG en
REM  vez de RAW (los psi_frame_NN.raw nunca aparecen).
REM  Click derecho -> Ejecutar como administrador
REM ====================================================
setlocal
set "TARGET=C:\ProgramData\Pakon\Temp"

echo.
echo ==== Fix RAW16 / carpeta temporal de PSI ====
echo.

REM --- Verificar privilegios de administrador ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Hay que ejecutar este .bat como ADMINISTRADOR.
    echo         Click derecho -^> Ejecutar como administrador.
    echo.
    pause
    exit /b 1
)

REM --- Estado previo ---
if exist "%TARGET%\" (
    echo [INFO] La carpeta YA existe: %TARGET%
) else (
    echo [INFO] La carpeta NO existe. Creandola...
)

REM --- Crear (mkdir crea toda la cadena ProgramData\Pakon\Temp) ---
mkdir "%TARGET%" 2>nul

if not exist "%TARGET%\" (
    echo [ERROR] No se pudo crear %TARGET%
    echo.
    pause
    exit /b 1
)
echo [OK] Carpeta presente: %TARGET%

REM --- Permisos: dar Modificar al grupo Usuarios (SID *S-1-5-32-545) ---
REM  (hereda a subcarpetas/archivos con OI/CI)
icacls "C:\ProgramData\Pakon" /grant "*S-1-5-32-545:(OI)(CI)M" /T >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Permisos de escritura otorgados al grupo Usuarios.
) else (
    echo [WARN] No se pudieron ajustar permisos (puede no ser necesario si PSI corre como admin).
)

REM --- Prueba de escritura real ---
set "TESTFILE=%TARGET%\_writetest.tmp"
echo test> "%TESTFILE%" 2>nul
if exist "%TESTFILE%" (
    del "%TESTFILE%" >nul 2>&1
    echo [OK] Prueba de escritura EXITOSA en %TARGET%
) else (
    echo [ERROR] No se pudo escribir en %TARGET%
    echo         Revisar Antivirus / Acceso controlado a carpetas ^(Windows Defender^).
)

echo.
echo ==== Listo. Ahora abrir PSI y probar Save As Raw. ====
echo  Durante la extraccion deberian aparecer archivos
echo  psi_frame_NN.raw dentro de %TARGET%
echo.
pause
endlocal
