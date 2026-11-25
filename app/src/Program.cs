using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows.Forms;

[assembly: AssemblyTitle("SwitchDeck")]
[assembly: AssemblyVersion("1.0.0.0")]

namespace SwitchDeck
{
    public static class Program
    {
        private const string Id = "Local\\SwitchDeck-6c1e2f94";
        internal static string Script;
        internal static string Root;
        internal static bool Rendering;

        public static string Version
        {
            get { Version v = typeof(Program).Assembly.GetName().Version; return v.Major + "." + v.Minor + "." + v.Build; }
        }

        internal static string DataDir { get { return Path.Combine(Root, "data"); } }
        internal static string LogsDir { get { return Path.Combine(Root, "logs"); } }
        internal static string AssetsDir { get { return Path.Combine(AppRoot, "assets"); } }
        internal static string AppRoot;

        private static Form splash;

        public static void CloseSplash()
        {
            Form f = splash;
            splash = null;
            if (f == null) return;
            try { f.Close(); f.Dispose(); } catch { }
        }

        public static int RunFromScript(string scriptPath, string[] args)
        {
            return RunFromScript(scriptPath, args, null);
        }

        public static int RunFromScript(string scriptPath, string[] args, object splashForm)
        {
            object o = splashForm;
            if (o != null && !(o is Form))
            {
                PropertyInfo pi = o.GetType().GetProperty("BaseObject");
                if (pi != null) o = pi.GetValue(o, null);
            }
            splash = o as Form;
            try { return Run(scriptPath, args); }
            finally { CloseSplash(); }
        }

        internal static bool Uninstalling;

        private static void Finish(bool uninstall)
        {
            using (SplashForm sp = new SplashForm(uninstall ? L.T("uninstalling") : L.T("closing")))
            {
                sp.Show();
                sp.Refresh();
                DateTime start = DateTime.Now;
                Thread t = new Thread(delegate()
                {
                    try { Sessions.CloseAll(); } catch { }
                    if (uninstall) { try { Install.Uninstall(); } catch (Exception ex) { Log.Error("Uninstall: " + ex.Message); } }
                });
                t.IsBackground = true;
                t.Start();
                while (t.IsAlive || (DateTime.Now - start).TotalMilliseconds < 900)
                {
                    Application.DoEvents();
                    Thread.Sleep(15);
                }
                sp.Close();
            }
            Log.Info(uninstall ? "SwitchDeck uninstalled" : "SwitchDeck closed");
        }

