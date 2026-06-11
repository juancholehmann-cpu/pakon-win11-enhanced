# Investigación Completa: Película con Base Transparente / Color - Corte Tras Cuadro 1

**Última actualización**: 2026-06-11 | **Estado**: Root cause identificada, patch en desarrollo

---

## 1. Definición del Problema

### Síntoma Observable
- **Película**: negativo color con base transparente/clara (Santacolor, Harman Phoenix)
- **Modo de escaneo**: Color (Neg)
- **FPC activado**: `UseFixedPatternCorrection=1`
- **Resultado**:
  - ✅ Primer cuadro: escanea y se ve limpio (FPC funciona)
  - ❌ **El scan se corta tras el cuadro 1** (debe escanear 4+ cuadros)
  - ✅ Mismo modo en **C41 B/W**: escanea los 4 cuadros correctamente
  - ✅ Película SIN código DX: también funciona en Color
  - ✅ **FPC OFF** (registro): escanea todos los cuadros pero aparecen bandas verticales (FPN)

### Casos de Prueba Confirmados
| Configuración | Resultado | Observación |
|---|---|---|
| Transparente + Color + FPC ON | Corta tras frame 1 | **PROBLEMA** |
| Transparente + B/W | Escanea 4 frames | OK |
| Transparente + Color + FPC OFF | Escanea 4 frames | Bandas FPN visibles |
| Color normal + FPC ON | Multiframe OK | OK |
| Transparente SIN DX + Color + FPC ON | Corta tras frame 1 | DX NO es causa |

### Conclusión Inicial
El corte está **acoplado específicamente a FPC + base transparente**, no a perforación DX ni a modo Color en general.

---

## 2. Análisis de la Cadena FPC (Confirmado vía WinDbg)

### 2.1 Pipeline FPC en TLB.dll

#### Ubicación y Tamaño
- **Módulo**: `TLB.dll` (F-X35 COM SERVER)
- **ImageBase**: `0x10000000` (variable en runtime; usar `lm m TLB` en WinDbg)
- **Tamaño real**: ~540 KB (PE32 i386)
- **Nota**: `TLA.dll` en disco es **solo referencia/diccionario**, NO se carga en runtime

#### Punto de Decisión FPC (`TLB+0x1e4a0`)
```asm
TLB+0x1e4e5  mov eax,dword ptr [esp+30h]    ; carga flag FPC desde argumento
TLB+0x1e4e9  test eax,eax
TLB+0x1e4eb  jne TLB+0x1e55a                ; si FPC=1, rama ON
; si FPC=0, cae a rama OFF
```

**Decodificación**:
- `eax=1` (FPC ON): salta a `TLB+0x1e55a` → genera tablas de corrección
- `eax=0` (FPC OFF): cae directo a `TLB+0x1e4ed` → limpia/zeroes buffers

---

### 2.2 Generador FPC: `TLB+0x1f550` (The Gain Table Generator)

#### Entrada (Argumentos en Stack)
```asm
TLB+0x1f550  sub esp,24h
; arg1 = objeto/contexto
; arg2 = FLAG ACTIVO (0=skip generación; 1=generar tablas completas)
```

#### Flujo Rama ON (cuando `arg2=1`)
1. **Inicialización**: `TLB+0x1f66b` → `call TLB+0x1d590` (procesador de ganancia)
2. **Cálculo de coeficientes**: múltiples `call TLB+0x1d4c0` en `0x1f6a6`, `0x1f6bb`, `0x1f6d0`, `0x1f6ea`, `0x1f700`, `0x1f716`, `0x1f739`
3. **Escritura en objeto** (campos de tabla):
   - `TLB+0x1f7a3`: escribe `[ebx+40]` (ej. valor `0x5d` o `0x5e`, escalar por canal)
   - `TLB+0x1f80e`: escribe `[ebx+44]` (ej. `0x0f` o `0x11`)
   - `TLB+0x1f878` (cercano): escribe `[ebx+48]` (ej. `0x04` o `0x07`)
