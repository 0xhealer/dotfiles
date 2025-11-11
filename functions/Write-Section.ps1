function Write-Section {
  param([Parameter(Mandatory = $true)][string]$Title)
  Write-Host ""
  Write-Host ("[ -- $Title -- ]") -ForegroundColor Cyan
}