using System;
using System.Collections.Generic;
using System.CommandLine;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Eigenverft.Distributed.Drydock.CommandDeclaration
{
    public static class ProjTypeCommand
    {
        public enum ReturnEnum
        {
            sdk,
        }

        public static Command Command { get; private set; }

        public static Option<string> Location { get; private set; }

        public static Option<ReturnEnum> Return { get; private set; }

        static ProjTypeCommand()
        {
            Location = new("--location")
            {
                Description = "Full path to the target .csproj file.",
                Required = true,
            };

            Return = new("--return")
            {
                Description = "Value scope: 'outer' returns the containing XML element; 'inner' returns only the element's text (default).",
                DefaultValueFactory = _ => ReturnEnum.sdk,
            };

            Command = new Command("projtype", "Read a property of a .csproj file.")
            {
                Location,
                Return,
            };
        }
    }
}
