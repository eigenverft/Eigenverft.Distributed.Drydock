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
if ($cmd = Test-CommandAvailable -Command "git") { Write-Host "Test-CommandAvailable: $($cmd.Name) $($cmd.Version) found at $($cmd.Source)" } else { Write-Error "git not found"; exit 1 }
if ($cmd = Test-CommandAvailable -Command "dotnet") { Write-Host "Test-CommandAvailable: $($cmd.Name) $($cmd.Version) found at $($cmd.Source)" } else { Write-Error "dotnet not found"; exit 1 }

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

# All config files paths
$configFolderName = Get-Path -Paths @("$gitTopLevelDirectory",".github","workflows",".config")

$dotnetToolsFileName = Get-Path -Paths @("$configFolderName","dotnet-tools","dotnet-tools.json")
$nugetLicenseAllowedFileName = Get-Path -Paths @("$configFolderName","nuget-license","allowed-licenses.json")
$nugetLicenseMappingFileName = Get-Path -Paths @("$configFolderName","nuget-license","licenses-mapping.json")
$docFxTemplateFileName = Get-Path -Paths @("$configFolderName","docfx","build","docfx_local.template.json")
$indexTemplateFileName = Get-Path -Paths @("$configFolderName","docfx","build","index.template.md")
$docfxConfigFile = Find-FilesByPattern -Path "$configFolderName\docfx" -Pattern "docfx_local.json"

# Enable the .NET tools specified in the manifest file
Enable-TempDotnetTools -ManifestFile "$dotnetToolsFileName" -NoReturn

# All required output folders
$outputFolderName = Get-Path -Paths @("$gitTopLevelDirectory","output")
$buildFolderName = Get-Path -Paths @("$outputFolderName","build")
$buildBinFolderName = Get-Path -Paths @("$buildFolderName","bin")
$buildObjFolderName = Get-Path -Paths @("$buildFolderName","obj")

$packFolderName = Get-Path -Paths @("$outputFolderName","pack")
$publishFolderName = Get-Path -Paths @("$outputFolderName","publish")

$reportsFolderName =  Get-Path -Paths @("$outputFolderName","reports")
$docsFolderName = Get-Path -Paths @("$outputFolderName","docs")

$outputFolder = New-Directory -Paths @($outputFolderName)
if (-not $($runEnvironment.IsCI)) { Remove-FilesByPattern -Path "$outputFolderName" -Pattern "*"  }

$branchVersionFolderName = Get-Path -Paths @($deploymentInfo.Branch.PathSegmentsSanitized,$generatedVersion.VersionFull)
$channelVersionFolderName = Get-Path -Paths @($deploymentInfo.Channel.Value,$generatedVersion.VersionFull)
$channelLatestFolderName = Get-Path -Paths @($deploymentInfo.Channel.Value,"latest")

$buildFolder = New-Directory -Paths @($buildFolderName)
$buildBinFolder = New-Directory -Paths @($buildBinFolderName,$branchVersionFolderName)
$buildObjFolder = New-Directory -Paths @($buildObjFolderName,$branchVersionFolderName)

$packFolder = New-Directory -Paths @($packFolderName,$channelVersionFolderName)
$publishFolder = New-Directory -Paths @($publishFolderName,$channelVersionFolderName)
$reportsFolder = New-Directory -Paths @($reportsFolderName,$channelVersionFolderName)
$docsFolder = New-Directory -Paths @($docsFolderName,$channelVersionFolderName)

Write-ConsoleLog -Message "OutputFolder is $outputFolder"
Write-ConsoleLog -Message "BuildFolder is $buildFolder"
Write-ConsoleLog -Message "PackFolder is $packFolder"
Write-ConsoleLog -Message "PublishFolder is $publishFolder"
Write-ConsoleLog -Message "ReportsFolder is $reportsFolder"
Write-ConsoleLog -Message "DocsFolder is $docsFolder"

# Initialize the array to accumulate projects.
$solutionFiles = Find-FilesByPattern -Path "$gitTopLevelDirectory\source" -Pattern "*.sln"
$solutionProjects = @()
foreach ($solutionFile in $solutionFiles) {
    # all ready sorted by the bbdist
    $currentProjects = Invoke-Exec -Executable "bbdist" -Arguments @( "sln", "--file", "$($solutionFile.FullName)")
    $solutionProjects += $currentProjects
}

