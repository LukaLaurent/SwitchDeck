using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Threading;

namespace SwitchDeck
{
    internal sealed class DemoIf
    {
        public string Name;
        public List<string> Lines = new List<string>();
        public bool Link;

        public DemoIf Clone()
        {
            DemoIf d = new DemoIf();
            d.Name = Name;
            d.Lines = new List<string>(Lines);
            d.Link = Link;
            return d;
        }
    }

    internal sealed class DemoState
    {
        public string Hostname;
        public string Model;
        public string Serial;
        public string Version;
        public List<DemoIf> Ifs = new List<DemoIf>();
        public SortedDictionary<int, string> Vlans = new SortedDictionary<int, string>();

        public DemoState Clone()
        {
            DemoState s = new DemoState();
            s.Hostname = Hostname; s.Model = Model; s.Serial = Serial; s.Version = Version;
            foreach (DemoIf i in Ifs) s.Ifs.Add(i.Clone());
            foreach (KeyValuePair<int, string> kv in Vlans) s.Vlans[kv.Key] = kv.Value;
            return s;
        }

        public DemoIf Find(string name)
        {
            string n = Ports.Normalize(name);
            if (n == null) return null;
            foreach (DemoIf i in Ifs) if (string.Equals(i.Name, n, StringComparison.OrdinalIgnoreCase)) return i;
            return null;
        }

        public JObj ToJson()
        {
            JObj o = new JObj();
            o["hostname"] = Hostname; o["model"] = Model; o["serial"] = Serial; o["version"] = Version;
            List<object> ifs = new List<object>();
            foreach (DemoIf i in Ifs)
            {
                JObj j = new JObj();
                j["name"] = i.Name;
                j["link"] = i.Link;
                j["lines"] = new List<object>(i.Lines.ToArray());
                ifs.Add(j);
            }
            o["interfaces"] = ifs;
            JObj v = new JObj();
            foreach (KeyValuePair<int, string> kv in Vlans) v[kv.Key.ToString(CultureInfo.InvariantCulture)] = kv.Value;
            o["vlans"] = v;
            return o;
        }

        public static DemoState FromJson(JObj o)
        {
            DemoState s = new DemoState();
            s.Hostname = o.Str("hostname", "Switch"); s.Model = o.Str("model"); s.Serial = o.Str("serial"); s.Version = o.Str("version");
            foreach (JObj j in o.Objs("interfaces"))
            {
                DemoIf i = new DemoIf();
                i.Name = j.Str("name");
                i.Link = j.Bool("link", false);
                i.Lines = j.Strs("lines");
                s.Ifs.Add(i);
            }
            foreach (KeyValuePair<string, object> kv in o.Obj("vlans"))
            {
                int id;
                if (int.TryParse(kv.Key, out id)) s.Vlans[id] = Convert.ToString(kv.Value, CultureInfo.InvariantCulture);
            }
            return s;
        }
    }

    internal sealed class DemoSwitch
    {
        private static readonly Dictionary<string, DemoState> running = new Dictionary<string, DemoState>();
        private readonly string id;
        private readonly string model;
        private readonly string enableSecret;
        private DemoState st;
        public Action<string> Output;
        public Action Quit;
        public int Latency = 25;

        private string mode = "user";
        private List<DemoIf> current = new List<DemoIf>();
        private string currentLabel = "";
        private int vlanEditing;
        private readonly StringBuilder line = new StringBuilder();
        private readonly List<string> history = new List<string>();
        private int histPos = -1;
        private int escState;
        private bool lastCr;
        private int termLength = 24, termWidth = 80;
        private bool askingEnable;
        private int enableTries;
        private Queue<string> pager;
        private bool pagerActive;

        public DemoSwitch(string id, string model, string enableSecret)
        {
            this.id = id;
            this.model = string.IsNullOrEmpty(model) ? "C9300-48P" : model;
            this.enableSecret = enableSecret ?? "";
        }

        private static string StartupFile(string id) { return Path.Combine(Path.Combine(Program.DataDir, "demo"), Store.SafeName(id) + ".json"); }

        public static void Forget(string id)
        {
            lock (running) running.Remove(id);
            try { File.Delete(StartupFile(id)); } catch { }
        }

        public void Boot()
        {
            lock (running)
            {
                if (!running.TryGetValue(id, out st))
                {
                    st = LoadStartup() ?? Factory(model);
                    running[id] = st;
                }
            }
            Out("\r\n");
            Out("User Access Verification\r\n\r\n");
            Thread.Sleep(120);
            Out("*** " + st.Model + " lab switch, simulated by SwitchDeck ***\r\n\r\n");
            Prompt();
        }

        private DemoState LoadStartup()
        {
            try
            {
                string f = StartupFile(id);
                if (!File.Exists(f)) return null;
                return DemoState.FromJson(Json.ParseObj(File.ReadAllText(f, Encoding.UTF8)));
            }
            catch (Exception ex)
            {
                Log.Warn("Demo startup config: " + ex.Message);
                return null;
            }
        }

        private void SaveStartup()
        {
            try
            {
                string f = StartupFile(id);
                Directory.CreateDirectory(Path.GetDirectoryName(f));
                File.WriteAllText(f, Json.Write(st.ToJson()), new UTF8Encoding(false));
            }
            catch (Exception ex) { Log.Warn("Demo save: " + ex.Message); }
        }

