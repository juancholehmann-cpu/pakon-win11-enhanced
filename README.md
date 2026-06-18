# Pakon F135 PSI — Windows 11 Enhanced Edition

This package contains patched files for an existing Pakon installation.

The original Pakon software and Windows 11 compatible drivers must already be installed before running this package.

## Prerequisites

Required installation order:

1. Install the original Pakon software.
2. Install the Windows 11 compatible Pakon scanner drivers.
3. Verify that the scanner is detected correctly by Windows.
4. Run **install.bat** as Administrator.
5. Launch PSI normally.

This package does **not** include the original Pakon software or scanner drivers. It only installs patched files, registry updates and configuration changes.

---

# Added Features

## Windows 11 Compatibility

Allows PSI to run correctly on modern versions of Windows by applying compatibility and ODBC fixes required for Windows 11.

## Half Frame Mode

A new **Half Frame** option is available under the **Help** menu.

When enabled, scans are automatically split into individual half-frame images.

The setting is persistent and will remain enabled after restarting PSI.

## UI Unlock During Scanning

Several interface restrictions have been removed.

While a scan is running, most controls remain accessible, allowing navigation and interaction without waiting for the scan to complete.

**Current limitation:** image previews cannot yet be opened while an active scan is in progress.

## 16-Bit Planar RAW Extraction

PSI can now export the scanner's original 16-bit planar RAW data.

You can start the extraction from either:

- **Help → Extract RAW16**
- The **Help (?) button** on the toolbar

### Workflow

1. Scan your film normally.
2. Run **Extract RAW16** using either method above.
3. Wait for extraction to complete.
4. Use **Save As Raw** as usual.

The exported files contain the original 16-bit planar RGB data produced by the scanner.

**Note:** the toolbar Help button no longer opens context help. It now triggers the RAW16 extraction process.

## Positive Film Scanning

A new **Positive** option is now available in the **Film Color** settings, alongside Negative and C41 B/W.

When selected, PSI scans positive film (slides / transparencies) correctly, producing properly developed positive images instead of inverted or negative-masked results.

## Full-Resolution 16 Base Scans

PSI no longer crops 16 Base scans to 2941 × 1960. Scans are now kept at their full **3000 × 2000** dimensions, preserving the entire image area.

## Ignore DX Sensors

A new **Ignore DX** option is available under the **Setup** menu.

When enabled (a check mark appears next to the menu item), PSI bypasses the scanner’s DX sensors during light calibration, so scanning works normally even when the DX sensors are missing or not functioning.

The setting is persistent between sessions, so you can enable it once and keep scanning across restarts.

**Tip:** if your scanner’s DX sensors are damaged, open **Setup → Ignore DX** once and enable it. From then on, every time you launch PSI the scan starts with the DX bypass already active.

## Transparent Base Color Film Scanning

A new **Clear Base Film** option is available under the **Help** menu.

When enabled, PSI can correctly scan color film with a very transparent base (e.g. Santacolor, Harman Phoenix and similar emulsions). Without this option, this kind of film stopped scanning after the first frame in color mode, because the frame detector treated the bright transparent base as a continuous gap.

### Usage

1. Load the transparent-base color film as usual.
2. Enable **Help → Clear Base Film** (a check mark appears next to the menu item).
3. Scan normally.
4. **Disable the option again before scanning regular (opaque-base) film.**

### Important notes

- The setting is **not persistent** by design. PSI resets it to off every time it starts. Leaving it on for normal opaque-base film can interfere with end-of-roll detection, so it is only meant to be enabled when scanning transparent-base color film.
- The option only takes effect after the scanner has been initialized. Toggling it before the scanner is connected has no effect and is safe.
- Fixed Pattern Correction (FPC) remains on, so the vertical-line artifacts ("FPN") that appeared with previous workarounds (registry-based FPC off plus external destripe) do not appear. No registry changes or post-processing are required.
- This option replaces the earlier *Clear base film* behavior, which used to toggle FPC. The previous FPC-based workflow is no longer needed for transparent-base color film.

## Custom Scanning Profiles

A new **Profiles** system is available under the **Setup** menu to allow saving and recalling up to 5 custom scanning configurations.

- **Save Profile**: Save the settings of the currently selected photo into one of 5 available slots. You can assign a custom name to each profile.
- **Apply Profile**: Quickly load your saved settings from the Profiles menu (Profile 1 to 5).
- **Delete Profile**: A submenu allows you to delete specific profiles individually (Delete Profile 1 to 5). PSI will warn you if you attempt to delete an empty slot and will ask for confirmation before deleting an occupied slot.

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

Run:

    install.bat

as **Administrator**.

The installer automatically performs the following actions:

- Installs the patched PSI executable
- Installs the patched TLB.dll
- Installs the patched ODBC driver
- Creates the required MRD and MRD Log ODBC data sources
- Applies Windows XP compatibility settings
- Disables IQueue auto-launch
- Creates a Pakon PSI desktop shortcut
- Installs the bundled Visual C++ 2003 runtime DLLs (mfc71u.dll, msvcp71.dll, msvcr71.dll) from the vc2003 folder, only if they are missing
- Installs PSIBitmapButtons.dll from the vc2003 folder, only if it is missing

---

# Included Files

| File | Purpose |
|------|---------|
| PSI.exe | Main PSI executable with Windows 11 compatibility and feature enhancements |
| TLB.dll | RAW16 extraction, Half Frame support and additional functionality |
| odbcjt32_patched_v10.dll | ODBC compatibility fix for Windows 11 |
| vc2003 (folder) | Bundled support libraries copied into the PSI folder only when missing |
| mfc71u.dll, msvcp71.dll, msvcr71.dll | Visual C++ 2003 runtime (placed in the vc2003 folder); installed if missing |
| PSIBitmapButtons.dll | PSI UI component (placed in the vc2003 folder); installed only if not already present |

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

# Author

This Windows 11 Enhanced Edition of Pakon PSI was created and maintained by:

**Juan Cruz Lehmann**

GitHub:
https://github.com/juancholehmann-cpu

The project focuses on preserving and extending the usability of the Pakon F135 on modern Windows systems while maintaining compatibility with the original workflow.

---

## Support

If this project helped you keep your Pakon running on Windows 11, consider supporting future development.

☕ Ko-fi: https://ko-fi.com/lehmannjuancruz

Support is completely optional, but it helps fund future development, bug fixes, reverse engineering efforts and new Pakon tools.

---

# Disclaimer

This package is an unofficial community modification of the original Pakon software.

It is intended to improve compatibility and usability on modern Windows systems while preserving the original scanning workflow.
