using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

namespace SwitchDeck
{
    internal sealed class DeployPlan
    {
        public Host Host;
        public string TemplateName = "";
        public string Mode = "range";
        public bool Reset, Backup, Check, Verify, WriteMemory;
        public string Kind = "deploy";
        public readonly List<string> Ports = new List<string>();
        public readonly Dictionary<string, List<string>> Lines = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);

        public static DeployPlan FromTemplate(Host host, Template t, Dictionary<string, string> values, IEnumerable<string> ports, string mode)
        {
            DeployPlan p = new DeployPlan();
            p.Host = host;
            p.TemplateName = t.Name;
            p.Mode = mode;
            p.Reset = t.ResetFirst;
            foreach (string port in SwitchDeck.Ports.Sorted(ports))
            {
                List<string> lines = new List<string>();
                foreach (string l in t.Lines) lines.Add(Cisco.Render(l, values, port));
                p.Ports.Add(port);
                p.Lines[port] = lines;
            }
            return p;
        }

        public List<KeyValuePair<List<string>, List<string>>> Groups()
        {
            List<KeyValuePair<List<string>, List<string>>> groups = new List<KeyValuePair<List<string>, List<string>>>();
            if (Mode != "range")
            {
                foreach (string port in Ports) groups.Add(new KeyValuePair<List<string>, List<string>>(new List<string> { port }, Lines[port]));
                return groups;
            }
            foreach (string port in Ports)
            {
                List<string> lines = Lines[port];
                string key = string.Join("\n", lines.ToArray());
                bool added = false;
                foreach (KeyValuePair<List<string>, List<string>> g in groups)
                {
                    if (string.Join("\n", g.Value.ToArray()) == key) { g.Key.Add(port); added = true; break; }
                }
                if (!added) groups.Add(new KeyValuePair<List<string>, List<string>>(new List<string> { port }, lines));
            }
            return groups;
        }

        public List<KeyValuePair<string, List<string>>> Blocks()
        {
            List<KeyValuePair<string, List<string>>> blocks = new List<KeyValuePair<string, List<string>>>();
            foreach (KeyValuePair<List<string>, List<string>> g in Groups())
            {
                if (Mode == "range")
                {
                    foreach (string spec in SwitchDeck.Ports.RangeCommands(g.Key))
                        blocks.Add(new KeyValuePair<string, List<string>>("range " + spec, g.Value));
                }
                else blocks.Add(new KeyValuePair<string, List<string>>(g.Key[0], g.Value));
            }
            return blocks;
        }

        public List<string> Script()
        {
            List<string> s = new List<string>();
            s.Add("configure terminal");
            foreach (KeyValuePair<string, List<string>> b in Blocks())
            {
                if (Reset) s.Add("default interface " + b.Key);
                s.Add("interface " + b.Key);
                foreach (string l in b.Value) s.Add(" " + l);
                s.Add(" exit");
            }
            s.Add("end");
            if (WriteMemory) s.Add("write memory");
            return s;
        }