        public static DemoState Factory(string model)
        {
            DemoState s = new DemoState();
            Random rnd = new Random(model.GetHashCode());
            s.Model = model;
            s.Vlans[1] = "default";
            s.Vlans[2] = "WIFI";
            s.Vlans[10] = "OFFICE";
            s.Vlans[20] = "VOICE";
            s.Vlans[30] = "PRINTERS";
            s.Vlans[999] = "PARKING";
            if (model.StartsWith("WS-C2960"))
            {
                s.Hostname = "SW-FLOOR2";
                s.Serial = "FOC1932X0" + rnd.Next(10, 99) + "K";
                s.Version = "15.2(7)E9";
                for (int i = 1; i <= 24; i++) s.Ifs.Add(Make("Gi1/0/" + i, rnd.NextDouble() < 0.55));
                for (int i = 25; i <= 28; i++) s.Ifs.Add(Make("Gi1/0/" + i, i == 25));
                s.Ifs.Add(Make("Fa0", false));
                s.Find("Fa0").Lines.Add("no ip address");
                s.Find("Gi1/0/25").Lines.AddRange(new[] { "description Uplink-Core", "switchport mode trunk" });
                s.Find("Gi1/0/3").Lines.AddRange(new[] { "description Printer-2F", "switchport access vlan 30", "switchport mode access" });
            }
            else if (model.StartsWith("C9200L"))
            {
                int members = StackSize(model);
                s.Hostname = members > 1 ? "SW-STACK-01" : "SW-ACCESS-01";
                s.Serial = "JAE2511" + rnd.Next(1000, 9999);
                s.Version = "17.9.5";
                for (int m = 1; m <= members; m++)
                {
                    for (int i = 1; i <= 48; i++) s.Ifs.Add(Make("Gi" + m + "/0/" + i, rnd.NextDouble() < 0.5));
                    for (int i = 1; i <= 4; i++) s.Ifs.Add(Make("Te" + m + "/1/" + i, i == 1));
                }
                s.Find("Te1/1/1").Lines.AddRange(new[] { "description Uplink-Core", "switchport mode trunk" });
                if (members > 1) s.Find("Te2/1/1").Lines.AddRange(new[] { "description Uplink-Core-B", "switchport mode trunk" });
                s.Find("Gi1/0/5").Lines.AddRange(new[] { "description Meeting-Room", "switchport access vlan 10", "switchport mode access", "spanning-tree portfast" });
            }
            else
            {
                s.Hostname = "SW-CORE-01";
                s.Serial = "FOC2245Y" + rnd.Next(100, 999) + "L";
                s.Version = "17.9.4a";
                for (int i = 1; i <= 48; i++) s.Ifs.Add(Make("Gi1/0/" + i, rnd.NextDouble() < 0.6));
                for (int i = 1; i <= 8; i++) s.Ifs.Add(Make("Te1/1/" + i, i <= 2));
                s.Find("Gi1/0/1").Lines.AddRange(new[] { "description AP-Hall-01", "switchport trunk allowed vlan 2", "switchport mode trunk", "spanning-tree portfast trunk" });
                s.Find("Gi1/0/2").Lines.AddRange(new[] { "description AP-Hall-02", "switchport trunk allowed vlan 2", "switchport mode trunk", "spanning-tree portfast trunk" });
                s.Find("Gi1/0/10").Lines.AddRange(new[] { "description Reception-PC", "switchport access vlan 10", "switchport mode access", "spanning-tree portfast" });
                s.Find("Gi1/0/47").Lines.AddRange(new[] { "description Unused", "switchport access vlan 999", "switchport mode access", "shutdown" });
                s.Find("Te1/1/1").Lines.AddRange(new[] { "description Uplink-Floor2", "switchport mode trunk" });
            }
            return s;
        }

        public static int StackSize(string model)
        {
            return model != null && model.EndsWith("-STACK") ? 2 : 1;
        }

        public static string RealModel(string model)
        {
            return model != null && model.EndsWith("-STACK") ? model.Substring(0, model.Length - 6) : model;
        }

        private static DemoIf Make(string name, bool link)
        {
            DemoIf d = new DemoIf();
            d.Name = name;
            d.Link = link;
            return d;
        }

        private void Out(string s)
        {
            Action<string> o = Output;
            if (o != null) o(s);
        }

        private string PromptText
        {
            get
            {
                string h = st.Hostname;
                switch (mode)
                {
                    case "user": return h + ">";
                    case "enable": return h + "#";
                    case "config": return h + "(config)#";
                    case "if": return h + "(config-if)#";
                    case "range": return h + "(config-if-range)#";
                    case "vlan": return h + "(config-vlan)#";
                    default: return h + "#";
                }
            }
        }

        private void Prompt()
        {
            Out(PromptText);
        }

        public void Key(char c)
        {
            if (pagerActive)
            {
                PagerKey(c);
                return;
            }
            if (escState == 1) { escState = c == '[' || c == 'O' ? 2 : 0; return; }
            if (escState == 2)
            {
                escState = 0;
                if (c == 'A') History(-1);
                else if (c == 'B') History(1);
                else if (c >= '0' && c <= '9') escState = 3;
                return;
            }
            if (escState == 3) { if (c == '~' || char.IsLetter(c)) escState = 0; return; }
            if (askingEnable)
            {
                EnableKey(c);
                return;
            }
            if (c == '\n' && lastCr) { lastCr = false; return; }
            lastCr = c == '\r';
            switch (c)
            {
                case '\x1b': escState = 1; return;
                case '\r':
                case '\n':
                    {
                        Out("\r\n");
                        string cmd = line.ToString();
                        line.Length = 0;
                        histPos = -1;
                        if (cmd.Trim().Length > 0)
                        {
                            history.Add(cmd);
                            if (history.Count > 30) history.RemoveAt(0);
                        }
                        if (Latency > 0 && cmd.Trim().Length > 0) Thread.Sleep(Latency);
                        Execute(cmd);
                        if (!askingEnable && !pagerActive) Prompt();
                        return;
                    }
                case '\b':
                case '\x7f':
                    if (line.Length > 0) { line.Length--; Out("\b \b"); }
                    return;
                case '\x15':
                    while (line.Length > 0) { line.Length--; Out("\b \b"); }
                    return;
                case '\x03':
                    line.Length = 0;
                    Out("^C\r\n");
                    if (mode != "user" && mode != "enable") mode = "enable";
                    Prompt();
                    return;
                case '\x1a':
                    line.Length = 0;
                    Out("^Z\r\n");
                    if (mode != "user" && mode != "enable") mode = "enable";
                    Prompt();
                    return;
                case '\x1e':
                    return;
                case '\x10': History(-1); return;
                case '\x0e': History(1); return;
                case '\t':
                    Complete();
                    return;
                case '?':
                    Out("?\r\n");
                    Help(line.ToString());
                    Prompt();
                    Out(line.ToString());
                    return;
            }
            if (c < ' ') return;
            line.Append(c);
            Out(c.ToString());
        }

        private void History(int dir)
        {
            if (history.Count == 0) return;
            if (histPos < 0) histPos = history.Count;
            histPos = Math.Max(0, Math.Min(history.Count, histPos + dir));
            while (line.Length > 0) { line.Length--; Out("\b \b"); }
            if (histPos < history.Count)
            {
                line.Append(history[histPos]);
                Out(history[histPos]);
            }
        }

        private void EnableKey(char c)
        {
            if (c == '\n' && lastCr) { lastCr = false; return; }
            lastCr = c == '\r';
            if (c == '\r' || c == '\n')
            {
                Out("\r\n");
                string pw = line.ToString();
                line.Length = 0;
                if (pw == enableSecret)
                {
                    askingEnable = false;
                    mode = "enable";
                    Prompt();
                }
                else if (++enableTries >= 3)
                {
                    askingEnable = false;
                    Out("% Bad secrets\r\n\r\n");
                    Prompt();
                }
                else Out("Password: ");
                return;
            }
            if (c == '\b' || c == '\x7f') { if (line.Length > 0) line.Length--; return; }
            if (c >= ' ') line.Append(c);
        }

