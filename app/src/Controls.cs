using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal static class Ui
    {
        public static float Sc = 1f;

        public static int D(float v) { return (int)Math.Round(v * Sc); }

        public const TextFormatFlags Left = TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis;
        public const TextFormatFlags Center = TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis;
        public const TextFormatFlags Right = TextFormatFlags.Right | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis;
        public const TextFormatFlags Wrap = TextFormatFlags.Left | TextFormatFlags.Top | TextFormatFlags.NoPadding | TextFormatFlags.WordBreak | TextFormatFlags.TextBoxControl;

        public static Size Measure(string s, Font f)
        {
            return TextRenderer.MeasureText(s ?? "", f, Size.Empty, TextFormatFlags.NoPadding | TextFormatFlags.SingleLine);
        }

        public static int WrapHeight(string s, Font f, int width)
        {
            return TextRenderer.MeasureText(s ?? "", f, new Size(width, 0), Wrap).Height;
        }

        public static void Text(Graphics g, string s, Font f, Rectangle r, Color c, TextFormatFlags flags)
        {
            TextRenderer.DrawText(g, s ?? "", f, r, c, flags);
        }

        public static void FillRound(Graphics g, RectangleF r, float radius, Color c)
        {
            using (GraphicsPath p = Icons.Rounded(r, radius))
            using (SolidBrush br = new SolidBrush(c))
                g.FillPath(br, p);
        }

        public static void StrokeRound(Graphics g, RectangleF r, float radius, Color c, float width)
        {
            using (GraphicsPath p = Icons.Rounded(r, radius))
            using (Pen pen = new Pen(c, width))
                g.DrawPath(pen, p);
        }

        public static void Shadow(Graphics g, RectangleF r, float radius, float depth)
        {
            Color baseC = Theme.P.Shadow;
            int steps = 6;
            for (int i = steps; i >= 1; i--)
            {
                float grow = depth * i / steps;
                int a = (int)(baseC.A * (1f - (float)(i - 1) / steps) / steps * 1.6f);
                RectangleF rr = new RectangleF(r.X - grow * 0.6f, r.Y - grow * 0.3f + depth * 0.35f, r.Width + grow * 1.2f, r.Height + grow * 1.2f);
                FillRound(g, rr, radius + grow, Color.FromArgb(Math.Max(0, Math.Min(255, a)), baseC.R, baseC.G, baseC.B));
            }
        }

        public static Label Label(string text, Font font, Color fore)
        {
            Label l = new Label();
            l.AutoSize = true;
            l.UseMnemonic = false;
            l.Margin = Padding.Empty;
            l.Padding = Padding.Empty;
            l.Font = font;
            l.ForeColor = fore;
            l.BackColor = Color.Transparent;
            l.Text = text;
            return l;
        }

        public static void DarkScroll(Control c)
        {
            try
            {
                if (c.IsHandleCreated) Native.SetWindowTheme(c.Handle, Theme.P.Dark ? "DarkMode_Explorer" : "Explorer", null);
                else c.HandleCreated += delegate { Native.SetWindowTheme(c.Handle, Theme.P.Dark ? "DarkMode_Explorer" : "Explorer", null); };
            }
            catch { }
        }

        public static Color StatusColor(string status)
        {
            Palette p = Theme.P;
            switch (status)
            {
                case "ok": case "connected": return p.Success;
                case "warn": case "applied": return p.Warning;
                case "failed": case "err-disabled": return p.Danger;
                case "running": return p.Orange;
                default: return p.Faint;
            }
        }

        public static string StatusIcon(string status)
        {
            switch (status)
            {
                case "ok": return "check_circle";
                case "warn": return "warning";
                case "failed": return "error";
                case "running": return "pending";
                case "applied": return "check";
                case "skipped": return "block";
                case "stopped": return "stop";
                default: return "radio_button_unchecked";
            }
        }
    }

    internal class Pane : Panel
    {
        public Pane()
        {
            DoubleBuffered = true;
            SetStyle(ControlStyles.ResizeRedraw | ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true);
            BackColor = Theme.P.Bg;
        }
    }

    internal class Card : Pane
    {
        public string Title;
        public string Icon;
        public string Subtitle;
        public Color Fill = Color.Empty;
        public readonly List<int> Dividers = new List<int>();
        public int HeaderHeight { get { return Title == null ? 0 : Ui.D(Subtitle == null ? 54 : 68); } }

        public Card()
        {
            BackColor = Theme.P.Surface;
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            Palette p = Theme.P;
            Color under = Parent != null ? Parent.BackColor : p.Bg;
            g.Clear(under);
            Icons.Smooth(g);
            float sc = Ui.Sc;
            RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            Color fill = Fill.IsEmpty ? p.Surface : Fill;
            Ui.FillRound(g, r, 14 * sc, fill);
            Ui.StrokeRound(g, r, 14 * sc, p.Border, Math.Max(1f, sc));
            if (Title != null)
            {
                int x = Ui.D(20);
                if (Icon != null)
                {
                    RectangleF ib = new RectangleF(x, Ui.D(15), Ui.D(26), Ui.D(26));
                    Ui.FillRound(g, ib, 7 * sc, p.OrangeSoft);
                    Icons.Draw(g, Icon, ib, p.Orange, 18 * sc, false);
                    x += Ui.D(36);
                }
                int right = Width - Ui.D(20);
                Ui.Text(g, Title, Fonts.Head(15.5f * sc), new Rectangle(x, Ui.D(14), right - x, Ui.D(28)), p.Text, Ui.Left);
                if (Subtitle != null)
                    Ui.Text(g, Subtitle, Fonts.Body(12.5f * sc), new Rectangle(Ui.D(20), Ui.D(42), right - Ui.D(20), Ui.D(18)), p.Muted, Ui.Left);
            }
            g.SmoothingMode = SmoothingMode.None;
            using (Pen pen = new Pen(p.Border, Math.Max(1f, (float)Math.Floor(sc))))
                foreach (int y in Dividers) g.DrawLine(pen, Ui.D(20), y, Width - Ui.D(20), y);
        }

        public Rectangle Inner
        {
            get
            {
                int pad = Ui.D(20);
                int top = HeaderHeight > 0 ? HeaderHeight : pad;
                return new Rectangle(pad, top, Width - 2 * pad, Height - top - pad);
            }
        }
    }

    internal abstract class Painted : Control
    {
        protected bool Hover, Pressed;
        public string Tip;

        protected Painted()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor, true);
            Cursor = Cursors.Hand;
            BackColor = Color.Transparent;
        }

        protected float Sc { get { return Ui.Sc; } }
        protected int D(float v) { return Ui.D(v); }

        protected Color Under
        {
            get
            {
                Control c = Parent;
                while (c != null && c.BackColor.A < 255) c = c.Parent;
                return c != null ? c.BackColor : Theme.P.Bg;
            }
        }

        protected Color ClearColor { get { return Under; } }

        protected Graphics Prepare(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.Clear(ClearColor);
            Icons.Smooth(g);
            return g;
        }

        protected bool ShowRing { get { return Focused && ShowFocusCues; } }

        protected void Ring(Graphics g, RectangleF r, float radius)
        {
            using (GraphicsPath path = Icons.Rounded(r, radius))
            using (Pen pen = new Pen(Color.FromArgb(120, Theme.P.Orange), 2f * Sc))
                g.DrawPath(pen, path);
        }

        protected override void OnMouseEnter(EventArgs e)
        {
            Hover = true;
            Invalidate();
            if (Tip != null) Tips.Show(this, Tip);
            base.OnMouseEnter(e);
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            Hover = false;
            Pressed = false;
            Invalidate();
            if (Tip != null) Tips.Hide(this);
            base.OnMouseLeave(e);
        }

        protected override void OnMouseDown(MouseEventArgs e) { if (e.Button == MouseButtons.Left) { Pressed = true; Invalidate(); } base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e) { Pressed = false; Invalidate(); base.OnMouseUp(e); }
        protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }
        protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }
        protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }
    }

    internal static class Tips
    {
        private static ToolTip tip;

        private static ToolTip Get()
        {
            if (tip == null)
            {
                tip = new ToolTip();
                tip.OwnerDraw = true;
                tip.InitialDelay = 450;
                tip.ReshowDelay = 100;
                tip.AutoPopDelay = 8000;
                tip.Popup += delegate(object s, PopupEventArgs e)
                {
                    Size sz = TextRenderer.MeasureText(tip.GetToolTip(e.AssociatedControl), Fonts.Body(12.5f * Ui.Sc), new Size(Ui.D(320), 0), Ui.Wrap);
                    e.ToolTipSize = new Size(sz.Width + Ui.D(20), sz.Height + Ui.D(12));
                };
                tip.Draw += delegate(object s, DrawToolTipEventArgs e)
                {
                    Palette p = Theme.P;
                    Color bg = p.Dark ? Theme.C(0x2A3038) : Theme.Charcoal;
                    using (SolidBrush br = new SolidBrush(bg)) e.Graphics.FillRectangle(br, e.Bounds);
                    Rectangle r = new Rectangle(Ui.D(10), Ui.D(6), e.Bounds.Width - Ui.D(20), e.Bounds.Height - Ui.D(12));
                    TextRenderer.DrawText(e.Graphics, e.ToolTipText, Fonts.Body(12.5f * Ui.Sc), r, Theme.OffWhite, Ui.Wrap);
                };
            }
            return tip;
        }

        public static void Show(Control c, string text)
        {
            Get().SetToolTip(c, text);
        }

        public static void Hide(Control c)
        {
            if (tip != null) tip.Hide(c);
        }

        public static void Set(Control c, string text)
        {
            Get().SetToolTip(c, text);
        }
    }

    internal enum BtnKind { Primary, Secondary, Ghost, Danger, Teal }

    internal sealed class Btn : Painted
    {
        public BtnKind Kind;
        public string Icon;
        public bool Compact;
        public bool IconOnly;

        public Btn(string text, string icon, BtnKind kind, EventHandler click)
        {
            Kind = kind;
            Icon = icon;
            Text = text ?? "";
            IconOnly = string.IsNullOrEmpty(text);
            if (click != null) Click += click;
            Fit();
        }

        public Btn Small()
        {
            Compact = true;
            Fit();
            return this;
        }

        public void Fit()
        {
            Font f = Fonts.Strong((Compact ? 13f : 13.5f) * Sc);
            int h = D(Compact ? 32 : 38);
            if (IconOnly) { Size = new Size(h, h); return; }
            int w = Ui.Measure(Text, f).Width + D(Compact ? 24 : 32);
            if (!string.IsNullOrEmpty(Icon)) w += D(Compact ? 22 : 26);
            if (!Compact) w = Math.Max(w, D(string.IsNullOrEmpty(Icon) ? 92 : 100));
            Size = new Size(w, h);
        }

        public void SetText(string text)
        {
            Text = text;
            Fit();
            Invalidate();
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Space || e.KeyCode == Keys.Enter) { OnClick(EventArgs.Empty); e.Handled = true; }
            base.OnKeyDown(e);
        }

        protected override void OnClick(EventArgs e)
        {
            if (!Enabled) return;
            base.OnClick(e);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            Color fill, text, border = Color.Empty;
            bool hv = Hover && Enabled;
            switch (Kind)
            {
                case BtnKind.Primary:
                    fill = hv ? p.OrangeHover : p.Orange; text = p.OnOrange; break;
                case BtnKind.Teal:
                    fill = hv ? Theme.Mix(p.Teal, Color.Black, 0.12f) : p.Teal; text = p.Dark ? Theme.C(0x16191D) : Color.White; break;
                case BtnKind.Danger:
                    fill = hv ? Theme.Mix(p.DangerSoft, p.Danger, 0.15f) : p.DangerSoft; text = p.Danger; break;
                case BtnKind.Ghost:
                    fill = hv ? p.HoverFill : Color.Empty; text = hv ? p.Text : p.Muted; break;
                default:
                    fill = hv ? p.HoverFill : p.Surface; text = p.Text; border = p.Border; break;
            }
            if (Pressed && Enabled && !fill.IsEmpty) fill = Theme.Mix(fill, p.Dark ? Color.White : Color.Black, 0.06f);
            if (!Enabled)
            {
                if (!fill.IsEmpty) fill = Kind == BtnKind.Primary || Kind == BtnKind.Teal ? Theme.Mix(fill, Under, 0.55f) : fill;
                text = Theme.Mix(text, Under, 0.55f);
            }
            float rad = 10 * Sc;
            if (!fill.IsEmpty) Ui.FillRound(g, r, rad, fill);
            if (!border.IsEmpty) Ui.StrokeRound(g, r, rad, border, Math.Max(1f, Sc));
            Font f = Fonts.Strong((Compact ? 13f : 13.5f) * Sc);
            float ip = (Compact ? 18f : 20f) * Sc;
            if (IconOnly)
            {
                Icons.Draw(g, Icon, r, text, ip, false);
            }
            else
            {
                int tw = Ui.Measure(Text, f).Width;
                int total = tw + (string.IsNullOrEmpty(Icon) ? 0 : D(Compact ? 22 : 26));
                int x = (Width - total) / 2;
                if (!string.IsNullOrEmpty(Icon))
                {
                    Icons.Draw(g, Icon, new RectangleF(x - D(1), 0, D(Compact ? 18 : 20), Height), text, ip, false);
                    x += D(Compact ? 22 : 26);
                }
                Ui.Text(g, Text, f, new Rectangle(x, 0, tw + D(2), Height), text, Ui.Left);
            }
            if (ShowRing) Ring(g, RectangleF.Inflate(r, -1, -1), rad);
        }
    }

    internal sealed class Toggle : Painted
    {
        private bool on;
        public event EventHandler Changed;

        public Toggle(bool value)
        {
            on = value;
            Size = new Size(D(46), D(28));
        }

        public bool Checked
        {
            get { return on; }
            set { if (on != value) { on = value; Invalidate(); } }
        }

        protected override void OnClick(EventArgs e)
        {
            base.OnClick(e);
            if (!Enabled) return;
            Focus();
            Flip();
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Space || e.KeyCode == Keys.Enter) { Flip(); e.Handled = true; }
            base.OnKeyDown(e);
        }

        private void Flip()
        {
            on = !on;
            Invalidate();
            EventHandler h = Changed;
            if (h != null) h(this, EventArgs.Empty);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            float m = 2 * Sc;
            RectangleF track = new RectangleF(m, m, Width - 2 * m - 1, Height - 2 * m - 1);
            Color fill = on ? (Hover ? p.OrangeHover : p.Orange) : (Hover ? p.Faint : p.Track);
            if (!Enabled) fill = Theme.Mix(fill, Under, 0.5f);
            Ui.FillRound(g, track, track.Height / 2f, fill);
            float k = track.Height - 6 * Sc;
            float kx = on ? track.Right - 3 * Sc - k : track.X + 3 * Sc;
            using (SolidBrush br = new SolidBrush(on ? Theme.Charcoal : Color.White))
                g.FillEllipse(br, kx, track.Y + 3 * Sc, k, k);
            if (ShowRing) Ring(g, RectangleF.Inflate(track, 2 * Sc, 2 * Sc), track.Height / 2f + 2 * Sc);
        }
    }

    internal sealed class Check : Painted
    {
        private bool on;
        public event EventHandler Changed;

        public Check(string text, bool value)
        {
            on = value;
            Text = text;
            Font f = Fonts.Body(13.5f * Sc);
            Size = new Size(D(28) + Ui.Measure(text, f).Width + D(4), D(26));
        }

        public bool Checked
        {
            get { return on; }
            set { if (on != value) { on = value; Invalidate(); } }
        }

        protected override void OnClick(EventArgs e)
        {
            base.OnClick(e);
            on = !on;
            Invalidate();
            EventHandler h = Changed;
            if (h != null) h(this, EventArgs.Empty);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            RectangleF box = new RectangleF(D(1), (Height - D(20)) / 2f, D(20), D(20));
            if (on) Ui.FillRound(g, box, 6 * Sc, Hover ? p.OrangeHover : p.Orange);
            else
            {
                Ui.FillRound(g, box, 6 * Sc, p.Surface2);
                Ui.StrokeRound(g, box, 6 * Sc, Hover ? p.Faint : p.Track, 1.4f * Sc);
            }
            if (on) Icons.Draw(g, "check", box, p.OnOrange, 16 * Sc, false);
            Ui.Text(g, Text, Fonts.Body(13.5f * Sc), new Rectangle(D(28), 0, Width - D(28), Height), p.Text, Ui.Left);
        }
    }

    internal sealed class Segmented : Painted
    {
        private string[] items;
        private string[] icons;
        private int[] widths;
        private int selected, hover = -1;
        public event EventHandler Changed;
        public bool Stretch;

        public Segmented(string[] items, int selected) : this(items, null, selected) { }

        public Segmented(string[] items, string[] icons, int selected)
        {
            this.items = items;
            this.icons = icons;
            this.selected = selected;
            Measure();
        }

        private void Measure()
        {
            widths = new int[items.Length];
            int total = D(8);
            for (int i = 0; i < items.Length; i++)
            {
                widths[i] = Ui.Measure(items[i], Fonts.Strong(13f * Sc)).Width + D(26);
                if (icons != null && icons[i] != null) widths[i] += D(22);
                total += widths[i];
            }
            Size = new Size(total, D(36));
        }

        public int SelectedIndex
        {
            get { return selected; }
            set { if (value != selected) { selected = value; Invalidate(); } }
        }

        private RectangleF Segment(int i)
        {
            if (Stretch)
            {
                float w = (Width - 8 * Sc) / items.Length;
                return new RectangleF(4 * Sc + i * w, 4 * Sc, w, Height - 8 * Sc - 1);
            }
            float x = 4 * Sc;
            for (int j = 0; j < i; j++) x += widths[j];
            return new RectangleF(x, 4 * Sc, widths[i], Height - 8 * Sc - 1);
        }

        private int HitTest(Point pt)
        {
            for (int i = 0; i < items.Length; i++) if (Segment(i).Contains(pt)) return i;
            return -1;
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            int h = HitTest(e.Location);
            if (h != hover) { hover = h; Invalidate(); }
            base.OnMouseMove(e);
        }

        protected override void OnMouseLeave(EventArgs e) { hover = -1; base.OnMouseLeave(e); }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            if (!Enabled) return;
            int h = HitTest(e.Location);
            if (h >= 0) Select(h);
        }

        protected override bool IsInputKey(Keys keyData)
        {
            return keyData == Keys.Left || keyData == Keys.Right || base.IsInputKey(keyData);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Left && selected > 0) { Select(selected - 1); e.Handled = true; }
            else if (e.KeyCode == Keys.Right && selected < items.Length - 1) { Select(selected + 1); e.Handled = true; }
            base.OnKeyDown(e);
        }

        private void Select(int i)
        {
            if (i == selected) return;
            selected = i;
            Invalidate();
            EventHandler h = Changed;
            if (h != null) h(this, EventArgs.Empty);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            RectangleF box = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            Ui.FillRound(g, box, 10 * Sc, p.Surface2);
            Ui.StrokeRound(g, box, 10 * Sc, p.Border, Math.Max(1f, Sc));
            Font f = Fonts.Strong(13f * Sc);
            for (int i = 0; i < items.Length; i++)
            {
                RectangleF r = Segment(i);
                Color text = p.Muted;
                if (i == selected)
                {
                    Ui.FillRound(g, r, 7 * Sc, Enabled ? p.Orange : Theme.Mix(p.Orange, Under, 0.5f));
                    text = p.OnOrange;
                }
                else if (i == hover && Enabled)
                {
                    Ui.FillRound(g, r, 7 * Sc, p.HoverFill);
                    text = p.Text;
                }
                Rectangle tr = Rectangle.Round(r);
                if (icons != null && icons[i] != null)
                {
                    int tw = Ui.Measure(items[i], f).Width + D(22);
                    int x = tr.X + (tr.Width - tw) / 2;
                    Icons.Draw(g, icons[i], new RectangleF(x, tr.Y, D(18), tr.Height), text, 17 * Sc, false);
                    Ui.Text(g, items[i], f, new Rectangle(x + D(22), tr.Y, tw, tr.Height), text, Ui.Left);
                }
                else Ui.Text(g, items[i], f, tr, text, Ui.Center);
            }
            if (ShowRing) Ring(g, RectangleF.Inflate(box, -1, -1), 10 * Sc);
        }
    }

    internal sealed class TabPill : Painted
    {
        public bool Selected;
        public string Icon;

        public TabPill(string text, string icon, bool selected)
        {
            Selected = selected;
            Icon = icon;
            SetStyle(ControlStyles.Selectable, false);
            TabStop = false;
            Text = text;
            Fit();
        }

        private string savedIcon;

        public void SetCompact(bool compact)
        {
            if (compact && Icon != null) { savedIcon = Icon; Icon = null; }
            else if (!compact && Icon == null && savedIcon != null) { Icon = savedIcon; savedIcon = null; }
            Fit();
            Invalidate();
        }

        private void Fit()
        {
            Font f = Fonts.Strong(14f * Sc);
            Size s = Ui.Measure(Text, f);
            Size = new Size(s.Width + D(26) + (Icon != null ? D(26) : 0), D(36));
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            RectangleF r = new RectangleF(0, 0, Width - 1, Height - 1);
            if (Selected || Hover) Ui.FillRound(g, r, 10 * Sc, Selected ? p.OrangeSoft : p.HoverFill);
            Color c = Selected || Hover ? p.Text : p.Muted;
            int x = D(13);
            if (Icon != null)
            {
                Icons.Draw(g, Icon, new RectangleF(x, 0, D(20), Height), Selected ? p.Orange : c, 19 * Sc, Selected);
                x += D(26);
            }
            Ui.Text(g, Text, Fonts.Strong(14f * Sc), new Rectangle(x, 0, Width - x, Height), c, Ui.Left);
        }
    }

    internal sealed class Chip : Painted
    {
        public Color Back, Fore;
        public string Icon;

        public Chip(string text, string icon, Color back, Color fore)
        {
            SetStyle(ControlStyles.Selectable, false);
            TabStop = false;
            Cursor = Cursors.Default;
            Icon = icon;
            Back = back;
            Fore = fore;
            SetText(text);
        }

        public void SetText(string text)
        {
            Text = text;
            Font f = Fonts.Strong(12f * Sc);
            Size = new Size(Ui.Measure(text, f).Width + D(20) + (Icon != null ? D(20) : 0), D(26));
            Invalidate();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            RectangleF r = new RectangleF(0, 0, Width - 1, Height - 1);
            Ui.FillRound(g, r, r.Height / 2f, Back);
            int x = D(10);
            if (Icon != null)
            {
                Icons.Draw(g, Icon, new RectangleF(x - D(2), 0, D(18), Height), Fore, 15 * Sc, true);
                x += D(19);
            }
            Ui.Text(g, Text, Fonts.Strong(12f * Sc), new Rectangle(x, 0, Width - x, Height), Fore, Ui.Left);
        }
    }

    internal sealed class Glyph : Painted
    {
        public string Icon;
        public Color Back, Fore;

        public Glyph(string icon, int size, Color back, Color fore)
        {
            SetStyle(ControlStyles.Selectable, false);
            TabStop = false;
            Cursor = Cursors.Default;
            Icon = icon;
            Back = back;
            Fore = fore;
            Size = new Size(size, size);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            RectangleF r = new RectangleF(0, 0, Width - 1, Height - 1);
            if (!Back.IsEmpty) Ui.FillRound(g, r, Width * 0.28f, Back);
            Icons.Draw(g, Icon, r, Fore, Width * 0.56f, false);
        }
    }

    internal sealed class ImageBox : Painted
    {
        private readonly Image image;

        public ImageBox(Image image)
        {
            this.image = image;
            SetStyle(ControlStyles.Selectable, false);
            TabStop = false;
            Cursor = Cursors.Default;
            Size = image.Size;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            g.DrawImage(image, 0, 0, image.Width, image.Height);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) image.Dispose();
            base.Dispose(disposing);
        }
    }

    internal sealed class NovaBox : Painted
    {
        public NovaBox(int size)
        {
            SetStyle(ControlStyles.Selectable, false);
            TabStop = false;
            Cursor = Cursors.Default;
            Size = new Size(size, size);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Icons.NovaBadge(g, new RectangleF(0, 0, Width - 1, Height - 1));
        }
    }

    internal sealed class Bar : Painted
    {
        private float value;
        public bool Indeterminate;
        private float phase;
        private readonly Timer timer;
        public Color Color = Color.Empty;

        public Bar()
        {
            SetStyle(ControlStyles.Selectable, false);
            TabStop = false;
            Cursor = Cursors.Default;
            Height = D(6);
            timer = new Timer();
            timer.Interval = 30;
            timer.Tick += delegate { phase = (phase + 0.02f) % 1.4f; Invalidate(); };
        }

        public float Value
        {
            get { return value; }
            set { this.value = Math.Max(0, Math.Min(1, value)); Invalidate(); }
        }

        public void SetIndeterminate(bool on)
        {
            Indeterminate = on;
            timer.Enabled = on && Visible;
            Invalidate();
        }

        protected override void OnVisibleChanged(EventArgs e)
        {
            timer.Enabled = Indeterminate && Visible;
            base.OnVisibleChanged(e);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            RectangleF r = new RectangleF(0, 0, Width - 1, Height - 1);
            Ui.FillRound(g, r, r.Height / 2f, p.Dark ? p.Surface2 : p.HoverFill);
            Color c = Color.IsEmpty ? p.Orange : Color;
            if (Indeterminate)
            {
                float w = r.Width * 0.3f;
                float x = r.X + (phase - 0.3f) * r.Width;
                RectangleF seg = RectangleF.Intersect(new RectangleF(x, r.Y, w, r.Height), r);
                if (seg.Width > 0) Ui.FillRound(g, seg, r.Height / 2f, c);
            }
            else if (value > 0)
            {
                Ui.FillRound(g, new RectangleF(r.X, r.Y, Math.Max(r.Height, r.Width * value), r.Height), r.Height / 2f, c);
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) timer.Dispose();
            base.Dispose(disposing);
        }
    }

    internal sealed class Spinner : Painted
    {
        private float angle;
        private readonly Timer timer;
        public Color Color = Color.Empty;

        public Spinner(int size)
        {
            SetStyle(ControlStyles.Selectable, false);
            TabStop = false;
            Cursor = Cursors.Default;
            Size = new Size(size, size);
            timer = new Timer();
            timer.Interval = 30;
            timer.Tick += delegate { angle = (angle + 12) % 360; Invalidate(); };
            timer.Start();
        }

        protected override void OnVisibleChanged(EventArgs e)
        {
            timer.Enabled = Visible;
            base.OnVisibleChanged(e);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            float w = Math.Max(2f, Width * 0.12f);
            RectangleF r = new RectangleF(w, w, Width - 2 * w - 1, Height - 2 * w - 1);
            using (Pen bg = new Pen(Theme.Mix(Color.IsEmpty ? p.Orange : Color, Under, 0.75f), w))
                g.DrawEllipse(bg, r);
            using (Pen pen = new Pen(Color.IsEmpty ? p.Orange : Color, w))
            {
                pen.StartCap = LineCap.Round;
                pen.EndCap = LineCap.Round;
                g.DrawArc(pen, r, angle, 100);
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) timer.Dispose();
            base.Dispose(disposing);
        }
    }

    internal sealed class Splitter2 : Control
    {
        public event Action<int> Dragged;
        private bool down;
        private int startX;

        public Splitter2()
        {
            Cursor = Cursors.SizeWE;
            SetStyle(ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            down = true;
            startX = e.X;
            Capture = true;
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            if (!down) return;
            Action<int> h = Dragged;
            if (h != null) h(e.X - startX);
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            down = false;
            Capture = false;
        }
    }

    internal sealed class ThemedMenu : ToolStripProfessionalRenderer
    {
        public ThemedMenu() : base(new MenuColors()) { RoundedEdges = false; }

        protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e)
        {
            e.TextColor = e.Item.Enabled ? (e.Item.Tag as string == "danger" ? Theme.P.Danger : Theme.P.Text) : Theme.P.Faint;
            base.OnRenderItemText(e);
        }

        protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e)
        {
            if (!e.Item.Selected || !e.Item.Enabled) return;
            Rectangle r = new Rectangle(Ui.D(4), 1, e.Item.Width - Ui.D(8), e.Item.Height - 2);
            Icons.Smooth(e.Graphics);
            Ui.FillRound(e.Graphics, r, 6 * Ui.Sc, Theme.P.HoverFill);
        }

        protected override void OnRenderImageMargin(ToolStripRenderEventArgs e) { }

        protected override void OnRenderToolStripBorder(ToolStripRenderEventArgs e)
        {
            using (Pen pen = new Pen(Theme.P.Border)) e.Graphics.DrawRectangle(pen, 0, 0, e.AffectedBounds.Width - 1, e.AffectedBounds.Height - 1);
        }

        protected override void OnRenderSeparator(ToolStripSeparatorRenderEventArgs e)
        {
            int y = e.Item.Height / 2;
            using (Pen pen = new Pen(Theme.P.Border)) e.Graphics.DrawLine(pen, Ui.D(10), y, e.Item.Width - Ui.D(10), y);
        }

        protected override void OnRenderItemImage(ToolStripItemImageRenderEventArgs e)
        {
            string icon = e.Item.ImageKey;
            if (string.IsNullOrEmpty(icon)) return;
            Icons.Draw(e.Graphics, icon, e.ImageRectangle, e.Item.Tag as string == "danger" ? Theme.P.Danger : Theme.P.Muted, 18 * Ui.Sc, false);
        }

        private sealed class MenuColors : ProfessionalColorTable
        {
            public override Color ToolStripDropDownBackground { get { return Theme.P.Surface; } }
            public override Color MenuBorder { get { return Theme.P.Border; } }
            public override Color MenuItemBorder { get { return Color.Transparent; } }
            public override Color ImageMarginGradientBegin { get { return Theme.P.Surface; } }
            public override Color ImageMarginGradientMiddle { get { return Theme.P.Surface; } }
            public override Color ImageMarginGradientEnd { get { return Theme.P.Surface; } }
            public override Color SeparatorDark { get { return Theme.P.Border; } }
            public override Color SeparatorLight { get { return Theme.P.Border; } }
        }

        public static ContextMenuStrip Make()
        {
            ContextMenuStrip m = new ContextMenuStrip();
            m.Renderer = new ThemedMenu();
            m.BackColor = Theme.P.Surface;
            m.ShowImageMargin = true;
            m.Padding = new Padding(0, Ui.D(4), 0, Ui.D(4));
            m.ImageScalingSize = new Size(Ui.D(20), Ui.D(20));
            m.Font = Fonts.Body(13.5f * Ui.Sc);
            return m;
        }

        public static ToolStripMenuItem Item(ContextMenuStrip m, string text, string icon, EventHandler click)
        {
            ToolStripMenuItem it = new ToolStripMenuItem(text);
            it.ImageKey = icon;
            it.Image = Blank;
            it.Font = Fonts.Body(13.5f * Ui.Sc);
            it.Padding = new Padding(Ui.D(4), Ui.D(5), Ui.D(18), Ui.D(5));
            if (click != null) it.Click += click;
            m.Items.Add(it);
            return it;
        }

        private static Bitmap blank;
        private static Bitmap Blank
        {
            get
            {
                if (blank == null) blank = new Bitmap(Ui.D(20), Ui.D(20));
                return blank;
            }
        }
    }
}
