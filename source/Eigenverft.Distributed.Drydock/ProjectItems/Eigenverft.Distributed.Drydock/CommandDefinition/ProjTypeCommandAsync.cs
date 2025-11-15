using System;
using System.CommandLine;
using System.Threading;
using System.Threading.Tasks;

using Eigenverft.Distributed.Drydock.CommandDeclaration;

using Microsoft.Extensions.Hosting;

using Microsoft.Extensions.Logging;

namespace Eigenverft.Distributed.Drydock.CommandDefinition
{
    public partial class CommandBackgroundService : BackgroundService
    {
        public async Task<int> ProjTypeCommandAsync(ParseResult parseResult, CancellationToken cancellationToken)
        {
            try
            {
                var location = parseResult.GetRequiredValue(ProjTypeCommand.Location);
                var returnType = parseResult.GetRequiredValue(ProjTypeCommand.Return);


                var result = await _solutionProjectService.GetProjectInfo(location, returnType, cancellationToken);

                if (!string.IsNullOrEmpty(result))
                {
                    Console.WriteLine(result);
                }
                else
                {
                    _logger.LogWarning("Return '{returnType}' was not found or is empty in project: {ProjectFile}", returnType, location);
                    return -1;
                }
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning("{Command} canceled by token.", nameof(CsProjCommandAsync));
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