        private void PagerKey(char c)
        {
            Out("\r          \r");
            if (c == ' ') ShowPage(termLength - 1);
            else if (c == '\r' || c == '\n') ShowPage(1);
            else
            {
                pager = null;
                pagerActive = false;
                Prompt();
            }
        }

        private void Print(List<string> lines)
        {
            if (termLength <= 0 || lines.Count < termLength)
            {
                StringBuilder sb = new StringBuilder();
                foreach (string l in lines) sb.Append(l).Append("\r\n");
                Out(sb.ToString());
                return;
            }
            pager = new Queue<string>(lines);
            ShowPage(termLength - 1);
        }

        private void ShowPage(int n)
        {
            StringBuilder sb = new StringBuilder();
            while (n-- > 0 && pager != null && pager.Count > 0) sb.Append(pager.Dequeue()).Append("\r\n");
            Out(sb.ToString());
            if (pager != null && pager.Count > 0)
            {
                pagerActive = true;
                Out(" --More-- ");
            }
            else
            {
                bool was = pagerActive;
                pager = null;
                pagerActive = false;
                if (was) Prompt();
            }
        }

        private sealed class Node
        {
            public string Word;
            public string Kind;
            public string Help;
            public List<Node> Next = new List<Node>();
            public bool Final;
            public Node(string word, string kind, string help) { Word = word; Kind = kind; Help = help; }
        }

        private static readonly Dictionary<string, Node> trees = new Dictionary<string, Node>();

        private static Node Tree(string treeMode)
        {
            lock (trees)
            {
                Node root;
                if (trees.TryGetValue(treeMode, out root)) return root;
                root = new Node("", "", "");
                foreach (string spec in Grammar(treeMode)) AddSpec(root, spec);
                trees[treeMode] = root;
                return root;
            }
        }

        private static void AddSpec(Node root, string spec)
        {
            string[] parts = spec.Split('|');
            string[] words = parts[0].Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            Node n = root;
            for (int i = 0; i < words.Length; i++)
            {
                string w = words[i];
                string kind = w.StartsWith("<") ? w.Trim('<', '>') : "";
                string help = i == words.Length - 1 && parts.Length > 1 ? parts[1] : "";
                Node found = null;
                foreach (Node c in n.Next) if (c.Word == w) found = c;
                if (found == null)
                {
                    found = new Node(w, kind, help);
                    n.Next.Add(found);
                }
                else if (help.Length > 0 && found.Help.Length == 0) found.Help = help;
                n = found;
            }
            n.Final = true;
        }

        private static IEnumerable<string> Grammar(string m)
        {
            if (m == "user" || m == "enable")
            {
                yield return "enable|Turn on privileged commands";
                yield return "exit|Exit from the EXEC";
                yield return "logout|Exit from the EXEC";
                yield return "ping <word>|Send echo messages";
                yield return "show version|System hardware and software status";
                yield return "show clock|Display the system clock";
                yield return "show interfaces status|Show interface line status";
                yield return "show interfaces <if>|Interface status and configuration";
                yield return "show interfaces <if> status|Show interface line status";
                yield return "show vlan brief|VTP all VLAN status in brief";
                yield return "show ip interface brief|Brief summary of IP status and configuration";
                yield return "show inventory|Show the physical inventory";
                yield return "terminal length <num>|Set number of lines on a screen";
                yield return "terminal width <num>|Set width of the display terminal";
                yield return "terminal no length|Set number of lines on a screen";
                if (m == "enable")
                {
                    yield return "disable|Turn off privileged commands";
                    yield return "configure terminal|Configure from the terminal";
                    yield return "show running-config|Current operating configuration";
                    yield return "show running-config interface <if>|Show interface configuration";
                    yield return "show startup-config|Contents of startup configuration";
                    yield return "write memory|Write to NV memory";
                    yield return "copy running-config startup-config|Update (merge with) configuration";
                    yield return "reload|Halt and perform a cold restart";
                }
                yield break;
            }
            if (m == "config")
            {
                yield return "interface <if>|Select an interface to configure";
                yield return "interface range <range>|interface range command";
                yield return "default interface <if>|Set an interface to its default configuration";
                yield return "default interface range <range>|interface range command";
                yield return "hostname <word>|Set system's network name";
                yield return "vlan <num>|VLAN commands";
                yield return "no vlan <num>|VLAN commands";
                yield return "end|Exit from configure mode";
                yield return "exit|Exit from configure mode";
                yield return "do <rest>|To run exec commands in config mode";
                yield break;
            }
            if (m == "vlan")
            {
                yield return "name <word>|Ascii name of the VLAN";
                yield return "exit|Apply changes, bump revision number, and exit mode";
                yield return "end|Exit from configure mode";
                yield return "do <rest>|To run exec commands in config mode";
                yield break;
            }
            foreach (string pre in new[] { "", "no " })
            {
                yield return pre + "description <rest>|Interface specific description";
                yield return pre + "shutdown|Shutdown the selected interface";
                yield return pre + "switchport|Set switching mode characteristics";
                yield return pre + "switchport mode access|Set trunking mode to ACCESS unconditionally";
                yield return pre + "switchport mode trunk|Set trunking mode to TRUNK unconditionally";
                yield return pre + "switchport mode dynamic auto|Set trunking mode dynamic negotiation parameter to AUTO";
                yield return pre + "switchport mode dynamic desirable|Set trunking mode dynamic negotiation parameter to DESIRABLE";
                yield return pre + "switchport access vlan <vlan>|Set VLAN when interface is in access mode";
                yield return pre + "switchport voice vlan <vlan>|Vlan for voice traffic";
                yield return pre + "switchport trunk native vlan <vlan>|Set native VLAN when interface is in trunking mode";
                yield return pre + "switchport trunk allowed vlan <vlans>|Set allowed VLANs when interface is in trunking mode";
                yield return pre + "switchport trunk allowed vlan add <vlans>|add VLANs to the current list";
                yield return pre + "switchport trunk allowed vlan remove <vlans>|remove VLANs from the current list";
                yield return pre + "switchport trunk allowed vlan all|all VLANs";
                yield return pre + "switchport trunk allowed vlan none|no VLANs";
                yield return pre + "switchport trunk encapsulation dot1q|Interface uses only 802.1q trunking encapsulation";
                yield return pre + "switchport nonegotiate|Device will not engage in negotiation protocol on this interface";
                yield return pre + "switchport port-security|Security related command";
                yield return pre + "switchport port-security maximum <num>|Max secure addresses";
                yield return pre + "switchport port-security violation shutdown|Security violation shutdown mode";
                yield return pre + "switchport port-security violation restrict|Security violation restrict mode";
                yield return pre + "switchport port-security mac-address sticky|Configure dynamic secure addresses as sticky";
                yield return pre + "spanning-tree portfast|Spanning tree portfast options";
                yield return pre + "spanning-tree portfast trunk|Enable portfast on the interface even in trunk mode";
                yield return pre + "spanning-tree portfast edge|Enable portfast edge on the interface";
                yield return pre + "spanning-tree portfast edge trunk|Enable portfast edge on the interface even in trunk mode";
                yield return pre + "spanning-tree bpduguard enable|Enable BPDU guard for this interface";
                yield return pre + "spanning-tree bpduguard disable|Disable BPDU guard for this interface";
                yield return pre + "spanning-tree guard root|Set guard mode to root guard on interface";
                yield return pre + "spanning-tree guard loop|Set guard mode to loop guard on interface";
                yield return pre + "speed auto|Enable AUTO speed configuration";
                yield return pre + "speed 10|Force 10 Mbps operation";
                yield return pre + "speed 100|Force 100 Mbps operation";
                yield return pre + "speed 1000|Force 1000 Mbps operation";
                yield return pre + "duplex auto|Enable AUTO duplex configuration";
                yield return pre + "duplex full|Force full duplex operation";
                yield return pre + "duplex half|Force half-duplex operation";
                yield return pre + "power inline auto|Automatically detect and power inline devices";
                yield return pre + "power inline never|Never apply inline power";
                yield return pre + "storm-control broadcast level <word>|Set storm suppression level on this interface";
                yield return pre + "storm-control multicast level <word>|Set storm suppression level on this interface";
                yield return pre + "channel-group <num> mode active|Enable LACP unconditionally";
                yield return pre + "channel-group <num> mode passive|Enable LACP only if a LACP device is detected";
                yield return pre + "channel-group <num> mode on|Enable Etherchannel only";
                yield return pre + "cdp enable|Enable CDP on interface";
                yield return pre + "lldp transmit|Enable LLDP transmission on interface";
                yield return pre + "lldp receive|Enable LLDP reception on interface";
                yield return pre + "ip dhcp snooping trust|DHCP Snooping trust config";
                yield return pre + "load-interval <num>|Specify interval for load calculation for an interface";
                yield return pre + "mls qos trust cos|cos keyword";
                yield return pre + "mls qos trust dscp|dscp keyword";
                yield return pre + "auto qos voip cisco-phone|Trust the QoS marking of Cisco IP Phone";
                yield return pre + "udld port|Enable UDLD protocol on this interface";
                yield return pre + "logging event link-status|UPDOWN and CHANGE messages";
            }
            foreach (string s in new[] { "description", "switchport mode", "switchport access vlan", "switchport voice vlan", "switchport trunk native vlan",
                "switchport trunk allowed vlan", "switchport trunk encapsulation", "switchport port-security maximum", "switchport port-security violation",
                "spanning-tree portfast", "spanning-tree bpduguard", "spanning-tree guard", "speed", "duplex", "power inline", "storm-control broadcast level",
                "storm-control multicast level", "channel-group", "load-interval", "mls qos trust" })
                yield return "no " + s;
            yield return "interface <if>|Select an interface to configure";
            yield return "interface range <range>|interface range command";
            yield return "default interface <if>|Set an interface to its default configuration";
            yield return "exit|Exit from interface configuration mode";
            yield return "end|Exit from configure mode";
            yield return "do <rest>|To run exec commands in config mode";
        }