        private static int Run(string scriptPath, string[] args)
        {
            Script = scriptPath;
            AppRoot = Path.GetDirectoryName(Path.GetDirectoryName(scriptPath));
            string home = Environment.GetEnvironmentVariable("SWITCHDECK_HOME");
            Root = string.IsNullOrEmpty(home) ? AppRoot : home;
            try { Native.SetProcessDpiAwarenessContext(new IntPtr(-4)); } catch { }

            List<string> a = new List<string>(args ?? new string[0]);
            if (a.Contains("--exit")) { Signal(Id + "-exit"); return 0; }
            int wa = a.IndexOf("--write-assets");
            if (wa >= 0 && wa + 1 < a.Count) { Install.WriteAssets(a[wa + 1]); return 0; }
            if (a.Contains("--selftest")) return SelfTest.Run();
            int sshi = a.IndexOf("--sshtest");
            if (sshi >= 0 && sshi + 1 < a.Count) return SelfTest.SshTest(int.Parse(a[sshi + 1]));
            if (a.Contains("--demo-shell")) return DemoShell(a);
            Fonts.Load(Path.Combine(AssetsDir, "fonts"));
            Store.Load();
            L.Lang = Store.Settings.Language;
            Theme.Apply(Store.Settings.Theme, Store.Settings.TermTheme);
            int render = a.IndexOf("--render-ui");
            if (render >= 0 && render + 1 < a.Count) { DevRender.Run(a[render + 1], a); return 0; }

            bool created;
            using (Mutex mutex = new Mutex(true, Id, out created))
            {
                if (a.Contains("--uninstall"))
                {
                    if (!created)
                    {
                        Signal(Id + "-exit");
                        try { created = mutex.WaitOne(20000); }
                        catch (AbandonedMutexException) { created = true; }
                    }
                    try { Application.EnableVisualStyles(); } catch { }
                    CloseSplash();
                    if (!Dialogs.Ask(null, L.T("uninstallTitle"), Install.UninstallText(), L.T("uninstall"), L.T("cancel"), "delete", true)) return 0;
                    Finish(true);
                    return 0;
                }
                if (!created && a.Contains("--wait"))
                {
                    try { created = mutex.WaitOne(20000); }
                    catch (AbandonedMutexException) { created = true; }
                }
                if (!created)
                {
                    CloseSplash();
                    Signal(Id + "-show");
                    return 0;
                }
                try { Application.EnableVisualStyles(); } catch { }
                try { Application.SetCompatibleTextRenderingDefault(false); } catch { }
                try { Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException); } catch { }
                Application.ThreadException += delegate(object s, ThreadExceptionEventArgs e)
                {
                    Log.Error("Unhandled: " + e.Exception);
                    try { Dialogs.Problem(MainForm.Instance, L.T("oops"), e.Exception.Message); } catch { }
                };
                AppDomain.CurrentDomain.UnhandledException += delegate(object s, UnhandledExceptionEventArgs e) { Log.Error("Fatal: " + e.ExceptionObject); };
                Log.Info("SwitchDeck " + Version + " started");

                using (EventWaitHandle show = new EventWaitHandle(false, EventResetMode.AutoReset, Id + "-show"))
                using (EventWaitHandle exit = new EventWaitHandle(false, EventResetMode.AutoReset, Id + "-exit"))
                {
                    if (Install.NeedsWelcome)
                    {
                        string launched = null;
                        using (WelcomeForm w = new WelcomeForm())
                        {
                            CloseSplash();
                            w.ShowDialog();
                            launched = w.InstalledScript;
                        }
                        if (launched != null)
                        {
                            mutex.ReleaseMutex();
                            Install.Launch(launched);
                            return 0;
                        }
                    }
                    else Install.Refresh();
                    MainForm form = new MainForm(0);
                    form.Shown += delegate { CloseSplash(); };
                    Thread watcher = new Thread(delegate()
                    {
                        try
                        {
                            WaitHandle[] handles = { show, exit };
                            while (true)
                            {
                                int i = WaitHandle.WaitAny(handles);
                                if (form.IsDisposed) return;
                                if (i == 0) form.BeginInvoke((Action)delegate
                                {
                                    if (form.WindowState == FormWindowState.Minimized) form.WindowState = FormWindowState.Normal;
                                    form.Activate();
                                    Native.SetForegroundWindow(form.Handle);
                                });
                                else { form.BeginInvoke((Action)delegate { Program.Rendering = true; form.Close(); }); return; }
                            }
                        }
                        catch { }
                    });
                    watcher.IsBackground = true;
                    watcher.Start();
                    Application.Run(form);
                }
                Finish(Uninstalling);
                try { mutex.ReleaseMutex(); } catch { }
            }
            return 0;
        }

        private static int DemoShell(List<string> a)
        {
            Store.Settings = new Settings();
            int mi = a.IndexOf("--model");
            string model = mi >= 0 && mi + 1 < a.Count ? a[mi + 1] : "C9300-48P";
            DemoSwitch d = new DemoSwitch("shell-" + model, model, "cisco");
            Stream stdout = Console.OpenStandardOutput();
            object gate = new object();
            d.Output = delegate(string s)
            {
                byte[] b = Encoding.ASCII.GetBytes(s);
                lock (gate) { stdout.Write(b, 0, b.Length); stdout.Flush(); }
            };
            bool quit = false;
            d.Quit = delegate { quit = true; };
            d.Boot();
            Stream stdin = Console.OpenStandardInput();
            byte[] buf = new byte[1024];
            while (!quit)
            {
                int n = stdin.Read(buf, 0, buf.Length);
                if (n <= 0) break;
                for (int i = 0; i < n && !quit; i++) d.Key((char)buf[i]);
            }
            return 0;
        }

