using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

namespace SwitchDeck
{
    internal sealed class PortStatus
    {
        public string Port = "", Name = "", Status = "", Vlan = "", Duplex = "", Speed = "", Type = "";
    }

    internal static class Cisco
    {
        public static readonly Regex PromptRx = new Regex(@"^([A-Za-z0-9_.:\-/]{1,64})(\((config[^)]*)\))?([>#])\s?$", RegexOptions.Compiled);
        private static readonly Regex VarRx = new Regex(@"\{\{\s*([A-Za-z_][A-Za-z0-9_\-]*)\s*\}\}", RegexOptions.Compiled);
        private static readonly string[] StatusWords = { "connected", "notconnect", "disabled", "err-disabled", "inactive", "monitoring", "suspended", "sfpAbsent", "xcvrAbsent", "noXcvr", "faulty", "notpresent", "routed" };

        public static bool IsPrompt(string line)
        {
            if (line == null) return false;
            return PromptRx.IsMatch(line.TrimEnd());
        }

        public static string Mode(string promptLine)
        {
            Match m = PromptRx.Match((promptLine ?? "").TrimEnd());
            if (!m.Success) return "";
            if (m.Groups[3].Success) return m.Groups[3].Value;
            return m.Groups[4].Value == "#" ? "enable" : "user";
        }

        public static string Hostname(string promptLine)
        {
            Match m = PromptRx.Match((promptLine ?? "").TrimEnd());
            return m.Success ? m.Groups[1].Value : "";
        }

        public static bool IsError(string line)
        {
            string t = line.TrimStart();
            if (t.StartsWith("% ") || t.StartsWith("%Error") || t.StartsWith("%Invalid")) return !t.StartsWith("% Note") && !t.StartsWith("% Warning");
            return t.StartsWith("Command rejected") || t.StartsWith("Command authorization failed");
        }

        public static string FirstError(string output)
        {
            foreach (string l in SplitLines(output)) if (IsError(l)) return l.Trim();
            return null;
        }

        public static List<string> SplitLines(string text)
        {
            List<string> r = new List<string>();
            if (string.IsNullOrEmpty(text)) return r;
            foreach (string l in text.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n')) r.Add(l);
            return r;
        }

        public static List<PortStatus> ParseStatus(string output)
        {
            List<PortStatus> list = new List<PortStatus>();
            List<string> lines = SplitLines(output);
            int nameCol = -1, statusCol = -1;
            foreach (string raw in lines)
            {
                string line = raw.TrimEnd();
                if (line.Length == 0) continue;
                if (line.StartsWith("Port") && line.Contains("Status"))
                {
                    nameCol = line.IndexOf("Name", StringComparison.Ordinal);
                    statusCol = line.IndexOf("Status", StringComparison.Ordinal);
                    continue;
                }
                if (statusCol < 0) continue;
                int sp = line.IndexOf(' ');
                if (sp <= 0) continue;
                string port = line.Substring(0, sp);
                if (Ports.IsVirtual(port)) continue;
                string norm = Ports.Normalize(port);
                if (norm == null) continue;
                int at = FindStatus(line, statusCol);
                if (at < 0) continue;
                PortStatus s = new PortStatus();
                s.Port = norm;
                int ns = nameCol > sp ? nameCol : sp;
                s.Name = at > ns ? line.Substring(ns, at - ns).Trim() : "";
                string[] rest = line.Substring(at).Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                if (rest.Length > 0) s.Status = rest[0];
                if (rest.Length > 1) s.Vlan = rest[1];
                if (rest.Length > 2) s.Duplex = rest[2];
                if (rest.Length > 3) s.Speed = rest[3];
                if (rest.Length > 4) s.Type = string.Join(" ", rest, 4, rest.Length - 4);
                list.Add(s);
            }
            return list;
        }

        private static int FindStatus(string line, int col)
        {
            int best = -1, bestDist = int.MaxValue;
            foreach (string w in StatusWords)
            {
                int i = 0;
                while ((i = line.IndexOf(w, i, StringComparison.Ordinal)) >= 0)
                {
                    bool startOk = i == 0 || line[i - 1] == ' ';
                    int end = i + w.Length;
                    bool endOk = end >= line.Length || line[end] == ' ';
                    if (startOk && endOk)
                    {
                        int d = Math.Abs(i - col);
                        if (d < bestDist) { bestDist = d; best = i; }
                    }
                    i = end;
                }
            }
            return bestDist <= 24 ? best : -1;
        }

        public static string InterfaceBody(string output)
        {
            StringBuilder sb = new StringBuilder();
            bool inside = false;
            foreach (string raw in SplitLines(output))
            {
                string line = raw.TrimEnd();
                if (!inside)
                {
                    if (line.StartsWith("interface ", StringComparison.OrdinalIgnoreCase)) inside = true;
                    continue;
                }
                if (line == "end" || line == "!" || (line.Length > 0 && line[0] != ' ')) break;
                if (line.Trim().Length == 0) continue;
                if (sb.Length > 0) sb.Append('\n');
                sb.Append(line.Trim());
            }
            return sb.ToString();
        }

        public static List<string> Variables(string body)
        {
            List<string> r = new List<string>();
            foreach (Match m in VarRx.Matches(body ?? ""))
            {
                string n = m.Groups[1].Value;
                bool dup = false;
                foreach (string e in r) if (string.Equals(e, n, StringComparison.OrdinalIgnoreCase)) dup = true;
                if (!dup && !string.Equals(n, "port", StringComparison.OrdinalIgnoreCase)) r.Add(n);
            }
            return r;
        }

        public static bool UsesPort(string body)
        {
            foreach (Match m in VarRx.Matches(body ?? "")) if (string.Equals(m.Groups[1].Value, "port", StringComparison.OrdinalIgnoreCase)) return true;
            return false;
        }

        public static string Render(string line, Dictionary<string, string> values, string port)
        {
            return VarRx.Replace(line, delegate(Match m)
            {
                string n = m.Groups[1].Value;
                if (string.Equals(n, "port", StringComparison.OrdinalIgnoreCase)) return port ?? "";
                string v;
                if (values != null && values.TryGetValue(n, out v)) return v ?? "";
                return "";
            });
        }

        public static string Norm(string line)
        {
            return Regex.Replace((line ?? "").Trim().ToLowerInvariant(), @"\s+", " ");
        }

        public static string CheckApplied(List<string> expected, string after)
        {
            List<string> have = new List<string>();
            foreach (string l in SplitLines(after)) if (l.Trim().Length > 0) have.Add(Norm(l));
            List<string> missing = new List<string>();
            foreach (string e in expected)
            {
                string n = Norm(e);
                if (n.Length == 0) continue;
                if (n.StartsWith("default ") || n.StartsWith("do ") || n == "exit" || n == "end") continue;
                if (n == "no shutdown" || n == "no shut")
                {
                    if (have.Contains("shutdown")) missing.Add(e);
                    continue;
                }
                if (n.StartsWith("no "))
                {
                    string what = n.Substring(3);
                    foreach (string h in have) if (h == what || h.StartsWith(what + " ")) { missing.Add(e); break; }
                    continue;
                }
                if (n.StartsWith("shut")) n = "shutdown";
                if (!have.Contains(n)) missing.Add(e);
            }
            return missing.Count == 0 ? null : string.Join("\n", missing.ToArray());
        }

        public static string ShortIfName(string full)
        {
            string n = Ports.Normalize(full);
            return n ?? full;
        }
    }
}