        private sealed class ParseResult
        {
            public List<string> Words = new List<string>();
            public List<string> Values = new List<string>();
            public string Error;
            public int ErrorAt = -1;
            public Node Last;
        }

        private ParseResult ParseCmd(string text, Node root)
        {
            ParseResult r = new ParseResult();
            List<KeyValuePair<int, string>> tokens = Tokens(text);
            Node n = root;
            for (int t = 0; t < tokens.Count; t++)
            {
                string tok = tokens[t].Value;
                List<Node> lit = new List<Node>();
                Node param = null;
                foreach (Node c in n.Next)
                {
                    if (c.Kind.Length == 0)
                    {
                        if (c.Word.Equals(tok, StringComparison.OrdinalIgnoreCase)) { lit.Clear(); lit.Add(c); break; }
                        if (c.Word.StartsWith(tok, StringComparison.OrdinalIgnoreCase)) lit.Add(c);
                    }
                    else if (param == null && Accepts(c.Kind, tok)) param = c;
                }
                if (lit.Count > 1)
                {
                    r.Error = "% Ambiguous command:  \"" + text.Trim() + "\"";
                    return r;
                }
                Node next = lit.Count == 1 ? lit[0] : param;
                if (next == null)
                {
                    r.Error = "invalid";
                    r.ErrorAt = tokens[t].Key;
                    return r;
                }
                if (next.Kind == "rest" || next.Kind == "range")
                {
                    r.Words.Add(next.Word);
                    string rest = text.Substring(tokens[t].Key).Trim();
                    r.Values.Add(rest);
                    n = next;
                    break;
                }
                r.Words.Add(next.Kind.Length == 0 ? next.Word : next.Word);
                r.Values.Add(next.Kind.Length == 0 ? next.Word : tok);
                n = next;
            }
            r.Last = n;
            if (!n.Final) r.Error = "% Incomplete command.";
            return r;
        }

        private static List<KeyValuePair<int, string>> Tokens(string text)
        {
            List<KeyValuePair<int, string>> r = new List<KeyValuePair<int, string>>();
            int i = 0;
            while (i < text.Length)
            {
                while (i < text.Length && text[i] == ' ') i++;
                if (i >= text.Length) break;
                int s = i;
                while (i < text.Length && text[i] != ' ') i++;
                r.Add(new KeyValuePair<int, string>(s, text.Substring(s, i - s)));
            }
            return r;
        }

        private bool Accepts(string kind, string tok)
        {
            int v;
            switch (kind)
            {
                case "num": return int.TryParse(tok, out v);
                case "vlan": return int.TryParse(tok, out v) && v >= 1 && v <= 4094;
                case "vlans":
                    foreach (char ch in tok) if (!char.IsDigit(ch) && ch != ',' && ch != '-') return false;
                    foreach (string part in tok.Split(',', '-'))
                    {
                        int n;
                        if (!int.TryParse(part, out n) || n < 1 || n > 4094) return false;
                    }
                    return tok.Length > 0;
                case "if": return st.Find(tok) != null || (tok.Length > 0 && char.IsLetter(tok[0]) && Ports.Parse(tok) != null);
                case "range": return tok.Length > 0 && char.IsLetter(tok[0]);
                case "word": case "rest": return tok.Length > 0;
            }
            return false;
        }

        private void Invalid(string text, int at)
        {
            Out(new string(' ', PromptText.Length + Math.Max(0, at)) + "^\r\n");
            Out("% Invalid input detected at '^' marker.\r\n\r\n");
        }

        private string TreeMode
        {
            get
            {
                if (mode == "range") return "if";
                return mode;
            }
        }

