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

        static SlnCommand()
        {
            Location = new("--location")
            {
                Description = "Full path to the target solution file (.sln).",
                Required = true,
            };


            Command = new Command("sln", "Retrieve project file paths from a solution (.sln) file.")
            {
                Location,
            };
        }
    }
}
