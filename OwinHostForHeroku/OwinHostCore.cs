using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.Remoting;
using System.Runtime.Remoting.Lifetime;
using System.Threading;
using Microsoft.Owin;
using Microsoft.Owin.Hosting;

namespace OwinHostForHeroku
{
    /// <summary>
    /// Starting Owin Host server.
    /// <para>This class is instantiated at Program.Main() live in new AppDomain.</para>
    /// </summary>
    public class OwinHostCore : MarshalByRefObject, ISponsor, IDisposable
    {
        private ILease _lease;

        private bool _disposed;

        private IDisposable _runningApp;

        /// <summary>
        /// Start OwinHost server.
        /// </summary>
        public void Start(string url)
        {
            this._lease = (ILease)RemotingServices.GetLifetimeService(this);
            this._lease.Register(this);

            // Wireup resolving loading assembly via "~/bin" folder.
            AppDomain.CurrentDomain.AssemblyResolve += CurrentDomain_AssemblyResolve;

            // Find the assembly from "~/bin" folder which annotated with "[OwinStartup]" attribute.
            var baseDir = AppDomain.CurrentDomain.BaseDirectory;
            var binDir = Path.Combine(baseDir, "bin");
            Console.WriteLine($"baseDir is [{baseDir}]");
            Console.WriteLine($"binDir is [{binDir}]");

            var dllsPath = Directory
                .GetFiles(binDir, "*.dll")
                .Where(path => !Path.GetFileName(path).StartsWith("Microsoft."))
                .Where(path => !Path.GetFileName(path).StartsWith("System."))
                .Where(path => !Path.GetFileName(path).StartsWith("Owin."));
            Console.WriteLine("\nScan DLL:\n" + string.Join("\n", dllsPath));

            Console.WriteLine("\nTry retrive OwinStartupAttribute...");

            var startupType = default(Type);
            foreach (var dllPath in dllsPath)
            {
                Console.Write(Path.GetFileName(dllPath) + " ... ");
                try
                {
                    var assembly = Assembly.LoadFile(dllPath);
                    var owinStartupAttribute = assembly.GetCustomAttribute<OwinStartupAttribute>();
                    if (owinStartupAttribute != null)
                    {
                        Console.WriteLine("FOUND.");
                        startupType = owinStartupAttribute.StartupType;
                        break;
                    }
                    else
                    {
                        Console.WriteLine("not found.");
                    }
                }
                catch (Exception e)
                {
                    Console.WriteLine("WARNING: Could not load assembly or check assembly attribute.\n" + e.Message);
                }
            }

            if (startupType == null)
            {
                Console.WriteLine("FATAL ERROR: Startup class could not found.");
                return;
            }

            Console.WriteLine("Creating Startup object instance.");
            dynamic startUpObject = Activator.CreateInstance(startupType);

            // Prepare for waiting for "Ctrl + C".
            var quitEvent = new ManualResetEvent(false);
            Console.CancelKeyPress += (sender, eArgs) =>
            {
                quitEvent.Set();
                eArgs.Cancel = true;
            };

            // Start server.
            Console.WriteLine("Start server.");
            Console.WriteLine("(Press Ctrl+C to stop server and quit.)");
            this._runningApp = WebApp.Start(url, app => startUpObject.Configuration(app));

            // Wait for "Ctrl + C"
            quitEvent.WaitOne();
        }

        private Dictionary<string, Assembly> _Cache = new Dictionary<string, Assembly>();

        private Assembly CurrentDomain_AssemblyResolve(object sender, ResolveEventArgs args)
        {
            var assembly = default(Assembly);
            lock (_Cache)
            {
                if (_Cache.TryGetValue(args.Name, out assembly)) return assembly;

                // Try to find assembly from "~/bin" folder.
                var name = new AssemblyName(args.Name).Name;
                var path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "bin", name + ".dll");
                if (File.Exists(path)) assembly = Assembly.LoadFile(path);

                _Cache.Add(args.Name, assembly);
                if (assembly != null) _Cache.Add(assembly.FullName, assembly);
                return assembly;
            }
        }

        public void Dispose()
        {
            if (!this._disposed)
            {
                this._disposed = true;
                this._lease.Unregister(this);
                if (this._runningApp != null) this._runningApp.Dispose();
            }
            GC.SuppressFinalize(this);
        }

        public TimeSpan Renewal(ILease lease)
        {
            if (this._disposed) return TimeSpan.Zero;
            return TimeSpan.FromMinutes(5.0);
        }
    }
}