        private void Execute(string raw)
        {
            string text = raw.TrimEnd();
            if (text.Trim().Length == 0) return;
            if (text.TrimStart().StartsWith("!")) return;
            string pipe = null;
            int bar = text.IndexOf(" | ", StringComparison.Ordinal);
            if (bar > 0) { pipe = text.Substring(bar + 3).Trim(); text = text.Substring(0, bar); }
            ParseResult p = ParseCmd(text, Tree(TreeMode));
            if (p.Error == "invalid") { Invalid(text, p.ErrorAt); return; }
            if (p.Error != null) { Out(p.Error + "\r\n\r\n"); return; }
            string first = p.Words[0];
            if (first == "do")
            {
                string saved = mode;
                mode = "enable";
                Execute(p.Values[1] + (pipe != null ? " | " + pipe : ""));
                mode = saved;
                return;
            }
            if (mode == "user" || mode == "enable") Exec(p, pipe);
            else if (mode == "config") Config(p);
            else if (mode == "vlan") VlanMode(p);
            else IfMode(p, text);
        }

        private void Exec(ParseResult p, string pipe)
        {
            string w0 = p.Words[0];
            switch (w0)
            {
                case "enable":
                    if (mode == "enable") return;
                    if (enableSecret.Length == 0) { mode = "enable"; return; }
                    askingEnable = true;
                    enableTries = 0;
                    Out("Password: ");
                    return;
                case "disable": mode = "user"; return;
                case "exit":
                case "logout":
                    Out("\r\n");
                    Action q = Quit;
                    if (q != null) q();
                    return;
                case "configure":
                    Out("Enter configuration commands, one per line.  End with CNTL/Z.\r\n");
                    mode = "config";
                    return;
                case "terminal":
                    if (p.Words[1] == "length") termLength = Math.Max(0, int.Parse(p.Values[2]));
                    else if (p.Words[1] == "width") termWidth = Math.Max(0, int.Parse(p.Values[2]));
                    else termLength = 24;
                    return;
                case "write":
                case "copy":
                    if (w0 == "copy") Out("Destination filename [startup-config]? \r\n");
                    Out("Building configuration...\r\n");
                    Thread.Sleep(400);
                    SaveStartup();
                    Out("[OK]\r\n");
                    return;
                case "reload":
                    Out("% Reload is disabled on the SwitchDeck lab switch.\r\n");
                    return;
                case "ping":
                    Out("Type escape sequence to abort.\r\nSending 5, 100-byte ICMP Echos to " + p.Values[1] + ", timeout is 2 seconds:\r\n");
                    for (int i = 0; i < 5; i++) { Thread.Sleep(90); Out("!"); }
                    Out("\r\nSuccess rate is 100 percent (5/5), round-trip min/avg/max = 1/1/2 ms\r\n");
                    return;
                case "show":
                    Print(Filter(Show(p), pipe));
                    return;
            }
        }

        private static List<string> Filter(List<string> lines, string pipe)
        {
            if (pipe == null) return lines;
            string[] w = pipe.Split(new[] { ' ' }, 2, StringSplitOptions.RemoveEmptyEntries);
            if (w.Length < 2) return lines;
            List<string> r = new List<string>();
            string what = w[1];
            bool inc = "include".StartsWith(w[0], StringComparison.OrdinalIgnoreCase);
            bool exc = "exclude".StartsWith(w[0], StringComparison.OrdinalIgnoreCase);
            bool sec = "section".StartsWith(w[0], StringComparison.OrdinalIgnoreCase);
            bool inSec = false;
            foreach (string l in lines)
            {
                bool has = l.IndexOf(what, StringComparison.OrdinalIgnoreCase) >= 0;
                if (inc && has) r.Add(l);
                else if (exc && !has) r.Add(l);
                else if (sec)
                {
                    if (l.Length > 0 && l[0] != ' ') inSec = has;
                    if (inSec) r.Add(l);
                }
            }
            return r;
        }

