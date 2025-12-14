using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

using Eigenverft.Distributed.Drydock.CommandDeclaration;

using Microsoft.Build.Construction;
using Microsoft.Extensions.Logging;
using Microsoft.VisualStudio.SolutionPersistence.Model;
using Microsoft.VisualStudio.SolutionPersistence.Serializer;

namespace Eigenverft.Distributed.Drydock.Services
{
    /// <summary>
    /// A service for retrieving project file paths and properties from a solution.
    /// </summary>
    public interface ISolutionProjectService
    {
        /// <summary>
        /// Retrieves the absolute paths of csproj files from the specified solution.
        /// </summary>
        /// <param name="solutionLocation">The full path to the solution file.</param>
        /// <param name="cancellationToken">A token for monitoring cancellation requests.</param>
        /// <returns>A list of absolute paths to csproj files.</returns>
        Task<List<string>> GetCsProjAbsolutPathsFromSolutions(string solutionLocation, CancellationToken cancellationToken);

        /// <summary>
        /// Retrieves a specified project property from a project file.
        /// </summary>
        /// <param name="projectLocation">The full path to the project file.</param>
        /// <param name="propertyName">The name of the property to retrieve.</param>
        /// <param name="scopeType">The element scope used to determine the property value (inner or outer element).</param>
        /// <param name="cancellationToken">A token for monitoring cancellation requests.</param>
        /// <returns>The property value if found; otherwise, null.</returns>
        Task<string?> GetProjectProperty(string projectLocation, string? propertyName, CsProjCommand.ElementScope? scopeType, CancellationToken cancellationToken);

        Task<string?> GetProjectInfo(string projectLocation, ProjTypeCommand.ReturnEnum? scopeType, CancellationToken cancellationToken);
    }

    /// <summary>
    /// A concrete implementation of <see cref="ISolutionProjectService"/> that retrieves project paths and properties.
    /// </summary>
    public class SolutionProjectService : ISolutionProjectService
    {
        private readonly ILogger<SolutionProjectService> _logger;

        public SolutionProjectService(ILogger<SolutionProjectService> logger)
        {
            _logger = logger;
        }

        public async Task<List<string>> GetCsProjAbsolutPathsFromSolutions(string solutionLocation, CancellationToken cancellationToken)
        {
            List<string> retval = new List<string>();

            try
            {
                // Load solution (.sln OR .slnx)
                var serializer = SolutionSerializers.GetSerializerByMoniker(solutionLocation);
                if (serializer is null)
                {
                    _logger.LogError("Unsupported solution file type: {SolutionLocation}", solutionLocation);
                    return null;
                }

                SolutionModel solution;
                try
                {
                    solution = await serializer.OpenAsync(solutionLocation, cancellationToken);
                }
                catch (SolutionException ex)
                {
                    _logger.LogError(ex, "Failed to parse solution file: {SolutionLocation}", solutionLocation);
                    return null;
                }

                string solutionDir = Path.GetDirectoryName(Path.GetFullPath(solutionLocation)) ?? Directory.GetCurrentDirectory();

                // Keep it simple: only take csproj entries
                var csprojPaths = solution.SolutionProjects
                    .Select(p => p.FilePath)
                    .Where(p => p.EndsWith(".csproj", StringComparison.OrdinalIgnoreCase))
                    .Select(p => Path.GetFullPath(Path.Combine(solutionDir, p)))
                    .ToList();

                if (csprojPaths.Count == 0)
                {
                    _logger.LogWarning("Solution contained no C# projects: {SolutionLocation}", solutionLocation);
                    return null;
                }

                // Load each project file (your existing logic)
                List<ProjectRootElement> projects = new List<ProjectRootElement>();
                foreach (var projectPath in csprojPaths)
                {
                    try
                    {
                        ProjectRootElement projectRoot = ProjectRootElement.Open(projectPath);
                        projects.Add(projectRoot);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Failed to open project file: {ProjectLocation}", projectPath);
                        return null;
                    }
                }

                // Your existing sorting logic (unchanged)
                var testProjects = projects.Where(project =>
                    project.Items.Any(item =>
                        item.ElementName == "PackageReference" &&
                        string.Equals(item.Include, "Microsoft.NET.Test.Sdk", StringComparison.OrdinalIgnoreCase)
                    )
                ).ToList();

                var nonTestProjects = projects.Where(project =>
                    !project.Items.Any(item =>
                        item.ElementName == "PackageReference" &&
                        string.Equals(item.Include, "Microsoft.NET.Test.Sdk", StringComparison.OrdinalIgnoreCase)
                    )
                ).ToList();

                nonTestProjects = nonTestProjects
                    .OrderBy(i => i.Items.Any(f => f.ElementName.Contains("ProjectReference")))
                    .ToList();

                foreach (var item in testProjects) retval.Add(item.FullPath);
                foreach (var item in nonTestProjects) retval.Add(item.FullPath);

                return retval.Count == 0 ? null : retval;
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning("Solution parsing canceled: {SolutionLocation}", solutionLocation);
                return null;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error while parsing the solution file: {SolutionLocation}", solutionLocation);
                throw;
            }
        }

