using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal static class SelfTest
    {
        private static int failed, passed;

        private static void Ok(bool cond, string name)
        {
            if (cond) passed++;
            else { failed++; Console.WriteLine("FAIL " + name); }
        }

        private static void Eq(object a, object b, string name)
        {
            bool same = Equals(a, b) || (a != null && b != null && a.ToString() == b.ToString());
            if (!same) Console.WriteLine("     expected [" + b + "] got [" + a + "]");
            Ok(same, name);
        }

        public static int SshTest(int port)
        {
            string home = Path.Combine(Path.GetTempPath(), "switchdeck-sshtest-" + Guid.NewGuid().ToString("N").Substring(0, 8));
            Program.Root = home;
            Store.Settings = new Settings();
            Store.Settings.SessionLogs = true;
            L.Lang = "en";
            try
            {
                Host h = new Host();
                h.Name = "ssh-lab";
                h.Kind = "ssh";
                h.Address = "127.0.0.1";
                h.Port = port;
                h.Username = "admin";
                h.Password = Secret.Protect("lab123");
                h.Enable = Secret.Protect("cisco");
                h.Legacy = true;
                Console.WriteLine("args: " + Ssh.Arguments(h));
                h.Legacy = false;
                int prompts = 0;
                Session s = new Session(h, 120, 30);
                s.HostKeyPrompt += delegate(string fp) { prompts++; Console.WriteLine("host key prompt: " + fp); s.AnswerHostKey(true); };
                s.Notice += delegate(string n) { Console.WriteLine("notice: " + n); };
                DateTime t0 = DateTime.Now;
                s.Start();
                try { s.WaitReady(60000); }
                catch
                {
                    Console.WriteLine("SCREEN [" + s.Term.Text(s.Term.FirstAbs, s.Term.EndAbs).TrimEnd() + "]");
                    Console.WriteLine("cursor line [" + s.CursorLine + "] col " + s.Term.CursorCol + " state " + s.State + " open " + s.IsOpen);
                    throw;
                }
                Console.WriteLine("ready in " + (int)(DateTime.Now - t0).TotalMilliseconds + " ms, prompt [" + s.CursorLine + "]");
                Ok(prompts == 1, "ssh host key asked once");
                Ok(s.CursorLine.EndsWith("#"), "ssh auto enable");
                List<PortStatus> found = Deployer.Detect(s);
                Eq(found.Count, 56, "ssh detect");
                foreach (PortStatus p in found) h.Ports.Add(new PortInfo(p.Port, p.Name));
                Template t = new Template();
                t.Name = "Office";
                t.Body = "description {{d}}\nswitchport mode access\nswitchport access vlan 10\nno shutdown";
                Dictionary<string, string> v = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                v["d"] = "Desk over ssh";
                DeployPlan plan = DeployPlan.FromTemplate(h, t, v, Ports.Expand("Gi1/0/30-36, Gi1/0/40", null), "range");
                plan.Check = true; plan.Verify = true; plan.Backup = true; plan.Reset = true;
                Deployer d = new Deployer(s, plan);
                d.Run();
                Console.WriteLine("deploy: " + d.Entry.Overall + " " + d.Entry.Summary);
                foreach (PortResult r in d.Entry.Results) if (r.Status != "ok") Console.WriteLine("  " + r.Port + " " + r.Status + " " + r.Message);
                Eq(d.Entry.Overall, "ok", "ssh deploy");
                string big = s.Run("show running-config", 30000);
                Ok(big.Contains("interface GigabitEthernet1/0/30") && big.Contains("Desk over ssh"), "ssh long output");
                s.Disconnect();
                Thread.Sleep(500);
                Session s2 = new Session(h, 120, 30);
                int prompts2 = 0;
                s2.HostKeyPrompt += delegate(string fp) { prompts2++; s2.AnswerHostKey(true); };
                s2.Start();
                s2.WaitReady(60000);
                Ok(prompts2 == 0, "ssh known host remembered");
                s2.Dispose();
                Host bad = h.Clone();
                bad.Password = Secret.Protect("wrong");
                Session s3 = new Session(bad, 120, 30);
                bool rejected = false;
                s3.Notice += delegate(string n) { if (n == "password-rejected") rejected = true; };
                s3.Start();
                DateTime end = DateTime.Now.AddSeconds(25);
                while (!rejected && DateTime.Now < end) Thread.Sleep(100);
                Ok(rejected, "ssh wrong password noticed");
                Console.WriteLine("tail: " + s3.Term.Text(s3.Term.CursorAbs - 3, s3.Term.CursorAbs + 1).Replace("\n", " | "));
                s3.Dispose();
            }
            catch (Exception ex)
            {
                failed++;
                Console.WriteLine("CRASH " + ex);
            }
            Console.WriteLine("passed " + passed + ", failed " + failed);
            return failed == 0 ? 0 : 1;
        }

        public static int Run()
        {
            string home = Path.Combine(Path.GetTempPath(), "switchdeck-selftest-" + Guid.NewGuid().ToString("N").Substring(0, 8));
            Program.Root = home;
            Store.Settings = new Settings();
            Store.Settings.SessionLogs = false;
            L.Lang = "en";
            try
            {
                TestPorts();
                TestCisco();
                TestVt();
                TestDemo();
                TestJson();
                TestDeploy();
                TestStack();
                TestInstall();
            }
            catch (Exception ex)
            {
                failed++;
                Console.WriteLine("CRASH " + ex);
            }
            Console.WriteLine("passed " + passed + ", failed " + failed);
            try { Directory.Delete(home, true); } catch { }
            return failed == 0 ? 0 : 1;
        }

        private static void TestPorts()
        {
            List<string> err = new List<string>();
            List<string> p = Ports.Expand("Gi1/0/1-4, Te1/1/1, 6, gigabitethernet2/0/10 - 11, po1, Fa0", err);
            Eq(string.Join(" ", p.ToArray()), "Gi1/0/1 Gi1/0/2 Gi1/0/3 Gi1/0/4 Te1/1/1 Te1/1/6 Gi2/0/10 Gi2/0/11 Po1 Fa0", "expand");
            Eq(err.Count, 0, "expand errors");
            Ports.Expand("Gi1/0/9-3, Zz1, Gi1/0/1-Te1/0/4", err);
            Eq(err.Count, 3, "expand bad");
            Eq(Ports.Expand("Gi1/0/1-4, 6-7", null).Count, 6, "prefix shorthand");
            Eq(Ports.Expand("Gi1/0/1-4, 6-7", null)[5], "Gi1/0/7", "prefix shorthand name");
            Eq(Ports.Normalize("TenGigabitEthernet1/1/2"), "Te1/1/2", "normalize long");
            Eq(Ports.Normalize("g1/0/3"), "Gi1/0/3", "normalize short");
            Eq(Ports.Normalize("Twe1/1/1"), "Twe1/1/1", "twe");
            Eq(Ports.Normalize("t1/1/1"), null, "ambiguous t");
            List<string> names = new List<string>();
            foreach (int i in new[] { 1, 2, 3, 5, 7, 8, 9, 11, 13, 15, 17 }) names.Add("Gi1/0/" + i);
            List<string> cmds = Ports.RangeCommands(names);
            Eq(cmds.Count, 2, "range chunks");
            Eq(cmds[0], "Gi1/0/1 - 3 , Gi1/0/5 , Gi1/0/7 - 9 , Gi1/0/11 , Gi1/0/13", "range text");
            Eq(Ports.Compact(new[] { "Gi1/0/2", "Gi1/0/1", "Te1/1/1", "Gi1/0/3" }), "Gi1/0/1-3, Te1/1/1", "compact");
            Eq(string.Join(",", Ports.Sorted(new[] { "Te1/1/1", "Gi2/0/1", "Gi1/0/10", "Gi1/0/2" }).ToArray()), "Gi1/0/2,Gi1/0/10,Te1/1/1,Gi2/0/1", "sort");
            Ok(Ports.IsVirtual("Vl10") && Ports.IsVirtual("Vlan1") && Ports.IsVirtual("Lo0") && !Ports.IsVirtual("Gi1/0/1") && !Ports.IsVirtual("Po1"), "virtual");
        }

        private static void TestCisco()
        {
            string status = "\nPort         Name               Status       Vlan       Duplex  Speed Type\n" +
                "Gi1/0/1      AP-Hall-01         connected    trunk      a-full a-1000 10/100/1000BaseTX\n" +
                "Gi1/0/2                         notconnect   1            auto   auto 10/100/1000BaseTX\n" +
                "Gi1/0/3      Desk with spaces   err-disabled 10           auto   auto 10/100/1000BaseTX\n" +
                "Te1/1/1                         notconnect   1            full    10G Not Present\n" +
                "Vl1                             connected    routed       auto   auto\n" +
                "Po1          Uplink             connected    trunk      a-full a-10G \n";
            List<PortStatus> l = Cisco.ParseStatus(status);
            Eq(l.Count, 5, "status count");
            Eq(l[0].Name, "AP-Hall-01", "status desc");
            Eq(l[0].Vlan, "trunk", "status vlan");
            Eq(l[2].Name, "Desk with spaces", "status spaces");
            Eq(l[2].Status, "err-disabled", "status err");
            Eq(l[4].Port, "Po1", "status po");
            Ok(Cisco.IsPrompt("SW-CORE-01#") && Cisco.IsPrompt("sw1(config-if-range)#") && Cisco.IsPrompt("Switch>") && !Cisco.IsPrompt("Password:"), "prompt");
            Eq(Cisco.Mode("sw1(config-if)#"), "config-if", "mode");
            Ok(Cisco.IsError("% Invalid input detected at '^' marker."), "error");
            List<string> vars = Cisco.Variables("description {{description}}\nswitchport access vlan {{ vlan }}\ndescription {{port}} {{vlan}}");
            Eq(string.Join(",", vars.ToArray()), "description,vlan", "variables");
            Dictionary<string, string> vals = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            vals["vlan"] = "20";
            Eq(Cisco.Render("switchport access vlan {{vlan}} {{port}}", vals, "Gi1/0/1"), "switchport access vlan 20 Gi1/0/1", "render");
            string body = Cisco.InterfaceBody("Building configuration...\n\nCurrent configuration : 105 bytes\n!\ninterface GigabitEthernet1/0/1\n description AP\n switchport mode trunk\nend\n");
            Eq(body, "description AP\nswitchport mode trunk", "interface body");
            Eq(Cisco.CheckApplied(new List<string> { "description AP", "switchport mode trunk", "no shutdown" }, body), null, "check ok");
            Ok(Cisco.CheckApplied(new List<string> { "switchport mode access" }, body) != null, "check missing");
        }

        private static void TestVt()
        {
            Vt vt = new Vt(20, 5);
            vt.Feed("hello\r\nworld");
            Eq(vt.LineText(vt.FirstAbs), "hello", "vt line");
            Eq(vt.CursorLineText(), "world", "vt cursor line");
            vt.Feed("\x1b[1;1Hxy\x1b[K");
            Eq(vt.LineText(vt.FirstAbs), "xy", "vt cup erase");
            vt.Feed("\x1b[5;1H" + new string('a', 25));
            Eq(vt.Text(vt.CursorAbs - 1, vt.CursorAbs + 1).TrimEnd('\n'), new string('a', 25), "vt wrap join");
            for (int i = 0; i < 30; i++) vt.Feed("\r\nline" + i);
            Ok(vt.EndAbs - vt.FirstAbs > 20, "vt scrollback");
            Eq(vt.CursorLineText(), "line29", "vt scrolled");
            vt.Feed("\x1b[31mred\x1b[0m");
            TermLine tl = vt.LineAt(vt.CursorAbs);
            Eq(tl.Cells[6].Fg, (byte)1, "vt sgr");
            vt.Feed("\b\b\b   \b\b\b");
            Eq(vt.CursorLineText(), "line29", "vt backspace");
            vt.Resize(40, 8);
            Eq(vt.CursorLineText(), "line29", "vt resize keeps cursor line");
        }

        private static void TestStack()
        {
            Session s = DemoSession("C9200L-48P-4X-STACK");
            List<PortStatus> found = Deployer.Detect(s);
            Eq(found.Count, 104, "stack detect");
            Ok(found.Exists(delegate(PortStatus p) { return p.Port == "Gi2/0/48"; }) && found.Exists(delegate(PortStatus p) { return p.Port == "Te2/1/4"; }), "stack member 2 ports");
            string v = s.Run("show version", 10000);
            Ok(v.Contains("C9200L-48P-4X") && !v.Contains("4X-STACK") && v.Contains("     2 "), "stack show version");
            Template t = new Template();
            t.Name = "x";
            t.Body = "description Stack test\nswitchport access vlan 10";
            DeployPlan plan = DeployPlan.FromTemplate(s.Host, t, null, Ports.Expand("Gi1/0/1-3, Gi2/0/1-3, Gi2/0/10", null), "range");
            plan.Verify = true;
            Deployer d = new Deployer(s, plan);
            d.Run();
            Eq(d.Entry.Overall, "ok", "stack range deploy");
            s.Dispose();
            Session one = DemoSession("C9200L-48P-4X");
            Eq(Deployer.Detect(one).Count, 52, "9200L single detect");
            one.Dispose();
        }

        private static void TestInstall()
        {
            string dir = Path.Combine(Program.Root, "install-test");
            Directory.CreateDirectory(dir);
            string ico = Path.Combine(dir, "t.ico");
            Install.WriteIcon(ico);
            using (Icon i = new Icon(ico, 48, 48)) Eq(i.Width, 48, "ico 48");
            Program.Script = @"C:\Test Folder\app\SwitchDeck.ps1";
            Program.AppRoot = @"C:\Test Folder";
            string lnk = Path.Combine(dir, "t.lnk");
            typeof(Install).GetMethod("Create", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static).Invoke(null, new object[] { lnk, Program.Script, Program.AppRoot });
            Ok(File.Exists(lnk), "shortcut created");
            Type t = Type.GetTypeFromProgID("WScript.Shell");
            object shell = Activator.CreateInstance(t);
            object sc = t.InvokeMember("CreateShortcut", System.Reflection.BindingFlags.InvokeMethod, null, shell, new object[] { lnk });
            string target = (string)sc.GetType().InvokeMember("TargetPath", System.Reflection.BindingFlags.GetProperty, null, sc, null);
            string args = (string)sc.GetType().InvokeMember("Arguments", System.Reflection.BindingFlags.GetProperty, null, sc, null);
            Ok(target.ToLowerInvariant().EndsWith("conhost.exe") && args.Contains("--headless") && args.Contains("SwitchDeck.ps1"), "shortcut target");
        }

        private static void TestDemo()
        {
            DemoSwitch d = new DemoSwitch("t1", "C9300-48P", "cisco");
            d.BootSilently();
            string o = d.RunScript("conf t\rint range gi1/0/5 - 8 , gi1/0/10\rsw mo acc\rswitchport access vlan 30\rdesc Test port\rshut\rend\rterm len 0\rsh run int gi1/0/6\r");
            Ok(o.Contains(" switchport access vlan 30") && o.Contains(" description Test port") && o.Contains(" shutdown"), "demo range config");
            o = d.RunScript("conf t\rint gi1/0/6\rno shut\rno desc\rend\rsh run int gi1/0/6\r");
            Ok(!o.Contains(" shutdown") && !o.Contains("description"), "demo negation");
            o = d.RunScript("conf t\rint gi1/0/6\rswitchport mode trunkk\rend\r");
            Ok(o.Contains("% Invalid input"), "demo invalid");
            o = d.RunScript("conf t\rint gi1/0/6\rsw\rend\r");
            Ok(!o.Contains("%"), "demo bare switchport");
            o = d.RunScript("sh int status\r");
            Eq(Cisco.ParseStatus(o).Count, 56, "demo status ports");
            o = d.RunScript("conf t\rint range gi1/0/1-2,gi1/0/4,gi1/0/6,gi1/0/8,gi1/0/10,gi1/0/12\rend\r");
            Ok(o.Contains("Command rejected"), "demo range limit");
            o = d.RunScript("conf t\rint gi1/0/20\rswitchport trunk allowed vlan 2,4-6\rswitchport trunk allowed vlan add 10\rswitchport trunk allowed vlan remove 5\rdo sh run int gi1/0/20\rend\r");
            Ok(o.Contains("switchport trunk allowed vlan 2,4,6,10"), "demo allowed vlan");
            d = new DemoSwitch("t2", "WS-C2960X-24PS-L", "");
            d.BootSilently();
            o = d.RunScript("term len 0\rsh int status\r");
            List<PortStatus> l = Cisco.ParseStatus(o);
            Eq(l.Count, 29, "2960 status ports");
            Ok(l.Exists(delegate(PortStatus s) { return s.Port == "Fa0"; }), "2960 Fa0");
        }

        private static void TestJson()
        {
            Host h = new Host();
            h.Name = "a\"b\\c\nd";
            h.Ports.Add(new PortInfo("Gi1/0/1", "é desc"));
            Host back = Host.FromJson(Json.ParseObj(Json.Write(h.ToJson())));
            Eq(back.Name, h.Name, "json escape");
            Eq(back.Ports[0].Description, "é desc", "json unicode");
            Template t = new Template();
            t.Defaults["vlan"] = "2";
            Eq(Template.FromJson(Json.ParseObj(Json.Write(t.ToJson()))).Defaults["vlan"], "2", "json dict");
        }

        private static Session DemoSession(string model)
        {
            Host h = new Host();
            h.Name = "Test " + model;
            h.Kind = "demo";
            h.DemoModel = model;
            h.Enable = Secret.Protect("cisco");
            Session s = new Session(h, 100, 30);
            s.Start();
            s.WaitReady(15000);
            return s;
        }

        private static void TestDeploy()
        {
            Session s = DemoSession("C9300-48P");
            Ok(s.CursorLine.EndsWith("#"), "auto enable");
            List<PortStatus> found = Deployer.Detect(s);
            Eq(found.Count, 56, "detect count");
            Host h = s.Host;
            foreach (PortStatus p in found) h.Ports.Add(new PortInfo(p.Port, p.Name));

            Template t = new Template();
            t.Name = "Wifi-Hotspot";
            t.Body = "description {{description}}\nswitchport mode trunk\nswitchport trunk allowed vlan {{vlan}}\nspanning-tree portfast trunk\nno shutdown";
            Dictionary<string, string> v = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            v["description"] = "Wifi AP";
            v["vlan"] = "2";
            List<string> ports = Ports.Expand("Gi1/0/3-9, Gi1/0/11, Gi1/0/13, Gi1/0/15, Gi1/0/17, Gi1/0/47", null);
            DeployPlan plan = DeployPlan.FromTemplate(h, t, v, ports, "range");
            plan.Backup = true; plan.Check = true; plan.Verify = true; plan.WriteMemory = true;
            Deployer d = new Deployer(s, plan);
            d.Run();
            Eq(d.Entry.Overall, "ok", "range deploy overall");
            Eq(d.Entry.Count("ok"), 12, "range deploy count");
            Ok(d.Entry.WroteMemory, "write memory");
            Ok(File.Exists(d.Entry.Backup), "backup file");
            PortResult r47 = d.Entry.Results.Find(delegate(PortResult r) { return r.Port == "Gi1/0/47"; });
            Ok(r47.Before.Contains("shutdown") && !r47.After.Contains("\nshutdown") && r47.After.Contains("allowed vlan 2"), "before after captured");
            foreach (string line in Cisco.SplitLines(d.Entry.Transcript)) if (line.Contains("interface range")) { Ok(line.Contains(" , "), "range syntax sent"); break; }

            Template pr = new Template();
            pr.Name = "Printer";
            pr.Body = "description Printer {{port}}\nswitchport access vlan 30\nswitchport mode access\nswitchport trunk allowed vlan 99999";
            DeployPlan plan2 = DeployPlan.FromTemplate(h, pr, v, new[] { "Gi1/0/20", "Gi1/0/21" }, "single");
            plan2.Reset = true; plan2.Verify = true;
            Deployer d2 = new Deployer(s, plan2);
            d2.Run();
            Eq(d2.Entry.Count("failed"), 2, "single deploy catches invalid line");
            Ok(d2.Entry.Results[0].Message.Contains("99999"), "single deploy error message");
            Ok(d2.Entry.Results[0].After.Contains("description Printer Gi1/0/20"), "port variable rendered");

            DeployPlan back = Deployer.RollbackPlan(d.Entry, h);
            Deployer d3 = new Deployer(s, back);
            d3.Run();
            Eq(d3.Entry.Overall, "ok", "rollback overall");
            PortResult b47 = d3.Entry.Results.Find(delegate(PortResult r) { return r.Port == "Gi1/0/47"; });
            Ok(b47.After.Contains("shutdown") && b47.After.Contains("vlan 999"), "rollback restored");

            s.BeginBusy("x");
            s.RequestStop();
            bool stopped = false;
            try { s.Run("show version", 5000); } catch (StopException) { stopped = true; }
            s.EndBusy();
            Ok(stopped, "stop request");
            s.Dispose();

            Session s2 = DemoSession("WS-C2960X-24PS-L");
            Ok(s2.CursorLine.EndsWith("#") || s2.CursorLine.EndsWith(">"), "2960 prompt");
            s2.Host.Enable = "";
            List<PortStatus> f2 = Deployer.Detect(s2);
            Eq(f2.Count, 29, "2960 detect");
            string o = s2.Run("show running-config", 20000);
            Ok(o.Contains("hostname SW-FLOOR2") && o.Trim().EndsWith("end"), "long output through pager");
            s2.Dispose();
        }
    }

    internal static class DevRender
    {
        [DllImport("user32.dll")] private static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);

        public static void Run(string dir, List<string> args)
        {
            Directory.CreateDirectory(dir);
            Program.Rendering = true;
            try { Application.EnableVisualStyles(); } catch { }
            try { Application.SetCompatibleTextRenderingDefault(false); } catch { }
            string[] themes = args.Contains("--dark-only") ? new[] { "dark" } : args.Contains("--light-only") ? new[] { "light" } : new[] { "light", "dark" };
            string[] langs = args.Contains("--fr") ? new[] { "en", "fr" } : new[] { "en" };
            int w = 1320, h = 840;
            int wi = args.IndexOf("--size");
            if (wi >= 0 && wi + 2 < args.Count) { w = int.Parse(args[wi + 1]); h = int.Parse(args[wi + 2]); }
            Store.Settings.WindowW = w;
            Store.Settings.WindowH = h;
            Store.Settings.Maximized = false;
            MainForm f = new MainForm(0);
            f.StartPosition = FormStartPosition.Manual;
            f.Location = new Point(-32000 + 10, 10);
            f.ShowInTaskbar = false;
            f.Show();
            f.Size = new Size(Ui.D(w), Ui.D(h));
            Pump(300);
            Host lab = Store.Hosts.Count > 0 ? Store.Hosts[0] : null;
            if (lab != null && args.Contains("--live"))
            {
                f.Switches.Connect(lab);
                WaitFor(delegate { Session s = Sessions.For(lab.Id); return s != null && s.State == SessionState.Connected && s.AtPrompt; }, 15000);
                Pump(800);
                if (args.Contains("--perf"))
                {
                    TerminalView tv = FindTerm(f);
                    Session ps = Sessions.For(lab.Id);
                    System.Diagnostics.Stopwatch sw = System.Diagnostics.Stopwatch.StartNew();
                    for (int i = 0; i < 20; i++) ps.UserSend("show interfaces status\r");
                    Pump(1500);
                    System.Reflection.MethodInfo op = typeof(TerminalView).GetMethod("OnPaint", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
                    using (Bitmap bmp = new Bitmap(tv.Width, tv.Height))
                    using (Graphics gg = Graphics.FromImage(bmp))
                    {
                        sw.Restart();
                        for (int i = 0; i < 30; i++) op.Invoke(tv, new object[] { new PaintEventArgs(gg, new Rectangle(0, 0, tv.Width, tv.Height)) });
                    }
                    Console.WriteLine("TERM size " + tv.Width + "x" + tv.Height + " cols " + ps.Term.Cols + " rows " + ps.Term.Rows);
                    Console.WriteLine("PAINT avg ms " + (sw.ElapsedMilliseconds / 30.0));
                    long start = ps.Term.CursorAbs;
                    sw.Restart();
                    for (int i = 0; i < 60; i++)
                    {
                        Key(tv, 0x0D);
                        DateTime until = DateTime.Now.AddMilliseconds(33);
                        while (DateTime.Now < until) { Application.DoEvents(); Thread.Sleep(1); }
                    }
                    long sentAt = sw.ElapsedMilliseconds;
                    long lagEnd = sentAt;
                    while (ps.Term.CursorAbs - start < 60 && sw.ElapsedMilliseconds < sentAt + 10000) { Application.DoEvents(); Thread.Sleep(1); lagEnd = sw.ElapsedMilliseconds; }
                    Console.WriteLine("ENTER x60 sent in " + sentAt + " ms, all prompts after " + lagEnd + " ms, lines " + (ps.Term.CursorAbs - start));
                }
                if (args.Contains("--typing"))
                {
                    TerminalView tv = FindTerm(f);
                    if (tv != null)
                    {
                        Type("sh vlan br\r", tv);
                        Pump(800);
                        Type("conf t\rint gi1/0/2", tv);
                        Key(tv, 0x09);
                        Type("?", tv);
                        Pump(400);
                        Type("\rdesc Typed by keys\rend\rsh run int gi1/0/2\r", tv);
                        Pump(1200);
                        Shot(f, Path.Combine(dir, "typing.png"));
                        Session ts = Sessions.For(lab.Id);
                        Console.WriteLine("TYPING " + (ts.Term.Text(ts.Term.FirstAbs, ts.Term.EndAbs).Contains("description Typed by keys") ? "OK" : "FAIL"));
                    }
                    else Console.WriteLine("TYPING no terminal");
                }
                if (args.Contains("--scenario"))
                {
                    Session ses = Sessions.For(lab.Id);
                    List<PortStatus> found = null;
                    Thread t = new Thread(delegate() { try { found = Deployer.Detect(ses); } catch (Exception ex) { Log.Error("render detect: " + ex.Message); } });
                    t.Start();
                    while (t.IsAlive) Pump(50);
                    if (found != null)
                    {
                        lab.Ports.Clear();
                        foreach (PortStatus st in found) lab.Ports.Add(new PortInfo(st.Port, st.Name));
                        lab.PortsAsked = true;
                        Store.ReplaceHost(lab);
                    }
                    ses.Run("show version", 5000);
                    Template wifi = Store.Templates.Find(delegate(Template x) { return x.Name == "Wifi-Hotspot"; });
                    f.Deploy.Prepare(lab, Ports.Expand("Gi1/0/3-9, Gi1/0/11-12, Gi1/0/47", null), wifi == null ? null : wifi.Id);
                    f.SelectTab(1);
                    Pump(300);
                    Shot(f, Path.Combine(dir, "scenario-deploy-1-setup.png"));
                    f.Deploy.ShowPortsStep();
                    Pump(300);
                    Shot(f, Path.Combine(dir, "scenario-deploy-2-ports.png"));
                    f.Deploy.Prepare(lab, Ports.Expand("Gi1/0/3-9, Gi1/0/11-12, Gi1/0/47", null), wifi == null ? null : wifi.Id);
                    f.Deploy.ShowPortsStep();
                    Pump(200);
                    f.Deploy.DeployOrStop();
                    Pump(700);
                    Shot(f, Path.Combine(dir, "scenario-deploy-running.png"));
                    WaitFor(delegate { return DeployPage.Run != null && DeployPage.Run.Done; }, 60000);
                    Pump(600);
                    f.SelectTab(0);
                    f.Switches.ShowSessionFor(lab.Id);
                    Pump(400);
                }
            }
            foreach (string theme in themes)
            {
                foreach (string lang in langs)
                {
                    L.Lang = lang;
                    Store.Settings.Language = lang;
                    Theme.Apply(theme, "dark");
                    Pump(200);
                    f.Rebuild();
                    Pump(300);
                    string prefix = Path.Combine(dir, theme + "-" + lang + "-");
                    for (int t = 0; t < 5; t++)
                    {
                        f.SelectTab(t);
                        Pump(350);
                        Shot(f, prefix + t + "-" + new[] { "switches", "deploy", "templates", "settings", "about" }[t] + ".png");
                    }
                    if (lab != null)
                    {
                        f.SelectTab(0);
                        f.Switches.SelectHost(lab.Id);
                        Pump(300);
                        Shot(f, prefix + "0b-overview.png");
                    }
                }
            }
            if (args.Contains("--dialogs"))
            {
                foreach (string theme in themes)
                {
                    Theme.Apply(theme, "dark");
                    L.Lang = "en";
                    f.Rebuild();
                    Pump(200);
                    DialogShot(f, new HostDialog(lab), Path.Combine(dir, theme + "-dlg-host.png"));
                    DialogShot(f, new HostDialog(null), Path.Combine(dir, theme + "-dlg-host-new.png"));
                    if (lab != null) DialogShot(f, new ChoiceForm(lab), Path.Combine(dir, theme + "-dlg-choice.png"));
                    DialogShot(f, new MessageForm("Deploy now?", "Wifi-Hotspot will be applied to 12 ports on Lab Core 9300:\nGi1/0/3-9, Gi1/0/11\n\nSwitchDeck will type 24 commands.", "rocket_launch", Theme.P.Orange, Theme.P.OrangeSoft, false, "Deploy on 12 ports", "Cancel", false), Path.Combine(dir, theme + "-dlg-confirm.png"));
                    StringBuilder cmds = new StringBuilder();
                    cmds.AppendLine("configure terminal");
                    for (int i = 1; i <= 20; i++) { cmds.AppendLine("interface Gi1/0/" + i); cmds.AppendLine(" description Wifi-Hotspot"); cmds.AppendLine(" switchport mode trunk"); cmds.AppendLine(" exit"); }
                    DialogShot(f, new CommandsForm(cmds.ToString().Replace("\r", "")), Path.Combine(dir, theme + "-dlg-commands.png"));
                    DialogShot(f, new WelcomeForm(), Path.Combine(dir, theme + "-dlg-welcome.png"));
                    Host stack = Store.Hosts.Find(delegate(Host x) { return x.DemoModel.EndsWith("-STACK"); });
                    if (stack != null)
                    {
                        stack.Ports.Clear();
                        foreach (DemoIf di in DemoSwitch.Factory(stack.DemoModel).Ifs) stack.Ports.Add(new PortInfo(di.Name, ""));
                        f.SelectTab(1);
                        f.Deploy.Prepare(stack, Ports.Expand("Gi1/0/1-6, Gi2/0/10-14", null), null);
                        f.Deploy.ShowPortsStep();
                        Pump(300);
                        Shot(f, Path.Combine(dir, theme + "-stack-ports.png"));
                    }
                    DialogShot(f, new MessageForm("Could not read the ports", "The switch did not show its prompt in time.", null, Color.Empty, Color.Empty, true, "OK", null, false), Path.Combine(dir, theme + "-dlg-problem.png"));
                }
            }
            Sessions.CloseAll();
            f.Close();
            f.Dispose();
        }

        [DllImport("user32.dll")] private static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, IntPtr l);

        private static List<Control> AllControls(Control c)
        {
            List<Control> r = new List<Control>();
            foreach (Control k in c.Controls) { r.Add(k); r.AddRange(AllControls(k)); }
            return r;
        }

        private static TerminalView FindTerm(Control c)
        {
            foreach (Control k in c.Controls)
            {
                if (k is TerminalView) return (TerminalView)k;
                TerminalView t = FindTerm(k);
                if (t != null) return t;
            }
            return null;
        }

        private static void Type(string text, TerminalView tv)
        {
            foreach (char ch in text)
            {
                if (ch == '\r') { Key(tv, 0x0D); continue; }
                SendMessage(tv.Handle, 0x102, (IntPtr)ch, IntPtr.Zero);
                Pump(15);
            }
        }

        private static void Key(TerminalView tv, int vk)
        {
            tv.Focus();
            Message m = Message.Create(tv.Handle, 0x100, (IntPtr)vk, IntPtr.Zero);
            if (!tv.PreProcessMessage(ref m)) SendMessage(tv.Handle, 0x100, (IntPtr)vk, IntPtr.Zero);
            Pump(30);
        }

        private static void DialogShot(Form owner, Form d, string path)
        {
            d.StartPosition = FormStartPosition.Manual;
            d.Location = new Point(-32000 + 10, 10);
            d.ShowInTaskbar = false;
            d.Show(owner);
            Pump(500);
            d.Refresh();
            using (Bitmap b = new Bitmap(d.Width, d.Height))
            {
                d.DrawToBitmap(b, new Rectangle(0, 0, d.Width, d.Height));
                b.Save(path, ImageFormat.Png);
            }
            d.Close();
            d.Dispose();
        }

        public static void Pump(int ms)
        {
            DateTime end = DateTime.Now.AddMilliseconds(ms);
            while (DateTime.Now < end)
            {
                Application.DoEvents();
                Thread.Sleep(15);
            }
        }

        public static void WaitFor(Func<bool> cond, int ms)
        {
            DateTime end = DateTime.Now.AddMilliseconds(ms);
            while (DateTime.Now < end && !cond()) Pump(50);
        }

        public static void Shot(Form f, string path)
        {
            f.Refresh();
            Pump(120);
            f.Refresh();
            using (Bitmap b = new Bitmap(f.Width, f.Height))
            {
                using (Graphics g = Graphics.FromImage(b))
                {
                    IntPtr hdc = g.GetHdc();
                    bool ok = PrintWindow(f.Handle, hdc, 2);
                    g.ReleaseHdc(hdc);
                    if (!ok) f.DrawToBitmap(b, new Rectangle(0, 0, f.Width, f.Height));
                }
                b.Save(path, ImageFormat.Png);
            }
        }
    }
}
