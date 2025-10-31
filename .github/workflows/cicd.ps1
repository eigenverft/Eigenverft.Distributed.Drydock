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

$RemoteResourcesAvailable = Test-RemoteResourcesAvailable -Quiet

# Ensure connectivity to PowerShell Gallery before attempting module installation, if not assuming being offline, installation is present check existance with Test-ModuleAvailable
if ($RemoteResourcesAvailable)
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

# In the case the secrets are not passed as parameters, try to get them from the secrets file, local development or CI/CD environment
$NUGET_GITHUB_PUSH = Get-ConfigValue -Check $NUGET_GITHUB_PUSH -FilePath (Join-Path $PSScriptRoot 'cicd.secrets.json') -Property 'NUGET_GITHUB_PUSH'
$NUGET_PAT = Get-ConfigValue -Check $NUGET_PAT -FilePath (Join-Path $PSScriptRoot 'cicd.secrets.json') -Property 'NUGET_PAT'
$NUGET_TEST_PAT = Get-ConfigValue -Check $NUGET_TEST_PAT -FilePath (Join-Path $PSScriptRoot 'cicd.secrets.json') -Property 'NUGET_TEST_PAT'
$PsGalleryApiKey = Get-ConfigValue -Check $PsGalleryApiKey -FilePath (Join-Path $PSScriptRoot 'cicd.secrets.json') -Property 'PsGalleryApiKey'
Test-VariableValue -Variable { $NUGET_GITHUB_PUSH } -ExitIfNullOrEmpty -HideValue
Test-VariableValue -Variable { $NUGET_PAT } -ExitIfNullOrEmpty -HideValue
Test-VariableValue -Variable { $NUGET_TEST_PAT } -ExitIfNullOrEmpty -HideValue
Test-VariableValue -Variable { $PsGalleryApiKey } -ExitIfNullOrEmpty -HideValue

# Verify required commands are available
if ($GitCliInfo = Test-CommandAvailable -Command "git") { Write-Host "Test-CommandAvailable: $($GitCliInfo.Name) $($GitCliInfo.Version) found at $($GitCliInfo.Source)" } else { Write-Error "git not found"; exit 1 }
if ($DotNetCliInfo = Test-CommandAvailable -Command "dotnet") { Write-Host "Test-CommandAvailable: $($DotNetCliInfo.Name) $($DotNetCliInfo.Version) found at $($DotNetCliInfo.Source)" } else { Write-Error "dotnet not found"; exit 1 }

# Preload environment information
$RunEnvironment = Get-RunEnvironment
$GitRepositoryRoot = Get-GitTopLevelDirectory
$GitCurrentBranch = Get-GitCurrentBranch
$GitBranchRootDirectory = Get-GitCurrentBranchRoot
$GitRepositoryName = Get-GitRepositoryName
$GitRemoteUrl = Get-GitRemoteUrl

# Failfast / guard if any of the required preloaded environment information is not available
Test-VariableValue -Variable { $RunEnvironment } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $GitRepositoryRoot } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $GitCurrentBranch } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $GitBranchRootDirectory } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $GitRepositoryName } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $GitRemoteUrl } -ExitIfNullOrEmpty

# Generate deployment info based on the current branch name
$BranchDeploymentConfig = Convert-BranchToDeploymentInfo -BranchName "$GitCurrentBranch"

# Generates a version based on the current date time to verify the version functions work as expected
$GeneratedVersion = Convert-DateTimeTo64SecVersionComponents -VersionBuild 0 -VersionMajor 1
$GeneratedVersionAsDateTime = Convert-64SecVersionComponentsToDateTime -VersionBuild $GeneratedVersion.VersionBuild -VersionMajor $GeneratedVersion.VersionMajor -VersionMinor $GeneratedVersion.VersionMinor -VersionRevision $GeneratedVersion.VersionRevision
Test-VariableValue -Variable { $GeneratedVersion } -ExitIfNullOrEmpty
Test-VariableValue -Variable { $GeneratedVersionAsDateTime } -ExitIfNullOrEmpty

