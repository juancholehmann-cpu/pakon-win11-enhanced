# Pakon F135 PSI — Windows 11 Enhanced Edition

This package contains patched files for an existing Pakon installation.

The original Pakon software and Windows 11 compatible drivers must already be installed before running this package.

Required installation order:

1. Install the original Pakon software.
2. Install the Windows 11 compatible Pakon scanner drivers.
3. Verify that the scanner is detected correctly by Windows.
4. Run **install.bat** as Administrator.
5. Launch PSI normally.

This package does not include the original Pakon software or scanner drivers. It only installs patched files, registry updates and configuration changes.

---

# Added Features

## Windows 11 Compatibility

Allows PSI to run correctly on modern versions of Windows by applying compatibility and ODBC fixes required for Windows 11.

---

## Half Frame Mode

A new **Half Frame** option is available under the **Help** menu.

When enabled, scans are automatically split into individual half-frame images.

The setting is persistent and will remain enabled after restarting PSI.

---

## UI Unlock During Scanning

Several interface restrictions have been removed.

While a scan is running, most controls remain accessible, allowing navigation and interaction without waiting for the scan to complete.

**Current limitation:** image previews cannot yet be opened while an active scan is in progress.

---

## 16-Bit Planar RAW Extraction

PSI can now export the scanner's original 16-bit planar RAW data.

You can start the extraction from either:

- **Help → Extract RAW16**
- The **Help (?) button** on the toolbar

Workflow:

1. Scan your film normally.
2. Run **Extract RAW16** using either method above.
3. Wait for extraction to complete.
4. Use **Save As Raw** as usual.

The exported files contain the original 16-bit planar RGB data produced by the scanner.

**Note:** the toolbar Help button no longer opens context help. It now triggers the RAW16 extraction process.

---

## Save As Raw Disabled By Default

The installer imports a registry patch that disables the **Save As Raw** checkbox by default.

This restores the normal PSI workflow and helps prevent accidental RAW exports.

Users can still enable the option manually whenever needed.

---

# Optional PPRC Update (Not Included In Installer)

A separate patch is available for **PPRC (pakon-planar-raw-converter)**.

This update allows PPRC to automatically read image dimensions directly from the RAW file header, eliminating the need to manually specify dimensions.

Benefits:

- Automatic dimension detection
- Supports full-frame and half-frame files
- Supports mixed-width RAW files
- No manual dimension entry required

This patch is distributed separately and is not installed by this package.

---

# Installation

The installer automatically performs the following actions:

- Installs the patched PSI executable
- Installs the patched TLB.dll
- Installs the patched ODBC driver
- Creates the required MRD and MRD Log ODBC data sources
- Applies Windows XP compatibility settings
- Disables IQueue auto-launch
- Creates a Pakon PSI desktop shortcut
- Imports the Save As Raw default-off registry patch
- Verifies required Visual C++ 2003 runtime DLLs

---

# Known Issues

## First Thumbnail After RAW16 Extraction

After running **Extract RAW16**, the first thumbnail of the next scanned roll may appear smaller than normal.

Characteristics:

- Cosmetic issue only
- RAW data is unaffected
- Saved files are correct
- No image data is lost
- Opening the image preview immediately fixes the thumbnail

At this time the issue is considered low priority because it does not affect image quality or exported files.

---

# Included Files

| File | Purpose |
|--------|--------|
| PSI.exe | Main PSI executable with Windows 11 compatibility and feature enhancements |
| TLB.dll | RAW16 extraction, Half Frame support and additional functionality |
| odbcjt32_patched_v10.dll | ODBC compatibility fix for Windows 11 |
| pakon_saveasraw_default_off.reg | Disables Save As Raw by default |

---

# Disclaimer

This package is an unofficial community modification of the original Pakon software.

It is intended to improve compatibility and usability on modern Windows systems while preserving the original scanning workflow.
