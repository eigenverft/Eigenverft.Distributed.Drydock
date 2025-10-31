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
        public async Task<int> CsProjCommandAsync(ParseResult parseResult, CancellationToken cancellationToken)
        {
            try
            {
                var sourceDirectory = parseResult.GetRequiredValue(CsProjCommand.Location);
                var outputArchive = parseResult.GetRequiredValue(CsProjCommand.Property);
                
                var result = await _solutionProjectService.GetProjectProperty(sourceDirectory, outputArchive, CsProjCommand.ElementScope.inner, cancellationToken);

                var propertyName = parseResult.GetRequiredValue(CsProjCommand.Property);
                if (!string.IsNullOrEmpty(result))
                {
                    _logger.LogInformation("Property '{Property}' from '{ProjectFile}' = {Value}", propertyName, sourceDirectory, result);
                }
                else
                {
                    _logger.LogWarning("Property '{Property}' was not found or is empty in project: {ProjectFile}", propertyName, sourceDirectory);
                    return -1;
                }
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning("{Command} canceled by token.",nameof(CsProjCommandAsync));
                return -1;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while reading property from project.");
                return -1;
            }

            return 0;
        }
    }
}