# Generate a local PowerShell Gallery repository to publish to.
$LocalPowerShellGalleryName = "LocalPowerShellGallery"
$LocalPowerShellGalleryName = Register-LocalPSGalleryRepository -RepositoryName "$LocalPowerShellGalleryName"

# Generate a local NuGet package source to publish to.
$LocalNuGetSourceName = "LocalNuGet"
$LocalNuGetSourceName = Register-LocalNuGetDotNetPackageSource -SourceName "$LocalNuGetSourceName"

# All config files paths
$ConfigRootPath = Get-Path -Paths @("$GitRepositoryRoot",".github","workflows",".config")

$DotNetToolsManifestPath = Get-Path -Paths @("$ConfigRootPath","dotnet-tools","dotnet-tools.json")
$NuGetAllowedLicensesPath = Get-Path -Paths @("$ConfigRootPath","nuget-license","allowed-licenses.json")
$NuGetLicenseMappingsPath = Get-Path -Paths @("$ConfigRootPath","nuget-license","licenses-mapping.json")
$DocFxTemplatePath = Get-Path -Paths @("$ConfigRootPath","docfx","build","docfx_local.template.json")
$IndexTemplatePath = Get-Path -Paths @("$ConfigRootPath","docfx","build","index.template.md")
$DocFxConfigFileInfos = Find-FilesByPattern -Path (Get-Path -Paths @("$ConfigRootPath","docfx")) -Pattern "docfx_local.json"

# Enable the .NET tools specified in the manifest file
Enable-TempDotnetTools -ManifestFile "$DotNetToolsManifestPath" -NoReturn

# All required output folders
$OutputRootPath = Get-Path -Paths @("$GitRepositoryRoot","output")
$BuildRootPath = Get-Path -Paths @("$OutputRootPath","build")
$BuildBinPath = Get-Path -Paths @("$BuildRootPath","bin")
$BuildObjPath = Get-Path -Paths @("$BuildRootPath","obj")
$PackRootPath = Get-Path -Paths @("$OutputRootPath","pack")
$PublishRootPath = Get-Path -Paths @("$OutputRootPath","publish")
$ReportsRootPath =  Get-Path -Paths @("$OutputRootPath","reports")
$DocsRootPath = Get-Path -Paths @("$OutputRootPath","docs")
$BranchVersionRelativePath = Get-Path -Paths @($BranchDeploymentConfig.Branch.PathSegmentsSanitized,$GeneratedVersion.VersionFull)
$ChannelVersionRelativePath = Get-Path -Paths @($BranchDeploymentConfig.Channel.Value,$GeneratedVersion.VersionFull)
$ChannelLatestRelativePath = Get-Path -Paths @($BranchDeploymentConfig.Channel.Value,"latest")

New-Directory -Paths @($OutputRootPath)
if (-not $($RunEnvironment.IsCI)) { Remove-FilesByPattern -Path "$OutputRootPath" -Pattern "*"  }

# Create required output directories
New-Directory -Paths @($BuildRootPath)
$BuildBinDirectory = New-Directory -Paths @($BuildBinPath,$BranchVersionRelativePath)
$BuildObjDirectory = New-Directory -Paths @($BuildObjPath,$BranchVersionRelativePath)
$PackDirectory = New-Directory -Paths @($PackRootPath,$ChannelVersionRelativePath)
$PublishDirectory = New-Directory -Paths @($PublishRootPath,$ChannelVersionRelativePath)
$ReportsDirectory = New-Directory -Paths @($ReportsRootPath,$ChannelVersionRelativePath)
$DocsDirectory = New-Directory -Paths @($DocsRootPath,$ChannelVersionRelativePath)


# Initialize the array to accumulate projects.
$SolutionFileInfos = Find-FilesByPattern -Path "$GitRepositoryRoot\source" -Pattern "*.sln"
$SolutionProjectPaths = @()
foreach ($solutionFile in $SolutionFileInfos) {
    # all ready sorted by the bbdist
    $CurrentProjectPaths = Invoke-Exec -Executable "bbdist" -Arguments @( "sln", "--file", "$($solutionFile.FullName)")
    $SolutionProjectPaths += $CurrentProjectPaths
}