        private static void Signal(string name)
        {
            try { Native.AllowSetForegroundWindow(-1); } catch { }
            try
            {
                using (EventWaitHandle ev = EventWaitHandle.OpenExisting(name)) ev.Set();
            }
            catch { }
        }
    }

    internal static class Log
    {
        private static readonly object gate = new object();

        public static void Info(string message) { Write("INFO", message); }
        public static void Warn(string message) { Write("WARN", message); }
        public static void Error(string message) { Write("ERROR", message); }

        private static void Write(string level, string message)
        {
            try
            {
                lock (gate)
                {
                    if (Program.Root == null) return;
                    Directory.CreateDirectory(Program.LogsDir);
                    string path = Path.Combine(Program.LogsDir, "SwitchDeck.log");
                    FileInfo fi = new FileInfo(path);
                    if (fi.Exists && fi.Length > 2 * 1024 * 1024)
                    {
                        File.Copy(path, Path.Combine(Program.LogsDir, "SwitchDeck.old.log"), true);
                        File.Delete(path);
                    }
                    File.AppendAllText(path, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") + " " + level + " " + message + Environment.NewLine, Encoding.UTF8);
                }
            }
            catch { }
        }
    }

    internal static class Samples
    {
        public static void AddHosts()
        {
            Host a = new Host();
            a.Name = "Lab Core 9300";
            a.Kind = "demo";
            a.DemoModel = "C9300-48P";
            a.Password = Secret.Protect("cisco");
            Store.Hosts.Add(a);
            Host b = new Host();
            b.Name = "Lab Floor 2960X";
            b.Kind = "demo";
            b.DemoModel = "WS-C2960X-24PS-L";
            b.Password = Secret.Protect("cisco");
            Store.Hosts.Add(b);
            AddC9200();
        }

        public static void AddC9200()
        {
            Host a = new Host();
            a.Name = "Lab Access 9200L";
            a.Kind = "demo";
            a.DemoModel = "C9200L-48P-4X";
            a.Password = Secret.Protect("cisco");
            Store.Hosts.Add(a);
            Host b = new Host();
            b.Name = "Lab Stack 9200L";
            b.Kind = "demo";
            b.DemoModel = "C9200L-48P-4X-STACK";
            b.Password = Secret.Protect("cisco");
            Store.Hosts.Add(b);
        }

        public static void AddTemplates()
        {
            Add("Wifi-Hotspot", L.T("sampleWifi"), 0, "wifi",
                "description {{description}}\nswitchport mode trunk\nswitchport trunk allowed vlan {{vlan}}\nspanning-tree portfast trunk\nno shutdown",
                new[] { "description", "Wifi-Hotspot", "vlan", "2" }, false);
            Add("Office PC", L.T("sampleOffice"), 1, "computer",
                "description {{description}}\nswitchport mode access\nswitchport access vlan {{vlan}}\nspanning-tree portfast\nspanning-tree bpduguard enable\nno shutdown",
                new[] { "description", "Office-PC", "vlan", "10" }, true);
            Add("IP Phone + PC", L.T("samplePhone"), 2, "call",
                "description {{description}}\nswitchport mode access\nswitchport access vlan {{data_vlan}}\nswitchport voice vlan {{voice_vlan}}\nspanning-tree portfast\nno shutdown",
                new[] { "description", "Phone-PC", "data_vlan", "10", "voice_vlan", "20" }, true);
            Add("Printer", L.T("samplePrinter"), 3, "print",
                "description Printer {{port}}\nswitchport mode access\nswitchport access vlan {{vlan}}\nspanning-tree portfast\nno shutdown",
                new[] { "vlan", "30" }, true);
            Add("Unused port", L.T("sampleUnused"), 7, "power_off",
                "! Parks the port in an unused VLAN and shuts it down\ndescription Unused\nswitchport mode access\nswitchport access vlan {{vlan}}\nshutdown",
                new[] { "vlan", "999" }, true);
        }

        private static void Add(string name, string desc, int color, string icon, string body, string[] defaults, bool reset)
        {
            Template t = new Template();
            t.Name = name;
            t.Description = desc;
            t.Color = color;
            t.Icon = icon;
            t.Body = body;
            t.ResetFirst = reset;
            for (int i = 0; i + 1 < defaults.Length; i += 2) t.Defaults[defaults[i]] = defaults[i + 1];
            Store.Templates.Add(t);
        }
    }
}
