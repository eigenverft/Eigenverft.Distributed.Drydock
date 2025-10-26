
<#
.SYNOPSIS
    Recursively searches a directory for files matching a specified pattern.
.DESCRIPTION
    This function searches the specified directory and all its subdirectories for files
    that match the provided filename pattern (e.g., "*.txt", "*.sln", "*.csproj").
    It returns an array of matching FileInfo objects, which can be iterated with a ForEach loop.
.PARAMETER Path
    The root directory where the search should begin.
.PARAMETER Pattern
    The filename pattern to search for (e.g., "*.txt", "*.sln", "*.csproj").
.EXAMPLE
    $files = Find-FilesByPattern -Path "C:\MyProjects" -Pattern "*.txt"
    foreach ($file in $files) {
        Write-Output $file.FullName
    }
#>
function Find-FilesByPattern {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    # Validate that the provided path exists and is a directory.
    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw "The specified path '$Path' does not exist or is not a directory."
    }

    try {
        # Recursively search for files matching the given pattern.
        $results = Get-ChildItem -Path $Path -Filter $Pattern -Recurse -File -ErrorAction Stop
        return $results
    }
    catch {
        Write-Error "An error occurred while searching for files: $_"
    }
}

function New-DirectoryFromSegments {
    <#
    .SYNOPSIS
        Combines path segments into a full directory path and creates the directory.
    
    .DESCRIPTION
        This function takes an array of strings representing parts of a file system path,
        combines them using [System.IO.Path]::Combine, validates the resulting path, creates
        the directory if it does not exist, and returns the full directory path.
    
    .PARAMETER Paths
        An array of strings that represents the individual segments of the directory path.
    
    .EXAMPLE
        $outputReportDirectory = New-DirectoryFromSegments -Paths @($outputRootReportResultsDirectory, "$($projectFile.BaseName)", "$branchVersionFolder")
        # This combines the three parts, creates the directory if needed, and returns the full path.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )
    
    # Combine the provided path segments into a single path.
    $combinedPath = [System.IO.Path]::Combine($Paths)
    
    # Validate that the combined path is not null or empty.
    if ([string]::IsNullOrEmpty($combinedPath)) {
        Write-Error "The combined path is null or empty."
        exit 1
    }
    
    # Create the directory if it does not exist.
    [System.IO.Directory]::CreateDirectory($combinedPath) | Out-Null
    
    # Return the combined directory path.
    return $combinedPath
}