        public static List<string> BlockPorts(string block)
        {
            if (!block.StartsWith("range ")) return new List<string> { block };
            return SwitchDeck.Ports.Expand(block.Substring(6).Replace(" - ", "-").Replace(" , ", ","), null);
        }
    }

    internal sealed class Deployer
    {
        private readonly Session s;
        private readonly DeployPlan plan;
        public readonly HistoryEntry Entry = new HistoryEntry();
        public event Action<string> Step;
        public event Action<PortResult> PortChanged;

        public Deployer(Session session, DeployPlan plan)
        {
            s = session;
            this.plan = plan;
            Entry.HostId = plan.Host.Id;
            Entry.HostName = plan.Host.Name;
            Entry.TemplateName = plan.TemplateName;
            Entry.Mode = plan.Mode;
            Entry.Kind = plan.Kind;
            Entry.Commands = string.Join("\n", plan.Script().ToArray());
            foreach (string p in plan.Ports)
            {
                PortResult r = new PortResult();
                r.Port = p;
                Entry.Results.Add(r);
            }
        }

        private PortResult Result(string port)
        {
            foreach (PortResult r in Entry.Results) if (string.Equals(r.Port, port, StringComparison.OrdinalIgnoreCase)) return r;
            return null;
        }

        private void Say(string text)
        {
            s.SetStatus(text);
            Action<string> h = Step;
            if (h != null) h(text);
        }

        private void Mark(string port, string status, string message)
        {
            PortResult r = Result(port);
            if (r == null) return;
            r.Status = status;
            if (message != null) r.Message = message;
            Action<PortResult> h = PortChanged;
            if (h != null) h(r);
        }

        private static string LongName(string port)
        {
            PortName p = Ports.Parse(port);
            return p == null ? port : p.Long;
        }

        public void Run()
        {
            s.BeginBusy(L.T("deploying"));
            s.BeginTranscript();
            bool inConfig = false;
            try
            {
                Say(L.T("stepReady"));
                s.WaitReady(s.State == SessionState.Connected ? 20000 : 120000);
                s.Prepare();
                s.EnsureEnable();

                if (plan.Backup)
                {
                    Say(L.T("stepBackup"));
                    string cfg = s.Run("show running-config", 90000);
                    Entry.Backup = SaveBackup(cfg);
                }
                if (plan.Check || plan.Kind == "rollback")
                {
                    int i = 0;
                    foreach (string p in plan.Ports)
                    {
                        Say(L.F("stepRead", p, ++i, plan.Ports.Count));
                        Result(p).Before = Cisco.InterfaceBody(s.Run("show running-config interface " + LongName(p), 20000));
                    }
                }

                Say(L.T("stepConfig"));
                string o = s.Run("configure terminal", 10000);
                if (!s.CursorLine.Contains("(config")) throw new InvalidOperationException(Cisco.FirstError(o) ?? L.T("noConfigMode"));
                inConfig = true;

                List<KeyValuePair<string, List<string>>> blocks = plan.Blocks();
                int n = 0;
                foreach (KeyValuePair<string, List<string>> b in blocks)
                {
                    n++;
                    List<string> ports = DeployPlan.BlockPorts(b.Key);
                    foreach (string p in ports) Mark(p, "running", null);
                    Say(plan.Mode == "range" ? L.F("stepRange", Ports.Compact(ports), n, blocks.Count) : L.F("stepPort", b.Key, n, blocks.Count));
                    string error = null;
                    if (plan.Reset)
                    {
                        string r = s.Run("default interface " + b.Key, 20000);
                        error = Cisco.FirstError(r);
                    }
                    if (error == null)
                    {
                        string r = s.Run("interface " + b.Key, 10000);
                        error = Cisco.FirstError(r);
                        if (error == null && !s.CursorLine.Contains("(config-if")) error = L.T("noIfMode");
                    }
                    List<string> lineErrors = new List<string>();
                    if (error == null)
                    {
                        foreach (string line in b.Value)
                        {
                            string r = s.Run(line, 15000);
                            string e = Cisco.FirstError(r);
                            if (e != null) lineErrors.Add(line + ": " + e);
                        }
                        s.Run("exit", 5000);
                    }
                    foreach (string p in ports)
                    {
                        if (error != null) Mark(p, "failed", error);
                        else if (lineErrors.Count > 0) Mark(p, "failed", string.Join("\n", lineErrors.ToArray()));
                        else Mark(p, "applied", "");
                    }
                }
                Say(L.T("stepEnd"));
                s.Run("end", 10000);
                inConfig = false;

                if (plan.Verify)
                {
                    int i = 0;
                    foreach (string p in plan.Ports)
                    {
                        PortResult r = Result(p);
                        Say(L.F("stepVerify", p, ++i, plan.Ports.Count));
                        r.After = Cisco.InterfaceBody(s.Run("show running-config interface " + LongName(p), 20000));
                        if (r.Status == "failed") continue;
                        string missing = Cisco.CheckApplied(plan.Lines[p], r.After);
                        if (missing == null) Mark(p, "ok", "");
                        else Mark(p, "warn", L.T("notVisible") + "\n" + missing);
                    }
                }
                else foreach (PortResult r in Entry.Results) if (r.Status == "applied") Mark(r.Port, "ok", "");

                if (plan.WriteMemory)
                {
                    Say(L.T("stepWrite"));
                    string w = s.Run("write memory", 120000, true);
                    Entry.WroteMemory = w.Contains("[OK]");
                    if (!Entry.WroteMemory) Entry.Summary = L.T("writeFailed") + " " + (Cisco.FirstError(w) ?? "");
                }
            }
            catch (StopException)
            {
                Entry.Stopped = true;
                Entry.Summary = L.T("stopped");
                SafeExit(inConfig);
            }
            catch (Exception ex)
            {
                Entry.Summary = ex.Message;
                Log.Error("Deploy on " + plan.Host.Name + ": " + ex.Message);
                SafeExit(inConfig);
            }
            finally
            {
                foreach (PortResult r in Entry.Results)
                {
                    if (r.Status == "pending" || r.Status == "running") Mark(r.Port, "skipped", Entry.Stopped ? L.T("stopped") : Entry.Summary);
                    else if (r.Status == "applied") Mark(r.Port, "ok", "");
                }
                Entry.Transcript = s.EndTranscript();
                Entry.Time = DateTime.Now;
                s.EndBusy();
                Log.Info("Deploy " + Entry.TemplateName + " on " + Entry.HostName + ": " + Entry.Overall + " (" + plan.Ports.Count + " ports)");
            }
        }

        private void SafeExit(bool inConfig)
        {
            if (!inConfig) return;
            try
            {
                s.RawSend("\x1a");
                System.Threading.Thread.Sleep(300);
            }
            catch { }
        }

        private string SaveBackup(string cfg)
        {
            try
            {
                string dir = Path.Combine(Path.Combine(Program.DataDir, "backups"), Store.SafeName(plan.Host.Name));
                Directory.CreateDirectory(dir);
                string file = Path.Combine(dir, DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss", CultureInfo.InvariantCulture) + ".cfg");
                File.WriteAllText(file, cfg.Replace("\n", "\r\n"), new UTF8Encoding(false));
                return file;
            }
            catch (Exception ex)
            {
                Log.Warn("Backup: " + ex.Message);
                return "";
            }
        }

        public static List<PortStatus> Detect(Session s)
        {
            s.BeginBusy(L.T("detecting"));
            try
            {
                s.WaitReady(s.State == SessionState.Connected ? 20000 : 120000);
                s.Prepare();
                string o = s.Run("show interfaces status", 30000);
                List<PortStatus> list = Cisco.ParseStatus(o);
                if (list.Count == 0) throw new InvalidOperationException(Cisco.FirstError(o) ?? L.T("noPortsFound"));
                return list;
            }
            finally { s.EndBusy(); }
        }

        public static DeployPlan RollbackPlan(HistoryEntry e, Host host)
        {
            DeployPlan p = new DeployPlan();
            p.Host = host;
            p.Kind = "rollback";
            p.TemplateName = L.F("rollbackOf", e.TemplateName);
            p.Mode = "single";
            p.Reset = true;
            p.Verify = true;
            foreach (PortResult r in e.Results)
            {
                if (r.Status == "skipped") continue;
                List<string> lines = new List<string>();
                foreach (string l in Cisco.SplitLines(r.Before)) if (l.Trim().Length > 0) lines.Add(l.Trim());
                p.Ports.Add(r.Port);
                p.Lines[r.Port] = lines;
            }
            return p;
        }
    }
}
