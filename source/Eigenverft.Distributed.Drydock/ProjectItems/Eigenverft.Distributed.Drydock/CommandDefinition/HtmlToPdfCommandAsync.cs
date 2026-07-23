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
        public async Task<int> HtmlToPdfCommandAsync(ParseResult parseResult, CancellationToken cancellationToken)
        {
            try
            {
                var input = parseResult.GetRequiredValue(HtmlToPdfCommand.Input);
                var output = parseResult.GetRequiredValue(HtmlToPdfCommand.Output);
                var browserCache = parseResult.GetValue(HtmlToPdfCommand.BrowserCache);

                var result = await _solutionProjectService.ConvertHtmlToPdf(input, output, browserCache, cancellationToken);

                if (!result)
                {
                    _logger.LogWarning("Html to pdf conversion failed for input file: {InputFile}", input);
                    return -1;
                }
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning("{Command} canceled by token.", nameof(HtmlToPdfCommandAsync));
                return -1;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while converting html to pdf.");
                return -1;
            }

            return 0;
        }
    }
}