function Copy-FilesRecursively {
    <#
    .SYNOPSIS
        Recursively copies files from a source directory to a destination directory.

    .DESCRIPTION
        This function copies files from the specified source directory to the destination directory.
        The file filter (default "*") limits the files that are copied. The –CopyEmptyDirs parameter
        controls directory creation:
         - If $true (default), the complete source directory tree is recreated.
         - If $false, only directories that contain at least one file matching the filter (in that
           directory or any subdirectory) will be created.
        The –ForceOverwrite parameter (default $true) determines whether existing files are overwritten.
        The –CleanDestination parameter (default $false) controls whether additional files in the root of the
        DestinationDirectory (files that do not exist in the source directory) should be removed.
        **Note:** This cleaning only applies to files in the destination root and does not affect files
        in subdirectories.

    .PARAMETER SourceDirectory
        The directory from which files and directories are copied.

    .PARAMETER DestinationDirectory
        The target directory to which files and directories will be copied.

    .PARAMETER Filter
        A wildcard filter that limits which files are copied. Defaults to "*".

    .PARAMETER CopyEmptyDirs
        If $true, the entire directory structure from the source is recreated in the destination.
        If $false, only directories that will contain at least one file matching the filter are created.
        Defaults to $true.

    .PARAMETER ForceOverwrite
        A Boolean value that indicates whether existing files should be overwritten.
        Defaults to $true.

    .PARAMETER CleanDestination
        If $true, any extra files found in the destination directory’s root (that are not present in the
        source directory, matching the filter) are removed. Files in subdirectories are not affected.
        Defaults to $false.

    .EXAMPLE
        # Copy all *.txt files, create only directories that hold matching files, and clean extra files in the destination root.
        Copy-FilesRecursively2 -SourceDirectory "C:\Source" `
                               -DestinationDirectory "C:\Dest" `
                               -Filter "*.txt" `
                               -CopyEmptyDirs $false `
                               -ForceOverwrite $true `
                               -CleanDestination $true

    .EXAMPLE
        # Copy all files, recreate the full directory tree without cleaning extra files.
        Copy-FilesRecursively2 -SourceDirectory "C:\Source" `
                               -DestinationDirectory "C:\Dest"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDirectory,

        [Parameter()]
        [string]$Filter = "*",

        [Parameter()]
        [bool]$CopyEmptyDirs = $true,

        [Parameter()]
        [bool]$ForceOverwrite = $true,

        [Parameter()]
        [bool]$CleanDestination = $false
    )

    # Validate that the source directory exists.
    if (-not (Test-Path -Path $SourceDirectory -PathType Container)) {
        Write-Error "Source directory '$SourceDirectory' does not exist."
        return
    }

    # If CopyEmptyDirs is false, check if there are any files matching the filter.
    if (-not $CopyEmptyDirs) {
        $matchingFiles = Get-ChildItem -Path $SourceDirectory -Recurse -File -Filter $Filter -ErrorAction SilentlyContinue
        if (-not $matchingFiles -or $matchingFiles.Count -eq 0) {
            Write-Verbose "No files matching filter found in source. Skipping directory creation as CopyEmptyDirs is false."
            return
        }
    }

    # Create the destination directory if it doesn't exist.
    if (-not (Test-Path -Path $DestinationDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $DestinationDirectory | Out-Null
    }

    # If CleanDestination is enabled, remove files in the destination root that aren't in the source root.
    if ($CleanDestination) {
        Write-Verbose "Cleaning destination root: removing extra files not present in source."
        $destRootFiles = Get-ChildItem -Path $DestinationDirectory -File -Filter $Filter
        foreach ($destFile in $destRootFiles) {
            $sourceFilePath = Join-Path -Path $SourceDirectory -ChildPath $destFile.Name
            if (-not (Test-Path -Path $sourceFilePath -PathType Leaf)) {
                Write-Verbose "Removing file: $($destFile.FullName)"
                Remove-Item -Path $destFile.FullName -Force
            }
        }
    }

    # Set full paths for easier manipulation.
    $sourceFullPath = (Get-Item $SourceDirectory).FullName.TrimEnd('\')
    $destFullPath   = (Get-Item $DestinationDirectory).FullName.TrimEnd('\')

    if ($CopyEmptyDirs) {
        Write-Verbose "Recreating complete directory structure from source."
        # Recreate every directory under the source.
        Get-ChildItem -Path $sourceFullPath -Recurse -Directory | ForEach-Object {
            $relativePath = $_.FullName.Substring($sourceFullPath.Length)
            $newDestDir   = Join-Path -Path $destFullPath -ChildPath $relativePath
            if (-not (Test-Path -Path $newDestDir)) {
                New-Item -ItemType Directory -Path $newDestDir | Out-Null
            }
        }
    }
    else {
        Write-Verbose "Creating directories only for files matching the filter."
        # Using previously obtained $matchingFiles.
        foreach ($file in $matchingFiles) {
            $sourceDir   = Split-Path -Path $file.FullName -Parent
            $relativeDir = $sourceDir.Substring($sourceFullPath.Length)
            $newDestDir  = Join-Path -Path $destFullPath -ChildPath $relativeDir
            if (-not (Test-Path -Path $newDestDir)) {
                New-Item -ItemType Directory -Path $newDestDir | Out-Null
            }
        }
    }

    # Copy files matching the filter, preserving relative paths.
    Write-Verbose "Copying files from source to destination."
    if ($CopyEmptyDirs) {
        $filesToCopy = Get-ChildItem -Path $SourceDirectory -Recurse -File -Filter $Filter
    }
    else {
        $filesToCopy = $matchingFiles
    }
    foreach ($file in $filesToCopy) {
        $relativePath = $file.FullName.Substring($sourceFullPath.Length)
        $destFile     = Join-Path -Path $destFullPath -ChildPath $relativePath

        # Skip copying if overwrite is disabled and the file already exists.
        if (-not $ForceOverwrite -and (Test-Path -Path $destFile)) {
            Write-Verbose "Skipping existing file (overwrite disabled): $destFile"
            continue
        }

        # Ensure the destination directory exists.
        $destDir = Split-Path -Path $destFile -Parent
        if (-not (Test-Path -Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir | Out-Null
        }

        Write-Verbose "Copying file: $($file.FullName) to $destFile"
        if ($ForceOverwrite) {
            Copy-Item -Path $file.FullName -Destination $destFile -Force
        }
        else {
            Copy-Item -Path $file.FullName -Destination $destFile
        }
    }
}










