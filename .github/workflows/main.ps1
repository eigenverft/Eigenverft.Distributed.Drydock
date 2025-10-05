param (
    [string]$NUGET_GITHUB_PUSH,
    [string]$NUGET_PAT,
    [string]$NUGET_TEST_PAT,
    [string]$POWERSHELL_GALLERY
)

# If any of the parameters are empty, try loading them from a secrets file.
if ([string]::IsNullOrEmpty($NUGET_GITHUB_PUSH) -or [string]::IsNullOrEmpty($NUGET_PAT) -or [string]::IsNullOrEmpty($NUGET_TEST_PAT) -or [string]::IsNullOrEmpty($POWERSHELL_GALLERY)) {
    if (Test-Path "$PSScriptRoot\main_secrets.ps1") {
        . "$PSScriptRoot\main_secrets.ps1"
        Write-Host "Secrets loaded from file."
    }
    if ([string]::IsNullOrEmpty($NUGET_GITHUB_PUSH))
    {
        exit 1
    }
}