        public async Task<string?> GetProjectProperty(string projectLocation, string? propertyName, CsProjCommand.ElementScope? scopeType, CancellationToken cancellationToken)
        {
            if (string.IsNullOrEmpty(propertyName))
            {
                _logger.LogWarning("No property name was specified for project: {ProjectLocation}", projectLocation);
                return null;
            }

            ProjectRootElement projectRoot;
            try
            {
                projectRoot = ProjectRootElement.Open(projectLocation);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to open project file: {ProjectLocation}", projectLocation);
                return null;
            }

            var property = projectRoot.Properties.FirstOrDefault(e => e.Name.Equals(propertyName, StringComparison.OrdinalIgnoreCase));

            if (property == null)
            {
                _logger.LogWarning("Property '{PropertyName}' was not found in the project file: {ProjectLocation}", propertyName, projectLocation);
                return null;
            }

            if (scopeType.HasValue)
            {
                if (scopeType.Value == CsProjCommand.ElementScope.inner)
                {
                    // _logger.LogDebug("Returning inner element value for property '{PropertyName}' from project: {ProjectLocation}", propertyName, projectLocation);
                    return property.Value;
                }
                else
                {
                    // _logger.LogDebug("Returning outer element value for property '{PropertyName}' from project: {ProjectLocation}", propertyName, projectLocation);
                    return property.OuterElement;
                }
            }
            else
            {
                _logger.LogWarning("No element scope specified for property '{PropertyName}' in project: {ProjectLocation}", propertyName, projectLocation);
                return null;
            }
        }

        /// <summary>
        /// Retrieves project information based on the specified return type.
        /// </summary>
        /// <remarks>
        /// Implementation reads the project file at the given path and returns metadata depending on the requested return type.
        /// </remarks>
        /// <param name="projectLocation">The full path to the project file.</param>
        /// <param name="returnType">The requested type of project information.</param>
        /// <param name="cancellationToken">Token to observe cancellation requests.</param>
        /// <returns>
        /// The requested project information as a string, or null if the input is invalid,
        /// the project file cannot be opened, or the requested information is not available.
        /// </returns>
        /// <example>
        /// var info = await GetProjectInfo("path/to/project.csproj", ProjTypeCommand.ReturnEnum.sdk, CancellationToken.None);
        /// </example>
        public async Task<string?> GetProjectInfo(string projectLocation, ProjTypeCommand.ReturnEnum? returnType, CancellationToken cancellationToken)
        {
            if (string.IsNullOrEmpty(projectLocation))
            {
                _logger.LogWarning("No project location was specified.");
                return null;
            }

            ProjectRootElement projectRoot;
            try
            {
                projectRoot = ProjectRootElement.Open(projectLocation);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to open project file: {ProjectLocation}", projectLocation);
                return null;
            }

            switch (returnType)
            {
                case ProjTypeCommand.ReturnEnum.sdk:
                    if (string.IsNullOrWhiteSpace(projectRoot.Sdk))
                    {
                        return "false";
                    }
                    else
                    {
                        return "true";
                    }

                default:
                    _logger.LogWarning("Requested return type '{ReturnType}' is not supported for project: {ProjectLocation}", returnType, projectLocation);
                    return null;
            }
        }

    }
}