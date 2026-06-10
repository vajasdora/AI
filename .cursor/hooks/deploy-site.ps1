# After an agent turn, push pending site changes to GitHub Pages.
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
$deployScript = Join-Path $repoRoot "scripts\deploy-site.ps1"

if (-not (Test-Path $deployScript)) {
  Write-Error "Deploy script not found: $deployScript"
  exit 0
}

try {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $deployScript `
    -CommitMessage "Update site for vajasklicsu.com"
  exit 0
}
catch {
  Write-Error $_
  exit 0
}
