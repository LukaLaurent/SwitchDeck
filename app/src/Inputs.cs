using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Text.RegularExpressions;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal sealed class TextField : Painted
    {
        public readonly TextBox Box;
        public string Icon;
        private readonly bool password;
        private bool reveal;
        public event EventHandler Changed;
        public event EventHandler Submit;
        public bool Error;

        public TextField(string text, string placeholder, string icon, bool password, bool mono)
        {
            Icon = icon;
            this.password = password;
            Cursor = Cursors.IBeam;
            SetStyle(ControlStyles.Selectable, false);
            TabStop = false;
            Box = new TextBox();
            Box.BorderStyle = BorderStyle.None;
            Box.Font = mono ? Fonts.Mono(13.5f * Sc) : Fonts.Body(14f * Sc);
            Box.BackColor = Theme.P.Surface2;
            Box.ForeColor = Theme.P.Text;
            Box.Text = text ?? "";
            if (password) Box.UseSystemPasswordChar = true;
            Box.TextChanged += delegate { Error = false; Invalidate(); EventHandler h = Changed; if (h != null) h(this, EventArgs.Empty); };
            Box.GotFocus += delegate { Invalidate(); };
            Box.LostFocus += delegate { Invalidate(); };
            Box.KeyDown += delegate(object s, KeyEventArgs e)
            {
                if (e.KeyCode == Keys.Enter)
                {
                    e.SuppressKeyPress = true;
                    EventHandler h = Submit;
                    if (h != null) h(this, EventArgs.Empty);
                }
            };
            Controls.Add(Box);
            Size = new Size(D(260), D(38));
            BackColor = Theme.P.Surface2;
            if (!string.IsNullOrEmpty(placeholder))
                Box.HandleCreated += delegate { Native.SendMessage(Box.Handle, 0x1501, new IntPtr(1), System.Runtime.InteropServices.Marshal.StringToHGlobalUni(placeholder)); };
        }

        public override string Text
        {
            get { return Box == null ? "" : Box.Text; }
            set { if (Box != null) Box.Text = value; }
        }

        private int LeftPad { get { return string.IsNullOrEmpty(Icon) ? D(12) : D(38); } }
        private int RightPad { get { return password ? D(38) : D(12); } }

        protected override void OnLayout(LayoutEventArgs e)
        {
            base.OnLayout(e);
            if (Box == null) return;
            int h = Box.PreferredHeight;
            Box.Bounds = new Rectangle(LeftPad, (Height - h) / 2 + 1, Math.Max(10, Width - LeftPad - RightPad), h);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            if (password && e.X > Width - D(36))
            {
                reveal = !reveal;
                Box.UseSystemPasswordChar = !reveal;
                Invalidate();
                return;
            }
            Box.Focus();
            Box.SelectionStart = Box.TextLength;
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            Cursor = password && e.X > Width - D(36) ? Cursors.Hand : Cursors.IBeam;
            base.OnMouseMove(e);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            RectangleF r = new RectangleF(Sc * 0.5f, Sc * 0.5f, Width - Sc - 1, Height - Sc - 1);
            bool focus = Box.Focused;
            Ui.FillRound(g, r, 10 * Sc, p.Surface2);
            Color border = Error ? p.Danger : focus ? p.Orange : (Hover ? p.Faint : p.Border);
            Ui.StrokeRound(g, r, 10 * Sc, border, focus || Error ? 1.6f * Sc : Math.Max(1f, Sc));
            if (focus && !Error) Ui.StrokeRound(g, RectangleF.Inflate(r, -2 * Sc, -2 * Sc), 8 * Sc, Color.FromArgb(40, p.Orange), 2 * Sc);
            if (!string.IsNullOrEmpty(Icon)) Icons.Draw(g, Icon, new RectangleF(D(10), 0, D(22), Height), focus ? p.Orange : p.Faint, 19 * Sc, false);
            if (password) Icons.Draw(g, reveal ? "visibility_off" : "visibility", new RectangleF(Width - D(32), 0, D(22), Height), p.Faint, 19 * Sc, false);
        }

        public void Retheme()
        {
            Box.BackColor = Theme.P.Surface2;
            Box.ForeColor = Theme.P.Text;
        }
    }

    internal sealed class DropItem
    {
        public string Text;
        public string Sub;
        public string Icon;
        public Color Dot = Color.Empty;
        public object Value;

        public DropItem(string text, object value) { Text = text; Value = value; }
    }

    internal sealed class Dropdown : Painted
    {
        public readonly List<DropItem> Items = new List<DropItem>();
        private int selected = -1;
        public string Placeholder = "";
        public event EventHandler Changed;
        private ContextMenuStrip menu;

        public Dropdown()
        {
            Size = new Size(D(260), D(40));
        }

        public int SelectedIndex
        {
            get { return selected; }
            set { selected = value; Invalidate(); }
        }

        public DropItem Selected { get { return selected >= 0 && selected < Items.Count ? Items[selected] : null; } }

        public object Value { get { DropItem d = Selected; return d == null ? null : d.Value; } }

        public void SelectValue(object v)
        {
            selected = -1;
            for (int i = 0; i < Items.Count; i++) if (Equals(Items[i].Value, v)) selected = i;
            Invalidate();
        }

        protected override void OnClick(EventArgs e)
        {
            base.OnClick(e);
            if (!Enabled || Items.Count == 0) return;
            Focus();
            Open();
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Space || e.KeyCode == Keys.Enter || e.KeyCode == Keys.F4) { Open(); e.Handled = true; }
            base.OnKeyDown(e);
        }

        private void Open()
        {
            if (menu != null) menu.Dispose();
            menu = ThemedMenu.Make();
            menu.MinimumSize = new Size(Width, 0);
            menu.MaximumSize = new Size(Math.Max(Width, D(420)), D(460));
            for (int i = 0; i < Items.Count; i++)
            {
                int index = i;
                DropItem d = Items[i];
                ToolStripMenuItem it = ThemedMenu.Item(menu, d.Sub == null ? d.Text : d.Text + "   " + d.Sub, d.Icon, delegate
                {
                    if (selected != index)
                    {
                        selected = index;
                        Invalidate();
                        EventHandler h = Changed;
                        if (h != null) h(this, EventArgs.Empty);
                    }
                });
                if (!d.Dot.IsEmpty)
                {
                    Color c = d.Dot;
                    it.ImageKey = null;
                    it.Paint += delegate(object s, PaintEventArgs pe)
                    {
                        Icons.Smooth(pe.Graphics);
                        float sz = 10 * Sc;
                        using (SolidBrush br = new SolidBrush(c)) pe.Graphics.FillEllipse(br, D(12), (it.Height - sz) / 2f, sz, sz);
                    };
                }
                if (i == selected) it.Font = Fonts.Strong(13.5f * Sc);
            }
            menu.Show(this, new Point(0, Height + D(4)));
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            RectangleF r = new RectangleF(Sc * 0.5f, Sc * 0.5f, Width - Sc - 1, Height - Sc - 1);
            Ui.FillRound(g, r, 10 * Sc, Hover && Enabled ? p.HoverFill : p.Surface2);
            Ui.StrokeRound(g, r, 10 * Sc, Focused ? p.Orange : p.Border, Focused ? 1.6f * Sc : Math.Max(1f, Sc));
            DropItem d = Selected;
            int x = D(12);
            if (d != null && !d.Dot.IsEmpty)
            {
                float sz = 10 * Sc;
                using (SolidBrush br = new SolidBrush(d.Dot)) g.FillEllipse(br, x, (Height - sz) / 2f, sz, sz);
                x += D(20);
            }
            else if (d != null && d.Icon != null)
            {
                Icons.Draw(g, d.Icon, new RectangleF(x - D(1), 0, D(20), Height), p.Muted, 19 * Sc, false);
                x += D(26);
            }
            Color tc = Enabled ? p.Text : p.Faint;
            if (d == null) Ui.Text(g, Placeholder, Fonts.Body(14f * Sc), new Rectangle(x, 0, Width - x - D(36), Height), p.Faint, Ui.Left);
            else
            {
                Font f = Fonts.Body(14f * Sc);
                int tw = Ui.Measure(d.Text, f).Width;
                Ui.Text(g, d.Text, f, new Rectangle(x, 0, Width - x - D(36), Height), tc, Ui.Left);
                if (d.Sub != null && x + tw + D(10) < Width - D(60))
                    Ui.Text(g, d.Sub, Fonts.Body(12.5f * Sc), new Rectangle(x + tw + D(10), 0, Width - x - tw - D(46), Height), p.Faint, Ui.Left);
            }
            Icons.Draw(g, "expand_more", new RectangleF(Width - D(32), 0, D(22), Height), p.Muted, 20 * Sc, false);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing && menu != null) menu.Dispose();
            base.Dispose(disposing);
        }
    }

    internal sealed class CodeBox : Painted
    {
        public readonly RichTextBox Box;
        private bool highlighting;
        private readonly Timer hl;
        public event EventHandler Changed;
        public bool Highlight = true;

        public CodeBox(string text, bool readOnly)
        {
            SetStyle(ControlStyles.Selectable, false);
            TabStop = false;
            Cursor = Cursors.IBeam;
            Box = new RichTextBox();
            Box.BorderStyle = BorderStyle.None;
            Box.Font = Fonts.Mono(13f * Sc);
            Box.ReadOnly = readOnly;
            Box.DetectUrls = false;
            Box.WordWrap = readOnly;
            Box.AcceptsTab = false;
            Box.ScrollBars = RichTextBoxScrollBars.None;
            Box.BackColor = Theme.P.Surface2;
            Box.ForeColor = Theme.P.Text;
            Box.Text = text ?? "";
            Box.ShortcutsEnabled = true;
            Box.VScroll += delegate { Invalidate(); };
            Box.Resize += delegate { Invalidate(); };
            Box.MouseWheel += delegate(object o, MouseEventArgs me) { ScrollY = ScrollY - me.Delta / 120 * 3 * Box.Font.Height; };
            Box.KeyDown += delegate(object s, KeyEventArgs e)
            {
                if ((e.Control && e.KeyCode == Keys.V) || (e.Shift && e.KeyCode == Keys.Insert))
                {
                    e.SuppressKeyPress = true;
                    if (!Box.ReadOnly && Clipboard.ContainsText()) Box.SelectedText = Clipboard.GetText().Replace("\r\n", "\n").Replace("\t", " ");
                }
            };
            Box.GotFocus += delegate { Invalidate(); };
            Box.LostFocus += delegate { Invalidate(); };
            hl = new Timer();
            hl.Interval = 180;
            hl.Tick += delegate { hl.Stop(); Paint2(); };
            Box.TextChanged += delegate
            {
                if (highlighting) return;
                if (Highlight) { hl.Stop(); hl.Start(); }
                EventHandler h = Changed;
                if (h != null) h(this, EventArgs.Empty);
            };
            Controls.Add(Box);
            Box.HandleCreated += delegate { Box.BeginInvoke((Action)Paint2); };
        }

        public override string Text
        {
            get { return Box == null ? "" : Box.Text; }
            set
            {
                if (Box == null) return;
                highlighting = true;
                Box.Text = value ?? "";
                highlighting = false;
                Paint2();
            }
        }

        public void SetColors(Color back, Color fore)
        {
            Box.BackColor = back;
            Box.ForeColor = fore;
            Invalidate();
            Paint2();
        }

        protected override void OnLayout(LayoutEventArgs e)
        {
            base.OnLayout(e);
            if (Box != null) Box.Bounds = new Rectangle(D(12), D(10), Math.Max(10, Width - D(30)), Math.Max(10, Height - D(16)));
        }

        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, ref POINT p);

        private int ScrollY
        {
            get
            {
                if (!Box.IsHandleCreated) return 0;
                POINT pt = new POINT();
                SendMessage(Box.Handle, 0x04DD, IntPtr.Zero, ref pt);
                return pt.Y;
            }
            set
            {
                if (!Box.IsHandleCreated) return;
                POINT pt = new POINT();
                pt.Y = Math.Max(0, value);
                SendMessage(Box.Handle, 0x04DE, IntPtr.Zero, ref pt);
                Invalidate();
            }
        }

        private int ContentHeight
        {
            get
            {
                if (!Box.IsHandleCreated || Box.TextLength == 0) return 0;
                Point last = Box.GetPositionFromCharIndex(Box.TextLength - 1);
                return last.Y + ScrollY + Box.Font.Height + D(4);
            }
        }

        private Rectangle Thumb
        {
            get
            {
                int content = ContentHeight, view = Box.ClientSize.Height;
                if (content <= view || view <= 0) return Rectangle.Empty;
                int track = Height - D(16);
                int th = Math.Max(D(28), (int)((long)track * view / content));
                int max = content - view;
                int y = D(8) + (int)((long)(track - th) * Math.Min(max, ScrollY) / Math.Max(1, max));
                return new Rectangle(Width - D(13), y, D(5), th);
            }
        }

        private bool dragging;
        private int dragStart, dragScroll;

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            Rectangle t = Thumb;
            if (!t.IsEmpty && e.X >= Width - D(18))
            {
                dragging = true;
                dragStart = e.Y;
                dragScroll = ScrollY;
                if (e.Y < t.Top || e.Y > t.Bottom)
                {
                    int max = ContentHeight - Box.ClientSize.Height;
                    dragScroll = (int)((long)(e.Y - t.Height / 2 - D(8)) * max / Math.Max(1, Height - D(16) - t.Height));
                    ScrollY = dragScroll;
                }
                Capture = true;
                return;
            }
            Box.Focus();
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            Cursor = e.X >= Width - D(18) ? Cursors.Default : Cursors.IBeam;
            if (!dragging) return;
            Rectangle t = Thumb;
            int track = Height - D(16) - t.Height;
            int max = ContentHeight - Box.ClientSize.Height;
            if (track > 0) ScrollY = dragScroll + (int)((long)(e.Y - dragStart) * max / track);
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            dragging = false;
            Capture = false;
            base.OnMouseUp(e);
        }

        protected override void OnMouseWheel(MouseEventArgs e)
        {
            ScrollY = ScrollY - e.Delta / 120 * 3 * Box.Font.Height;
            base.OnMouseWheel(e);
        }

        private static readonly Regex Var = new Regex(@"\{\{\s*[A-Za-z_][A-Za-z0-9_\-]*\s*\}\}", RegexOptions.Compiled);
        private static readonly Regex Comment = new Regex(@"(?m)^\s*!.*$", RegexOptions.Compiled);
        private static readonly Regex Neg = new Regex(@"(?m)^\s*(no|default)\b", RegexOptions.Compiled);
        private static readonly Regex Err = new Regex(@"(?m)^\s*%.*$", RegexOptions.Compiled);
        private static readonly Regex Head = new Regex(@"(?m)^(configure terminal|interface .*|end|write memory|\s*exit)$", RegexOptions.Compiled);

        public void Paint2()
        {
            if (!Box.IsHandleCreated || !Highlight) return;
            highlighting = true;
            try
            {
                Native.SetRedraw(Box.Handle, false);
                int ss = Box.SelectionStart, sl = Box.SelectionLength;
                Box.SelectAll();
                Box.SelectionColor = Box.ForeColor;
                Box.SelectionBackColor = Box.BackColor;
                string t = Box.Text;
                Palette p = Theme.P;
                foreach (Match m in Head.Matches(t)) Color(m.Index, m.Length, p.Teal);
                foreach (Match m in Neg.Matches(t)) Color(m.Index, m.Length, p.Danger);
                foreach (Match m in Var.Matches(t)) Color(m.Index, m.Length, p.Orange);
                foreach (Match m in Comment.Matches(t)) Color(m.Index, m.Length, p.Faint);
                foreach (Match m in Err.Matches(t)) Color(m.Index, m.Length, p.Danger);
                Box.Select(ss, sl);
            }
            finally
            {
                Native.SetRedraw(Box.Handle, true);
                Box.Invalidate();
                highlighting = false;
            }
        }

        private void Color(int start, int len, Color c)
        {
            Box.Select(start, len);
            Box.SelectionColor = c;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            RectangleF r = new RectangleF(Sc * 0.5f, Sc * 0.5f, Width - Sc - 1, Height - Sc - 1);
            Ui.FillRound(g, r, 12 * Sc, Box.BackColor);
            bool focus = Box.Focused && !Box.ReadOnly;
            Ui.StrokeRound(g, r, 12 * Sc, focus ? p.Orange : p.Border, focus ? 1.6f * Sc : Math.Max(1f, Sc));
            Rectangle t = Thumb;
            if (!t.IsEmpty) Ui.FillRound(g, t, t.Width / 2f, dragging ? p.Faint : p.Track);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) hl.Dispose();
            base.Dispose(disposing);
        }
    }

    internal sealed class ScrollPanel : Pane
    {
        public readonly Pane Content;
        private int offset;
        private bool dragging;
        private int dragStart, dragOffset;
        private bool hoverBar;

        public ScrollPanel()
        {
            Content = new Pane();
            Content.BackColor = BackColor;
            Controls.Add(Content);
            Content.MouseWheel += delegate(object s, MouseEventArgs e) { Scroll(-e.Delta); };
        }

        public int Max { get { return Math.Max(0, Content.Height - Height); } }

        public void SetContentHeight(int h)
        {
            Content.Bounds = new Rectangle(0, -offset, Width - (h > Height ? D(10) : 0), h);
            Clamp();
            Invalidate();
        }

        private int D(float v) { return Ui.D(v); }

        public new void Scroll(int delta)
        {
            offset += delta / 2;
            Clamp();
        }

        public void ScrollTo(int y)
        {
            offset = y;
            Clamp();
        }

        private void Clamp()
        {
            offset = Math.Max(0, Math.Min(Max, offset));
            if (Content.Top != -offset) Content.Top = -offset;
            Invalidate();
        }

        protected override void OnBackColorChanged(EventArgs e)
        {
            base.OnBackColorChanged(e);
            if (Content != null) Content.BackColor = BackColor;
        }

        protected override void OnMouseWheel(MouseEventArgs e)
        {
            Scroll(-e.Delta);
            base.OnMouseWheel(e);
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            if (Content != null)
            {
                Content.Width = Width - (Content.Height > Height ? D(10) : 0);
                Clamp();
            }
        }

        private Rectangle Thumb
        {
            get
            {
                if (Max <= 0) return Rectangle.Empty;
                int track = Height - D(8);
                int th = Math.Max(D(30), (int)((long)track * Height / Content.Height));
                int y = D(4) + (int)((long)(track - th) * offset / Max);
                return new Rectangle(Width - D(8), y, D(5), th);
            }
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            Rectangle t = Thumb;
            if (t.IsEmpty) return;
            Icons.Smooth(e.Graphics);
            Ui.FillRound(e.Graphics, t, t.Width / 2f, hoverBar || dragging ? Theme.P.Faint : Theme.P.Track);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            Rectangle t = Thumb;
            if (!t.IsEmpty && e.X >= Width - D(12))
            {
                dragging = true;
                dragStart = e.Y;
                dragOffset = offset;
                if (e.Y < t.Top || e.Y > t.Bottom)
                {
                    offset = (int)((long)(e.Y - t.Height / 2) * Max / Math.Max(1, Height - t.Height));
                    dragOffset = offset;
                    Clamp();
                }
                Capture = true;
            }
            base.OnMouseDown(e);
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            bool hb = e.X >= Width - D(12);
            if (hb != hoverBar) { hoverBar = hb; Invalidate(); }
            if (dragging)
            {
                Rectangle t = Thumb;
                int track = Height - D(8) - t.Height;
                if (track > 0) offset = dragOffset + (int)((long)(e.Y - dragStart) * Max / track);
                Clamp();
            }
            base.OnMouseMove(e);
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            dragging = false;
            Capture = false;
            Invalidate();
            base.OnMouseUp(e);
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            hoverBar = false;
            Invalidate();
            base.OnMouseLeave(e);
        }
    }
}
