param(
  [string]$RepoRoot = ""
)

Add-Type -AssemblyName System.Drawing

function Get-RepoRootPath {
  if ($RepoRoot) { return $RepoRoot }
  return (Get-Item "C:\Users\D*\Desktop\Vajas-Klicsu*\00MDMA1\MDMA 1*\2026tavasz\AI").FullName
}

function Save-OptimizedImage {
  param(
    [string]$SourcePath,
    [string]$DestPath,
    [int]$MaxWidth,
    [long]$Quality
  )

  $img = [System.Drawing.Image]::FromFile($SourcePath)
  try {
    $ratio = [Math]::Min(1.0, $MaxWidth / [double]$img.Width)
    $newW = [Math]::Max(1, [int][Math]::Round($img.Width * $ratio))
    $newH = [Math]::Max(1, [int][Math]::Round($img.Height * $ratio))

    $bmp = New-Object System.Drawing.Bitmap $newW, $newH
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::FromArgb(255, 248, 248, 243))
    $graphics.DrawImage($img, 0, 0, $newW, $newH)
    $graphics.Dispose()

    $encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
      Where-Object { $_.MimeType -eq "image/jpeg" } |
      Select-Object -First 1
    $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters 1
    $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter (
      [System.Drawing.Imaging.Encoder]::Quality,
      $Quality
    )

    $destDir = Split-Path $DestPath -Parent
    if (-not (Test-Path $destDir)) {
      New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }

    $bmp.Save($DestPath, $encoder, $encoderParams)
    $bmp.Dispose()
  }
  finally {
    $img.Dispose()
  }
}

$root = Get-RepoRootPath
$outRoot = Join-Path $root "assets\hogytovabb-ne-repedjen"
$displayDir = Join-Path $outRoot "display"
$fullDir = Join-Path $outRoot "full"

foreach ($dir in @($displayDir, $fullDir)) {
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

$sources = @(
  @{ Match = "vajas-htnr-00.jpg"; Base = "vajas-htnr-00" },
  @{ Match = "vajas-htnr-01.jpg"; Base = "vajas-htnr-01" },
  @{ Match = "vajas-htnr-02.jpg"; Base = "vajas-htnr-02" },
  @{ Match = "vajas-htnr-03.jpg"; Base = "vajas-htnr-03" },
  @{ Match = "vajas-htnr-04.jpg"; Base = "vajas-htnr-04" }
)

foreach ($entry in $sources) {
  $sourceFile = Get-ChildItem $outRoot -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq $entry.Match } |
    Select-Object -First 1

  if (-not $sourceFile) {
    $sourceFile = Get-ChildItem (Join-Path $root "assets") -Recurse -File |
      Where-Object { $_.Name -match "VAJAS_HTNR_0$($entry.Base.Substring($entry.Base.Length - 1))" } |
      Select-Object -First 1
  }

  if (-not $sourceFile) {
    Write-Warning "Missing source for $($entry.Base)"
    continue
  }

  $displayPath = Join-Path $displayDir "$($entry.Base).jpg"
  $fullPath = Join-Path $fullDir "$($entry.Base).jpg"

  Save-OptimizedImage -SourcePath $sourceFile.FullName -DestPath $displayPath -MaxWidth 1200 -Quality 84
  Save-OptimizedImage -SourcePath $sourceFile.FullName -DestPath $fullPath -MaxWidth 2200 -Quality 90

  $displaySize = [math]::Round((Get-Item $displayPath).Length / 1KB, 0)
  $fullSize = [math]::Round((Get-Item $fullPath).Length / 1KB, 0)
  Write-Host "Optimized $($entry.Base): display ${displaySize}KB, full ${fullSize}KB"
}

Write-Host "Done. Output: $outRoot"