4. **Generación de buffers grandes** (tablas en memoria):
   - `TLB+0x1f88c..0x1f90f`: genera buffer en `[ebx+30]` (tabla canal 1)
   - `TLB+0x1f90f..0x1f97d`: genera buffer en `[ebx+34]` ← **LA TABLA CRÍTICA**
   - `TLB+0x1f97d..0x1f9ed`: genera buffer en `[ebx+38]`
   - `TLB+0x1f9ed..0x1fa6e`: genera buffer en `[ebx+3c]`

#### Flujo Rama OFF (cuando `arg2=0`)
- Limpia/zeroea los mismos buffers
- Retorna sin generar tablas útiles

---

### 2.3 La Tabla Crítica: `[ebx+0x34]` (Gain/Correction por Canal)

#### Formato
- **Tipo**: DWORD en punto fijo 16.16
  - Ejemplo: `0x0001d653` = 1 + 0xd653/0x10000 ≈ 1.835x (multiplicador)
  - Identidad neutra: `0x00010000` = 1.0x (sin cambio)
- **Tamaño**: `0x3ea0` bytes (4008 píxeles × 4 bytes/píxel)
- **Índice**: se lee vía `[ebx+0x34]` en el core MMX

#### Propósito Original (Película Color Normal)
En **negativo color C41 estándar**:
- La emulsión tiene **máscara naranja** que absorbe ~45-50% de la luz en ciertos canales
- La tabla `[ebx+0x34]` contiene factores ~1.83x–1.99x para **compensar esa absorción**
- Después de aplicar: imagen se ve con colores naturales (sin tinte naranja)

#### El Problema en Base Transparente
En **película con base transparente** (Santacolor, Phoenix):
- **NO hay máscara naranja** (es película diferente)
- Pero la tabla `[ebx+0x34]` sigue teniendo valores ~1.83x–1.99x
- Al aplicar esos factores: **saturación de píxeles** (valores clipped)
- Imagen queda con píxeles en techo (0xFF en 8-bit, o máximo en 16-bit)
- Detector de bordes MMX no puede distinguir bordes en píxeles saturados

---

### 2.4 Donde se Aplica la Tabla: Core MMX (`TLB+0x25220`)

```asm
TLB+0x247b5  mov edx,[esi+34h]              ; carga puntero tabla [ebx+34]
TLB+0x247b8  mov edi,[edx+eax*4]            ; lee valor DWORD de tabla
TLB+0x247bb  mov edx,[ebp-8]
TLB+0x247be  shr edi,2                      ; DWORD → 16-bit (divide por 4)
TLB+0x247c1  mov [edx],di                   ; escribe WORD al buffer de salida
TLB+0x247c4  add edx,2
; ... repeats para otros canales ...
TLB+0x247e3  inc eax                        ; siguiente píxel
TLB+0x247e4  cmp eax,edx                    ; vs ancho total
TLB+0x247e6  jb TLB+0x24769                 ; loop
```

**Operación**:
1. Lee DWORD desde tabla (ej. `0x0001d653`)
2. Divide por 4 con shift (`shr 2` → `0x00007596` ≈ 30118 en 16-bit)
3. Escribe WORD al buffer de salida
4. Loop sobre todos los píxeles × 3 canales

---

### 2.5 Publicación de Tablas: `TLB+0x24aa0..0x24b43`

Después de generación, el objeto se **publica** a globales para que el core las lea:

```asm
TLB+0x24aa0  mov edi,dword ptr [esi+2c]     ; p2c (correction plane WORD)
TLB+0x24aa3  mov di,word ptr [edi+eax*2]    ; índice en plano
TLB+0x24aa7  mov word ptr [ecx],di          ; escribe a buffer global

TLB+0x24aa0  mov edi,dword ptr [esi+3c]     ; [ebx+3c] → buffer de dwords
TLB+0x24dxx  mov edi,dword ptr [esi+34h]    ; [ebx+34] → buffer de dwords
; etc.
```

**En Color Normal + FPC ON**:
- `[ebx+2c]` = WORD stream `0x011x`, `0x012x`, ... (correction plane)
- `[ebx+3c]` = DWORD gradiente real, ej. `00027d56 00027735 ...`
- `[ebx+34]` = DWORD valores ~`0x0001d653`, sin neutralizar

**En Transparente + FPC ON (ANTES de patch)**:
- `[ebx+2c]` = WORD stream (algo de corrección)
- `[ebx+3c]` = DWORD gradiente
- `[ebx+34]` = **MISMO**: `0x0001d653` sin cambios ← **CAUSA DEL PROBLEMA**

