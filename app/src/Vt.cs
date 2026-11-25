using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace SwitchDeck
{
    internal struct Cell
    {
        public char C;
        public byte Fg, Bg, A;
    }

    internal sealed class TermLine
    {
        public Cell[] Cells;
        public bool Wrapped;

        public TermLine(int cols) { Cells = new Cell[Math.Max(1, cols)]; Clear(0, Cells.Length, Vt.Default); }

        public void Ensure(int cols)
        {
            if (Cells.Length >= cols) return;
            int old = Cells.Length;
            Array.Resize(ref Cells, cols);
            Clear(old, cols, Vt.Default);
        }

        public void Clear(int from, int to, Cell blank)
        {
            to = Math.Min(to, Cells.Length);
            for (int i = Math.Max(0, from); i < to; i++) Cells[i] = blank;
        }

        public string Text(int cols)
        {
            int n = Math.Min(cols, Cells.Length);
            int end = n;
            while (end > 0 && (Cells[end - 1].C == '\0' || Cells[end - 1].C == ' ')) end--;
            StringBuilder sb = new StringBuilder(end);
            for (int i = 0; i < end; i++) sb.Append(Cells[i].C == '\0' ? ' ' : Cells[i].C);
            return sb.ToString();
        }
    }

    internal sealed class Vt
    {
        public const byte DefColor = 255;
        public const byte Bold = 1, Underline = 2, Inverse = 4, DimA = 8;
        public static readonly Cell Default = new Cell { C = '\0', Fg = DefColor, Bg = DefColor, A = 0 };

        private readonly object gate = new object();
        private List<TermLine> lines = new List<TermLine>();
        private List<TermLine> savedMain;
        private int savedMainRow, savedMainCol;
        private int rows, cols;
        private int row, col;
        private bool wrapPending;
        private int top, bottom;
        private byte fg = DefColor, bg = DefColor, attr;
        private int saveRow, saveCol;
        private byte saveFg = DefColor, saveBg = DefColor, saveAttr;
        private bool autoWrap = true, originMode, lineDraw, altScreen;
        private int state;
        private readonly StringBuilder seq = new StringBuilder();
        private readonly StringBuilder osc = new StringBuilder();
        private long trimmed;
        private long version;
        public int MaxScrollback = 8000;
        public bool CursorVisible = true;
        public bool AppCursorKeys;
        public bool BracketedPaste;
        public string Title = "";
        public event Action<string> Reply;

        public Vt(int cols, int rows)
        {
            this.cols = Math.Max(10, cols);
            this.rows = Math.Max(3, rows);
            for (int i = 0; i < this.rows; i++) lines.Add(new TermLine(this.cols));
            top = 0;
            bottom = this.rows - 1;
        }

        public object Gate { get { return gate; } }
        public int Rows { get { return rows; } }
        public int Cols { get { return cols; } }
        public long Version { get { lock (gate) return version; } }
        public long Trimmed { get { lock (gate) return trimmed; } }
        public int LineCount { get { lock (gate) return lines.Count; } }
        public bool AltScreen { get { lock (gate) return altScreen; } }

        private int ScreenTop { get { return lines.Count - rows; } }

        public long CursorAbs { get { lock (gate) return trimmed + ScreenTop + row; } }
        public int CursorCol { get { lock (gate) return col; } }
        public long FirstAbs { get { lock (gate) return trimmed; } }
        public long EndAbs { get { lock (gate) return trimmed + lines.Count; } }

        public TermLine LineAt(long abs)
        {
            long i = abs - trimmed;
            if (i < 0 || i >= lines.Count) return null;
            return lines[(int)i];
        }

        public string LineText(long abs)
        {
            lock (gate)
            {
                TermLine l = LineAt(abs);
                return l == null ? "" : l.Text(cols);
            }
        }

        public string CursorLineText()
        {
            lock (gate)
            {
                TermLine l = lines[ScreenTop + row];
                return l.Text(cols);
            }
        }

        public string Text(long fromAbs, long toAbs)
        {
            lock (gate)
            {
                StringBuilder sb = new StringBuilder();
                long from = Math.Max(fromAbs, trimmed);
                long to = Math.Min(toAbs, trimmed + lines.Count);
                for (long a = from; a < to; a++)
                {
                    TermLine l = lines[(int)(a - trimmed)];
                    sb.Append(l.Text(cols));
                    if (!l.Wrapped) sb.Append('\n');
                }
                return sb.ToString();
            }
        }

        public string SelectionText(long a1, int c1, long a2, int c2)
        {
            lock (gate)
            {
                if (a2 < a1 || (a2 == a1 && c2 < c1)) { long ta = a1; a1 = a2; a2 = ta; int tc = c1; c1 = c2; c2 = tc; }
                StringBuilder sb = new StringBuilder();
                for (long a = Math.Max(a1, trimmed); a <= a2 && a < trimmed + lines.Count; a++)
                {
                    TermLine l = lines[(int)(a - trimmed)];
                    string t = l.Text(cols);
                    int s = a == a1 ? Math.Min(c1, t.Length) : 0;
                    int e = a == a2 ? Math.Min(c2 + 1, t.Length) : t.Length;
                    if (e > s) sb.Append(t, s, e - s);
                    if (a != a2 && !l.Wrapped) sb.Append("\r\n");
                }
                return sb.ToString();
            }
        }

        public void Resize(int newCols, int newRows)
        {
            lock (gate)
            {
                newCols = Math.Max(10, newCols);
                newRows = Math.Max(3, newRows);
                if (newCols == cols && newRows == rows) return;
                long cursorAbs = ScreenTop + row;
                cols = newCols;
                if (newRows > rows)
                {
                    int need = newRows - lines.Count;
                    for (int i = 0; i < need; i++) lines.Add(new TermLine(cols));
                }
                else if (newRows < rows)
                {
                    int drop = rows - newRows;
                    while (drop > 0 && lines.Count > newRows && lines.Count - 1 > cursorAbs && lines[lines.Count - 1].Text(cols).Length == 0)
                    {
                        lines.RemoveAt(lines.Count - 1);
                        drop--;
                    }
                }
                rows = newRows;
                while (lines.Count < rows) lines.Add(new TermLine(cols));
                row = (int)Math.Max(0, Math.Min(rows - 1, cursorAbs - ScreenTop));
                col = Math.Min(col, cols - 1);
                top = 0;
                bottom = rows - 1;
                wrapPending = false;
                version++;
            }
        }

        public void Clear()
        {
            lock (gate)
            {
                TermLine cur = lines[ScreenTop + row];
                lines.Clear();
                for (int i = 0; i < rows - 1; i++) lines.Add(new TermLine(cols));
                lines.Add(cur);
                trimmed = 0;
                row = rows - 1;
                version++;
            }
        }

        public void Feed(string s)
        {
            lock (gate)
            {
                foreach (char ch in s) Put(ch);
                version++;
            }
        }

        private void Put(char ch)
        {
            switch (state)
            {
                case 0:
                    if (ch == '\x1b') { state = 1; return; }
                    if (ch < ' ' || ch == '\x7f') { Control(ch); return; }
                    Print(ch);
                    return;
                case 1:
                    Escape(ch);
                    return;
                case 2:
                    if (ch >= '@' && ch <= '~' && !(seq.Length == 0 && (ch == '?' || ch == '>' || ch == '=' || ch == '<')))
                    {
                        Csi(seq.ToString(), ch);
                        seq.Length = 0;
                        state = 0;
                    }
                    else if (ch == '\x1b') { seq.Length = 0; state = 1; }
                    else if (ch < ' ') Control(ch);
                    else if (seq.Length < 64) seq.Append(ch);
                    return;
                case 3:
                    if (ch == '\x07') { EndOsc(); return; }
                    if (ch == '\x1b') { state = 4; return; }
                    if (osc.Length < 512) osc.Append(ch);
                    return;
                case 4:
                    if (ch == '\\') EndOsc(); else { state = 3; }
                    return;
                case 5:
                    lineDraw = ch == '0';
                    state = 0;
                    return;
                case 6:
                    state = 0;
                    return;
            }
        }

        private void EndOsc()
        {
            string o = osc.ToString();
            osc.Length = 0;
            state = 0;
            int semi = o.IndexOf(';');
            if (semi > 0)
            {
                string code = o.Substring(0, semi);
                if (code == "0" || code == "2") Title = o.Substring(semi + 1);
            }
        }

        private void Control(char ch)
        {
            switch (ch)
            {
                case '\r': col = 0; wrapPending = false; break;
                case '\n':
                case '\x0b':
                case '\x0c': LineFeed(); break;
                case '\b': if (col > 0) col--; wrapPending = false; break;
                case '\t':
                    {
                        int next = (col / 8 + 1) * 8;
                        col = Math.Min(cols - 1, next);
                        break;
                    }
                case '\x07': break;
                case '\x0e': lineDraw = true; break;
                case '\x0f': lineDraw = false; break;
            }
        }

        private void Escape(char ch)
        {
            state = 0;
            switch (ch)
            {
                case '[': state = 2; seq.Length = 0; break;
                case ']': state = 3; osc.Length = 0; break;
                case '(': state = 5; break;
                case ')': case '*': case '+': case '#': case '%': state = 6; break;
                case '7': SaveCursor(); break;
                case '8': RestoreCursor(); break;
                case 'D': LineFeed(); break;
                case 'E': col = 0; LineFeed(); break;
                case 'M': ReverseIndex(); break;
                case 'c': ResetAll(); break;
                case '=': case '>': break;
                case 'P': case '^': case '_': state = 3; osc.Length = 0; break;
            }
        }

        private void ResetAll()
        {
            fg = bg = DefColor; attr = 0;
            top = 0; bottom = rows - 1;
            autoWrap = true; originMode = false; lineDraw = false;
            EraseDisplay(2);
            row = col = 0;
        }

        private TermLine Cur
        {
            get
            {
                TermLine l = lines[ScreenTop + row];
                l.Ensure(cols);
                return l;
            }
        }

        private Cell Blank
        {
            get { Cell c = Default; c.Bg = bg; return c; }
        }

        private static char LineDrawChar(char ch)
        {
            switch (ch)
            {
                case 'j': return '┘';
                case 'k': return '┐';
                case 'l': return '┌';
                case 'm': return '└';
                case 'n': return '┼';
                case 'q': return '─';
                case 't': return '├';
                case 'u': return '┤';
                case 'v': return '┴';
                case 'w': return '┬';
                case 'x': return '│';
                case 'a': return '▒';
                case '`': return '◆';
                case '~': return '·';
                default: return ch;
            }
        }

        private void Print(char ch)
        {
            if (lineDraw) ch = LineDrawChar(ch);
            if (wrapPending)
            {
                if (autoWrap)
                {
                    Cur.Wrapped = true;
                    col = 0;
                    LineFeed();
                }
                wrapPending = false;
            }
            TermLine l = Cur;
            Cell c;
            c.C = ch;
            c.Fg = fg;
            c.Bg = bg;
            c.A = attr;
            l.Cells[col] = c;
            if (col >= cols - 1) wrapPending = true;
            else col++;
        }

        private void LineFeed()
        {
            wrapPending = false;
            if (row == bottom) ScrollUp(1);
            else if (row < rows - 1) row++;
        }

        private void ReverseIndex()
        {
            wrapPending = false;
            if (row == top) ScrollDown(1);
            else if (row > 0) row--;
        }

        private void ScrollUp(int n)
        {
            for (int k = 0; k < n; k++)
            {
                if (top == 0 && bottom == rows - 1 && !altScreen)
                {
                    TermLine nl = new TermLine(cols);
                    if (bg != DefColor) nl.Clear(0, cols, Blank);
                    lines.Add(nl);
                    Trim();
                }
                else
                {
                    int st = ScreenTop;
                    lines.RemoveAt(st + top);
                    TermLine nl = new TermLine(cols);
                    lines.Insert(st + bottom, nl);
                }
            }
        }

        private void ScrollDown(int n)
        {
            for (int k = 0; k < n; k++)
            {
                int st = ScreenTop;
                lines.RemoveAt(st + bottom);
                lines.Insert(st + top, new TermLine(cols));
            }
        }

        private void Trim()
        {
            int max = MaxScrollback + rows;
            if (lines.Count > max + 200)
            {
                int drop = lines.Count - max;
                lines.RemoveRange(0, drop);
                trimmed += drop;
            }
        }

        private void SaveCursor()
        {
            saveRow = row; saveCol = col; saveFg = fg; saveBg = bg; saveAttr = attr;
        }

        private void RestoreCursor()
        {
            row = Math.Min(saveRow, rows - 1); col = Math.Min(saveCol, cols - 1); fg = saveFg; bg = saveBg; attr = saveAttr;
            wrapPending = false;
        }

        private static int Arg(string[] a, int i, int def)
        {
            if (i >= a.Length || a[i].Length == 0) return def;
            int v;
            return int.TryParse(a[i], NumberStyles.None, CultureInfo.InvariantCulture, out v) ? v : def;
        }

        private void Csi(string p, char final)
        {
            bool priv = p.StartsWith("?");
            if (priv || p.StartsWith(">") || p.StartsWith("=")) p = p.Substring(1);
            int sp = p.IndexOf(' ');
            if (sp >= 0) p = p.Substring(0, sp);
            string[] a = p.Length == 0 ? new string[0] : p.Split(';');
            int n = Math.Max(1, Arg(a, 0, 1));
            switch (final)
            {
                case 'A': row = Math.Max(row < top ? 0 : top, row - n); wrapPending = false; break;
                case 'B': row = Math.Min(row > bottom ? rows - 1 : bottom, row + n); wrapPending = false; break;
                case 'C': col = Math.Min(cols - 1, col + n); wrapPending = false; break;
                case 'D': col = Math.Max(0, col - n); wrapPending = false; break;
                case 'E': row = Math.Min(rows - 1, row + n); col = 0; wrapPending = false; break;
                case 'F': row = Math.Max(0, row - n); col = 0; wrapPending = false; break;
                case 'G': case '`': col = Math.Max(0, Math.Min(cols - 1, n - 1)); wrapPending = false; break;
                case 'd': row = Math.Max(0, Math.Min(rows - 1, n - 1 + (originMode ? top : 0))); wrapPending = false; break;
                case 'H':
                case 'f':
                    {
                        int r = Math.Max(1, Arg(a, 0, 1)) - 1 + (originMode ? top : 0);
                        int c = Math.Max(1, Arg(a, 1, 1)) - 1;
                        row = Math.Max(0, Math.Min(rows - 1, r));
                        col = Math.Max(0, Math.Min(cols - 1, c));
                        wrapPending = false;
                        break;
                    }
                case 'J': EraseDisplay(Arg(a, 0, 0)); break;
                case 'K': EraseLine(Arg(a, 0, 0)); break;
                case 'X': Cur.Clear(col, col + n, Blank); break;
                case '@':
                    {
                        TermLine l = Cur;
                        for (int i = cols - 1; i >= col + n; i--) l.Cells[i] = l.Cells[i - n];
                        l.Clear(col, Math.Min(cols, col + n), Blank);
                        break;
                    }
                case 'P':
                    {
                        TermLine l = Cur;
                        for (int i = col; i < cols; i++) l.Cells[i] = i + n < cols ? l.Cells[i + n] : Blank;
                        break;
                    }
                case 'L':
                    if (row >= top && row <= bottom)
                        for (int k = 0; k < n; k++)
                        {
                            int st = ScreenTop;
                            lines.RemoveAt(st + bottom);
                            lines.Insert(st + row, new TermLine(cols));
                        }
                    break;
                case 'M':
                    if (row >= top && row <= bottom)
                        for (int k = 0; k < n; k++)
                        {
                            int st = ScreenTop;
                            lines.RemoveAt(st + row);
                            lines.Insert(st + bottom, new TermLine(cols));
                        }
                    break;
                case 'S': ScrollUp(n); break;
                case 'T': if (!priv) ScrollDown(n); break;
                case 'm': Sgr(a); break;
                case 'r':
                    {
                        int t = Math.Max(1, Arg(a, 0, 1)) - 1;
                        int b = Arg(a, 1, rows) - 1;
                        if (b > rows - 1 || b <= 0) b = rows - 1;
                        if (t < b) { top = t; bottom = b; }
                        row = originMode ? top : 0;
                        col = 0;
                        break;
                    }
                case 's': SaveCursor(); break;
                case 'u': RestoreCursor(); break;
                case 'h': case 'l': Mode(a, priv, final == 'h'); break;
                case 'n':
                    if (Arg(a, 0, 0) == 6) Send("\x1b[" + (row + 1) + ";" + (col + 1) + "R");
                    else if (Arg(a, 0, 0) == 5) Send("\x1b[0n");
                    break;
                case 'c':
                    if (!priv) Send("\x1b[?1;2c");
                    break;
                case 't': break;
            }
        }

        private void Send(string s)
        {
            Action<string> r = Reply;
            if (r != null) r(s);
        }

        private void Mode(string[] a, bool priv, bool on)
        {
            foreach (string s in a)
            {
                int m = Arg(new[] { s }, 0, -1);
                if (!priv) continue;
                switch (m)
                {
                    case 1: AppCursorKeys = on; break;
                    case 6: originMode = on; row = on ? top : 0; col = 0; break;
                    case 7: autoWrap = on; break;
                    case 25: CursorVisible = on; break;
                    case 2004: BracketedPaste = on; break;
                    case 47:
                    case 1047:
                    case 1049:
                        SetAlt(on);
                        break;
                }
            }
        }

        private void SetAlt(bool on)
        {
            if (on == altScreen) return;
            if (on)
            {
                savedMain = lines;
                savedMainRow = row; savedMainCol = col;
                lines = new List<TermLine>();
                for (int i = 0; i < rows; i++) lines.Add(new TermLine(cols));
                altScreen = true;
                row = col = 0;
            }
            else
            {
                lines = savedMain ?? new List<TermLine>();
                while (lines.Count < rows) lines.Add(new TermLine(cols));
                savedMain = null;
                altScreen = false;
                row = Math.Min(savedMainRow, rows - 1); col = Math.Min(savedMainCol, cols - 1);
            }
            top = 0; bottom = rows - 1;
        }

        private void Sgr(string[] a)
        {
            if (a.Length == 0) { fg = bg = DefColor; attr = 0; return; }
            for (int i = 0; i < a.Length; i++)
            {
                int v = Arg(a, i, 0);
                if (v == 0) { fg = bg = DefColor; attr = 0; }
                else if (v == 1) attr |= Bold;
                else if (v == 2) attr |= DimA;
                else if (v == 4) attr |= Underline;
                else if (v == 7) attr |= Inverse;
                else if (v == 22) attr &= unchecked((byte)~(Bold | DimA));
                else if (v == 24) attr &= unchecked((byte)~Underline);
                else if (v == 27) attr &= unchecked((byte)~Inverse);
                else if (v >= 30 && v <= 37) fg = (byte)(v - 30);
                else if (v == 39) fg = DefColor;
                else if (v >= 40 && v <= 47) bg = (byte)(v - 40);
                else if (v == 49) bg = DefColor;
                else if (v >= 90 && v <= 97) fg = (byte)(v - 90 + 8);
                else if (v >= 100 && v <= 107) bg = (byte)(v - 100 + 8);
                else if (v == 38 || v == 48)
                {
                    byte c = DefColor;
                    if (Arg(a, i + 1, 0) == 5) { c = Map256(Arg(a, i + 2, 0)); i += 2; }
                    else if (Arg(a, i + 1, 0) == 2) { c = MapRgb(Arg(a, i + 2, 0), Arg(a, i + 3, 0), Arg(a, i + 4, 0)); i += 4; }
                    if (v == 38) fg = c; else bg = c;
                }
            }
        }

        private static byte Map256(int n)
        {
            if (n < 16) return (byte)n;
            if (n >= 232)
            {
                int g = (n - 232) * 10 + 8;
                return MapRgb(g, g, g);
            }
            n -= 16;
            int r = n / 36, gg = (n / 6) % 6, b = n % 6;
            return MapRgb(r == 0 ? 0 : r * 40 + 55, gg == 0 ? 0 : gg * 40 + 55, b == 0 ? 0 : b * 40 + 55);
        }

        private static readonly int[] Std = { 0x000000, 0xCD0000, 0x00CD00, 0xCDCD00, 0x0000EE, 0xCD00CD, 0x00CDCD, 0xE5E5E5,
                                              0x7F7F7F, 0xFF0000, 0x00FF00, 0xFFFF00, 0x5C5CFF, 0xFF00FF, 0x00FFFF, 0xFFFFFF };

        private static byte MapRgb(int r, int g, int b)
        {
            int best = 7;
            long bestD = long.MaxValue;
            for (int i = 0; i < 16; i++)
            {
                int cr = (Std[i] >> 16) & 255, cg = (Std[i] >> 8) & 255, cb = Std[i] & 255;
                long d = (long)(cr - r) * (cr - r) + (long)(cg - g) * (cg - g) + (long)(cb - b) * (cb - b);
                if (d < bestD) { bestD = d; best = i; }
            }
            return (byte)best;
        }

        private void EraseLine(int mode)
        {
            TermLine l = Cur;
            if (mode == 0) { l.Clear(col, cols, Blank); l.Wrapped = false; }
            else if (mode == 1) l.Clear(0, col + 1, Blank);
            else { l.Clear(0, cols, Blank); l.Wrapped = false; }
        }

        private void EraseDisplay(int mode)
        {
            int st = ScreenTop;
            if (mode == 0)
            {
                EraseLine(0);
                for (int r = row + 1; r < rows; r++) { lines[st + r] = new TermLine(cols); }
            }
            else if (mode == 1)
            {
                EraseLine(1);
                for (int r = 0; r < row; r++) lines[st + r] = new TermLine(cols);
            }
            else if (mode == 2 || mode == 3)
            {
                if (mode == 3 && !altScreen)
                {
                    int drop = ScreenTop;
                    lines.RemoveRange(0, drop);
                    trimmed += drop;
                    st = 0;
                }
                bool any = false;
                if (!altScreen && mode == 2)
                    for (int r = 0; r < rows; r++) if (lines[st + r].Text(cols).Length > 0) { any = true; break; }
                if (any)
                {
                    for (int r = 0; r < rows; r++) lines.Add(new TermLine(cols));
                    Trim();
                }
                else
                {
                    st = ScreenTop;
                    for (int r = 0; r < rows; r++) lines[st + r] = new TermLine(cols);
                }
            }
        }
    }
}
