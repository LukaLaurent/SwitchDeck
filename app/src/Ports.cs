using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace SwitchDeck
{
    internal sealed class PortName : IComparable<PortName>
    {
        public string Type = "";
        public string Prefix = "";
        public int Number;
        public int[] Parts = new int[0];

        public string Short { get { return Type + Prefix + Number.ToString(CultureInfo.InvariantCulture); } }
        public string Long { get { return Ports.LongType(Type) + Prefix + Number.ToString(CultureInfo.InvariantCulture); } }
        public string GroupKey { get { return Type + Prefix; } }
        public int Member { get { return Parts.Length > 1 ? Parts[0] : 1; } }

        public int CompareTo(PortName o)
        {
            int m = Member.CompareTo(o.Member);
            if (m != 0) return m;
            int ta = Ports.TypeOrder(Type), tb = Ports.TypeOrder(o.Type);
            if (ta != tb) return ta.CompareTo(tb);
            int n = Math.Min(Parts.Length, o.Parts.Length);
            for (int i = 0; i < n; i++) if (Parts[i] != o.Parts[i]) return Parts[i].CompareTo(o.Parts[i]);
            return Parts.Length.CompareTo(o.Parts.Length);
        }
    }

    internal static class Ports
    {
        private static readonly string[][] Types =
        {
            new[] { "Fa", "FastEthernet" },
            new[] { "Gi", "GigabitEthernet" },
            new[] { "Tw", "TwoGigabitEthernet" },
            new[] { "Fi", "FiveGigabitEthernet" },
            new[] { "Te", "TenGigabitEthernet" },
            new[] { "Twe", "TwentyFiveGigE" },
            new[] { "Fo", "FortyGigabitEthernet" },
            new[] { "Hu", "HundredGigE" },
            new[] { "Ap", "AppGigabitEthernet" },
            new[] { "Et", "Ethernet" },
            new[] { "Po", "Port-channel" },
        };

        private static readonly string[] Virtual = { "vl", "vlan", "lo", "loopback", "tu", "tunnel", "nu", "null", "bd", "bdi", "mgmt" };

        private static readonly Regex NameRx = new Regex(@"^\s*([A-Za-z][A-Za-z\-]*)\s*(\d+(?:/\d+)*)\s*$", RegexOptions.Compiled);
        private static readonly Regex RangeRx = new Regex(@"^\s*([A-Za-z][A-Za-z\-]*)\s*((?:\d+/)*)(\d+)\s*-\s*(?:([A-Za-z][A-Za-z\-]*)\s*((?:\d+/)*))?(\d+)\s*$", RegexOptions.Compiled);

        public static string LongType(string shortType)
        {
            foreach (string[] t in Types) if (t[0] == shortType) return t[1];
            return shortType;
        }

        public static int TypeOrder(string shortType)
        {
            for (int i = 0; i < Types.Length; i++) if (Types[i][0] == shortType) return i;
            return 99;
        }

        public static string ResolveType(string word)
        {
            if (string.IsNullOrEmpty(word)) return null;
            string w = word.Trim();
            foreach (string[] t in Types) if (string.Equals(t[0], w, StringComparison.OrdinalIgnoreCase)) return t[0];
            foreach (string[] t in Types) if (string.Equals(t[1], w, StringComparison.OrdinalIgnoreCase)) return t[0];
            string found = null;
            foreach (string[] t in Types)
            {
                if (t[1].StartsWith(w, StringComparison.OrdinalIgnoreCase))
                {
                    if (found != null && found != t[0]) return null;
                    found = t[0];
                }
            }
            return found;
        }

        public static bool IsVirtual(string word)
        {
            Match m = Regex.Match(word ?? "", @"^[A-Za-z\-]+");
            string w = m.Value.ToLowerInvariant();
            foreach (string v in Virtual) if (w == v || (w.Length >= 2 && v.StartsWith(w))) return true;
            return false;
        }

        public static PortName Parse(string text)
        {
            if (string.IsNullOrEmpty(text)) return null;
            Match m = NameRx.Match(text);
            if (!m.Success) return null;
            string type = ResolveType(m.Groups[1].Value);
            if (type == null) return null;
            return Make(type, m.Groups[2].Value);
        }

        private static PortName Make(string type, string numbers)
        {
            string[] bits = numbers.Split('/');
            PortName p = new PortName();
            p.Type = type;
            p.Parts = new int[bits.Length];
            for (int i = 0; i < bits.Length; i++)
            {
                int v;
                if (!int.TryParse(bits[i], NumberStyles.None, CultureInfo.InvariantCulture, out v)) return null;
                p.Parts[i] = v;
            }
            p.Number = p.Parts[p.Parts.Length - 1];
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < bits.Length - 1; i++) sb.Append(p.Parts[i].ToString(CultureInfo.InvariantCulture)).Append('/');
            p.Prefix = sb.ToString();
            return p;
        }

        public static string Normalize(string text)
        {
            PortName p = Parse(text);
            return p == null ? null : p.Short;
        }

        public static List<string> Expand(string spec, List<string> errors)
        {
            List<string> result = new List<string>();
            HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if (string.IsNullOrWhiteSpace(spec)) return result;
            string lastType = null;
            foreach (string rawPart in spec.Split(new[] { ',', ';', '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries))
            {
                string part = rawPart.Trim();
                if (part.Length == 0) continue;
                if (char.IsDigit(part[0]) && lastType != null && part.IndexOf('/') < 0) part = lastType + part;
                else if (char.IsDigit(part[0]) && lastType != null) part = Regex.Match(lastType, @"^[A-Za-z\-]+").Value + part;
                Match r = RangeRx.Match(part);
                if (r.Success)
                {
                    string type = ResolveType(r.Groups[1].Value);
                    string prefix = r.Groups[2].Value;
                    if (r.Groups[4].Success && r.Groups[4].Value.Length > 0)
                    {
                        string type2 = ResolveType(r.Groups[4].Value);
                        if (type2 != type || (r.Groups[5].Value.Length > 0 && r.Groups[5].Value != prefix)) type = null;
                    }
                    else if (r.Groups[5].Value.Length > 0 && r.Groups[5].Value != prefix) type = null;
                    int a = int.Parse(r.Groups[3].Value, CultureInfo.InvariantCulture);
                    int b = int.Parse(r.Groups[6].Value, CultureInfo.InvariantCulture);
                    if (type == null || b < a || b - a > 512)
                    {
                        if (errors != null) errors.Add(part);
                        continue;
                    }
                    lastType = type + prefix;
                    for (int i = a; i <= b; i++)
                    {
                        PortName p = Make(type, prefix + i.ToString(CultureInfo.InvariantCulture));
                        if (p != null && seen.Add(p.Short)) result.Add(p.Short);
                    }
                    continue;
                }
                PortName one = Parse(part);
                if (one == null)
                {
                    if (errors != null) errors.Add(part);
                    continue;
                }
                lastType = one.Type + one.Prefix;
                if (seen.Add(one.Short)) result.Add(one.Short);
            }
            return result;
        }

        public static List<string> Sorted(IEnumerable<string> names)
        {
            List<PortName> list = new List<PortName>();
            List<string> bad = new List<string>();
            foreach (string n in names)
            {
                PortName p = Parse(n);
                if (p != null) list.Add(p); else bad.Add(n);
            }
            list.Sort();
            List<string> r = new List<string>();
            foreach (PortName p in list) r.Add(p.Short);
            r.AddRange(bad);
            return r;
        }

        public static List<string> Segments(IEnumerable<string> names, bool iosStyle)
        {
            List<PortName> list = new List<PortName>();
            foreach (string n in names)
            {
                PortName p = Parse(n);
                if (p != null) list.Add(p);
            }
            list.Sort();
            List<string> segs = new List<string>();
            int i = 0;
            while (i < list.Count)
            {
                int j = i;
                while (j + 1 < list.Count && list[j + 1].GroupKey == list[i].GroupKey && list[j + 1].Number == list[j].Number + 1) j++;
                if (j == i) segs.Add(list[i].Short);
                else segs.Add(list[i].Short + (iosStyle ? " - " : "-") + list[j].Number.ToString(CultureInfo.InvariantCulture));
                i = j + 1;
            }
            return segs;
        }

        public static string Compact(IEnumerable<string> names)
        {
            return string.Join(", ", Segments(names, false).ToArray());
        }

        public static List<string> RangeCommands(IEnumerable<string> names)
        {
            List<string> segs = Segments(names, true);
            List<string> cmds = new List<string>();
            for (int i = 0; i < segs.Count; i += 5)
            {
                int n = Math.Min(5, segs.Count - i);
                cmds.Add(string.Join(" , ", segs.GetRange(i, n).ToArray()));
            }
            return cmds;
        }

        public static string Speed(string type)
        {
            switch (type)
            {
                case "Fa": return "100M";
                case "Gi": return "1G";
                case "Tw": return "2.5G";
                case "Fi": return "5G";
                case "Te": return "10G";
                case "Twe": return "25G";
                case "Fo": return "40G";
                case "Hu": return "100G";
                default: return "";
            }
        }
    }
}
