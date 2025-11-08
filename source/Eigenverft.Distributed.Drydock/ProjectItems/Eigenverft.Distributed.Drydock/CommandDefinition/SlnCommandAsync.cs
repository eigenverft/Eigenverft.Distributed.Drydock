using System;
using System.Collections.Generic;
using System.CommandLine;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using Eigenverft.Distributed.Drydock.CommandDeclaration;

using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Eigenverft.Distributed.Drydock.CommandDefinition
{
    public partial class CommandBackgroundService : BackgroundService
    {
        public async Task<int> SlnCommandAsync(ParseResult parseResult, CancellationToken cancellationToken)
        {
            try
            {
                var sourceDirectory = parseResult.GetRequiredValue(SlnCommand.Location);
                
                var result = await _solutionProjectService.GetCsProjAbsolutPathsFromSolutions(sourceDirectory, cancellationToken);

                if (result is null)
                {
                    _logger.LogWarning("No project paths could be read from solution: {SolutionPath}", sourceDirectory);
                    return -1;
                }

                if (result.Count > 0)
                {
                    foreach (var item in result)
                    {
                        Console.WriteLine(item);
                    }

                    // _logger.LogInformation("Retrieved {Count} project path(s) from solution: {SolutionPath}", result.Count, sourceDirectory);
                    // _logger.LogDebug("Project paths: {ProjectPaths}", string.Join(";", result));
                }
                else
                {
                    _logger.LogWarning("Solution contained no MSBuild projects: {SolutionPath}", sourceDirectory);
                    return -1;
                }
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning("SlnCommandAsync canceled by token.");
                return -1;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while reading project paths from solution: {SolutionPath}", ex.Message);
                return -1;
            }

            return 0;
        }
    }
}