---

## 3. La Cadena del Deadlock (Confirmado vía Instrumentación)

### 3.1 Detector de Bordes: Loop Consumidor (`TLB+0x30a0c..0x30bfb`)

```asm
TLB+0x30a0c  loop_head:
TLB+0x30a28  mov eax,[ebp+48]
TLB+0x30a2d  test eax,eax
TLB+0x30a2d  je TLB+0x30a7b                 ; si [ebp+48]==0, finaliza
TLB+0x30a7b  ; bloque de conteo/decisión
TLB+0x30a7b  mov eax,[ebp+10]               ; contador actual
TLB+0x30a7f  cmp eax,[ebp+0c]               ; vs límite
TLB+0x30a82  jge TLB+0x30ac0                ; si >= límite, salir del loop
```

**En Color Transparente + FPC ON SATURADO**:
1. Las líneas de escaneo llegan al core MMX
2. Píxeles saturados (ganancia 1.83x aplicada a base clara)
3. Detector de bordes **NO encuentra bordes válidos**
4. No escupe frames → `[ebp+48]` permanece no-cero
5. Loop no avanza → no libera buffer
6. Productor llena buffer, intenta escribir más líneas
7. `WaitForSingleObject` bloquea → espera que consumidor libere

### 3.2 Productor (Thread 21): `TLB+0x29db9` (ReadFile overlapped)

```asm
TLB+0x29db9  call [ds:0x1005b050]           ; KERNEL32!ReadFile
; args: hFile=[esi+5a0], lpBuffer=buf, nBytesToRead=size, lpBytesRead, lpOverlapped=[esi+0x14]
```

**Flujo**:
1. Produce: encola lecturas del scanner (ReadFile overlapped)
2. Espera en `TLB+0x29e57` con `WaitForSingleObject`
3. Si consumidor liberó → continúa
4. Si consumidor NO libera → se queda esperando
5. Cuando buffer lleno: produce se bloquea

### 3.3 Watchdog (Thread 23): `TLB+0x310d9..0x310f6` (Timer de Inactividad)

```asm
TLB+0x310d9  mov ecx,[esi+1c]
TLB+0x310dc  test ecx,ecx
TLB+0x310de  jne TLB+0x310ec                ; si [esi+1c]!=0, aborta directo
TLB+0x310e0  mov edx,[ebp+10]               ; contador de timeout
TLB+0x310e3  mov ecx,[esp+58]               ; límite esperado
TLB+0x310e7  inc edx
TLB+0x310e8  cmp ecx,edx                    ; ¿expiró?
TLB+0x310ea  jg TLB+0x31111                 ; si NO expiró (ecx > edx), continúa
; else fall through:
TLB+0x310ec  mov eax,[esp+14]               ; puntero a StopTransfer
TLB+0x310f6  mov byte ptr [eax],1           ; StopTransfer = 1 ← EMERGENCY ABORT
```

**Secuencia**:
1. Contador watchdog incrementa cada ciclo
2. Cuando contador >= límite (típicamente 1 segundo):
3. **Escribe `StopTransfer=1`** (orden de aborto de emergencia)
4. Hardware scanner recibe señal via `CancelIo()`
5. Escaneo se detiene abruptamente

### 3.4 El Deadlock Gráfico

