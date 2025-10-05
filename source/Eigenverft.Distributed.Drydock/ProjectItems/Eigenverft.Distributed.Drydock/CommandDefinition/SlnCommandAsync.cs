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
                var outputArchive = parseResult.GetRequiredValue(SlnCommand.Property);
                
                var result = await _solutionProjectService.GetCsProjAbsolutPathsFromSolutions(sourceDirectory, cancellationToken);

                _logger.LogInformation("Successfully created ZIP: {ZipPath}", outputArchive);
                _logger.LogInformation("result {result}", result.ToString());
                _logger.LogError("Failed to create ZIP: {ZipPath}", outputArchive);
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning("SlnCommandAsync canceled by token.");
                return -1;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while CsProjCommandAsync.");
                return -1;
            }

            return 0;
        }
    }
}