        private List<string> Show(ParseResult p)
        {
            List<string> o = new List<string>();
            string w1 = p.Words[1];
            if (w1 == "version")
            {
                bool old = st.Model.StartsWith("WS-");
                if (old)
                {
                    o.Add("Cisco IOS Software, C2960X Software (C2960X-UNIVERSALK9-M), Version " + st.Version + ", RELEASE SOFTWARE (fc1)");
                    o.Add("Technical Support: http://www.cisco.com/techsupport");
                }
                else
                {
                    o.Add("Cisco IOS XE Software, Version " + st.Version);
                    o.Add("Cisco IOS Software [Cupertino], Catalyst L3 Switch Software (CAT9K_IOSXE), Version " + st.Version + ", RELEASE SOFTWARE (fc3)");
                }
                o.Add("");
                o.Add(st.Hostname + " uptime is 12 weeks, 3 days, 4 hours, 18 minutes");
                o.Add("System image file is \"flash:packages.conf\"");
                o.Add("");
                o.Add("cisco " + RealModel(st.Model) + " (" + (old ? "APM86XXX" : "X86") + ") processor with 1361248K bytes of memory.");
                o.Add("Processor board ID " + st.Serial);
                o.Add(st.Ifs.Count + " Ethernet interfaces");
                o.Add("");
                o.Add("Switch Ports Model              SW Version        SW Image");
                o.Add("------ ----- -----              ----------        ----------");
                int members = StackSize(st.Model);
                for (int m = 1; m <= members; m++)
                    o.Add((m == 1 ? "*" : " ") + "    " + m + " " + (st.Ifs.Count / members).ToString().PadRight(5) + " " + RealModel(st.Model).PadRight(18) + " " + st.Version.PadRight(17) + " " + (old ? "C2960X-UNIVERSALK9-M" : "CAT9K_LITE_IOSXE"));
                o.Add("");
                o.Add("Configuration register is 0x102");
                return o;
            }
            if (w1 == "clock") { o.Add("*" + DateTime.Now.ToString("HH:mm:ss.fff", CultureInfo.InvariantCulture) + " CET " + DateTime.Now.ToString("ddd MMM d yyyy", CultureInfo.InvariantCulture)); return o; }
            if (w1 == "inventory")
            {
                o.Add("NAME: \"c" + st.Model.Substring(st.Model.StartsWith("WS-") ? 4 : 1, 4) + "xx Stack\", DESCR: \"c" + st.Model + " Stack\"");
                o.Add("PID: " + st.Model.PadRight(18) + ", VID: V02  , SN: " + st.Serial);
                o.Add("");
                return o;
            }
            if (w1 == "vlan")
            {
                o.Add("");
                o.Add("VLAN Name                             Status    Ports");
                o.Add("---- -------------------------------- --------- -------------------------------");
                foreach (KeyValuePair<int, string> kv in st.Vlans)
                {
                    List<string> members = new List<string>();
                    foreach (DemoIf i in st.Ifs)
                        if (Value(i, "switchport mode") != "trunk" && AccessVlan(i) == kv.Key && i.Name != "Fa0") members.Add(i.Name);
                    string ports = Ports.Compact(members);
                    o.Add(kv.Key.ToString().PadRight(5) + kv.Value.PadRight(33) + "active    " + (ports.Length > 31 ? ports.Substring(0, 28) + "..." : ports));
                }
                return o;
            }
            if (w1 == "ip")
            {
                o.Add("Interface              IP-Address      OK? Method Status                Protocol");
                o.Add("Vlan1                  10.0.1." + (st.Model.StartsWith("WS-") ? "12" : "2") + "        YES NVRAM  up                    up");
                foreach (DemoIf i in st.Ifs)
                {
                    bool up = Status(i) == "connected";
                    o.Add(Ports.Parse(i.Name).Long.PadRight(23) + "unassigned      YES unset  " + (Has(i, "shutdown") ? "administratively down down" : (up ? "up                    up" : "down                  down")));
                }
                return o;
            }
            if (w1 == "interfaces")
            {
                if (p.Words.Count == 3 && p.Words[2] == "status") return StatusTable(st.Ifs);
                DemoIf one = st.Find(p.Values[2]);
                if (one == null) { o.Add("                        ^"); o.Add("% Invalid input detected at '^' marker."); return o; }
                if (p.Words.Count > 3) { List<DemoIf> l = new List<DemoIf>(); l.Add(one); return StatusTable(l); }
                PortName pn = Ports.Parse(one.Name);
                string state = Has(one, "shutdown") ? "administratively down, line protocol is down (disabled)" : (Status(one) == "connected" ? "up, line protocol is up (connected)" : "down, line protocol is down (notconnect)");
                o.Add(pn.Long + " is " + state);
                o.Add("  Hardware is " + (pn.Type == "Te" ? "Ten Gigabit Ethernet" : "Gigabit Ethernet") + ", address is 00a3.d1f" + (pn.Number % 10) + "." + (8000 + pn.Number).ToString("x4"));
                string d = Value(one, "description");
                if (d.Length > 0) o.Add("  Description: " + d);
                o.Add("  MTU 1500 bytes, BW 1000000 Kbit/sec, DLY 10 usec,");
                o.Add("  Full-duplex, 1000Mb/s, media type is 10/100/1000BaseTX");
                return o;
            }
            if (w1 == "running-config" || w1 == "startup-config")
            {
                DemoState src = w1 == "running-config" ? st : (LoadStartup() ?? st);
                if (p.Words.Count > 2)
                {
                    DemoIf one = src.Find(p.Values[3]);
                    if (one == null) { o.Add("                                ^"); o.Add("% Invalid input detected at '^' marker."); return o; }
                    StringBuilder body = new StringBuilder();
                    body.Append("interface " + Ports.Parse(one.Name).Long + "\n");
                    foreach (string l in one.Lines) body.Append(" " + l + "\n");
                    o.Add("Building configuration...");
                    o.Add("");
                    o.Add("Current configuration : " + (body.Length + 4) + " bytes");
                    o.Add("!");
                    o.Add("interface " + Ports.Parse(one.Name).Long);
                    foreach (string l in one.Lines) o.Add(" " + l);
                    o.Add("end");
                    o.Add("");
                    return o;
                }
                o.Add("Building configuration...");
                o.Add("");
                o.Add("Current configuration : 14872 bytes");
                o.Add("!");
                o.Add("version " + src.Version.Split('(')[0].Split('.')[0] + "." + (src.Version.Contains(".") ? src.Version.Split('.')[1].Split('(')[0] : "2"));
                o.Add("service timestamps debug datetime msec");
                o.Add("service timestamps log datetime msec");
                o.Add("service password-encryption");
                o.Add("!");
                o.Add("hostname " + src.Hostname);
                o.Add("!");
                o.Add("enable secret 9 $9$Q2xhdWRlU3dpdGNoRGVjaw$lab");
                o.Add("!");
                o.Add("spanning-tree mode rapid-pvst");
                o.Add("spanning-tree extend system-id");
                o.Add("!");
                foreach (KeyValuePair<int, string> kv in src.Vlans)
                {
                    if (kv.Key == 1) continue;
                    o.Add("vlan " + kv.Key);
                    o.Add(" name " + kv.Value);
                    o.Add("!");
                }
                foreach (DemoIf i in src.Ifs)
                {
                    o.Add("interface " + Ports.Parse(i.Name).Long);
                    foreach (string l in i.Lines) o.Add(" " + l);
                    o.Add("!");
                }
                o.Add("interface Vlan1");
                o.Add(" ip address 10.0.1." + (src.Model.StartsWith("WS-") ? "12" : "2") + " 255.255.255.0");
                o.Add("!");
                o.Add("ip ssh version 2");
                o.Add("!");
                o.Add("line con 0");
                o.Add(" stopbits 1");
                o.Add("line vty 0 15");
                o.Add(" login local");
                o.Add(" transport input ssh");
                o.Add("!");
                o.Add("end");
                o.Add("");
                return o;
            }
            return o;
        }

        private List<string> StatusTable(List<DemoIf> list)
        {
            List<string> o = new List<string>();
            o.Add("");
            o.Add("Port         Name               Status       Vlan       Duplex  Speed Type");
            foreach (DemoIf i in list)
            {
                string status = Status(i);
                string vlan = i.Name == "Fa0" ? "routed" : (Value(i, "switchport mode") == "trunk" ? "trunk" : AccessVlan(i).ToString());
                bool up = status == "connected";
                PortName pn = Ports.Parse(i.Name);
                string type = pn.Type == "Te" ? (up ? "SFP-10GBase-SR" : "Not Present") : (i.Name == "Fa0" ? "10/100BaseTX" : (pn.Number > 24 && st.Model.StartsWith("WS-") ? (up ? "1000BaseSX SFP" : "Not Present") : "10/100/1000BaseTX"));
                string desc = Value(i, "description");
                if (desc.Length > 18) desc = desc.Substring(0, 18);
                o.Add(i.Name.PadRight(13) + desc.PadRight(19) + status.PadRight(13) + vlan.PadRight(11) + (up ? "a-full" : "  auto").PadRight(8) + (up ? (pn.Type == "Te" ? " a-10G" : "a-1000") : "  auto").PadRight(6) + " " + type);
            }
            return o;
        }

        private string Status(DemoIf i)
        {
            if (Has(i, "shutdown")) return "disabled";
            return i.Link ? "connected" : "notconnect";
        }

        private static bool Has(DemoIf i, string line)
        {
            foreach (string l in i.Lines) if (l == line) return true;
            return false;
        }

