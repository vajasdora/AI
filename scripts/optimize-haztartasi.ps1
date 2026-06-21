param(
  [string]$RepoRoot = ""
)

Add-Type -AssemblyName System.Drawing

function Get-RepoRootPath {
  param([string]$Start)
  if ($RepoRoot) { return $RepoRoot }
  return (Get-Item "C:\Users\D*\Desktop\Vajas-Klicsu*\00MDMA1\MDMA 1*\2026tavasz\AI").FullName
}

function Find-Ffmpeg {
  $winget = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($winget) { return $winget.FullName }

  $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  throw "ffmpeg not found"
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

function Optimize-Video {
  param(
    [string]$Ffmpeg,
    [string]$SourcePath,
    [string]$DestPath
  )

  $destDir = Split-Path $DestPath -Parent
  if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
  }

  & $Ffmpeg `
    -hide_banner `
    -loglevel error `
    -y `
    -ss 5 `
    -i $SourcePath `
    -c:v libx264 `
    -preset slow `
    -crf 26 `
    -pix_fmt yuv420p `
    -vf "scale='min(1280,iw)':-2" `
    -c:a aac `
    -b:a 128k `
    -movflags +faststart `
    $DestPath

  if ($LASTEXITCODE -ne 0) {
    throw "ffmpeg failed for $SourcePath"
  }
}

$root = Get-RepoRootPath
$sourceDir = Get-ChildItem (Join-Path $root "assets") -Recurse -Directory |
  Where-Object { $_.Name -eq "VAJAS_HT000" } |
  Select-Object -First 1

if (-not $sourceDir) {
  throw "VAJAS_HT000 source folder not found"
}

$outRoot = Join-Path $root "assets\haztartasi-transzcendencia"
$displayDir = Join-Path $outRoot "display"
$fullDir = Join-Path $outRoot "full"
$videoDir = Join-Path $outRoot "video"

foreach ($dir in @($displayDir, $fullDir, $videoDir)) {
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

$imageMap = @(
  @{ Source = "fejlec_000.png"; Base = "fejlec-000" },
  @{ Source = "DT_01.png"; Base = "dt-01" },
  @{ Source = "DT_02.png"; Base = "dt-02" },
  @{ Source = "DT_03.jpg"; Base = "dt-03" },
  @{ Source = "HT_01.png"; Base = "ht-01" },
  @{ Source = "HT_02.png"; Base = "ht-02" },
  @{ Source = "HT_03.png"; Base = "ht-03" }
)

foreach ($entry in $imageMap) {
  $sourceFile = Get-ChildItem $sourceDir.FullName -File |
    Where-Object { $_.Name -eq $entry.Source } |
    Select-Object -First 1

  if (-not $sourceFile) {
    Write-Warning "Missing source image: $($entry.Source)"
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

$ffmpeg = Find-Ffmpeg
$videoMap = @(
  @{ Source = "HT_01_VIDEO.mp4"; Base = "ht-01" },
  @{ Source = "HT_03_VIDEO.mp4"; Base = "ht-03" }
)

foreach ($entry in $videoMap) {
  $sourceFile = Get-ChildItem $sourceDir.FullName -File |
    Where-Object { $_.Name -eq $entry.Source } |
    Select-Object -First 1

  if (-not $sourceFile) {
    Write-Warning "Missing source video: $($entry.Source)"
    continue
  }

  $destPath = Join-Path $videoDir "$($entry.Base).mp4"
  Write-Host "Encoding $($entry.Base)..."
  Optimize-Video -Ffmpeg $ffmpeg -SourcePath $sourceFile.FullName -DestPath $destPath
  $sizeMB = [math]::Round((Get-Item $destPath).Length / 1MB, 2)
  Write-Host "Encoded $($entry.Base): ${sizeMB}MB"
}

Write-Host "Done. Output: $outRoot"
