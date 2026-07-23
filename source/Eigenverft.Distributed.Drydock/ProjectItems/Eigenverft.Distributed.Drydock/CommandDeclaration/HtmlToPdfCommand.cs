using System.CommandLine;

namespace Eigenverft.Distributed.Drydock.CommandDeclaration
{
    public static class HtmlToPdfCommand
    {
        public static Command Command { get; private set; }

        public static Option<string> Input { get; private set; }

        public static Option<string> Output { get; private set; }

        public static Option<string?> BrowserCache { get; private set; }

        static HtmlToPdfCommand()
        {
            Input = new("--input")
            {
                Description = "Full path to the source html file.",
                Required = true,
            };

            Output = new("--output")
            {
                Description = "Full path to the target pdf file.",
                Required = true,
            };

            BrowserCache = new("--browser-cache")
            {
                Description = "Optional browser cache directory for Chromium downloads.",
                Required = false,
            };

            Command = new Command("htmltopdf", "Convert an html file to pdf.")
            {
                Input,
                Output,
                BrowserCache,
            };
        }
    }
}