        private static string Value(DemoIf i, string key)
        {
            foreach (string l in i.Lines) if (l.StartsWith(key + " ")) return l.Substring(key.Length + 1);
            return "";
        }

        private static int AccessVlan(DemoIf i)
        {
            int v;
            return int.TryParse(Value(i, "switchport access vlan"), out v) ? v : 1;
        }

        private void Config(ParseResult p)
        {
            string w0 = p.Words[0];
            switch (w0)
            {
                case "end": mode = "enable"; return;
                case "exit": mode = "enable"; return;
                case "hostname": st.Hostname = p.Values[1]; return;
                case "vlan":
                    vlanEditing = int.Parse(p.Values[1]);
                    if (vlanEditing < 1 || vlanEditing > 4094) { Out("% Invalid VLAN\r\n"); return; }
                    if (!st.Vlans.ContainsKey(vlanEditing)) st.Vlans[vlanEditing] = "VLAN" + vlanEditing.ToString("0000");
                    mode = "vlan";
                    return;
                case "no":
                    {
                        int v = int.Parse(p.Values[2]);
                        if (v != 1) st.Vlans.Remove(v);
                        return;
                    }
                case "interface":
                case "default":
                    Interfaces(p);
                    return;
            }
        }

        private void VlanMode(ParseResult p)
        {
            string w0 = p.Words[0];
            if (w0 == "name") st.Vlans[vlanEditing] = p.Values[1];
            else if (w0 == "end") mode = "enable";
            else mode = "config";
        }

        private void Interfaces(ParseResult p)
        {
            bool isDefault = p.Words[0] == "default";
            int at = isDefault ? 2 : 1;
            bool range = p.Words.Count > at && p.Words[at] == "range";
            List<DemoIf> targets = new List<DemoIf>();
            if (range)
            {
                string spec = p.Values[at + 1];
                List<string> errors = new List<string>();
                string cleaned = spec.Replace(" - ", "-").Replace(" -", "-").Replace("- ", "-");
                List<string> names = Ports.Expand(cleaned, errors);
                if (errors.Count > 0 || names.Count == 0) { Out("% Command rejected: Bad interface range command\r\n"); return; }
                int segments = cleaned.Split(',').Length;
                if (segments > 5) { Out("% Command rejected: Bad interface range command\r\n"); return; }
                foreach (string n in names)
                {
                    DemoIf i = st.Find(n);
                    if (i == null) { Out("% Command rejected: Bad interface range command\r\n"); return; }
                    targets.Add(i);
                }
                currentLabel = cleaned;
            }
            else
            {
                DemoIf i = st.Find(p.Values[at]);
                if (i == null)
                {
                    Out("                    ^\r\n% Invalid input detected at '^' marker.\r\n\r\n");
                    return;
                }
                targets.Add(i);
            }
            if (isDefault)
            {
                foreach (DemoIf i in targets)
                {
                    i.Lines.Clear();
                    if (i.Name == "Fa0") i.Lines.Add("no ip address");
                    Out("Interface " + Ports.Parse(i.Name).Long + " set to default configuration\r\n");
                }
                return;
            }
            current = targets;
            mode = range ? "range" : "if";
        }

        private void IfMode(ParseResult p, string text)
        {
            string w0 = p.Words[0];
            if (w0 == "exit") { mode = "config"; return; }
            if (w0 == "end") { mode = "enable"; return; }
            if (w0 == "interface" || w0 == "default") { Interfaces(p); return; }
            bool neg = w0 == "no";
            List<string> words = new List<string>(neg ? p.Values.GetRange(1, p.Values.Count - 1) : p.Values);
            string cmd = string.Join(" ", words.ToArray());
            foreach (DemoIf i in current)
            {
                if (i.Name == "Fa0" && cmd.StartsWith("switchport")) { Out("% Invalid input detected at '^' marker.\r\n"); return; }
                Apply(i, words, neg);
            }
        }

        private static readonly string[] ValueKeys =
        {
            "description", "switchport mode", "switchport access vlan", "switchport voice vlan", "switchport trunk native vlan",
            "switchport trunk allowed vlan", "switchport trunk encapsulation", "switchport port-security maximum",
            "switchport port-security violation", "spanning-tree portfast", "spanning-tree bpduguard", "spanning-tree guard",
            "speed", "duplex", "power inline", "storm-control broadcast level", "storm-control multicast level", "channel-group",
            "load-interval", "mls qos trust"
        };

        private void Apply(DemoIf i, List<string> words, bool neg)
        {
            string cmd = string.Join(" ", words.ToArray());
            string key = null;
            foreach (string k in ValueKeys) if (cmd == k || cmd.StartsWith(k + " ")) { if (key == null || k.Length > key.Length) key = k; }
            if (neg)
            {
                if (cmd == "switchport") { i.Lines.RemoveAll(delegate(string l) { return l.StartsWith("switchport"); }); return; }
                string k2 = key ?? cmd;
                i.Lines.RemoveAll(delegate(string l) { return l == k2 || l.StartsWith(k2 + " "); });
                if (cmd == "cdp enable") Insert(i, "no cdp enable");
                if (cmd == "lldp transmit" || cmd == "lldp receive") Insert(i, "no " + cmd);
                return;
            }
            if (cmd == "cdp enable") { i.Lines.Remove("no cdp enable"); return; }
            if (cmd == "lldp transmit" || cmd == "lldp receive") { i.Lines.Remove("no " + cmd); return; }
            if (cmd == "switchport") return;
            if (cmd == "spanning-tree bpduguard disable") { i.Lines.RemoveAll(delegate(string l) { return l.StartsWith("spanning-tree bpduguard"); }); return; }
            if (cmd == "speed auto" || cmd == "duplex auto" || cmd == "power inline auto")
            {
                string k3 = key;
                i.Lines.RemoveAll(delegate(string l) { return l.StartsWith(k3 + " "); });
                return;
            }
            if (key == "switchport trunk allowed vlan" && words.Count >= 5 && (words[4] == "add" || words[4] == "remove"))
            {
                string existing = Value(i, "switchport trunk allowed vlan");
                SortedSet<int> set = VlanSet(existing.Length == 0 ? "1-4094" : existing);
                SortedSet<int> delta = VlanSet(words.Count > 5 ? words[5] : "");
                if (words[4] == "add") set.UnionWith(delta); else set.ExceptWith(delta);
                cmd = "switchport trunk allowed vlan " + VlanText(set);
            }
            else if (key == "switchport trunk allowed vlan" && words.Count == 5 && words[4] == "all")
            {
                i.Lines.RemoveAll(delegate(string l) { return l.StartsWith("switchport trunk allowed vlan"); });
                return;
            }
            else if (key == "switchport trunk allowed vlan" && words.Count >= 5)
            {
                cmd = "switchport trunk allowed vlan " + (words[4] == "none" ? "none" : VlanText(VlanSet(words[4])));
            }
            if (key == "switchport access vlan" || key == "switchport voice vlan")
            {
                int v = int.Parse(words[words.Count - 1]);
                if (!st.Vlans.ContainsKey(v))
                {
                    st.Vlans[v] = "VLAN" + v.ToString("0000");
                    Out("% Access VLAN does not exist. Creating vlan " + v + "\r\n");
                }
            }
            if (key != null)
            {
                string k4 = key;
                i.Lines.RemoveAll(delegate(string l) { return l == k4 || l.StartsWith(k4 + " "); });
            }
            else if (i.Lines.Contains(cmd)) return;
            if (cmd == "shutdown" && !i.Lines.Contains("shutdown")) { i.Lines.Add("shutdown"); return; }
            Insert(i, cmd);
        }

