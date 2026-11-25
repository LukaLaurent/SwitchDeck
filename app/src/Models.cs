using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace SwitchDeck
{
    internal sealed class PortInfo
    {
        public string Name = "";
        public string Description = "";

        public PortInfo() { }
        public PortInfo(string name, string description) { Name = name; Description = description ?? ""; }
    }

    internal sealed class Host
    {
        public string Id = Guid.NewGuid().ToString("N");
        public string Name = "";
        public string Group = "";
        public string Kind = "ssh";
        public string Address = "";
        public int Port = 22;
        public string Username = "";
        public string Password = "";
        public string Enable = "";
        public bool Legacy;
        public string ComPort = "COM1";
        public int Baud = 9600;
        public string DemoModel = "";
        public string Notes = "";
        public List<PortInfo> Ports = new List<PortInfo>();
        public bool PortsAsked;
        public DateTime LastConnected = DateTime.MinValue;

        public string Target
        {
            get
            {
                if (Kind == "serial") return ComPort + " " + Baud.ToString(CultureInfo.InvariantCulture);
                if (Kind == "demo") return L.T("demoTarget");
                return Port == 22 || Port == 0 ? Address : Address + ":" + Port.ToString(CultureInfo.InvariantCulture);
            }
        }

        public JObj ToJson()
        {
            JObj o = new JObj();
            o["id"] = Id; o["name"] = Name; o["group"] = Group; o["kind"] = Kind;
            o["address"] = Address; o["port"] = Port; o["username"] = Username;
            o["password"] = Password; o["enable"] = Enable; o["legacy"] = Legacy;
            o["com"] = ComPort; o["baud"] = Baud; o["demo"] = DemoModel; o["notes"] = Notes;
            o["portsAsked"] = PortsAsked;
            o["lastConnected"] = LastConnected == DateTime.MinValue ? "" : LastConnected.ToString("o", CultureInfo.InvariantCulture);
            List<object> ports = new List<object>();
            foreach (PortInfo p in Ports)
            {
                JObj j = new JObj();
                j["name"] = p.Name;
                j["description"] = p.Description;
                ports.Add(j);
            }
            o["ports"] = ports;
            return o;
        }

        public static Host FromJson(JObj o)
        {
            Host h = new Host();
            h.Id = o.Str("id", h.Id); h.Name = o.Str("name"); h.Group = o.Str("group"); h.Kind = o.Str("kind", "ssh");
            h.Address = o.Str("address"); h.Port = o.Int("port", 22); h.Username = o.Str("username");
            h.Password = o.Str("password"); h.Enable = o.Str("enable"); h.Legacy = o.Bool("legacy", false);
            h.ComPort = o.Str("com", "COM1"); h.Baud = o.Int("baud", 9600); h.DemoModel = o.Str("demo"); h.Notes = o.Str("notes");
            h.PortsAsked = o.Bool("portsAsked", false);
            h.LastConnected = o.Date("lastConnected");
            foreach (JObj p in o.Objs("ports")) h.Ports.Add(new PortInfo(p.Str("name"), p.Str("description")));
            return h;
        }

        public Host Clone()
        {
            return FromJson(Json.ParseObj(Json.Write(ToJson())));
        }

        public PortInfo FindPort(string name)
        {
            foreach (PortInfo p in Ports) if (string.Equals(p.Name, name, StringComparison.OrdinalIgnoreCase)) return p;
            return null;
        }
    }

    internal sealed class Template
    {
        public string Id = Guid.NewGuid().ToString("N");
        public string Name = "";
        public string Description = "";
        public int Color;
        public string Icon = "settings_ethernet";
        public string Body = "";
        public bool ResetFirst;
        public Dictionary<string, string> Defaults = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        public DateTime Modified = DateTime.Now;

        public JObj ToJson()
        {
            JObj o = new JObj();
            o["id"] = Id; o["name"] = Name; o["description"] = Description; o["color"] = Color; o["icon"] = Icon;
            o["body"] = Body; o["resetFirst"] = ResetFirst;
            JObj d = new JObj();
            foreach (KeyValuePair<string, string> kv in Defaults) d[kv.Key] = kv.Value;
            o["defaults"] = d;
            o["modified"] = Modified.ToString("o", CultureInfo.InvariantCulture);
            return o;
        }

        public static Template FromJson(JObj o)
        {
            Template t = new Template();
            t.Id = o.Str("id", t.Id); t.Name = o.Str("name"); t.Description = o.Str("description");
            t.Color = o.Int("color", 0); t.Icon = o.Str("icon", "settings_ethernet"); t.Body = o.Str("body");
            t.ResetFirst = o.Bool("resetFirst", false);
            foreach (KeyValuePair<string, object> kv in o.Obj("defaults")) t.Defaults[kv.Key] = Convert.ToString(kv.Value, CultureInfo.InvariantCulture);
            DateTime m = o.Date("modified");
            if (m != DateTime.MinValue) t.Modified = m;
            return t;
        }

        public Template Clone()
        {
            return FromJson(Json.ParseObj(Json.Write(ToJson())));
        }

        public List<string> Lines
        {
            get
            {
                List<string> r = new List<string>();
                foreach (string raw in Body.Replace("\r", "").Split('\n'))
                {
                    string s = raw.Trim();
                    if (s.Length == 0 || s.StartsWith("!")) continue;
                    r.Add(s);
                }
                return r;
            }
        }
    }

    internal sealed class PortResult
    {
        public string Port = "";
        public string Status = "pending";
        public string Message = "";
        public string Before = "";
        public string After = "";
    }

    internal sealed class HistoryEntry
    {
        public string Id = Guid.NewGuid().ToString("N");
        public DateTime Time = DateTime.Now;
        public string HostId = "", HostName = "", TemplateName = "", Mode = "range", Kind = "deploy";
        public string Commands = "", Transcript = "", Backup = "", Summary = "";
        public bool WroteMemory;
        public bool Stopped;
        public List<PortResult> Results = new List<PortResult>();

        public int Count(string status)
        {
            int n = 0;
            foreach (PortResult r in Results) if (r.Status == status) n++;
            return n;
        }

        public string Overall
        {
            get
            {
                if (Results.Count == 0) return Stopped ? "stopped" : "failed";
                int ok = Count("ok"), warn = Count("warn"), fail = Count("failed");
                if (fail == 0 && warn == 0 && ok == Results.Count) return "ok";
                if (ok == 0 && warn == 0) return "failed";
                return "warn";
            }
        }

        public JObj ToJson()
        {
            JObj o = new JObj();
            o["id"] = Id; o["time"] = Time.ToString("o", CultureInfo.InvariantCulture); o["hostId"] = HostId; o["host"] = HostName;
            o["template"] = TemplateName; o["mode"] = Mode; o["kind"] = Kind; o["commands"] = Commands; o["transcript"] = Transcript;
            o["backup"] = Backup; o["summary"] = Summary; o["wroteMemory"] = WroteMemory; o["stopped"] = Stopped;
            List<object> rs = new List<object>();
            foreach (PortResult r in Results)
            {
                JObj j = new JObj();
                j["port"] = r.Port; j["status"] = r.Status; j["message"] = r.Message; j["before"] = r.Before; j["after"] = r.After;
                rs.Add(j);
            }
            o["results"] = rs;
            return o;
        }

        public static HistoryEntry FromJson(JObj o)
        {
            HistoryEntry h = new HistoryEntry();
            h.Id = o.Str("id", h.Id); h.Time = o.Date("time"); h.HostId = o.Str("hostId"); h.HostName = o.Str("host");
            h.TemplateName = o.Str("template"); h.Mode = o.Str("mode", "range"); h.Kind = o.Str("kind", "deploy");
            h.Commands = o.Str("commands"); h.Transcript = o.Str("transcript"); h.Backup = o.Str("backup"); h.Summary = o.Str("summary");
            h.WroteMemory = o.Bool("wroteMemory", false); h.Stopped = o.Bool("stopped", false);
            foreach (JObj j in o.Objs("results"))
            {
                PortResult r = new PortResult();
                r.Port = j.Str("port"); r.Status = j.Str("status", "pending"); r.Message = j.Str("message");
                r.Before = j.Str("before"); r.After = j.Str("after");
                h.Results.Add(r);
            }
            return h;
        }
    }

    internal sealed class Settings
    {
        public string Language = "en";
        public string Theme = "system";
        public string TermTheme = "dark";
        public float TermFontSize = 13f;
        public bool CopyOnSelect = true;
        public bool RightClickPaste = true;
        public bool SessionLogs;
        public bool ConfirmDeploy = true;
        public bool BackupBeforeDeploy = true;
        public bool CheckBeforeDeploy = true;
        public bool VerifyAfterDeploy = true;
        public bool WriteMemory = true;
        public bool LabV2;
        public string DefaultMode = "range";
        public string DefaultUser = "";
        public int LineDelay = 0;
        public int WindowW, WindowH;
        public bool Maximized;
        public int SidebarW = 280;

        public JObj ToJson()
        {
            JObj o = new JObj();
            o["language"] = Language; o["theme"] = Theme; o["termTheme"] = TermTheme; o["termFont"] = (double)TermFontSize;
            o["copyOnSelect"] = CopyOnSelect; o["rightClickPaste"] = RightClickPaste; o["sessionLogs"] = SessionLogs;
            o["confirmDeploy"] = ConfirmDeploy; o["backupBeforeDeploy"] = BackupBeforeDeploy; o["checkBeforeDeploy"] = CheckBeforeDeploy;
            o["verifyAfterDeploy"] = VerifyAfterDeploy; o["writeMem"] = WriteMemory; o["labV2"] = LabV2; o["defaultMode"] = DefaultMode;
            o["defaultUser"] = DefaultUser; o["lineDelay"] = LineDelay;
            o["windowW"] = WindowW; o["windowH"] = WindowH; o["maximized"] = Maximized; o["sidebarW"] = SidebarW;
            return o;
        }

        public static Settings FromJson(JObj o)
        {
            Settings s = new Settings();
            if (CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "fr") s.Language = "fr";
            if (o.Count == 0) return s;
            s.Language = o.Str("language", s.Language) == "fr" ? "fr" : "en";
            string t = o.Str("theme", "system");
            s.Theme = t == "light" || t == "dark" ? t : "system";
            string tt = o.Str("termTheme", "dark");
            s.TermTheme = tt == "light" || tt == "theme" ? tt : "dark";
            object fs;
            if (o.TryGetValue("termFont", out fs) && fs is double) s.TermFontSize = (float)Math.Max(10, Math.Min(24, (double)fs));
            s.CopyOnSelect = o.Bool("copyOnSelect", true); s.RightClickPaste = o.Bool("rightClickPaste", true);
            s.ConfirmDeploy = o.Bool("confirmDeploy", true);
            s.BackupBeforeDeploy = o.Bool("backupBeforeDeploy", true); s.CheckBeforeDeploy = o.Bool("checkBeforeDeploy", true);
            s.VerifyAfterDeploy = o.Bool("verifyAfterDeploy", true); s.WriteMemory = o.Bool("writeMem", true); s.LabV2 = o.Bool("labV2", false);
            s.DefaultMode = o.Str("defaultMode", "range") == "single" ? "single" : "range";
            s.DefaultUser = o.Str("defaultUser"); s.LineDelay = Math.Max(0, Math.Min(500, o.Int("lineDelay", 0)));
            s.WindowW = o.Int("windowW", 0); s.WindowH = o.Int("windowH", 0); s.Maximized = o.Bool("maximized", false);
            s.SidebarW = Math.Max(220, Math.Min(480, o.Int("sidebarW", 280)));
            return s;
        }
    }

    internal static class Secret
    {
        private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("SwitchDeck.v1");
        private static byte[] key;
        private static readonly HashSet<string> warned = new HashSet<string>();

        private static byte[] Key
        {
            get
            {
                if (key != null) return key;
                string path = Path.Combine(Program.DataDir, "key.bin");
                try
                {
                    if (File.Exists(path))
                    {
                        byte[] k = File.ReadAllBytes(path);
                        if (k.Length == 32) { key = k; return key; }
                    }
                    byte[] fresh = new byte[32];
                    using (RandomNumberGenerator rng = RandomNumberGenerator.Create()) rng.GetBytes(fresh);
                    Directory.CreateDirectory(Program.DataDir);
                    File.WriteAllBytes(path, fresh);
                    key = fresh;
                }
                catch (Exception ex)
                {
                    Log.Error("Secret key: " + ex.Message);
                    key = new byte[32];
                }
                return key;
            }
        }

        public static string Protect(string plain)
        {
            if (string.IsNullOrEmpty(plain)) return "";
            try
            {
                using (Aes aes = Aes.Create())
                {
                    aes.Key = Key;
                    aes.GenerateIV();
                    using (ICryptoTransform enc = aes.CreateEncryptor())
                    {
                        byte[] data = Encoding.UTF8.GetBytes(plain);
                        byte[] cipher = enc.TransformFinalBlock(data, 0, data.Length);
                        byte[] all = new byte[16 + cipher.Length];
                        Buffer.BlockCopy(aes.IV, 0, all, 0, 16);
                        Buffer.BlockCopy(cipher, 0, all, 16, cipher.Length);
                        return "aes:" + Convert.ToBase64String(all);
                    }
                }
            }
            catch (Exception ex)
            {
                Log.Error("Could not protect a secret: " + ex.Message);
                return "";
            }
        }

        public static string Reveal(string stored)
        {
            if (string.IsNullOrEmpty(stored)) return "";
            try
            {
                if (stored.StartsWith("aes:"))
                {
                    byte[] all = Convert.FromBase64String(stored.Substring(4));
                    using (Aes aes = Aes.Create())
                    {
                        aes.Key = Key;
                        byte[] iv = new byte[16];
                        Buffer.BlockCopy(all, 0, iv, 0, 16);
                        aes.IV = iv;
                        using (ICryptoTransform dec = aes.CreateDecryptor())
                            return Encoding.UTF8.GetString(dec.TransformFinalBlock(all, 16, all.Length - 16));
                    }
                }
                if (stored.StartsWith("dpapi:"))
                {
                    byte[] data = ProtectedData.Unprotect(Convert.FromBase64String(stored.Substring(6)), Entropy, DataProtectionScope.CurrentUser);
                    return Encoding.UTF8.GetString(data);
                }
                return stored;
            }
            catch (Exception ex)
            {
                lock (warned)
                    if (warned.Add(stored)) Log.Warn("A saved password could not be read on this computer, type it again in the switch settings (" + ex.Message + ")");
                return "";
            }
        }

        public static bool Readable(string stored)
        {
            return string.IsNullOrEmpty(stored) || Reveal(stored).Length > 0;
        }
    }

    internal static class Store
    {
        public static Settings Settings = new Settings();
        public static readonly List<Host> Hosts = new List<Host>();
        public static readonly List<Template> Templates = new List<Template>();
        public static readonly List<HistoryEntry> History = new List<HistoryEntry>();
        public static event Action HostsChanged, TemplatesChanged, HistoryChanged;

        private static string FileOf(string name) { return Path.Combine(Program.DataDir, name); }

        public static void Load()
        {
            Settings = Settings.FromJson(Read("settings.json"));
            L.Lang = Settings.Language;
            bool first = !File.Exists(FileOf("hosts.json"));
            Hosts.Clear();
            foreach (JObj o in Read("hosts.json").Objs("hosts")) Hosts.Add(Host.FromJson(o));
            Templates.Clear();
            bool firstTemplates = !File.Exists(FileOf("templates.json"));
            foreach (JObj o in Read("templates.json").Objs("templates")) Templates.Add(Template.FromJson(o));
            History.Clear();
            foreach (JObj o in Read("history.json").Objs("entries")) History.Add(HistoryEntry.FromJson(o));
            if (first) { Samples.AddHosts(); Settings.LabV2 = true; SaveHosts(); SaveSettings(); }
            else if (!Settings.LabV2)
            {
                Settings.LabV2 = true;
                if (!Hosts.Exists(delegate(Host x) { return x.DemoModel.StartsWith("C9200L"); })) { Samples.AddC9200(); SaveHosts(); }
                SaveSettings();
            }
            else
            {
                bool changed = false;
                foreach (Host h in Hosts)
                {
                    if (h.Password.StartsWith("dpapi:")) { string p = Secret.Reveal(h.Password); if (p.Length > 0) { h.Password = Secret.Protect(p); changed = true; } }
                    if (h.Enable.StartsWith("dpapi:")) { string p = Secret.Reveal(h.Enable); if (p.Length > 0) { h.Enable = Secret.Protect(p); changed = true; } }
                    if (h.Kind == "demo" && Secret.Reveal(h.Password).Length == 0 && Secret.Reveal(h.Enable).Length == 0) { h.Password = Secret.Protect("cisco"); h.Enable = ""; changed = true; }
                }
                if (changed) SaveHosts();
            }
            if (firstTemplates) { Samples.AddTemplates(); SaveTemplates(); }
        }

        private static JObj Read(string name)
        {
            string path = FileOf(name);
            try
            {
                if (!File.Exists(path)) return new JObj();
                return Json.ParseObj(File.ReadAllText(path, Encoding.UTF8));
            }
            catch (Exception ex)
            {
                Log.Error("Could not read " + name + ": " + ex.Message);
                try { File.Copy(path, path + ".broken-" + DateTime.Now.ToString("yyyyMMdd-HHmmss"), true); } catch { }
                return new JObj();
            }
        }

        private static void Write(string name, object data)
        {
            string path = FileOf(name);
            try
            {
                Directory.CreateDirectory(Program.DataDir);
                string tmp = path + ".tmp";
                File.WriteAllText(tmp, Json.Write(data), new UTF8Encoding(false));
                if (File.Exists(path)) File.Replace(tmp, path, null);
                else File.Move(tmp, path);
            }
            catch (Exception ex) { Log.Error("Could not save " + name + ": " + ex.Message); }
        }

        public static void SaveSettings() { Write("settings.json", Settings.ToJson()); }

        public static void SaveHosts()
        {
            JObj o = new JObj();
            List<object> list = new List<object>();
            foreach (Host h in Hosts) list.Add(h.ToJson());
            o["hosts"] = list;
            Write("hosts.json", o);
            Action a = HostsChanged;
            if (a != null) a();
        }

        public static void SaveTemplates()
        {
            JObj o = new JObj();
            List<object> list = new List<object>();
            foreach (Template t in Templates) list.Add(t.ToJson());
            o["templates"] = list;
            Write("templates.json", o);
            Action a = TemplatesChanged;
            if (a != null) a();
        }

        public static void AddHistory(HistoryEntry e)
        {
            History.Insert(0, e);
            while (History.Count > 500) History.RemoveAt(History.Count - 1);
            SaveHistory();
        }

        public static void SaveHistory()
        {
            JObj o = new JObj();
            List<object> list = new List<object>();
            foreach (HistoryEntry e in History) list.Add(e.ToJson());
            o["entries"] = list;
            Write("history.json", o);
            Action a = HistoryChanged;
            if (a != null) a();
        }

        public static Host FindHost(string id)
        {
            foreach (Host h in Hosts) if (h.Id == id) return h;
            return null;
        }

        public static Template FindTemplate(string id)
        {
            foreach (Template t in Templates) if (t.Id == id) return t;
            return null;
        }

        public static void ReplaceHost(Host h)
        {
            for (int i = 0; i < Hosts.Count; i++) if (Hosts[i].Id == h.Id) { Hosts[i] = h; SaveHosts(); return; }
            Hosts.Add(h);
            SaveHosts();
        }

        public static void ReplaceTemplate(Template t)
        {
            for (int i = 0; i < Templates.Count; i++) if (Templates[i].Id == t.Id) { Templates[i] = t; SaveTemplates(); return; }
            Templates.Add(t);
            SaveTemplates();
        }

        public static List<string> Groups()
        {
            List<string> g = new List<string>();
            foreach (Host h in Hosts) if (h.Group.Length > 0 && !g.Contains(h.Group)) g.Add(h.Group);
            g.Sort(StringComparer.CurrentCultureIgnoreCase);
            return g;
        }

        public static string SafeName(string s)
        {
            StringBuilder sb = new StringBuilder();
            foreach (char c in s) sb.Append(Array.IndexOf(Path.GetInvalidFileNameChars(), c) >= 0 || c == ' ' ? '_' : c);
            string r = sb.ToString().Trim('_');
            return r.Length == 0 ? "switch" : r;
        }
    }
}
