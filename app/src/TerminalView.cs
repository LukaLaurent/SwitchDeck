using System;
using System.Collections.Generic;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal sealed class TerminalView : Control
    {
        private Session session;
        private readonly System.Windows.Forms.Timer tick;
        private readonly System.Windows.Forms.Timer resize;
        private long seenVersion = -1;
        private int cellW;
        private int cellH;
        private Font font, fontBold;
        private int back;
        private bool blink = true;
        private int blinkCount;
        private bool selecting, hasSel;
        private long selA, selB;
        private int selCA, selCB;
        private bool draggingBar;
        private int barStart, barOffset;
        public event Action FontChanged2;

        public TerminalView()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
            Cursor = Cursors.IBeam;
            TabStop = true;
            tick = new System.Windows.Forms.Timer();
            tick.Interval = 16;
            tick.Tick += OnTick;
            tick.Start();
            resize = new System.Windows.Forms.Timer();
            resize.Interval = 140;
            resize.Tick += delegate { resize.Stop(); ApplySize(); };
            SetFont();
        }

        public Session Session
        {
            get { return session; }
            set
            {
                session = value;
                back = 0;
                hasSel = false;
                seenVersion = -1;
                ScheduleResize();
                Invalidate();
            }
        }

        public void SetFont()
        {
            float px = Store.Settings.TermFontSize * Ui.Sc;
            font = Fonts.Mono(px);
            fontBold = Fonts.MonoBold(px);
            FreeFonts();
            hFont = font.ToHfont();
            hFontBold = fontBold.ToHfont();
            Size s = TextRenderer.MeasureText("MMMMMMMMMMMMMMMMMMMM", font, Size.Empty, TextFormatFlags.NoPadding | TextFormatFlags.SingleLine);
            cellW = Math.Max(1, (int)Math.Round(s.Width / 20f));
            cellH = Math.Max(1, font.Height + (int)Math.Round(Ui.Sc));
            ScheduleResize();
            Invalidate();
        }

        private IntPtr hFont, hFontBold;

        private void FreeFonts()
        {
            if (hFont != IntPtr.Zero) { Gdi.DeleteObject(hFont); hFont = IntPtr.Zero; }
            if (hFontBold != IntPtr.Zero) { Gdi.DeleteObject(hFontBold); hFontBold = IntPtr.Zero; }
        }

        private int PadX { get { return Ui.D(8); } }
        private int PadY { get { return Ui.D(6); } }

        public int ColsFit { get { return Math.Max(20, (Width - PadX * 2 - Ui.D(8)) / Math.Max(1, cellW)); } }
        public int RowsFit { get { return Math.Max(5, (Height - PadY * 2) / Math.Max(1, cellH)); } }

        private void ScheduleResize()
        {
            resize.Stop();
            resize.Start();
        }

        private void ApplySize()
        {
            if (session == null || Width < 50 || Height < 50) return;
            if (session.Term.Cols != ColsFit || session.Term.Rows != RowsFit) session.Resize(ColsFit, RowsFit);
            Invalidate();
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            ScheduleResize();
        }

        private void OnTick(object sender, EventArgs e)
        {
            if (session == null) return;
            long v = session.Term.Version;
            if (v != seenVersion)
            {
                seenVersion = v;
                if (back > 0 && !selecting && !draggingBar) back = 0;
                Invalidate();
            }
            if (++blinkCount >= 33)
            {
                blinkCount = 0;
                blink = !blink;
                if (Focused) Invalidate();
            }
        }

        private Color Fg(byte c, bool bold)
        {
            TermPalette t = Theme.T;
            if (c == Vt.DefColor) return t.Fg;
            if (bold && c < 8) c = (byte)(c + 8);
            return t.Ansi[c % 16];
        }

        private Color Bg(byte c)
        {
            TermPalette t = Theme.T;
            if (c == Vt.DefColor) return t.Bg;
            return t.Ansi[c % 16];
        }

        private long TopAbs(Vt vt)
        {
            long end = vt.EndAbs;
            long top = end - vt.Rows - back;
            return Math.Max(vt.FirstAbs, top);
        }

        private static int Ref(Color c) { return c.R | (c.G << 8) | (c.B << 16); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            TermPalette tp = Theme.T;
            g.Clear(tp.Bg);
            if (session == null) return;
            Vt vt = session.Term;
            int rows, cols, cursorCol;
            long top, cursorAbs, total;
            bool cursorVisible;
            Cell[][] snap;
            lock (vt.Gate)
            {
                rows = vt.Rows;
                cols = vt.Cols;
                back = (int)Math.Max(0, Math.Min(back, vt.EndAbs - vt.Rows - vt.FirstAbs));
                top = TopAbs(vt);
                cursorAbs = vt.CursorAbs;
                cursorCol = vt.CursorCol;
                cursorVisible = vt.CursorVisible;
                total = vt.EndAbs - vt.FirstAbs;
                snap = new Cell[rows][];
                for (int r = 0; r < rows; r++)
                {
                    TermLine line = vt.LineAt(top + r);
                    if (line == null) continue;
                    int n = Math.Min(cols, line.Cells.Length);
                    Cell[] copy = new Cell[n];
                    Array.Copy(line.Cells, copy, n);
                    snap[r] = copy;
                }
            }
            long sa = selA, sb = selB;
            int sca = selCA, scb = selCB;
            if (sb < sa || (sb == sa && scb < sca)) { long t = sa; sa = sb; sb = t; int tc = sca; sca = scb; scb = tc; }
            bool showCursor = cursorVisible && session.State != SessionState.Closed && cursorAbs - top >= 0 && cursorAbs - top < rows;
            int cr = (int)(cursorAbs - top);
            bool solidCursor = showCursor && Focused && blink && !session.Busy;
            List<Rectangle> underlines = null;
            List<Color> underlineColors = null;
            int defBg = Ref(tp.Bg);
            IntPtr hdc = g.GetHdc();
            try
            {
                IntPtr oldFont = Gdi.SelectObject(hdc, hFont);
                Gdi.SetBkMode(hdc, 2);
                char[] buf = new char[Math.Max(cols, 1) + 1];
                int[] dx = new int[Math.Max(cols, 1) + 1];
                for (int i = 0; i < dx.Length; i++) dx[i] = cellW;
                IntPtr curFont = hFont;
                for (int r = 0; r < rows; r++)
                {
                    Cell[] line = snap[r];
                    if (line == null) continue;
                    long abs = top + r;
                    int y = PadY + r * cellH;
                    int n = line.Length;
                    int c = 0;
                    while (c < n)
                    {
                        Cell first = line[c];
                        bool selFirst = hasSel && InSel(abs, c, sa, sca, sb, scb);
                        bool curFirst = solidCursor && r == cr && c == cursorCol;
                        int start = c;
                        int len = 0;
                        bool blank = true;
                        while (c < n)
                        {
                            Cell x = line[c];
                            bool sel = hasSel && InSel(abs, c, sa, sca, sb, scb);
                            bool cur = solidCursor && r == cr && c == cursorCol;
                            if (c > start && (x.Fg != first.Fg || x.Bg != first.Bg || x.A != first.A || sel != selFirst || cur || curFirst)) break;
                            char ch = x.C == '\0' ? ' ' : x.C;
                            if (ch != ' ') blank = false;
                            buf[len++] = ch;
                            c++;
                            if (curFirst) break;
                        }
                        bool inv = (first.A & Vt.Inverse) != 0;
                        bool bold = (first.A & Vt.Bold) != 0;
                        Color fg = Fg(first.Fg, bold), bg = Bg(first.Bg);
                        if (inv) { Color t = fg; fg = bg; bg = t; }
                        if ((first.A & Vt.DimA) != 0) fg = Theme.Mix(fg, bg, 0.4f);
                        if (selFirst) bg = tp.Selection;
                        if (curFirst) { bg = tp.Cursor; fg = tp.Bg; }
                        int bgRef = Ref(bg);
                        if (blank && bgRef == defBg) continue;
                        IntPtr want = bold ? hFontBold : hFont;
                        if (want != curFont) { Gdi.SelectObject(hdc, want); curFont = want; }
                        Gdi.SetTextColor(hdc, Ref(fg));
                        Gdi.SetBkColor(hdc, bgRef);
                        RECT rc;
                        rc.Left = PadX + start * cellW;
                        rc.Top = y;
                        rc.Right = rc.Left + len * cellW;
                        rc.Bottom = y + cellH;
                        Gdi.ExtTextOutW(hdc, rc.Left, y + (cellH - font.Height) / 2, 2 | 4, ref rc, buf, (uint)len, dx);
                        if ((first.A & Vt.Underline) != 0)
                        {
                            if (underlines == null) { underlines = new List<Rectangle>(); underlineColors = new List<Color>(); }
                            underlines.Add(new Rectangle(rc.Left, rc.Bottom - 2, rc.Right - rc.Left, 1));
                            underlineColors.Add(fg);
                        }
                    }
                    if (hasSel && n < cols && abs >= sa && abs < sb)
                    {
                        Gdi.SetBkColor(hdc, Ref(tp.Selection));
                        RECT rc;
                        rc.Left = PadX + n * cellW; rc.Top = y; rc.Right = rc.Left + cellW; rc.Bottom = y + cellH;
                        Gdi.ExtTextOutW(hdc, rc.Left, y, 2, ref rc, buf, 0, dx);
                    }
                }
                if (solidCursor && (snap[cr] == null || cursorCol >= snap[cr].Length))
                {
                    Gdi.SetBkColor(hdc, Ref(tp.Cursor));
                    RECT rc;
                    rc.Left = PadX + Math.Min(cursorCol, cols - 1) * cellW; rc.Top = PadY + cr * cellH; rc.Right = rc.Left + cellW; rc.Bottom = rc.Top + cellH;
                    Gdi.ExtTextOutW(hdc, rc.Left, rc.Top, 2, ref rc, buf, 0, dx);
                }
                Gdi.SelectObject(hdc, oldFont);
            }
            finally { g.ReleaseHdc(hdc); }
            if (underlines != null)
                for (int i = 0; i < underlines.Count; i++)
                    using (SolidBrush br = new SolidBrush(underlineColors[i])) g.FillRectangle(br, underlines[i]);
            if (showCursor && !solidCursor && !Focused)
            {
                Rectangle cur = new Rectangle(PadX + Math.Min(cursorCol, cols - 1) * cellW, PadY + cr * cellH, cellW, cellH);
                using (Pen pen = new Pen(Theme.Mix(tp.Cursor, tp.Bg, 0.3f))) g.DrawRectangle(pen, cur.X, cur.Y, cur.Width - 1, cur.Height - 1);
            }
            if (total > rows)
            {
                lock (vt.Gate)
                {
                    Rectangle t = ThumbRect(vt);
                    Icons.Smooth(g);
                    Ui.FillRound(g, t, t.Width / 2f, Theme.Mix(tp.Fg, tp.Bg, draggingBar ? 0.55f : 0.78f));
                }
            }
        }

        private Rectangle ThumbRect(Vt vt)
        {
            long total = vt.EndAbs - vt.FirstAbs;
            int track = Height - Ui.D(12);
            int th = Math.Max(Ui.D(28), (int)((long)track * vt.Rows / Math.Max(1, total)));
            long maxBack = Math.Max(1, total - vt.Rows);
            int y = Ui.D(6) + (int)((track - th) * (maxBack - back) / maxBack);
            return new Rectangle(Width - Ui.D(8), y, Ui.D(5), th);
        }

        private static bool InSel(long abs, int col, long sa, int sca, long sb, int scb)
        {
            if (abs < sa || abs > sb) return false;
            if (abs == sa && col < sca) return false;
            if (abs == sb && col > scb) return false;
            return true;
        }

        private void CellAt(Point p, out long abs, out int col)
        {
            Vt vt = session.Term;
            long top = TopAbs(vt);
            int r = Math.Max(0, Math.Min(vt.Rows - 1, (p.Y - PadY) / Math.Max(1, cellH)));
            abs = top + r;
            col = Math.Max(0, Math.Min(vt.Cols - 1, (p.X - PadX) / Math.Max(1, cellW)));
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            Focus();
            if (session == null) return;
            Vt vt = session.Term;
            if (e.Button == MouseButtons.Left && e.X >= Width - Ui.D(12) && vt.EndAbs - vt.FirstAbs > vt.Rows)
            {
                draggingBar = true;
                barStart = e.Y;
                barOffset = back;
                Capture = true;
                return;
            }
            if (e.Button == MouseButtons.Left)
            {
                long a; int c;
                CellAt(e.Location, out a, out c);
                if (e.Clicks == 2)
                {
                    SelectWord(a, c);
                    return;
                }
                if (e.Clicks >= 3)
                {
                    selA = selB = a; selCA = 0; selCB = vt.Cols - 1; hasSel = true;
                    Invalidate();
                    CopyIfWanted();
                    return;
                }
                selA = selB = a;
                selCA = selCB = c;
                selecting = true;
                hasSel = false;
                Capture = true;
                Invalidate();
            }
            else if (e.Button == MouseButtons.Right)
            {
                if (Store.Settings.RightClickPaste && (ModifierKeys & Keys.Control) == 0)
                {
                    if (hasSel && !Store.Settings.CopyOnSelect) { Copy(); return; }
                    Paste();
                }
                else ShowMenu(e.Location);
            }
            else if (e.Button == MouseButtons.Middle) Paste();
            base.OnMouseDown(e);
        }

        private void SelectWord(long a, int c)
        {
            string t = session.Term.LineText(a);
            if (c >= t.Length || t[c] == ' ') return;
            int s = c, en = c;
            while (s > 0 && t[s - 1] != ' ') s--;
            while (en < t.Length - 1 && t[en + 1] != ' ') en++;
            selA = selB = a; selCA = s; selCB = en; hasSel = true;
            Invalidate();
            CopyIfWanted();
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            if (session == null) return;
            if (draggingBar)
            {
                Vt vt = session.Term;
                Rectangle t = ThumbRect(vt);
                long total = vt.EndAbs - vt.FirstAbs;
                int track = Height - Ui.D(12) - t.Height;
                if (track > 0) back = (int)Math.Max(0, Math.Min(total - vt.Rows, barOffset - (long)(e.Y - barStart) * (total - vt.Rows) / track));
                Invalidate();
                return;
            }
            Cursor = e.X >= Width - Ui.D(12) ? Cursors.Default : Cursors.IBeam;
            if (!selecting) return;
            if (e.Y < 0 && back < session.Term.EndAbs) back++;
            if (e.Y > Height && back > 0) back--;
            long a; int c;
            CellAt(e.Location, out a, out c);
            selB = a; selCB = c;
            hasSel = selA != selB || selCA != selCB;
            Invalidate();
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            if (draggingBar) { draggingBar = false; Capture = false; Invalidate(); return; }
            if (selecting)
            {
                selecting = false;
                Capture = false;
                CopyIfWanted();
            }
            base.OnMouseUp(e);
        }

        protected override void OnMouseWheel(MouseEventArgs e)
        {
            if (session == null) return;
            Vt vt = session.Term;
            int lines = e.Delta / 40;
            back = (int)Math.Max(0, Math.Min(vt.EndAbs - vt.Rows - vt.FirstAbs, back + lines));
            Invalidate();
        }

        private void CopyIfWanted()
        {
            if (hasSel && Store.Settings.CopyOnSelect) Copy();
        }

        public void Copy()
        {
            if (!hasSel || session == null) return;
            string t = session.Term.SelectionText(selA, selCA, selB, selCB);
            if (t.Length > 0)
            {
                try { Clipboard.SetText(t); } catch { }
            }
        }

        public void CopyAll()
        {
            if (session == null) return;
            string t = session.Term.Text(session.Term.FirstAbs, session.Term.EndAbs).TrimEnd();
            try { if (t.Length > 0) Clipboard.SetText(t.Replace("\n", "\r\n")); } catch { }
        }

        public void SelectAll()
        {
            if (session == null) return;
            Vt vt = session.Term;
            selA = vt.FirstAbs; selCA = 0; selB = vt.EndAbs - 1; selCB = vt.Cols - 1; hasSel = true;
            Invalidate();
        }

        public void Paste()
        {
            if (session == null || session.Busy) return;
            string t;
            try { t = Clipboard.ContainsText() ? Clipboard.GetText() : ""; } catch { return; }
            if (t.Length == 0) return;
            back = 0;
            hasSel = false;
            string norm = t.Replace("\r\n", "\n").Replace('\r', '\n');
            string[] lines = norm.Split('\n');
            Session s = session;
            if (lines.Length <= 1) { s.UserSend(norm); return; }
            Thread th = new Thread(delegate()
            {
                for (int i = 0; i < lines.Length; i++)
                {
                    if (i == lines.Length - 1 && lines[i].Length == 0) break;
                    s.UserSend(lines[i] + (i < lines.Length - 1 ? "\r" : ""));
                    Thread.Sleep(Math.Max(25, Store.Settings.LineDelay));
                }
            });
            th.IsBackground = true;
            th.Start();
        }

        private void ShowMenu(Point p)
        {
            ContextMenuStrip m = ThemedMenu.Make();
            ThemedMenu.Item(m, L.T("copy"), "content_copy", delegate { Copy(); }).Enabled = hasSel;
            ThemedMenu.Item(m, L.T("paste"), "content_paste", delegate { Paste(); });
            ThemedMenu.Item(m, L.T("selectAll"), "select_all", delegate { SelectAll(); });
            ThemedMenu.Item(m, L.T("copyAll"), "file_copy", delegate { CopyAll(); });
            m.Items.Add(new ToolStripSeparator());
            ThemedMenu.Item(m, L.T("clearScreen"), "clear_all", delegate { if (session != null) session.Term.Clear(); });
            m.Closed += delegate { BeginInvoke((Action)m.Dispose); };
            m.Show(this, p);
        }

        protected override bool IsInputKey(Keys keyData) { return true; }

        protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
        {
            if (!Focused || session == null) return base.ProcessCmdKey(ref msg, keyData);
            Keys key = keyData & Keys.KeyCode;
            bool ctrl = (keyData & Keys.Control) != 0, shift = (keyData & Keys.Shift) != 0, alt = (keyData & Keys.Alt) != 0;
            if (ctrl && shift && key == Keys.C) { Copy(); return true; }
            if (ctrl && shift && key == Keys.V) { Paste(); return true; }
            if (ctrl && !shift && key == Keys.V) { Paste(); return true; }
            if (ctrl && !shift && key == Keys.C && hasSel) { Copy(); hasSel = false; Invalidate(); return true; }
            if (ctrl && shift && key == Keys.D6) { Send("\x1e"); return true; }
            if (ctrl && key == Keys.Oemplus) { Zoom(1); return true; }
            if (ctrl && key == Keys.OemMinus) { Zoom(-1); return true; }
            if (shift && key == Keys.PageUp) { back += session.Term.Rows - 1; Invalidate(); return true; }
            if (shift && key == Keys.PageDown) { back = Math.Max(0, back - session.Term.Rows + 1); Invalidate(); return true; }
            bool app = session.Term.AppCursorKeys;
            string seq = null;
            switch (key)
            {
                case Keys.Up: seq = app ? "\x1bOA" : "\x1b[A"; break;
                case Keys.Down: seq = app ? "\x1bOB" : "\x1b[B"; break;
                case Keys.Right: seq = app ? "\x1bOC" : "\x1b[C"; break;
                case Keys.Left: seq = app ? "\x1bOD" : "\x1b[D"; break;
                case Keys.Home: seq = "\x1b[H"; break;
                case Keys.End: seq = "\x1b[F"; break;
                case Keys.Delete: seq = "\x1b[3~"; break;
                case Keys.Insert: if (shift) { Paste(); return true; } seq = "\x1b[2~"; break;
                case Keys.PageUp: seq = "\x1b[5~"; break;
                case Keys.PageDown: seq = "\x1b[6~"; break;
                case Keys.Tab: seq = shift ? "\x1b[Z" : "\t"; break;
                case Keys.Enter: seq = "\r"; break;
                case Keys.Escape: seq = "\x1b"; break;
                case Keys.Back: seq = ctrl ? "\x17" : "\x7f"; break;
                case Keys.F1: seq = "\x1bOP"; break;
                case Keys.F2: seq = "\x1bOQ"; break;
                case Keys.F3: seq = "\x1bOR"; break;
                case Keys.F4: if (alt) return base.ProcessCmdKey(ref msg, keyData); seq = "\x1bOS"; break;
            }
            if (seq != null)
            {
                if (alt && seq.Length == 1) seq = "\x1b" + seq;
                Send(seq);
                return true;
            }
            if (ctrl && !alt && key >= Keys.A && key <= Keys.Z)
            {
                Send(((char)(key - Keys.A + 1)).ToString());
                return true;
            }
            if (ctrl && !alt && (key == Keys.OemOpenBrackets)) { Send("\x1b"); return true; }
            if (ctrl && !alt && (key == Keys.Space || key == Keys.D2)) { Send("\0"); return true; }
            return base.ProcessCmdKey(ref msg, keyData);
        }

        protected override void OnKeyPress(KeyPressEventArgs e)
        {
            if (session == null) return;
            char c = e.KeyChar;
            if (c >= ' ' && c != '\x7f')
            {
                Send(c.ToString());
                e.Handled = true;
            }
        }

        private void Send(string s)
        {
            if (session == null) return;
            if (session.Busy) { Native.MessageBeep(0); return; }
            back = 0;
            if (hasSel && !selecting) { hasSel = false; Invalidate(); }
            blink = true;
            blinkCount = 0;
            session.UserSend(s);
        }

        private void Zoom(int dir)
        {
            float next = Math.Max(10, Math.Min(24, Store.Settings.TermFontSize + dir));
            if (next == Store.Settings.TermFontSize) return;
            Store.Settings.TermFontSize = next;
            Store.SaveSettings();
            SetFont();
            Action h = FontChanged2;
            if (h != null) h();
        }

        protected override void OnGotFocus(EventArgs e) { blink = true; Invalidate(); base.OnGotFocus(e); }
        protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                tick.Dispose();
                resize.Dispose();
            }
            FreeFonts();
            base.Dispose(disposing);
        }
    }

    internal static class Gdi
    {
        [DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr hdc, IntPtr obj);
        [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr obj);
        [DllImport("gdi32.dll")] public static extern int SetTextColor(IntPtr hdc, int color);
        [DllImport("gdi32.dll")] public static extern int SetBkColor(IntPtr hdc, int color);
        [DllImport("gdi32.dll")] public static extern int SetBkMode(IntPtr hdc, int mode);
        [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern bool ExtTextOutW(IntPtr hdc, int x, int y, uint options, ref RECT rect, char[] text, uint count, int[] dx);
    }
}