        private static readonly string[] Order =
        {
            "description", "switchport trunk encapsulation", "switchport trunk native vlan", "switchport trunk allowed vlan",
            "switchport access vlan", "switchport mode", "switchport nonegotiate", "switchport voice vlan", "switchport port-security",
            "load-interval", "speed", "duplex", "power inline", "storm-control", "auto qos", "mls qos", "channel-group", "cdp", "lldp",
            "udld", "logging", "spanning-tree portfast", "spanning-tree bpduguard", "spanning-tree guard", "ip dhcp", "shutdown"
        };

        private static int Rank(string l)
        {
            string t = l.StartsWith("no ") ? l.Substring(3) : l;
            for (int k = 0; k < Order.Length; k++) if (t.StartsWith(Order[k])) return k;
            return Order.Length - 1;
        }

        private static void Insert(DemoIf i, string cmd)
        {
            int r = Rank(cmd);
            int at = i.Lines.Count;
            for (int k = 0; k < i.Lines.Count; k++) if (Rank(i.Lines[k]) > r) { at = k; break; }
            i.Lines.Insert(at, cmd);
        }

        private static SortedSet<int> VlanSet(string text)
        {
            SortedSet<int> s = new SortedSet<int>();
            foreach (string part in text.Split(','))
            {
                string[] ab = part.Split('-');
                int a, b;
                if (ab.Length == 1 && int.TryParse(ab[0], out a)) s.Add(a);
                else if (ab.Length == 2 && int.TryParse(ab[0], out a) && int.TryParse(ab[1], out b))
                    for (int v = a; v <= b && v <= 4094; v++) s.Add(v);
            }
            return s;
        }

        private static string VlanText(SortedSet<int> set)
        {
            List<string> parts = new List<string>();
            int start = -1, prev = -1;
            foreach (int v in set)
            {
                if (start < 0) { start = prev = v; continue; }
                if (v == prev + 1) { prev = v; continue; }
                parts.Add(start == prev ? start.ToString() : start + "-" + prev);
                start = prev = v;
            }
            if (start >= 0) parts.Add(start == prev ? start.ToString() : start + "-" + prev);
            return string.Join(",", parts.ToArray());
        }

        private void Complete()
        {
            string text = line.ToString();
            if (text.EndsWith(" ") || text.Length == 0) return;
            int lastSpace = text.LastIndexOf(' ');
            string before = lastSpace >= 0 ? text.Substring(0, lastSpace + 1) : "";
            string partial = text.Substring(lastSpace + 1);
            Node n = Tree(TreeMode);
            if (before.Trim().Length > 0)
            {
                ParseResult p = ParseCmd(before, n);
                if (p.Error == "invalid" || p.Last == null) return;
                n = p.Last;
            }
            string match = null;
            int count = 0;
            foreach (Node c in n.Next)
                if (c.Kind.Length == 0 && c.Word.StartsWith(partial, StringComparison.OrdinalIgnoreCase)) { match = c.Word; count++; }
            if (count != 1)
            {
                PortName pn = Ports.Parse(partial);
                if (pn == null) return;
                bool ifParam = false;
                foreach (Node c in n.Next) if (c.Kind == "if") ifParam = true;
                if (!ifParam) return;
                match = pn.Long;
            }
            string add = match + " ";
            for (int k = 0; k < partial.Length; k++) Out("\b");
            Out(add + new string(' ', Math.Max(0, partial.Length - add.Length)));
            if (partial.Length > add.Length) Out(new string('\b', partial.Length - add.Length));
            line.Length = before.Length;
            line.Append(add);
        }

        private void Help(string text)
        {
            Node n = Tree(TreeMode);
            string partial = "";
            if (!text.EndsWith(" ") && text.Length > 0)
            {
                int ls = text.LastIndexOf(' ');
                partial = text.Substring(ls + 1);
                text = ls >= 0 ? text.Substring(0, ls + 1) : "";
            }
            if (text.Trim().Length > 0)
            {
                ParseResult p = ParseCmd(text, n);
                if (p.Error == "invalid" || p.Last == null)
                {
                    Out("% Unrecognized command\r\n");
                    return;
                }
                n = p.Last;
            }
            List<string> rows = new List<string>();
            foreach (Node c in n.Next)
            {
                if (!c.Word.StartsWith(partial, StringComparison.OrdinalIgnoreCase) && c.Kind.Length == 0) continue;
                string label = c.Kind.Length == 0 ? c.Word : KindLabel(c.Kind);
                string help = c.Help.Length > 0 ? c.Help : HelpFor(c);
                rows.Add("  " + label.PadRight(22) + help);
            }
            if (partial.Length > 0 && rows.Count > 0)
            {
                StringBuilder sb = new StringBuilder();
                foreach (Node c in n.Next) if (c.Kind.Length == 0 && c.Word.StartsWith(partial, StringComparison.OrdinalIgnoreCase)) sb.Append(c.Word).Append("  ");
                Out(sb.ToString().TrimEnd() + "\r\n\r\n");
                return;
            }
            if (n.Final) rows.Add("  <cr>");
            Out(string.Join("\r\n", rows.ToArray()) + "\r\n\r\n");
        }

        private static string KindLabel(string kind)
        {
            switch (kind)
            {
                case "vlan": return "<1-4094>";
                case "num": return "<0-4294967295>";
                case "if": return "<interface>";
                case "range": return "<interface range>";
                case "vlans": return "WORD";
                default: return "LINE";
            }
        }

        private static string HelpFor(Node c)
        {
            foreach (Node k in c.Next) if (k.Help.Length > 0) return k.Help;
            return "";
        }

        public string RunScript(string text)
        {
            StringBuilder sb = new StringBuilder();
            Output = delegate(string s) { sb.Append(s); };
            Latency = 0;
            foreach (char c in text) Key(c);
            return sb.ToString();
        }

        public void BootSilently()
        {
            st = Factory(model);
            mode = "enable";
        }

        public DemoState State { get { return st; } }
    }
}
