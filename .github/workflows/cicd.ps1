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

# Required output root folder
$OutputRootPath = Get-Path -Paths @("$GitRepositoryRoot","output")
New-Directory -Paths @($OutputRootPath)
if (-not $($RunEnvironment.IsCI)) { Remove-FilesByPattern -Path "$OutputRootPath" -Pattern "*"  }

$BranchVersionRelativePath = Get-Path -Paths @($BranchDeploymentConfig.Branch.PathSegmentsSanitized,$GeneratedVersion.VersionFull)
$ChannelVersionRelativePath = Get-Path -Paths @($BranchDeploymentConfig.Channel.Value,$GeneratedVersion.VersionFull)
$ChannelLatestRelativePath = Get-Path -Paths @($BranchDeploymentConfig.Channel.Value,"latest")

# All required output folders
$BuildRootPath = Get-Path -Paths @("$OutputRootPath","build")
$BuildBinPath = Get-Path -Paths @("$BuildRootPath","bin")
$BuildObjPath = Get-Path -Paths @("$BuildRootPath","obj")
$PackRootPath = Get-Path -Paths @("$OutputRootPath","pack")
$PublishRootPath = Get-Path -Paths @("$OutputRootPath","publish")
$ReportsRootPath =  Get-Path -Paths @("$OutputRootPath","reports")
$DocsRootPath = Get-Path -Paths @("$OutputRootPath","docs")

# Initialize the array to accumulate projects.
$SolutionFileInfos = Find-FilesByPattern -Path "$GitRepositoryRoot\source" -Pattern "*.sln"
$SolutionProjectPaths = @()
foreach ($solutionFile in $SolutionFileInfos) {
    # all ready sorted by the bbdist
    $CurrentProjectPaths = Invoke-Exec -Executable "bbdist" -Arguments @( "sln", "--file", "$($solutionFile.FullName)") -ReturnType 'Strings'
    $SolutionProjectPaths += [pscustomobject]@{ Sln =$solutionFile; Prj = ($CurrentProjectPaths | ForEach-Object { Get-Item $_ }) };
}

$Vswhere = Find-FilesByPattern -Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio" -Pattern "vswhere.exe"
$MsBuildVs = Invoke-ProcessTyped -Executable "$Vswhere" -Arguments @("-latest", "-products","*", "-requires","Microsoft.Component.MSBuild", "-find", "**\Bin\MSBuild.exe") -ReturnType Objects