$ProjectFileInfos = $SolutionProjectPaths | ForEach-Object { Get-Item $_ }

foreach ($ProjectFileInfo in $ProjectFileInfos) {
    Write-Host "$($ProjectFileInfo)"
}

# --verbosity quiet,minimal,normal (default),detailed,diagnostic
$DotnetCommonParameters = @(
    "--verbosity",
    "minimal",
    "-p:""Deterministic=true""",
    "-p:""ContinuousIntegrationBuild=true""",
    "-p:""VersionBuild=$($GeneratedVersion.VersionBuild)""",
    "-p:""VersionMajor=$($GeneratedVersion.VersionMajor)""",
    "-p:""VersionMinor=$($GeneratedVersion.VersionMinor)""",
    "-p:""VersionRevision=$($GeneratedVersion.VersionRevision)""",
    "-p:""VersionSuffix=$($BranchDeploymentConfig.Affix.Suffix)""",
    "-p:""BaseOutputPath=$($BuildBinDirectory)/""",
    "-p:""IntermediateOutputPath=$($BuildObjDirectory)/""",
    "-p:""UseSharedCompilation=false""",
    "-m:1"
)

# Build, Test, Pack, Publish, and Generate Reports for each project in the solution.
foreach ($ProjectFileInfo in $ProjectFileInfos) {

    $IsTestProject = Invoke-Exec -Executable "bbdist" -Arguments @("csproj", "--file", "$($ProjectFileInfo.FullName)", "--property", "IsTestProject") -ReturnType Objects
    $IsPackable = Invoke-Exec -Executable "bbdist" -Arguments @("csproj", "--file", "$($ProjectFileInfo.FullName)", "--property", "IsPackable") -ReturnType Objects
    $IsPublishable = Invoke-Exec -Executable "bbdist" -Arguments @("csproj", "--file", "$($ProjectFileInfo.FullName)", "--property", "IsPublishable") -ReturnType Objects

    Invoke-Exec -Executable "dotnet" -Arguments @("clean", """$($ProjectFileInfo.FullName)""", "-c", "Release","-p:""Stage=clean""")  -CommonArguments $DotnetCommonParameters -CaptureOutput $false
    Invoke-Exec -Executable "dotnet" -Arguments @("restore", """$($ProjectFileInfo.FullName)""", "-p:""Stage=restore""")  -CommonArguments $DotnetCommonParameters -CaptureOutput $false
    Invoke-Exec -Executable "dotnet" -Arguments @("build", """$($ProjectFileInfo.FullName)""", "-c", "Release","-p:""Stage=build""")  -CommonArguments $DotnetCommonParameters -CaptureOutput $false

    if (($IsPackable -eq $true) -or ($IsPublishable -eq $true))
    {
        $VulnerabilitiesJson = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($ProjectFileInfo.FullName)", "package", "--vulnerable", "--format", "json")
        New-DotnetVulnerabilitiesReport -jsonInput $VulnerabilitiesJson -OutputFile "$ReportsDirectory\$($ProjectFileInfo.BaseName).Report.Vulnerabilities.md" -OutputFormat markdown -ExitOnVulnerability $false
    
        $DeprecatedPackagesJson = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($ProjectFileInfo.FullName)", "package", "--deprecated", "--include-transitive", "--format", "json")
        New-DotnetDeprecatedReport -jsonInput $DeprecatedPackagesJson -OutputFile "$ReportsDirectory\$($ProjectFileInfo.BaseName).Report.Deprecated.md" -OutputFormat markdown -IgnoreTransitivePackages $true -ExitOnDeprecated $false
    
        $OutdatedPackagesJson = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($ProjectFileInfo.FullName)", "package", "--outdated", "--include-transitive", "--format", "json")
        New-DotnetOutdatedReport -jsonInput $OutdatedPackagesJson -OutputFile "$ReportsDirectory\$($ProjectFileInfo.BaseName).Report.Outdated.md" -OutputFormat markdown -IgnoreTransitivePackages $false
    
        $BillOfMaterialsJson = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($ProjectFileInfo.FullName)", "package", "--include-transitive", "--format", "json")
        New-DotnetBillOfMaterialsReport -jsonInput $BillOfMaterialsJson -OutputFile "$ReportsDirectory\$($ProjectFileInfo.BaseName).Report.BillOfMaterials.md" -OutputFormat markdown -IgnoreTransitivePackages $true
    
        Invoke-Exec -Executable "nuget-license" -Arguments @("--input", "$($ProjectFileInfo.FullName)", "--allowed-license-types", "$NuGetAllowedLicensesPath", "--output", "JsonPretty", "--licenseurl-to-license-mappings" ,"$NuGetLicenseMappingsPath", "--file-output", "$ReportsDirectory/ReportProjectLicences.json" )
        New-ThirdPartyNotice -LicenseJsonPath "$ReportsDirectory/ReportProjectLicences.json" -OutputPath "$ReportsDirectory\$($ProjectFileInfo.BaseName).Report.ThirdPartyNotices.txt"
    }

    if ($IsTestProject -eq $true)
    {
        Invoke-Exec -Executable "dotnet" -Arguments @("test", "$($ProjectFileInfo.FullName)", "-c", "Release","-p:""Stage=test""")  -CommonArguments $DotnetCommonParameters -CaptureOutput $false
    }

    if ($IsPackable -eq $true)
    {
        Invoke-Exec -Executable "dotnet" -Arguments @("pack", "$($ProjectFileInfo.FullName)", "-c", "Release","-p:""Stage=pack""","-p:""PackageOutputPath=$($PackDirectory)""")  -CommonArguments $DotnetCommonParameters -CaptureOutput $false
    }

    if ($IsPublishable -eq $true)
    {
        Invoke-Exec -Executable "dotnet" -Arguments @("publish", "$($ProjectFileInfo.FullName)", "-c", "Release","-p:""Stage=publish""","-p:""PublishDir=$($PublishDirectory)""")  -CommonArguments $DotnetCommonParameters -CaptureOutput $false
    }
    
    if ($IsPackable -eq $true)
    {
        $DocFxReplacementsByToken = @{
            "sourceCodeDirectory" = "$($ProjectFileInfo.DirectoryName.Replace('\','/'))"
            "outputDirectory"     = (Get-Path -Paths @("$DocsDirectory","docfx")).Replace('\','/')
            "appName"     = "$($ProjectFileInfo.BaseName)"
        }
        Convert-TemplateFilePlaceholders -TemplateFile $DocFxTemplatePath -Replacements $DocFxReplacementsByToken
        Convert-TemplateFilePlaceholders -TemplateFile $IndexTemplatePath -Replacements $DocFxReplacementsByToken
        Invoke-Exec -Executable "docfx" -Arguments @("$($DocFxConfigFileInfos.FullName)")  -CaptureOutput $false -CaptureOutputDump $true
    }
}

# Resolving deployment information for the current branch
$DeploymentChannel = $BranchDeploymentConfig.Channel.Value
$GitHubPackagesUser = "eigenverft"
$GitHubSourceName = "github"
$GitHubSourceUri = "https://nuget.pkg.github.com/$GitHubPackagesUser/index.json"
$NuGetTestSourceUri = "https://apiint.nugettest.org/v3/index.json"
$NuGetOrgSourceUri = "https://api.nuget.org/v3/index.json"

$BinaryDropRootPath = "C:\temp\$($ProjectFileInfo.BaseName)-drops"

$PushToLocalSource = $false
$PushToGitHubSource = $false
$PushToNuGetTest = $false
$PushToNuGetOrg = $false
$CopyToChannelDrops = $false
$CopyToDistributionDrop = $false

# Determine where to publish based on the deployment channel
if ($DeploymentChannel -in @("development"))
{
    $PushToLocalSource = $true
    $PushToGitHubSource = $false
    $PushToNuGetTest = $false
    $PushToNuGetOrg = $false

    $CopyToChannelDrops = $true
    $CopyToDistributionDrop = $false
}

if ($DeploymentChannel -in @('quality'))
{
    $PushToLocalSource = $true
    $PushToGitHubSource = $true
    $PushToNuGetTest = $true
    $PushToNuGetOrg = $false

    $CopyToChannelDrops = $true
    $CopyToDistributionDrop = $false
}

if ($DeploymentChannel -in @('staging'))
{
    $PushToLocalSource = $true
    $PushToGitHubSource = $true
    $PushToNuGetTest = $true
    $PushToNuGetOrg = $false

    $CopyToChannelDrops = $true
    $CopyToDistributionDrop = $false
}

if ($DeploymentChannel -in @('production'))
{
    $PushToLocalSource = $true
    $PushToGitHubSource = $true
    $PushToNuGetTest = $false
    $PushToNuGetOrg = $true

    $CopyToChannelDrops = $true
    $CopyToDistributionDrop = $true
}

# Deploy *.nupkg artifacts to the appropriate destinations
if ($PushToLocalSource -eq $true)
{
    $NuGetPackageFileInfos = Find-FilesByPattern -Path "$PackRootPath" -Pattern "*.nupkg"
    Invoke-Exec -Executable "dotnet" -Arguments @("nuget", "push", "$($NuGetPackageFileInfos.FullName)", "--source","$LocalNuGetSourceName") -CaptureOutput $false
}

if ($PushToGitHubSource -eq $true)
{
    $NuGetPackageFileInfos = Find-FilesByPattern -Path "$PackRootPath" -Pattern "*.nupkg"
    Invoke-Exec -Executable "dotnet" -Arguments @("nuget","add", "source", "--username", "$GitHubPackagesUser","--password","$NUGET_GITHUB_PUSH","--store-password-in-clear-text","--name","$GitHubSourceName","$GitHubSourceUri") -CaptureOutput $false -CaptureOutputDump $false -HideValues @($NUGET_GITHUB_PUSH)
    Invoke-Exec -Executable "dotnet" -Arguments @("nuget","push", "$($NuGetPackageFileInfos.FullName)", "--api-key", "$NUGET_GITHUB_PUSH","--source","$GitHubSourceName") -CaptureOutput $false -CaptureOutputDump $false -HideValues @($NUGET_GITHUB_PUSH)
    Unregister-LocalNuGetDotNetPackageSource -SourceName "$GitHubSourceName"
}

if ($PushToNuGetTest -eq $true)
{
    $NuGetPackageFileInfos = Find-FilesByPattern -Path "$PackRootPath" -Pattern "*.nupkg"
    Invoke-Exec -Executable "dotnet" -Arguments @("nuget","push", "$($NuGetPackageFileInfos.FullName)", "--api-key", "$NUGET_TEST_PAT","--source","$NuGetTestSourceUri") -CaptureOutput $false -CaptureOutputDump $false -HideValues @($NUGET_TEST_PAT)
}

if ($PushToNuGetOrg -eq $true)
{
    $NuGetPackageFileInfos = Find-FilesByPattern -Path "$PackRootPath" -Pattern "*.nupkg"
    Invoke-Exec -Executable "dotnet" -Arguments @("nuget","push", "$($NuGetPackageFileInfos.FullName)", "--api-key", "$NUGET_PAT","--source","$NuGetOrgSourceUri") -CaptureOutput $false -CaptureOutputDump $false -HideValues @($NUGET_PAT)
}

if ($CopyToChannelDrops -eq $true)
{   
    Copy-FilesRecursively -SourceDirectory "$PublishDirectory" -DestinationDirectory (Get-Path -Paths @($BinaryDropRootPath,"$ChannelVersionRelativePath")) -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $false
    Copy-FilesRecursively -SourceDirectory "$PublishDirectory" -DestinationDirectory (Get-Path -Paths @($BinaryDropRootPath,"$ChannelLatestRelativePath")) -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $true
}

if ($CopyToDistributionDrop -eq $true)
{   
    Copy-FilesRecursively -SourceDirectory "$PublishDirectory" -DestinationDirectory (Get-Path -Paths @($BinaryDropRootPath,"distributed")) -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $true
}