```
┌─────────────────────────────────────────────────────────────────┐
│ Thread 21 (Productor): ReadFile overlapped                      │
│ ├─ Encola líneas del scanner                                    │
│ └─ WaitForSingleObject(buffer_ready) → BLOQUEADO                │
│    (esperando que consumidor libere espacio)                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                       BUFFER LLENO
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Thread 22 (Consumidor): MMX + Edge Detection (`TLB+0x25220`)   │
│ ├─ Aplica ganancia 1.83x (saturación en transparente)          │
│ ├─ Detector no ve bordes válidos en píxeles saturados          │
│ ├─ No escupe frames                                             │
│ ├─ No libera buffer                                             │
│ └─ Sleep loop esperando datos válidos → BLOQUEADO              │
│    (nunca ve bordes, así que nunca avanza)                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                        AMBOS ESPERAN
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Thread 23 (Watchdog): `TLB+0x310d9..0x310f6`                  │
│ ├─ Monitorea inactividad (~1 segundo)                          │
│ ├─ Contador expira                                              │
│ └─ Escribe StopTransfer=1 → CancelIo() → ABORT FORZADO        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Evidencia Experimental (WinDbg Sessions)

### 4.1 Sesión 2026-06-10 (Primeros Hallazgos)

#### Conteos Comparativos

**Entrada a consumidor `TLB+0x2f550`**:
- Color (multiframe real): 1 entrada
- Transparente B/N (proxy, full FPC): 1 entrada
- **Conclusión**: no es re-entrada; ambos llegan una vez a teardown

**Rama `TLB+0x30492` (decisión interna)**:
- Color normal: 938 hits
- Transparente full FPC: ~5063 hits
- **Color es ~5.4× menor** → transparente toma esa rama mucho más
- Síntoma: rama de "no hay más frames" se toma temprano en transparente

**Inicialización idéntica en `TLB+0x30447`** (primeras muestras):
- `esi=fffc`, `[esp+9c]=d2f0`, `[esp+b0]=ee48`, `[esp+b4]=2` en ambos
- **Diferencia: la rama se toma demasiado pronto en transparente**

#### Escritura de StopTransfer (`TLB+0x310f6`)
- Conteo: 1 en ambos modos (Color y ByN)
- **NO es discriminador directo**; ocurre como finalización de emergencia igual en todos

### 4.2 Sesión 2026-06-11 (Descartes Host-Side)

#### DeviceIoControl (Comando Control)

**Llamadas totales durante scan**:
- Color: 604 IOCTLs
- ByN: 901 IOCTLs
- Diferencia: ByN tiene más porque el scan dura más (duración, no cantidad de comandos útiles)

**Códigos de comando en `0x222090`** (poll/status):
```asm
[lpInBuffer+2] = código de comando
```
- Muestreo: primeras 30 llamadas en ambos modos
- **Únicos valores observados**: `0x10`, `0x40`, `0x44`
- **NO aparece ningún otro código** que ordene "avanzar" o "transportar N cuadros"

**IOCTL `0x222059`** (comando fijo transportar):
- Color: 0 llamadas
- ByN: 0 llamadas
- **NO se usa durante el scan**, solo durante setup/calibración

**Conclusión**: El canal `DeviceIoControl` **NO contiene la orden de avance**. Todo es poll/status. El transporte/avance se decide **en software (TLB) antes de encolar ReadFile**, no vía comando explícito.

#### Búsqueda de SenseFilm / SetFilmLength

**SenseFilm** (reference `0x10010cfb`):
- BP pegó 2 veces en ambos modos
- Post-call en `TLB+0x10d07`: campos idénticos en Color y ByN
  - `[esi+0x28]=1`, `[esi+0x20]=0`, `[esi+0x24]=0`, `[esi+0x2c]=0`
- **No discrimina el caso malo**

**Conclusión parcial**: SenseFilm **lee bien** pero el lugar donde decide el largo de transporte está **en otro sitio**, probablemente en el bucle que encola ReadFile.

---

## 5. Hipótesis Vigentes (Prioridad)

### Hipótesis Principal (MÁS PROBABLE)
**El largo de transporte calculado es menor en Color con base transparente**

- Lugar: algún bucle en el **productor** (`~TLB+0x10029dd0–0x10029f3e`) o en inicialización previa
- Síntoma: Color encolallamadas a ReadFile (menos líneas), ByN encola 4× más
- Detección: contar `call [ds:0x1005b050]` (ReadFile) en cada sitio vs Color/ByN

### Hipótesis Secundaria
**El detector rechaza los bordes encontrados en Color transparente **

- Lugar: el loop de conteo/decisión `TLB+0x30a0c..0x30a7f`
- Síntoma: `[ebp+48]` (bandera de "hay frames válidos") se queda no-cero temprano
- Acción: aunque se encolen líneas, el consumidor decide "estos bordes NO son válidos" y finaliza

---

## 6. Soluciones Propuestas

### Solución A: Neutralizar Tabla `[ebx+0x34]` en Transparente (TESTEADA)

#### Estrategia
1. Forzar `TLB+0x2146e`: activar FPC con `arg2=1` siempre
2. Después de generación en `TLB+0x1fa6e`: llenar `[ebx+0x34]` con identidad `0x00010000`

#### Comando WinDbg (validación)
```windbg
bp /1 TLB+0x2146e "r eax=1; ed @esp+8 1; gc"           ; force FPC ON
bp TLB+0x1fa6e "f poi(@ebx+34) L3ea0 00 00 01 00; gc"  ; fill identity
```

#### Resultados Observados
- ✅ **Scan transparente COMPLETÓ** (4 cuadros, no cortó tras 1)
- ✅ **Detectó fin de película correctamente** (no hang infinito)
- ✅ **NO activó watchdog** (no hubo `StopTransfer=1` prematuro)
- ❓ **Validación visual PENDIENTE**: ¿desaparecen bandas? ¿color es correcto?

#### Ventajas
- Mínima, quirúrgica
- Solo toca `[ebx+0x34]` (una tabla de 4 canales)
- Preserva resto de FPC (`p2c`, `p3c`, `p4c`, `p50`, `p54`, `[ebx+30/38/3c]`)

#### Desventajas
- Identidad `0x00010000` **destruye estructura por columna** del mapa de ganancias
- Película color normal podría perder finura de corrección
- Necesita **discriminación de tipo de película** (transparente vs color)

#### Implementación Recomendada
**Cave patch en TLB** (similar a raw16 existente):
```asm
; pseudocode cave
; post TLB+0x1fa6e, antes de retorno de generador