# Build, Test, Pack, Publish, and Generate Reports for each project in the solution.
foreach ($SolutionProjectPaths in $SolutionProjectPaths) {
    foreach ($ProjectFileInfo in $SolutionProjectPaths.Prj) {
        $SolutionFileInfo = $SolutionProjectPaths.Sln

        # Create required output directories
        New-Directory -Paths @($BuildRootPath)
        $BuildBinDirectory = New-Directory -Paths @($BuildBinPath,$SolutionFileInfo.BaseName,$ProjectFileInfo.BaseName,$BranchVersionRelativePath)
        $BuildObjDirectory = New-Directory -Paths @($BuildObjPath,$SolutionFileInfo.BaseName,$ProjectFileInfo.BaseName,$BranchVersionRelativePath)
        
        $PackDirectory = New-Directory -Paths @($PackRootPath,$SolutionFileInfo.BaseName,$ProjectFileInfo.BaseName,$ChannelVersionRelativePath)
        $PublishDirectory = New-Directory -Paths @($PublishRootPath,$SolutionFileInfo.BaseName,$ProjectFileInfo.BaseName,$ChannelVersionRelativePath)
        $ReportsDirectory = New-Directory -Paths @($ReportsRootPath,$SolutionFileInfo.BaseName,$ProjectFileInfo.BaseName,$ChannelVersionRelativePath)
        $DocsDirectory = New-Directory -Paths @($DocsRootPath,$SolutionFileInfo.BaseName,$ProjectFileInfo.BaseName,$ChannelVersionRelativePath)

        $DotnetCommonParameters = @(
            "-p:Configuration=Release",
            "-p:Platform=AnyCPU",
            "-v:minimal",
            "-p:Deterministic=true",
            "-p:ContinuousIntegrationBuild=true",
            "-p:VersionBuild=$($GeneratedVersion.VersionBuild)",
            "-p:VersionMajor=$($GeneratedVersion.VersionMajor)",
            "-p:VersionMinor=$($GeneratedVersion.VersionMinor)",
            "-p:VersionRevision=$($GeneratedVersion.VersionRevision)",
            "-p:VersionSuffix=$($BranchDeploymentConfig.Affix.Suffix)",
            "-p:BaseOutputPath=$($BuildBinDirectory)/",
            "-p:IntermediateOutputPath=$($BuildObjDirectory)/",
            "-p:UseSharedCompilation=false",
            "-m:1"
        )

        $NonSDKParameters = @(
            "-p:Configuration=Release",
            "-p:Platform=AnyCPU",
            "-v:minimal",
            "-p:VersionBuild=$($GeneratedVersion.VersionBuild)",
            "-p:VersionMajor=$($GeneratedVersion.VersionMajor)",
            "-p:VersionMinor=$($GeneratedVersion.VersionMinor)",
            "-p:VersionRevision=$($GeneratedVersion.VersionRevision)",
            "-p:VersionSuffix=$($BranchDeploymentConfig.Affix.Suffix)",
            "-p:OutputPath=$($BuildBinDirectory)/",
            "-p:BaseIntermediateOutputPath=$($BuildObjDirectory)/",
            "-p:UseSharedCompilation=false"
        )

        $TargetFrameworkVersion = Invoke-Exec -Executable "bbdist" -Arguments @("csproj", "--file", "$($ProjectFileInfo.FullName)", "--property", "TargetFrameworkVersion") -ReturnType Objects -AllowedExitCodes @(0,14)
        
        $UseVSMsbuild = $false
        $UseDotNetBuild = $false
        $IsSDKProj = $false

        # TargetFrameworkVersion not found assume sdk project style and get TargetFramework
        if ($LASTEXITCODE -eq 14) {
            
            $TargetFramework = Invoke-ProcessTyped -Executable "bbdist" -Arguments @("csproj", "--file", "$($ProjectFileInfo.FullName)", "--property", "TargetFramework") -ReturnType Objects -AllowedExitCodes @(0,14)
            if ($LASTEXITCODE -eq 14)
            {
                $TargetFrameworks = Invoke-ProcessTyped -Executable "bbdist" -Arguments @("csproj", "--file", "$($ProjectFileInfo.FullName)", "--property", "TargetFrameworks") -ReturnType Objects -AllowedExitCodes @(0)
                $TargetFrameworks = $TargetFrameworks.Split(';')
                $IsDotNetFramework = $false
                foreach ($TargetFrame in $TargetFrameworks)
                {
                    if ($TargetFrame.Trim().ToLowerInvariant() -in @('net20', 'net35', 'net40', 'net403', 'net45', 'net451', 'net452', 'net46', 'net461', 'net462', 'net47', 'net471', 'net472', 'net48', 'net481'))
                    {
                        $IsDotNetFramework = $true
                        break;
                    }
                }
                if ($IsDotNetFramework)
                {
                    $UseVSMsbuild = $true
                    $UseDotNetBuild = $false
                }
                else {
                    $UseVSMsbuild = $false
                    $UseDotNetBuild = $true
                }
                $foo = 1
            } elseif ($LASTEXITCODE -eq 0) {
                $IsSDKProj = $true
                if ($TargetFramework -in @('net20', 'net35', 'net40', 'net403', 'net45', 'net451', 'net452', 'net46', 'net461', 'net462', 'net47', 'net471', 'net472', 'net48', 'net481'))
                {
                    $UseVSMsbuild = $true
                    $UseDotNetBuild = $false
                }
                else {
                    $UseVSMsbuild = $false
                    $UseDotNetBuild = $true
                }
            }
        } elseif ($LASTEXITCODE -eq 0){
            $UseVSMsbuild = $true
            $UseDotNetBuild = $false
            $IsSDKProj = $false
        }

        # Sequence for framework and dotnet core projects , restore,clean,restore needed for proper incremental build
        Invoke-Exec -Executable "dotnet" -Arguments @("restore", "$($ProjectFileInfo.FullName)", "-p:Stage=restore")  -CommonArguments $DotnetCommonParameters -CaptureOutput $false
        Invoke-Exec -Executable "dotnet" -Arguments @("clean", "$($ProjectFileInfo.FullName)", "-p:Stage=clean")  -CommonArguments $DotnetCommonParameters -CaptureOutput $false
        Invoke-Exec -Executable "dotnet" -Arguments @("restore", "$($ProjectFileInfo.FullName)", "-p:Stage=restore")  -CommonArguments $DotnetCommonParameters -CaptureOutput $false
        
        if ($UseVSMsbuild)
        {
            if ($IsSDKProj)
            {
                Invoke-Exec -Executable "$MsBuildVs" -Arguments @("$($ProjectFileInfo.FullName)", "-p:Stage=build")  -CommonArguments $DotnetCommonParameters -CaptureOutput $false
            }
            else {
                Invoke-Exec -Executable "$MsBuildVs" -Arguments @("$($ProjectFileInfo.FullName)", "-p:Stage=build")  -CommonArguments $NonSDKParameters -CaptureOutput $false
            }
        }

        if ($UseDotNetBuild)
        {
            Invoke-Exec -Executable "dotnet" -Arguments @("build","$($ProjectFileInfo.FullName)", "-p:Stage=build")  -CommonArguments $DotnetCommonParameters -CaptureOutput $false
        }

        $IsTestProject = $false
        $IsPackable = $false
        $IsPublishable = $false
        if ($IsSDKProj)
        {
            $IsTestProject = Invoke-ProcessTyped -Executable "bbdist" -Arguments @("csproj", "--file", "$($ProjectFileInfo.FullName)", "--property", "IsTestProject") -ReturnType Objects
            $IsPackable = Invoke-ProcessTyped -Executable "bbdist" -Arguments @("csproj", "--file", "$($ProjectFileInfo.FullName)", "--property", "IsPackable") -ReturnType Objects
            $IsPublishable = Invoke-ProcessTyped -Executable "bbdist" -Arguments @("csproj", "--file", "$($ProjectFileInfo.FullName)", "--property", "IsPublishable") -ReturnType Objects
        }

        if (($IsPackable -eq $true) -or ($IsPublishable -eq $true))
        {
            #Dependency-Health-and-Inventory.Report
            $VulnerabilitiesJson = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($ProjectFileInfo.FullName)", "package", "--vulnerable", "--format", "json")
            New-DotnetVulnerabilitiesReport -jsonInput $VulnerabilitiesJson -OutputFile "$ReportsDirectory\Vulnerabilities.md" -OutputFormat markdown -ExitOnVulnerability $false
            New-DotnetVulnerabilitiesReport -jsonInput $VulnerabilitiesJson -OutputFile "$ReportsDirectory\Vulnerabilities.txt" -OutputFormat text -ExitOnVulnerability $false
        
            $DeprecatedPackagesJson = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($ProjectFileInfo.FullName)", "package", "--deprecated", "--include-transitive", "--format", "json")
            New-DotnetDeprecatedReport -jsonInput $DeprecatedPackagesJson -OutputFile "$ReportsDirectory\Deprecated.md" -OutputFormat markdown -IgnoreTransitivePackages $true -ExitOnDeprecated $false
            New-DotnetDeprecatedReport -jsonInput $DeprecatedPackagesJson -OutputFile "$ReportsDirectory\Deprecated.txt" -OutputFormat text -IgnoreTransitivePackages $true -ExitOnDeprecated $false
        
            $OutdatedPackagesJson = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($ProjectFileInfo.FullName)", "package", "--outdated", "--include-transitive", "--format", "json")
            New-DotnetOutdatedReport -jsonInput $OutdatedPackagesJson -OutputFile "$ReportsDirectory\Outdated.md" -OutputFormat markdown -IgnoreTransitivePackages $false
            New-DotnetOutdatedReport -jsonInput $OutdatedPackagesJson -OutputFile "$ReportsDirectory\Outdated.txt" -OutputFormat text -IgnoreTransitivePackages $false
        
            $BillOfMaterialsJson = Invoke-Exec -Executable "dotnet" -Arguments @("list", "$($ProjectFileInfo.FullName)", "package", "--include-transitive", "--format", "json")
            New-DotnetBillOfMaterialsReport -jsonInput $BillOfMaterialsJson -OutputFile "$ReportsDirectory\BillOfMaterials.md" -OutputFormat markdown -IgnoreTransitivePackages $true
            New-DotnetBillOfMaterialsReport -jsonInput $BillOfMaterialsJson -OutputFile "$ReportsDirectory\BillOfMaterials.txt" -OutputFormat text -IgnoreTransitivePackages $true
        
            Join-FileText -InputFiles @("$ReportsDirectory\BillOfMaterials.txt", "$ReportsDirectory\Vulnerabilities.txt","$ReportsDirectory\Deprecated.txt") -OutputFile "$ReportsDirectory\$($ProjectFileInfo.BaseName).Inventory-Health-Report.txt" -BetweenFiles 'One'

            Invoke-Exec -Executable "nuget-license" -Arguments @("--input", "$($ProjectFileInfo.FullName)", "--allowed-license-types", "$NuGetAllowedLicensesPath", "--output", "JsonPretty", "--licenseurl-to-license-mappings" ,"$NuGetLicenseMappingsPath", "--file-output", "$ReportsDirectory/$($ProjectFileInfo.BaseName).ThirdPartyLicencesNotices.json" )
            New-ThirdPartyNotice -LicenseJsonPath "$ReportsDirectory/$($ProjectFileInfo.BaseName).ThirdPartyLicencesNotices.json" -OutputPath "$ReportsDirectory\$($ProjectFileInfo.BaseName).ThirdPartyLicencesNotices.txt" -Name "$($ProjectFileInfo.BaseName)"
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

        if (-not($IsSDKProj)) {
            Copy-FilesRecursively -SourceDirectory "$($BuildBinDirectory)" -DestinationDirectory "$($PublishDirectory)" -Filter "*" -CopyEmptyDirs $false -ForceOverwrite $true -CleanDestination $true
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
}

exit

$ThirdPartyLicencesNoticesFiles = Find-FilesByPattern -Path "$ReportsRootPath" -Pattern "*.ThirdPartyLicencesNotices.txt" | ForEach-Object { $_.FullName } 
$THIRDPARTYDirectory = New-Directory -Paths @($PublishDirectory,"THIRDPARTY-LICENSES-NOTICE")
Join-FileText -InputFiles @($ThirdPartyLicencesNoticesFiles) -OutputFile "$THIRDPARTYDirectory\THIRDPARTY-LICENSE-NOTICE" -BetweenFiles 'One'
$InventoryHealthReportFiles = Find-FilesByPattern -Path "$ReportsRootPath" -Pattern "*.Inventory-Health-Report.txt" | ForEach-Object { $_.FullName } 
Join-FileText -InputFiles @($InventoryHealthReportFiles) -OutputFile "$PublishDirectory\BOM-HEALTH" -BetweenFiles 'One'


# Resolving deployment information for the current branch
$DeploymentChannel = $BranchDeploymentConfig.Channel.Value
$GitHubPackagesUser = "eigenverft"
$GitHubSourceName = "github"
$GitHubSourceUri = "https://nuget.pkg.github.com/$GitHubPackagesUser/index.json"
$NuGetTestSourceUri = "https://apiint.nugettest.org/v3/index.json"
$NuGetOrgSourceUri = "https://api.nuget.org/v3/index.json"

$BinaryDropRootPath = "C:\temp\$GitRepositoryName-drops"

$PushToLocalSource = $false
$PushToGitHubSource = $false
$PushToNuGetTest = $false
$PushToNuGetOrg = $false

$CopyToChannelDrops = $false
$CopyToDistributionDrop = $false
$CopyToZipDrop = $false

# Determine where to publish based on the deployment channel
if ($DeploymentChannel -in @("development"))
{
    $PushToLocalSource = $true
    $PushToGitHubSource = $false
    $PushToNuGetTest = $false
    $PushToNuGetOrg = $false

    $CopyToChannelDrops = $true
    $CopyToDistributionDrop = $false
    $CopyToZipDrop = $true
}

if ($DeploymentChannel -in @('quality'))
{
    $PushToLocalSource = $true
    $PushToGitHubSource = $true
    $PushToNuGetTest = $true
    $PushToNuGetOrg = $false

    $CopyToChannelDrops = $true
    $CopyToDistributionDrop = $false
    $CopyToZipDrop = $true
}

if ($DeploymentChannel -in @('staging'))
{
    $PushToLocalSource = $true
    $PushToGitHubSource = $true
    $PushToNuGetTest = $true
    $PushToNuGetOrg = $false

    $CopyToChannelDrops = $true
    $CopyToDistributionDrop = $false
    $CopyToZipDrop = $true
}

if ($DeploymentChannel -in @('production'))
{
    $PushToLocalSource = $true
    $PushToGitHubSource = $true
    $PushToNuGetTest = $false
    $PushToNuGetOrg = $true

    $CopyToChannelDrops = $true
    $CopyToDistributionDrop = $true
    $CopyToZipDrop = $true
}

# Deploy *.nupkg artifacts to the appropriate destinations
if ($PushToLocalSource -eq $true)
{
    $NuGetPackageFileInfos = Find-FilesByPattern -Path "$PackRootPath" -Pattern "*.nupkg"
    foreach ($NuGetPackageFileInfo in $NuGetPackageFileInfos)
    {
        Invoke-Exec -Executable "dotnet" -Arguments @("nuget", "push", "$($NuGetPackageFileInfo.FullName)", "--source","$LocalNuGetSourceName") -CaptureOutput $false
    }
}

if ($PushToGitHubSource -eq $true)
{
    $NuGetPackageFileInfos = Find-FilesByPattern -Path "$PackRootPath" -Pattern "*.nupkg"
    Invoke-Exec -Executable "dotnet" -Arguments @("nuget","add", "source", "--username", "$GitHubPackagesUser","--password","$NUGET_GITHUB_PUSH","--store-password-in-clear-text","--name","$GitHubSourceName","$GitHubSourceUri") -CaptureOutput $false -CaptureOutputDump $false -HideValues @($NUGET_GITHUB_PUSH)
    foreach ($NuGetPackageFileInfo in $NuGetPackageFileInfos)
    {
        Invoke-Exec -Executable "dotnet" -Arguments @("nuget","push", "$($NuGetPackageFileInfo.FullName)", "--api-key", "$NUGET_GITHUB_PUSH","--source","$GitHubSourceName") -CaptureOutput $false -CaptureOutputDump $false -HideValues @($NUGET_GITHUB_PUSH)
    }
    Unregister-LocalNuGetDotNetPackageSource -SourceName "$GitHubSourceName"
}

if ($PushToNuGetTest -eq $true)
{
    $NuGetPackageFileInfos = Find-FilesByPattern -Path "$PackRootPath" -Pattern "*.nupkg"
    foreach ($NuGetPackageFileInfo in $NuGetPackageFileInfos)
    {
        Invoke-Exec -Executable "dotnet" -Arguments @("nuget","push", "$($NuGetPackageFileInfo.FullName)", "--api-key", "$NUGET_TEST_PAT","--source","$NuGetTestSourceUri") -CaptureOutput $false -CaptureOutputDump $false -HideValues @($NUGET_TEST_PAT)
    }
}

if ($PushToNuGetOrg -eq $true)
{
    $NuGetPackageFileInfos = Find-FilesByPattern -Path "$PackRootPath" -Pattern "*.nupkg"
    foreach ($NuGetPackageFileInfo in $NuGetPackageFileInfos)
    {
        Invoke-Exec -Executable "dotnet" -Arguments @("nuget","push", "$($NuGetPackageFileInfo.FullName)", "--api-key", "$NUGET_PAT","--source","$NuGetOrgSourceUri") -CaptureOutput $false -CaptureOutputDump $false -HideValues @($NUGET_PAT)
    }
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

if ($CopyToZipDrop -eq $true)
{
    $nugetFilePart1 = Join-Text -InputObject @("$GitRepositoryName","$($GeneratedVersion.VersionFull)") -Separator '.' -Normalization Trim
    $nugetFileEmulation = Join-Text -InputObject @("$nugetFilePart1","$($BranchDeploymentConfig.Affix.Label)") -Separator '-' -Normalization Trim
    Compress-Directory -SourceDirectory "$PublishDirectory" -DestinationFile "$(Get-Path -Paths @($BinaryDropRootPath,"zipped","$nugetFileEmulation.zip"))"
}
