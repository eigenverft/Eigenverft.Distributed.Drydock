param (
    [string]$NUGET_GITHUB_PUSH,
    [string]$NUGET_PAT,
    [string]$NUGET_TEST_PAT,
    [string]$PsGalleryApiKey
)

# Fail-fast defaults for reliable CI/local runs:
# - StrictMode 3: treat uninitialized variables, unknown members, etc. as errors.
# - ErrorActionPreference='Stop': convert non-terminating errors into terminating ones (catchable).
# Error-handling guidance:
# - In catch{ }, prefer Write-Error or 'throw' to preserve fail-fast behavior.
#   * Write-Error (with ErrorActionPreference='Stop') is terminating and bubbles to the caller 'throw' is always terminating and keeps stack context.
# - Using Write-Host in catch{ } only logs and SWALLOWS the exception; execution continues, use a sentinel value (e.g., $null) explicitly.
# - Note: native tool exit codes on PS5 aren’t governed by ErrorActionPreference; use the Invoke-Exec wrapper to enforce policy.
Set-StrictMode -Version 3
$ErrorActionPreference     = 'Stop'   # errors become terminating
$Global:ConsoleLogMinLevel = 'INF'    # gate: TRC/DBG/INF/WRN/ERR/FTL

# Keep this script compatible with PowerShell 5.1 and PowerShell 7+
# Lean, pipeline-friendly style—simple, readable, and easy to modify, failfast on errors.
Write-Host "Powershell script $(Split-Path -Leaf $PSCommandPath) has started."

# Provides lightweight reachability guards for external services.
# Detection only—no installs, imports, network changes, or pushes. (e.g Test-PSGalleryConnectivity)
# Designed to short-circuit local and CI/CD workflows when dependencies are offline (e.g., skip a push if the Git host is unreachable).
. "$PSScriptRoot\cicd.bootstrap.ps1"

$remoteResourcesOk = Test-RemoteResourcesAvailable -Quiet

# Ensure connectivity to PowerShell Gallery before attempting module installation, if not assuming being offline, installation is present check existance with Test-ModuleAvailable
if ($remoteResourcesOk)
{
    # Install the required modules to run this script, Eigenverft.Manifested.Drydock needs to be Powershell 5.1 and Powershell 7+ compatible
    Install-Module -Name 'Eigenverft.Manifested.Drydock' -Repository "PSGallery" -Scope CurrentUser -Force -AllowClobber -AllowPrerelease -ErrorAction Stop
}

Test-ModuleAvailable -Name 'Eigenverft.Manifested.Drydock' -IncludePrerelease -ExitIfNotFound -Quiet

# Required for updating PowerShellGet and PackageManagement providers in local PowerShell 5.x environments
Initialize-PowerShellMiniBootstrap

# Test TLS, NuGet, PackageManagement, PowerShellGet, and PSGallery publish endpoint
Test-PsGalleryPublishPrereqsOffline -ExitOnFailure

# Clean up previous versions of the module to avoid conflicts in local PowerShell environments
Uninstall-PreviousModuleVersions -ModuleName 'Eigenverft.Manifested.Drydock'

# Import optional integration script if it exists
Import-Script -File @("$PSScriptRoot\cicd.integration.ps1") -NormalizeSeparators
Write-IntegrationMsg -Message "This function is defined in the optional integration script. That should be integrated into this main module script."

# In the case the secrets are not passed as parameters, try to get them from the secrets file, local development or CI/CD environment
$NUGET_GITHUB_PUSH = Get-ConfigValue -Check $NUGET_GITHUB_PUSH -FilePath (Join-Path $PSScriptRoot 'cicd.secrets.json') -Property 'NUGET_GITHUB_PUSH'
$NUGET_PAT = Get-ConfigValue -Check $NUGET_PAT -FilePath (Join-Path $PSScriptRoot 'cicd.secrets.json') -Property 'NUGET_PAT'
$NUGET_TEST_PAT = Get-ConfigValue -Check $NUGET_TEST_PAT -FilePath (Join-Path $PSScriptRoot 'cicd.secrets.json') -Property 'NUGET_TEST_PAT'
$PsGalleryApiKey = Get-ConfigValue -Check $PsGalleryApiKey -FilePath (Join-Path $PSScriptRoot 'cicd.secrets.json') -Property 'PsGalleryApiKey'
Test-VariableValue -Variable { $PsGalleryApiKey } -ExitIfNullOrEmpty -HideValue

