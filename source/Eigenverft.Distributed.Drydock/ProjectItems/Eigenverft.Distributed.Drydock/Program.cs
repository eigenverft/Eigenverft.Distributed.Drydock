using System;
using System.Threading.Tasks;

using Eigenverft.Distributed.Drydock.CommandDefinition;
using Eigenverft.Distributed.Drydock.Services;

using Microsoft.Build.Locator;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using Serilog;

namespace Eigenverft.Distributed.Drydock
{
    internal partial class Program
    {
        private static async Task<int> Main(string[] args)
        {
            MSBuildLocator.RegisterDefaults();

            Log.Logger = new LoggerConfiguration()
                .MinimumLevel.Verbose()
                .Enrich.FromLogContext()
                .MinimumLevel.Override("Microsoft.Extensions.Hosting.Internal.Host", Serilog.Events.LogEventLevel.Information)
                .WriteTo.Console(outputTemplate: "[{Timestamp:yyyy-MM-dd HH:mm:ss.fff} {Level:u3}] {Message:lj}{NewLine}{Exception}")
                .CreateLogger();

            IHostBuilder builder = Host.CreateDefaultBuilder();

            builder.ConfigureLogging(logging => { logging.ClearProviders(); });

            builder.ConfigureServices(services =>
            {
                services.AddSingleton<ICommandLineArgs>(new CommandLineArgs(args));
                services.Configure<ConsoleLifetimeOptions>(opts => opts.SuppressStatusMessages = true);
                services.AddSingleton<ISolutionProjectService, SolutionProjectService>();
                services.AddHostedService<CommandBackgroundService>();
            }).UseSerilog(Log.Logger);

            var app = builder.Build();

            try
            {
                await app.RunAsync();
            }
            catch (Exception ex)
            {
                Log.Fatal(ex, "An unhandled exception occurred during execution of the application.");
            }

            await Log.CloseAndFlushAsync();

            return Environment.ExitCode;
        }
    }
}