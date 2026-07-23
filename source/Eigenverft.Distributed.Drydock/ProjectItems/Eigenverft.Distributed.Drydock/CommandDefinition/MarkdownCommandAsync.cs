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
        public async Task<int> MarkdownCommandAsync(ParseResult parseResult, CancellationToken cancellationToken)
        {
            try
            {
                var input = parseResult.GetRequiredValue(MarkdownCommand.Input);
                var output = parseResult.GetRequiredValue(MarkdownCommand.Output);

                var result = await _solutionProjectService.ConvertMarkdownToHtml(input, output, cancellationToken);

                if (!result)
                {
                    _logger.LogWarning("Markdown conversion failed for input file: {InputFile}", input);
                    return -1;
                }
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning("{Command} canceled by token.", nameof(MarkdownCommandAsync));
                return -1;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while converting markdown to html.");
                return -1;
            }

            return 0;
        }
    }
}
