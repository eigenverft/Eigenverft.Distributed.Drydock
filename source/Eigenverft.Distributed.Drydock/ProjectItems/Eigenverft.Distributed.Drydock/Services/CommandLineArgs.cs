using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Eigenverft.Distributed.Drydock.Services
{
    /// <summary>
    /// Provides access to the original command-line arguments.
    /// &lt;implementation hidden&gt;
    /// </summary>
    public interface ICommandLineArgs
    {
        /// <summary>
        /// All arguments passed to <c>Main(string[] args)</c>.
        /// </summary>
        string[] Args { get; }
    }

    /// <summary>
    /// Default implementation of <see cref="ICommandLineArgs"/>.
    /// &lt;implementation hidden&gt;
    /// </summary>
    public class CommandLineArgs : ICommandLineArgs
    {
        /// <inheritdoc/>
        public string[] Args { get; }

        /// <summary>
        /// Initializes a new instance of <see cref="CommandLineArgs"/>.
        /// </summary>
        /// <param name="args">The raw arguments from <c>Main</c>.</param>
        public CommandLineArgs(string[] args)
        {
            Args = args ?? Array.Empty<string>();
        }
    }
}
