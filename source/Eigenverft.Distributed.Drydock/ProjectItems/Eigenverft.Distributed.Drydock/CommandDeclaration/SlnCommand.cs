using System.CommandLine;

namespace Eigenverft.Distributed.Drydock.CommandDeclaration
{
    public static class SlnCommand
    {
        public enum ElementScope
        {
            outer,
            inner
        }

        public static Command Command { get; private set; }

        public static Option<string> Location { get; private set; }

        public static Option<string> Property { get; private set; }

        static SlnCommand()
        {
            Location = new("--location")
            {
                Description = "Full path to the target solution file (.sln).",
                Required = true,
            };

            Property = new("--property")
            {
                Description = "MSBuild property name to read.",
                Required = true,
            };

            Command = new Command("sln", "Retrieve project file paths from a solution (.sln) file.")
            {
                Location,
                Property,
            };
        }
    }
}
