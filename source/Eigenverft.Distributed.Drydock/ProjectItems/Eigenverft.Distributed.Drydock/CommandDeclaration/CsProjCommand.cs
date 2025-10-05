using System.CommandLine;

namespace Eigenverft.Distributed.Drydock.CommandDeclaration
{
    public static class CsProjCommand
    {
        public enum ElementScope
        {
            outer,
            inner
        }

        public static Command Command { get; private set; }

        public static Option<string> Location { get; private set; }

        public static Option<string> Property { get; private set; }

        public static Option<ElementScope> Scope { get; private set; }

        static CsProjCommand()
        {
            Location = new("--location")
            {
                Description = "Full path to the target .csproj file.",
                Required = true,
            };

            Property = new("--property")
            {
                Description = "MSBuild property name to read.",
                Required = true,
            };

            Scope = new("--scope")
            {
                Description = "Value scope: 'outer' returns the containing XML element; 'inner' returns only the element's text (default).",
                DefaultValueFactory = _ => ElementScope.inner,
            };

            Command = new Command("csproj", "Read a property value from a .csproj file.")
            {
                Location,
                Property,
                Scope,
            };
        }
    }
}