mov ecx, poi(@ebx+34)           ; ptr tabla
mov edx, 0x3ea0                 ; tamaño en bytes

fill_loop:
    mov dword ptr [ecx], 0x00010000
    add ecx, 4
    sub edx, 4
    jnz fill_loop
    
; return a TLB+0x1fa6e+5 con flags intactos
```

---

### Solución B: Clamp Selectivo por Columna (NO TESTEADA)

#### Idea
En lugar de reemplazar con identidad, **limitar valores a rango seguro** (ej. 1.5x–1.7x) preservando estructura columnar.

#### Ventaja
- Mantiene fine-structure de FPC (probablemente mejor visual)
- Menos riesgo de romper película color

#### Desventaja
- Lógica más compleja (read, check, conditional write per DWORD)
- Threshold selection es empírico (¿1.5x? ¿1.7x? varía por scanner/película)
- Más código de cave

---

### Solución C: Discriminación de Tipo de Película (MEJOR CALIDAD)

#### Idea
Detectar en runtime si base es transparente vs color, y:
- **Transparente**: aplicar Solución A o B
- **Color**: dejar FPC intacto

#### Detección Posible
1. **UI explícito**: usuario marca "Clear/Transparent Film" (nuevo checkbox)
2. **Registro**: `HKLM\...\Pakon\TLB\Scan\Test\` algún flag o modo
3. **Automática**: estadística del primer frame (píxeles muy brillantes = transparente?)

#### Ventaja
- Preserva **full FPC para película color normal**
- Aplica corrección adecuada a transparente

#### Desventaja
- Necesita mecanismo de detección confiable
- Más código (condicional en cave)

---

## 7. Workaround Actual (Registro, SIN Parche Binario)

Hasta que se implemente patch permanente:

```batch
reg add "HKLM\Software\WOW6432Node\Pakon\TLB\Scan\Test" /v UseFixedPatternCorrection /t REG_DWORD /d 0 /f
reg add "HKLM\Software\WOW6432Node\Pakon\TLB\Scan\Test" /v RequireDxSensorsDuringLightCalibration /t REG_DWORD /d 0 /f
reg add "HKLM\Software\WOW6432Node\Pakon\TLB\Scan\Test" /v DxCalibrationFilmOffset /t REG_DWORD /d 5 /f
```

**Resultado**:
- ✅ Escanea todos los cuadros (no se corta)
- ❌ Aparecen bandas verticales (FPN, inherente del sensor)
- ⚠️ Color podría verse "flat" sin corrección por canales

**Post-procesamiento**: usar `pprc --calibrate --destripe` offline (calibración por máquina, reusable)

---

## 8. Próximos Pasos (Recomendación)

### Inmediato
1. **Validación Visual de Solución A**
   - Escanear película transparente con workaround `0x00010000`
   - Extraer RAW, convertir con pprc
   - Comparar:
     - vs FPC OFF (registro): ¿menos bandas que esta?
     - vs Color normal con FPC ON: ¿color similar?
   - Verificar: Digital ICE funciona

2. **Confirmación de Multiframe**
   - Escanear >4 cuadros en transparente con `0x00010000`
   - Verificar: cada RAW tiene datos correctos

### Corto Plazo
3. **Decisión Solución**
   - Si Solución A es aceptable visual → codificar cave patch
   - Si hay problemas visuales → evaluar Solución B (clamp) o C (discriminación)

4. **Implementación**
   - Build TLB.dll con patch elegido
   - Rebuild PSI.exe si es necesario (probably no)
   - Testing exhaustivo (color normal, transparente, B/W, DX/no-DX)

### Mediano Plazo
5. **Integración**
   - Merge en build oficial
   - Documentación usuario (modo "Clear Film" o instrucciones)
   - Validación en equipos de clientes

---

## 9. Datos Técnicos de Referencia (Para Implementación)

### Offsets IAT de TLB.dll
```
DeviceIoControl = 0x1005b0b4
ReadFile        = 0x1005b050
WriteFile       = 0x1005b048
CancelIo        = 0x1005b0c0
WaitForSingleObject = 0x1005b04c
SetEvent        = 0x1005b044
ResetEvent      = 0x1005b040
GetOverlappedResult = 0x1005b084
GetLastError    = 0x1005b028
```

### Estructuras del Contexto
```
counter_struct (instalado en TLB+0x2e762):
  [addr+0x14] = Reading (líneas leídas)
  [addr+0x18] = ToRead (líneas por leer)
  [addr+0x1c] = Writing (líneas escritas)
  [addr+0x20] = NF (número de fotogramas)

