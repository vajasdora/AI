# Publishes local site changes to GitHub so vajasklicsu.com updates.
param(
  [string]$CommitMessage = "Update site for vajasklicsu.com"
)

function Get-RepoRoot {
  param([string]$Start)
  $dir = $Start
  while ($dir) {
    if (Test-Path (Join-Path $dir ".git")) {
      return $dir
    }
    $parent = Split-Path $dir -Parent
    if (-not $parent -or $parent -eq $dir) {
      break
    }
    $dir = $parent
  }
  throw "Git repository not found."
}

function Find-Git {
  $desktopApps = Join-Path $env:LOCALAPPDATA "GitHubDesktop"
  if (Test-Path $desktopApps) {
    $candidate = Get-ChildItem $desktopApps -Directory -Filter "app-*" -ErrorAction SilentlyContinue |
      Sort-Object Name -Descending |
      ForEach-Object { Join-Path $_.FullName "resources\app\git\cmd\git.exe" } |
      Where-Object { Test-Path $_ } |
      Select-Object -First 1
    if ($candidate) {
      return $candidate
    }
  }

  foreach ($path in @(
      "${env:ProgramFiles}\Git\bin\git.exe",
      "${env:ProgramFiles(x86)}\Git\bin\git.exe"
    )) {
    if (Test-Path $path) {
      return $path
    }
  }

  $cmd = Get-Command git -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }

  throw "Git not found. Install GitHub Desktop or Git for Windows."
}

$RepoRoot = Get-RepoRoot -Start $PSScriptRoot
$git = Find-Git

Push-Location $RepoRoot
try {
  $dirty = & $git status --porcelain
  if (-not $dirty) {
    Write-Host "No changes to deploy."
    exit 0
  }

  $sitePaths = @(
    "elso-oldal.html",
    "index.html",
    "styles.css",
    "CNAME",
    "assets",
    ".github",
    "scripts",
    ".cursor"
  )

  foreach ($path in $sitePaths) {
    if (-not (Test-Path $path)) {
      continue
    }

    & $git add -u -- $path
  }

  $newFiles = & $git ls-files --others --exclude-standard -- $sitePaths
  if ($newFiles) {
    & $git add -- $newFiles
  }

  $staged = & $git diff --cached --name-only
  if (-not $staged) {
    Write-Host "No site files staged for deploy."
    exit 0
  }

  & $git commit -m $CommitMessage
  if ($LASTEXITCODE -ne 0) {
    throw "git commit failed with exit code $LASTEXITCODE"
  }

  & $git push origin main
  if ($LASTEXITCODE -ne 0) {
    throw "git push failed with exit code $LASTEXITCODE"
  }

  Write-Host "Deployed to https://vajasklicsu.com"
  exit 0
}
finally {
  Pop-Location
}
