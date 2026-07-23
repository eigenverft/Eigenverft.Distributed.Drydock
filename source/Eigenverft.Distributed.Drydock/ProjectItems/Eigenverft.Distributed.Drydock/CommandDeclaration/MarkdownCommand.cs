using System.CommandLine;

namespace Eigenverft.Distributed.Drydock.CommandDeclaration
{
    public static class MarkdownCommand
    {
        public static Command Command { get; private set; }

        public static Option<string> Input { get; private set; }

        public static Option<string> Output { get; private set; }

        static MarkdownCommand()
        {
            Input = new("--input")
            {
                Description = "Full path to the source markdown file.",
                Required = true,
            };

            Output = new("--output")
            {
                Description = "Full path to the target html file.",
                Required = true,
            };

            Command = new Command("markdown", "Convert a markdown file to html.")
            {
                Input,
                Output,
            };
        }
    }
}
