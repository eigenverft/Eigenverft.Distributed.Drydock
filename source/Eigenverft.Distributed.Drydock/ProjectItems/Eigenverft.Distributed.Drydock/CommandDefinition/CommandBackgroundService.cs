using System;
using System.Collections.Generic;
using System.CommandLine;
using System.CommandLine.Help;
using System.CommandLine.Invocation;
using System.ComponentModel.DataAnnotations;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

using Eigenverft.Distributed.Drydock.CommandDeclaration;
using Eigenverft.Distributed.Drydock.Services;

using Microsoft.Build.Construction;
using Microsoft.Build.Evaluation;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Eigenverft.Distributed.Drydock.CommandDefinition
{
    public partial class CommandBackgroundService : BackgroundService
    {
        private readonly RootCommand rootCommand;
        private readonly ICommandLineArgs _commandLineArgs;
        private readonly ILogger<CommandBackgroundService> _logger;
        private readonly IHostApplicationLifetime _lifetime;

        private readonly ISolutionProjectService _solutionProjectService;

        public CommandBackgroundService(ICommandLineArgs commandLineArgs, ILogger<CommandBackgroundService> logger, IHostApplicationLifetime lifetime, ISolutionProjectService solutionProjectService)
        {
            _lifetime = lifetime ?? throw new ArgumentNullException(nameof(lifetime), "HostApplicationLifetime cannot be null.");
            _logger = logger ?? throw new ArgumentNullException(nameof(logger), $"{nameof(logger)} cannot be null.");
            _commandLineArgs = commandLineArgs ?? throw new ArgumentNullException(nameof(commandLineArgs));
            _solutionProjectService = solutionProjectService ?? throw new ArgumentNullException(nameof(solutionProjectService), $"{nameof(solutionProjectService)} cannot be null.");

            rootCommand = new("Sample app for System.CommandLine");

            //ReadCommand.Command.SetAction(ReadCommandAsync);
            CsProjCommand.Command.SetAction(CsProjCommandAsync);
            SlnCommand.Command.SetAction(SlnCommandAsync);
            ProjTypeCommand.Command.SetAction(ProjTypeCommandAsync);

            //rootCommand.Subcommands.Add(ReadCommand.Command);
            rootCommand.Subcommands.Add(CsProjCommand.Command);
            rootCommand.Subcommands.Add(SlnCommand.Command);
            rootCommand.Subcommands.Add(ProjTypeCommand.Command);

        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken, CancellationToken.None);

            int returnCode = -99;
            try
            {
                ParseResult parseResult = rootCommand.Parse(_commandLineArgs.Args);

                bool isDefault = false;
                var defaultParameters = parseResult.CommandResult.Command.Options.Select(e => e.Name).Concat(parseResult.CommandResult.Command.Options.SelectMany(e => e.Aliases)).ToList();
                if (parseResult.Tokens.Count == 1 && defaultParameters.Contains(parseResult.Tokens[0].Value))
                {
                    isDefault = true;
                }

                if (parseResult?.Action is ParseErrorAction)
                {
                    returnCode = parseResult.Invoke();
                }
                else if (parseResult?.Action is HelpAction)
                {
                    returnCode = parseResult.Invoke();
                }
                else if (isDefault)
                {
                    if (parseResult is not null)
                    {
                        returnCode = parseResult.Invoke();
                    }
                }
                else if (parseResult?.Action is SynchronousCommandLineAction)
                {
                    returnCode = parseResult.Invoke();
                }
                else if (parseResult?.Action is AsynchronousCommandLineAction)
                {
                    returnCode = await ((AsynchronousCommandLineAction)parseResult.Action).InvokeAsync(parseResult, linkedCts.Token);
                }

                Environment.ExitCode = returnCode;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error executing command: {ErrorMessage}", ex.Message);
                returnCode = -1;
            }
            finally
            {
                Environment.ExitCode = returnCode;
                // Ensure the host stops in all cases
                _lifetime.StopApplication();
            }
        }


    }
}