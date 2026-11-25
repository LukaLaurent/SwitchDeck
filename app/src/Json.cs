using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace SwitchDeck
{
    internal sealed class JObj : Dictionary<string, object>
    {
        public JObj() : base(StringComparer.Ordinal) { }

        public string Str(string key, string fallback)
        {
            object v;
            if (TryGetValue(key, out v) && v != null) return Convert.ToString(v, CultureInfo.InvariantCulture);
            return fallback;
        }

        public string Str(string key) { return Str(key, ""); }

        public int Int(string key, int fallback)
        {
            object v;
            if (TryGetValue(key, out v) && v is double) return (int)(double)v;
            int r;
            if (v is string && int.TryParse((string)v, out r)) return r;
            return fallback;
        }

        public bool Bool(string key, bool fallback)
        {
            object v;
            if (TryGetValue(key, out v) && v is bool) return (bool)v;
            return fallback;
        }

        public DateTime Date(string key)
        {
            DateTime d;
            if (DateTime.TryParse(Str(key), CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out d)) return d;
            return DateTime.MinValue;
        }

        public List<object> Arr(string key)
        {
            object v;
            if (TryGetValue(key, out v) && v is List<object>) return (List<object>)v;
            return new List<object>();
        }

        public JObj Obj(string key)
        {
            object v;
            if (TryGetValue(key, out v) && v is JObj) return (JObj)v;
            return new JObj();
        }

        public IEnumerable<JObj> Objs(string key)
        {
            foreach (object o in Arr(key)) if (o is JObj) yield return (JObj)o;
        }

        public List<string> Strs(string key)
        {
            List<string> r = new List<string>();
            foreach (object o in Arr(key)) if (o != null) r.Add(Convert.ToString(o, CultureInfo.InvariantCulture));
            return r;
        }
    }

    internal static class Json
    {
        public static object Parse(string s)
        {
            int i = 0;
            object v = Value(s, ref i);
            return v;
        }

        public static JObj ParseObj(string s)
        {
            if (string.IsNullOrWhiteSpace(s)) return new JObj();
            object v = Parse(s);
            return v as JObj ?? new JObj();
        }

        private static void Ws(string s, ref int i)
        {
            while (i < s.Length && char.IsWhiteSpace(s[i])) i++;
        }

        private static object Value(string s, ref int i)
        {
            Ws(s, ref i);
            if (i >= s.Length) throw new FormatException("Unexpected end");
            char c = s[i];
            if (c == '{')
            {
                JObj o = new JObj();
                i++;
                Ws(s, ref i);
                if (i < s.Length && s[i] == '}') { i++; return o; }
                while (true)
                {
                    Ws(s, ref i);
                    string key = Str(s, ref i);
                    Ws(s, ref i);
                    if (i >= s.Length || s[i] != ':') throw new FormatException("Expected : at " + i);
                    i++;
                    o[key] = Value(s, ref i);
                    Ws(s, ref i);
                    if (i < s.Length && s[i] == ',') { i++; continue; }
                    if (i < s.Length && s[i] == '}') { i++; return o; }
                    throw new FormatException("Expected , or } at " + i);
                }
            }
            if (c == '[')
            {
                List<object> a = new List<object>();
                i++;
                Ws(s, ref i);
                if (i < s.Length && s[i] == ']') { i++; return a; }
                while (true)
                {
                    a.Add(Value(s, ref i));
                    Ws(s, ref i);
                    if (i < s.Length && s[i] == ',') { i++; continue; }
                    if (i < s.Length && s[i] == ']') { i++; return a; }
                    throw new FormatException("Expected , or ] at " + i);
                }
            }
            if (c == '"') return Str(s, ref i);
            if (s.Length - i >= 4 && string.CompareOrdinal(s, i, "true", 0, 4) == 0) { i += 4; return true; }
            if (s.Length - i >= 5 && string.CompareOrdinal(s, i, "false", 0, 5) == 0) { i += 5; return false; }
            if (s.Length - i >= 4 && string.CompareOrdinal(s, i, "null", 0, 4) == 0) { i += 4; return null; }
            int start = i;
            while (i < s.Length && "+-0123456789.eE".IndexOf(s[i]) >= 0) i++;
            if (i == start) throw new FormatException("Unexpected character at " + i);
            return double.Parse(s.Substring(start, i - start), NumberStyles.Float, CultureInfo.InvariantCulture);
        }

        private static string Str(string s, ref int i)
        {
            if (s[i] != '"') throw new FormatException("Expected string at " + i);
            i++;
            StringBuilder sb = new StringBuilder();
            while (i < s.Length)
            {
                char c = s[i++];
                if (c == '"') return sb.ToString();
                if (c != '\\') { sb.Append(c); continue; }
                char e = s[i++];
                switch (e)
                {
                    case 'n': sb.Append('\n'); break;
                    case 'r': sb.Append('\r'); break;
                    case 't': sb.Append('\t'); break;
                    case 'b': sb.Append('\b'); break;
                    case 'f': sb.Append('\f'); break;
                    case 'u': sb.Append((char)int.Parse(s.Substring(i, 4), NumberStyles.HexNumber)); i += 4; break;
                    default: sb.Append(e); break;
                }
            }
            throw new FormatException("Unterminated string");
        }

        public static string Write(object v)
        {
            StringBuilder sb = new StringBuilder();
            Write(sb, v, 0);
            return sb.ToString();
        }

        private static void Indent(StringBuilder sb, int n)
        {
            sb.Append('\n');
            sb.Append(' ', n * 2);
        }

        private static void Write(StringBuilder sb, object v, int depth)
        {
            if (v == null) { sb.Append("null"); return; }
            if (v is string) { Quote(sb, (string)v); return; }
            if (v is bool) { sb.Append((bool)v ? "true" : "false"); return; }
            if (v is DateTime) { Quote(sb, ((DateTime)v).ToString("o", CultureInfo.InvariantCulture)); return; }
            if (v is int || v is long || v is double || v is float)
            {
                sb.Append(Convert.ToString(v, CultureInfo.InvariantCulture));
                return;
            }
            IDictionary d = v as IDictionary;
            if (d != null)
            {
                if (d.Count == 0) { sb.Append("{}"); return; }
                sb.Append('{');
                bool first = true;
                foreach (DictionaryEntry e in d)
                {
                    if (!first) sb.Append(',');
                    first = false;
                    Indent(sb, depth + 1);
                    Quote(sb, Convert.ToString(e.Key, CultureInfo.InvariantCulture));
                    sb.Append(": ");
                    Write(sb, e.Value, depth + 1);
                }
                Indent(sb, depth);
                sb.Append('}');
                return;
            }
            IEnumerable list = v as IEnumerable;
            if (list != null)
            {
                bool any = false;
                bool simple = true;
                foreach (object o in list)
                {
                    any = true;
                    if (o is IDictionary || (o is IEnumerable && !(o is string))) simple = false;
                }
                if (!any) { sb.Append("[]"); return; }
                sb.Append('[');
                bool first = true;
                foreach (object o in list)
                {
                    if (!first) sb.Append(simple ? ", " : ",");
                    first = false;
                    if (!simple) Indent(sb, depth + 1);
                    Write(sb, o, depth + 1);
                }
                if (!simple) Indent(sb, depth);
                sb.Append(']');
                return;
            }
            Quote(sb, v.ToString());
        }

        private static void Quote(StringBuilder sb, string s)
        {
            sb.Append('"');
            foreach (char c in s)
            {
                switch (c)
                {
                    case '"': sb.Append("\\\""); break;
                    case '\\': sb.Append("\\\\"); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    default:
                        if (c < 0x20) sb.Append("\\u").Append(((int)c).ToString("x4"));
                        else sb.Append(c);
                        break;
                }
            }
            sb.Append('"');
        }
    }
}
