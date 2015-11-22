using System;
using System.IO;
using System.Linq;

namespace OwinHostForHeroku
{
    class Program
    {
        /// <summary>
        /// Entry point of the progrm.
        /// </summary>
        static void Main(string[] args)
        {
            // Retrive URL from command line arguments and check it.
            var url = args.FirstOrDefault() ?? "";
            if (IsValidUrl(url) == false)
            {
                Console.WriteLine("FATAL ERROR: Invalid URL.");
                Console.WriteLine("Usage: OwinHostForHeroku {url}");
                return;
            }

            // Detect "wwwroot" folder especialy running on Heroku.
            var workDir = Directory.GetCurrentDirectory();
            var baseDir = AppDomain.CurrentDomain.BaseDirectory;
            var pubDir = Path.Combine(baseDir, "_PublishedWebsites");
            if (Directory.Exists(pubDir))
            {
                var wwwroot = Directory.GetDirectories(pubDir)
                    .Where(dir => Path.GetFileName(dir) != "packages")
                    .Where(dir => Directory.Exists(Path.Combine(dir, "bin")))
                    .Where(dir => Directory.GetFiles(Path.Combine(dir, "bin"), "*.dll").Any())
                    .FirstOrDefault();
                if (wwwroot != null)
                {
                    workDir = wwwroot;
                }
            }
            Directory.SetCurrentDirectory(workDir);

            // Detect web.config and get exact full path for case sensitive file system.
            var webConfigPath = Directory.GetFiles(workDir, "*.config")
                .Where(path => Path.GetFileName(path).ToLower() == "web.config")
                .FirstOrDefault() ?? Path.Combine(workDir, "Web.config");

            // Create new AppDomain based on working directory.
            var info = new AppDomainSetup
            {
                ApplicationBase = workDir,
                PrivateBinPath = "bin",
                PrivateBinPathProbe = "*",
                LoaderOptimization = LoaderOptimization.MultiDomainHost,
                ConfigurationFile = webConfigPath
            };
            var domain = AppDomain.CreateDomain("OWIN", null, info);

            // Start OwinHostCore server in new AppDomain.
            var hostCore = default(OwinHostCore);
            try
            {
                hostCore = domain.CreateInstanceAndUnwrap(typeof(OwinHostCore).Assembly.FullName, typeof(OwinHostCore).FullName) as OwinHostCore;
            }
            catch
            {
                hostCore = domain.CreateInstanceFromAndUnwrap(typeof(OwinHostCore).Assembly.Location, typeof(OwinHostCore).FullName) as OwinHostCore;
            }

            using (hostCore)
                hostCore.Start(url);
        }

        /// <summary>
        /// Check the URL string is valid URL.
        /// </summary>
        private static bool IsValidUrl(string url)
        {
            url = url.Replace("*", "host").Replace("+", "host");
            var uri = default(Uri);
            var isValidUrl = Uri.TryCreate(url, UriKind.Absolute, out uri);
            return isValidUrl;
        }
    }
}