$solutionProjectsObj = $solutionProjects | ForEach-Object { Get-Item $_ }

foreach ($projectFile in $solutionProjectsObj) {
    Write-Host "$($projectFile)"
}

# --verbosity quiet,minimal,normal (default),detailed,diagnostic
$commonProjectParameters = @(
    "--verbosity",
    "minimal",
    "-p:""Deterministic=true""",
    "-p:""ContinuousIntegrationBuild=true""",
    "-p:""VersionBuild=$($generatedVersion.VersionBuild)""",
    "-p:""VersionMajor=$($generatedVersion.VersionMajor)""",
    "-p:""VersionMinor=$($generatedVersion.VersionMinor)""",
    "-p:""VersionRevision=$($generatedVersion.VersionRevision)""",
    "-p:""VersionSuffix=$($deploymentInfo.Affix.Suffix)""",
    "-p:""BaseOutputPath=$($buildBinFolder)/""",
    "-p:""IntermediateOutputPath=$($buildObjFolder)/""",
    "-p:""UseSharedCompilation=false""",
    "-m:1"
)

# Build, Test, Pack, Publish, and Generate Reports for each project in the solution.
foreach ($projectFile in $solutionProjectsObj) {

    $isTestProject = Invoke-Exec -Executable "bbdist" -Arguments @("csproj", "--file", "$($projectFile.FullName)", "--property", "IsTestProject") -ReturnType Objects
    $isPackable = Invoke-Exec -Executable "bbdist" -Arguments @("csproj", "--file", "$($projectFile.FullName)", "--property", "IsPackable") -ReturnType Objects
    $isPublishable = Invoke-Exec -Executable "bbdist" -Arguments @("csproj", "--file", "$($projectFile.FullName)", "--property", "IsPublishable") -ReturnType Objects

    Invoke-Exec -Executable "dotnet" -Arguments @("clean", """$($projectFile.FullName)""", "-c", "Release","-p:""Stage=clean""")  -CommonArguments $commonProjectParameters -CaptureOutput $false
    Invoke-Exec -Executable "dotnet" -Arguments @("restore", """$($projectFile.FullName)""", "-p:""Stage=restore""")  -CommonArguments $commonProjectParameters -CaptureOutput $false
    Invoke-Exec -Executable "dotnet" -Arguments @("build", """$($projectFile.FullName)""", "-c", "Release","-p:""Stage=build""")  -CommonArguments $commonProjectParameters -CaptureOutput $false

    if (($isPackable -eq $true) -or ($isPublishable -eq $true))
    {
        $jsonOutputVulnerable = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($projectFile.FullName)", "package", "--vulnerable", "--format", "json")
        New-DotnetVulnerabilitiesReport -jsonInput $jsonOutputVulnerable -OutputFile "$reportsFolder\$($projectFile.BaseName).Report.Vulnerabilities.md" -OutputFormat markdown -ExitOnVulnerability $false
    
        $jsonOutputDeprecated = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($projectFile.FullName)", "package", "--deprecated", "--include-transitive", "--format", "json")
        New-DotnetDeprecatedReport -jsonInput $jsonOutputDeprecated -OutputFile "$reportsFolder\$($projectFile.BaseName).Report.Deprecated.md" -OutputFormat markdown -IgnoreTransitivePackages $true -ExitOnDeprecated $false
    
        $jsonOutputOutdated = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($projectFile.FullName)", "package", "--outdated", "--include-transitive", "--format", "json")
        New-DotnetOutdatedReport -jsonInput $jsonOutputOutdated -OutputFile "$reportsFolder\$($projectFile.BaseName).Report.Outdated.md" -OutputFormat markdown -IgnoreTransitivePackages $false
    
        $jsonOutputBom = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($projectFile.FullName)", "package", "--include-transitive", "--format", "json")
        New-DotnetBillOfMaterialsReport -jsonInput $jsonOutputBom -OutputFile "$reportsFolder\$($projectFile.BaseName).Report.BillOfMaterials.md" -OutputFormat markdown -IgnoreTransitivePackages $true
    
        Invoke-Exec -Executable "nuget-license" -Arguments @("--input", "$($projectFile.FullName)", "--allowed-license-types", "$nugetLicenseAllowedFileName", "--output", "JsonPretty", "--licenseurl-to-license-mappings" ,"$nugetLicenseMappingFileName", "--file-output", "$reportsFolder/ReportProjectLicences.json" )
        New-ThirdPartyNotice -LicenseJsonPath "$reportsFolder/ReportProjectLicences.json" -OutputPath "$reportsFolder\$($projectFile.BaseName).Report.ThirdPartyNotices.txt"
    }

    if ($isTestProject -eq $true)
    {
        Invoke-Exec -Executable "dotnet" -Arguments @("test", "$($projectFile.FullName)", "-c", "Release","-p:""Stage=test""")  -CommonArguments $commonProjectParameters -CaptureOutput $false
    }

    if ($isPackable -eq $true)
    {
        Invoke-Exec -Executable "dotnet" -Arguments @("pack", "$($projectFile.FullName)", "-c", "Release","-p:""Stage=pack""","-p:""PackageOutputPath=$($packFolder)""")  -CommonArguments $commonProjectParameters -CaptureOutput $false
    }

    if ($isPublishable -eq $true)
    {
        Invoke-Exec -Executable "dotnet" -Arguments @("publish", "$($projectFile.FullName)", "-c", "Release","-p:""Stage=publish""","-p:""PublishDir=$($publishFolder)""")  -CommonArguments $commonProjectParameters -CaptureOutput $false
    }
    
    if ($isPackable -eq $true)
    {
        $replacementsMap = @{
            "sourceCodeDirectory" = "$($projectFile.DirectoryName.Replace('\','/'))"
            "outputDirectory"     = ("$docsFolder\docfx").Replace('\','/')
            "appName"     = "$($projectFile.BaseName)"
        }
        Convert-TemplateFilePlaceholders -TemplateFile $docFxTemplateFileName -Replacements $replacementsMap
        Convert-TemplateFilePlaceholders -TemplateFile $indexTemplateFileName -Replacements $replacementsMap
        Invoke-Exec -Executable "docfx" -Arguments @("$($docfxConfigFile.FullName)")  -CaptureOutput $false -CaptureOutputDump $true
    }
}

# Resolving deployment information for the current branch
$channelName = $deploymentInfo.Channel.Value

# Determine where to publish based on the deployment channel
if ($channelName -in @("development"))
{
    $publishToNugetToPublicLocal = $true
    $publishToNugetToPublicGithub = $false
    $publishToNugetToPublicTest = $false
    $publishToNugetToPublic = $false

    $buildBinFolderNamePub = $true
}

if ($channelName -in @('quality'))
{
    $publishToNugetToPublicLocal = $true
    $publishToNugetToPublicGithub = $true
    $publishToNugetToPublicTest = $true
    $publishToNugetToPublic = $false
}

if ($channelName -in @('staging'))
{
    $publishToNugetToPublicLocal = $true
    $publishToNugetToPublicGithub = $true
    $publishToNugetToPublicTest = $true
    $publishToNugetToPublic = $false
}

if ($channelName -in @('production'))
{
    $publishToNugetToPublicLocal = $true
    $publishToNugetToPublicGithub = $true
    $publishToNugetToPublicTest = $false
    $publishToNugetToPublic = $true
}

# Publish artifacts to the appropriate destinations

if ($publishToNugetToPublicLocal -eq $true)
{
    $nupkgFile = Find-FilesByPattern -Path "$packFolderName" -Pattern "*.nupkg"
    Invoke-Exec -Executable "dotnet" -Arguments @("nuget", "push", "$($nupkgFile.FullName)", "--source","$LocalNugetSourceName") -CaptureOutput $false
}

if ($buildBinFolderNamePub -eq $true)
{
    #Copy-FilesRecursively -SourceDirectory "$publishFolder" -DestinationDirectory "C:\temp\aaaaa\$channelVersionFolderName" -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $false
    #Copy-FilesRecursively -SourceDirectory "$publishFolder" -DestinationDirectory "C:\temp\aaaaa\$channelLatestFolderName" -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $true
    #Copy-FilesRecursively -SourceDirectory "$publishFolder" -DestinationDirectory "C:\temp\aaaaa\distributed" -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $true
    
}