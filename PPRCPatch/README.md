# pprc + parche de header (full / half frame)

Esto instala **pprc** (`pakon-planar-raw-converter`, el conversor de RAW planar de Pakon a TIFF)
y le aplica un **parche** para que lea las dimensiones (ancho × alto) del **header de cada
archivo `.raw`**. Así convierte full-frame, half-frame y fotos de cualquier ancho **sin** tener
que pasar `--dimensions` a mano.

## Qué incluye la carpeta

- `Install-pprc.ps1` — instalador todo-en-uno (instala pprc si falta + aplica el parche).
- `Restore-pprc.ps1` — deshace el parche (vuelve al pprc original).
- `README.md` — esto.

## Requisitos

- **Node.js** (incluye npm): https://nodejs.org
- **ImageMagick** (comando `magick`): https://imagemagick.org/script/download.php#windows
  (pprc lo usa para convertir; el instalador avisa si falta).
- *(Opcional)* **negfix8**: sólo si vas a usar pprc en su modo por defecto (negativos color).
  Para positivos/E6 se usa `--e6` y no hace falta.

## Instalación (en otra PC o de cero)

1. Copiá esta carpeta a la otra máquina.
2. Abrí **PowerShell** dentro de la carpeta.
3. Corré:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Install-pprc.ps1
   ```

   El script: verifica Node/npm, instala pprc si no estaba, hace backup del archivo original,
   aplica el parche (no rompe nada si ya estaba parcheado) y verifica la sintaxis.

## Uso

En la carpeta donde tengas tus `.raw`:

```powershell
pprc --no-negfix --e6
```

Cada `.raw` se convierte usando su **propio** ancho/alto leído del header. **Ya no hace falta
`--dimensions`.** (Igual lo podés seguir pasando para archivos sin header; el header tiene
prioridad sólo cuando existe y valida.)

Los `.tif` quedan en la subcarpeta `out`.

## El formato del RAW (referencia)

```
Header = 16 bytes (4 dwords little-endian):  [0]=0x10  [1]=W  [2]=H  [3]=0x30
Datos  = planar RGB 16-bit: plano R (W*H uint16), luego plano G, luego plano B
tamaño = 16 + W*H*6
```

## Deshacer el parche

```powershell
powershell -ExecutionPolicy Bypass -File .\Restore-pprc.ps1
```

Restaura el `index.js` original desde el backup más reciente
(`index.js.bak-preheaderpatch_<fecha>`).

## Si reinstalás/actualizás pprc

Un `npm install -g pakon-planar-raw-converter` reemplaza el `index.js` y borra el parche.
Si pprc vuelve a pedir `--dimensions` o rechaza half-frames, simplemente volvé a correr
`Install-pprc.ps1` (es idempotente).
