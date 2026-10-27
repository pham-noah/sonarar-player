<#
.SYNOPSIS
  Install (or verify) every component the PersonaR tools need, on Windows.

  Normal run (installs what is missing):
      powershell -ExecutionPolicy Bypass -File setup.ps1

  Report only (installs nothing):
      powershell -ExecutionPolicy Bypass -File setup.ps1 -Check

.COMPONENTS
  - Python 3   required by every tool     (installed via winget if missing)
  - pip        required by pip installs    (ensurepip)
  - numpy      required by build_spectrum.py
  - ffmpeg     required by the library builder + spectrum  (winget Gyan.FFmpeg)
  - yt-dlp     OPTIONAL - only download_library_playlists.py needs it

  Safe to re-run: every step is skip-if-already-present. No admin required.
.NOTES
  "All files access" on the phone is still a manual Settings toggle - this
  script only prepares the PC. See README.md.
#>

[CmdletBinding()]
param(
    [switch]$Check   # report what is/isn't installed, install nothing
)

$ErrorActionPreference = "Continue"

function Say     { Write-Host $args[0] }
function Ok      { Write-Host ("  [OK]      " + $args[0]) -ForegroundColor Green }
function Missing { Write-Host ("  [MISSING] " + $args[0]) -ForegroundColor Red }
function Info    { Write-Host ("  [..]      " + $args[0]) -ForegroundColor Yellow }

if ($Check) { Say "CHECK MODE - verifying only, nothing will be installed.`n" }

# ----------------------------------------------------------------------------
# Find a working Python (py launcher first, then python - the Store 'python'
# alias may exist but fail to run, so we ask it to execute a trivial script).
# ----------------------------------------------------------------------------
function Find-Python {
    foreach ($cand in @("py", "python")) {
        $cmd = Get-Command $cand -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        & $cmd.Source -c "pass" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { return $cmd.Source }
    }
    return $null
}

$py = Find-Python

if ($py) {
    $ver = & $py -c "import sys; print(sys.version.split()[0])" 2>$null
    Ok "Python found: $py  ($ver)"
} else {
    Missing "Python 3 not found"
    if (-not $Check) {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Info "Installing Python 3.12 via winget..."
            winget install -e --id Python.Python.3.12 --silent `
                --accept-package-agreements --accept-source-agreements | Out-Null
            Info "Installed. Open a NEW terminal and re-run this script (PATH refresh)."
        } else {
            Info "winget is not available here."
            Info "Download Python from https://www.python.org/downloads/ and tick 'Add Python to PATH'."
        }
        Say ""
        Info "Nothing else can be installed until Python runs - please re-run after installing it."
    } else {
        Say ""
        Info "Remaining checks skipped (Python absent)."
    }
    exit 1
}

# ----------------------------------------------------------------------------
# pip
# ----------------------------------------------------------------------------
$pip = & $py -m pip --version 2>$null
if ($LASTEXITCODE -eq 0 -and $pip) {
    Ok "pip: $pip"
} else {
    Missing "pip"
    if (-not $Check) {
        Info "Bootstrapping pip (ensurepip)..."
        & $py -m ensurepip --upgrade 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { Ok "pip bootstrapped" } else { Missing "pip bootstrap failed" }
    }
}

# ----------------------------------------------------------------------------
# numpy (required by build_spectrum.py)
# ----------------------------------------------------------------------------
$np = & $py -c "import numpy; print(numpy.__version__)" 2>$null
if ($LASTEXITCODE -eq 0 -and $np) {
    Ok "numpy $np"
} else {
    Missing "numpy"
    if (-not $Check) {
        Info "Installing numpy..."
        & $py -m pip install --upgrade numpy 2>$null | Out-Null
        $np2 = & $py -c "import numpy; print(numpy.__version__)" 2>$null
        if ($LASTEXITCODE -eq 0 -and $np2) { Ok "numpy $np2" } else { Missing "numpy install failed - run: python -m pip install --upgrade numpy" }
    }
}

# ----------------------------------------------------------------------------
# ffmpeg + ffprobe (required)
# ----------------------------------------------------------------------------
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
$ffprobe = Get-Command ffprobe -ErrorAction SilentlyContinue
if ($ffmpeg -and $ffprobe) {
    Ok "ffmpeg + ffprobe found"
} else {
    Missing "ffmpeg (=$([bool]$ffmpeg)) / ffprobe (=$([bool]$ffprobe))"
    if (-not $Check) {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Info "Installing ffmpeg via winget (Gyan.FFmpeg)..."
            winget install -e --id Gyan.FFmpeg --silent `
                --accept-package-agreements --accept-source-agreements | Out-Null
            Info "Installed. Open a NEW terminal so ffmpeg is on PATH."
        } else {
            Info "winget not available. Download ffmpeg from https://www.gyan.dev/ffmpeg/builds/ and add its bin\ to PATH."
        }
    }
}

# ----------------------------------------------------------------------------
# yt-dlp (OPTIONAL - only for download_library_playlists.py)
# ----------------------------------------------------------------------------
if (Get-Command yt-dlp -ErrorAction SilentlyContinue) {
    Ok "yt-dlp found (optional)"
} else {
    $modOk = & $py -c "import yt_dlp; print('ok')" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Ok "yt-dlp present as a Python module (optional)"
    } else {
        Info "yt-dlp OPTIONAL - only needed for download_library_playlists.py (pulling from YouTube)."
        if (-not $Check) {
            Info "Installing yt-dlp..."
            & $py -m pip install --upgrade yt-dlp 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { Ok "yt-dlp installed (optional)" } else { Info "yt-dlp install failed - optional, skip if unused." }
        }
    }
}

Say ""
Say "Done."

if ($Check) {
    Say "This was a check - re-run without -Check to install the missing pieces."
}