scan_context (ebp en consumidor TLB+0x30a0c):
  [ebp+0x0c] = LIMIT (límite de fotogramas esperado)
  [ebp+0x10] = COUNTER (contador actual)
  [ebp+0x30] = StopTransfer (byte flag)
  [ebp+0x40] = done (byte flag)
  [ebp+0x48] = indica si hay fotogramas válidos
  [ebp+0x94] = tipo/modo de escaneo (ej. 4=?)
```

### Tamaño de Buffer
```
[ebx+0x34] buffer size = 0x3ea0 bytes (NO EXCEDER)
IMPORTANTE: fill > 0x3ea0 causa heap corruption
```

### Identidad en Punto Fijo 16.16
```
0x00010000 = 1.0 (no change)
Derivada para WORD: shr 0x00010000 2 = 0x0004 (4 en 16-bit)
```

---

## 10. Referencias de Sesiones WinDbg

| Fecha | Archivo Log | Tema |
|-------|---|---|
| 2026-06-10 | `pakon_B_transparent_*.txt` | Primeros hallazgos FPC, deadlock, watchdog |
| 2026-06-10 | `pakon_A_color_*.txt` | Comparación Color vs Transparente |
| 2026-06-10 | `pakon_disasm_303a9_*.txt` | Desensamblado de loop de decisión |
| 2026-06-11 | `C:\Temp\ioctl_color.txt` | DeviceIoControl en Color |
| 2026-06-11 | `C:\Temp\ioctl_byn.txt` | DeviceIoControl en ByN |

---

## 11. Estado Resumen

| Aspecto | Estado |
|--------|--------|
| **Root Cause Identificada** | ✅ Sí (saturación por ganancia 1.83x en transparente) |
| **Mecanismo Deadlock Confirmado** | ✅ Sí (consumidor atrapado, watchdog aborta) |
| **Solución A Testeada en WinDbg** | ✅ Sí (`0x00010000` permite scan completo) |
| **Validación Visual** | ⏳ Pendiente |
| **Patch Binario Codificado** | ⏳ Pendiente |
| **Testing Multiframe** | ⏳ Pendiente |
| **Discriminación Tipo Película** | ⏳ Opcional (TBD) |

---

**Próxima sesión**: Validar visual con Solución A y decidir implementación final.