# Verify required commands are available
if ($cmd = Test-CommandAvailable -Command "git") { Write-Host "Test-CommandAvailable: $($cmd.Name) $($cmd.Version) found at $($cmd.Source)" } else { Write-Error "git not found"; exit 1 }
if ($cmd = Test-CommandAvailable -Command "dotnet") { Write-Host "Test-CommandAvailable: $($cmd.Name) $($cmd.Version) found at $($cmd.Source)" } else { Write-Error "dotnet not found"; exit 1 }

# Enable the .NET tools specified in the manifest file
Enable-TempDotnetTools -ManifestFile "$PSScriptRoot\.config\dotnet-tools\dotnet-tools.json" -NoReturn

# Preload environment information
$runEnvironment = Get-RunEnvironment
$gitTopLevelDirectory = Get-GitTopLevelDirectory
$gitCurrentBranch = Get-GitCurrentBranch
$gitCurrentBranchRoot = Get-GitCurrentBranchRoot
$gitRepositoryName = Get-GitRepositoryName
$gitRemoteUrl = Get-GitRemoteUrl

# Failfast / guard if any of the required preloaded environment information is not available
Test-VariableValue -Variable { $runEnvironment } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $gitTopLevelDirectory } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $gitCurrentBranch } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $gitCurrentBranchRoot } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $gitRepositoryName } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $gitRemoteUrl } -ExitIfNullOrEmpty

# Generate deployment info based on the current branch name
$deploymentInfo = Convert-BranchToDeploymentInfo -BranchName "$gitCurrentBranch"

# Generates a version based on the current date time to verify the version functions work as expected
$generatedVersion = Convert-DateTimeTo64SecVersionComponents -VersionBuild 0 -VersionMajor 1
$probeGeneratedNetVersion = Convert-64SecVersionComponentsToDateTime -VersionBuild $generatedVersion.VersionBuild -VersionMajor $generatedVersion.VersionMajor -VersionMinor $generatedVersion.VersionMinor -VersionRevision $generatedVersion.VersionRevision
Test-VariableValue -Variable { $generatedVersion } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $probeGeneratedNetVersion } -ExitIfNullOrEmpty

# Generate a local PowerShell Gallery repository to publish to.
$LocalPowershellGalleryName = "LocalPowershellGallery"
$LocalPowershellGalleryName = Register-LocalPSGalleryRepository -RepositoryName "$LocalPowershellGalleryName"

# Generate a local NuGet package source to publish to.
$LocalNugetSourceName = "LocalNuget"
$LocalNugetSourceName = Register-LocalNuGetDotNetPackageSource -SourceName "$LocalNugetSourceName"

##############################################################################
# Main CICD Logic

Install-Module -Name BlackBytesBox.Manifested.Initialize -Repository "PSGallery" -Force -AllowClobber
Install-Module -Name BlackBytesBox.Manifested.Git -Repository "PSGallery" -Force -AllowClobber

. "$PSScriptRoot\psutility\common.ps1"
. "$PSScriptRoot\psutility\dotnetlist.ps1"

#Required directorys
$artifactsFolderName = "artifacts"
$reportsFolderName = "reports"
$docsFolderName = "docs"

$artifactsFolder = New-Directory -Paths @("$gitTopLevelDirectory","$artifactsFolderName",$deploymentInfo.Branch.PathSegmentsSanitized,$generatedVersion.VersionFull)
$reportsFolder = New-Directory -Paths @("$gitTopLevelDirectory","$reportsFolderName",$deploymentInfo.Branch.PathSegmentsSanitized,$generatedVersion.VersionFull)
$docsFolder = New-Directory -Paths @("$gitTopLevelDirectory","$docsFolderName",$deploymentInfo.Branch.PathSegmentsSanitized,$generatedVersion.VersionFull)

Write-Output "artifactsFolder to $artifactsFolder"
Write-Output "reportsFolder to $reportsFolder"
Write-Output "docsFolder to $docsFolder"

if (-not $($runEnvironment.IsCI)) { Remove-FilesByPattern -Path "$artifactsFolder" -Pattern "*"  }
if (-not $($runEnvironment.IsCI)) { Remove-FilesByPattern -Path "$reportsFolder" -Pattern "*"  }
if (-not $($runEnvironment.IsCI)) { Remove-FilesByPattern -Path "$docsFolder" -Pattern "*"  }



