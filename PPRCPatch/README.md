# PPRC + Header Patch (Full-Frame / Half-Frame Support)

This package installs **PPRC** (*pakon-planar-raw-converter*, the Pakon planar RAW to TIFF converter) and applies a **patch** that automatically reads image dimensions (width × height) from the header of each `.raw` file.

This allows conversion of full-frame, half-frame and variable-width images **without** manually specifying `--dimensions`.

## Contents

- `Install-pprc.ps1` — all-in-one installer (installs PPRC if missing and applies the patch).
- `Restore-pprc.ps1` — restores the original PPRC installation.
- `README.md` — this file.

## Requirements

- **Node.js** (includes npm): https://nodejs.org
- **ImageMagick** (`magick` command): https://imagemagick.org/script/download.php#windows
  (required by PPRC for TIFF conversion; the installer will warn if it is missing).
- *(Optional)* **negfix8** — only required when using PPRC in its default color-negative mode. For positives/E6 film, use `--e6` and negfix8 is not required.

## Installation

1. Copy this folder to the target computer.
2. Open **PowerShell** inside the folder.
3. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-pprc.ps1
```

The installer will:

- Verify that Node.js and npm are installed.
- Install PPRC if it is not already present.
- Create a backup of the original file.
- Apply the header-detection patch.
- Verify that the modified file is valid.
- Skip reapplying the patch if it is already installed.

## Usage

Navigate to the folder containing your `.raw` files and run:

```powershell
pprc --no-negfix --e6
```

Each RAW file will be converted using its own dimensions read directly from the header.

**Manual `--dimensions` parameters are no longer required.**

The `--dimensions` option may still be used for files without a valid header. When a valid header is present, the header values take priority.

Converted TIFF files are written to the `out` subfolder.

## RAW File Format Reference

```text
Header = 16 bytes (4 little-endian DWORDs)

[0] = 0x10
[1] = Width
[2] = Height
[3] = 0x30

Image Data:
16-bit planar RGB

R plane (Width × Height uint16)
G plane (Width × Height uint16)
B plane (Width × Height uint16)

Total size:
16 + Width × Height × 6 bytes
```

## Restoring the Original Version

To remove the patch and restore the original PPRC installation:

```powershell
powershell -ExecutionPolicy Bypass -File .\Restore-pprc.ps1
```

The script restores the original `index.js` from the most recent backup:

```text
index.js.bak-preheaderpatch_<date>
```

## Reinstalling or Updating PPRC

Running:

```powershell
npm install -g pakon-planar-raw-converter
```

will replace `index.js` and remove the patch.

If PPRC starts requiring `--dimensions` again or stops accepting half-frame files, simply rerun:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-pprc.ps1
```

The installer is idempotent and can safely be run multiple times.
