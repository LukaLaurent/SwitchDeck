$ErrorActionPreference = 'Stop'
$scriptPath = $MyInvocation.MyCommand.Path
$splash = $null
$quiet = @('--selftest', '--sshtest', '--render-ui', '--exit', '--demo-shell', '--write-assets') | Where-Object { $args -contains $_ }

function Show-Splash {
    $existing = $null
    if ([System.Threading.Mutex]::TryOpenExisting('Local\SwitchDeck-6c1e2f94', [ref]$existing)) { $existing.Dispose(); return $null }
    $ab = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object Reflection.AssemblyName 'SwitchDeckSplash'), 'Run')
    $tb = $ab.DefineDynamicModule('SwitchDeckSplash').DefineType('SwitchDeckSplash.Native', 'Public,Class')
    [void]$tb.DefinePInvokeMethod('SetProcessDpiAwarenessContext', 'user32.dll', 'Public,Static,PinvokeImpl', 'Standard', [bool], [Type[]]@([IntPtr]), 'Winapi', 'Auto')
    [void]$tb.DefinePInvokeMethod('DwmSetWindowAttribute', 'dwmapi.dll', 'Public,Static,PinvokeImpl', 'Standard', [int], [Type[]]@([IntPtr], [int], [int].MakeByRefType(), [int]), 'Winapi', 'Auto')
    $native = $tb.CreateType()
    try { [void]$native::SetProcessDpiAwarenessContext([IntPtr](-4)) } catch { }
    $root = Split-Path -Parent (Split-Path -Parent $scriptPath)
    $assets = Join-Path $root 'assets'
    $g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
    $sc = $g.DpiX / 96.0
    $g.Dispose()
    $fonts = New-Object System.Drawing.Text.PrivateFontCollection
    foreach ($f in 'Poppins-SemiBold.ttf', 'Inter-Regular.ttf') {
        $p = Join-Path $assets ('fonts\' + $f)
        if (Test-Path $p) { $fonts.AddFontFile($p) }
    }
    $head = 'Segoe UI Semibold'; $body = 'Segoe UI'
    foreach ($fam in $fonts.Families) {
        if ($fam.Name -like '*Poppins*') { $head = $fam }
        if ($fam.Name -like '*Inter*') { $body = $fam }
    }
    $charcoal = [System.Drawing.Color]::FromArgb(32, 37, 43)
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = 'None'
    $form.StartPosition = 'CenterScreen'
    $form.ShowInTaskbar = $true
    $form.Text = 'SwitchDeck'
    $form.BackColor = $charcoal
    $form.ClientSize = New-Object System.Drawing.Size ([int](360 * $sc)), ([int](250 * $sc))
    $ico = Join-Path $assets 'icon.ico'
    if (Test-Path $ico) { $form.Icon = New-Object System.Drawing.Icon $ico }
    $logoPath = Join-Path $assets 'logo.png'
    if (Test-Path $logoPath) {
        $logo = New-Object System.Windows.Forms.PictureBox
        $logo.SizeMode = 'Zoom'
        $logo.Image = [System.Drawing.Image]::FromFile($logoPath)
        $logo.Size = New-Object System.Drawing.Size ([int](72 * $sc)), ([int](72 * $sc))
        $logo.Location = New-Object System.Drawing.Point ([int](($form.ClientSize.Width - $logo.Width) / 2)), ([int](40 * $sc))
        $form.Controls.Add($logo)
    }
    $title = New-Object System.Windows.Forms.Label
    $title.UseCompatibleTextRendering = $true
    $title.Text = 'SwitchDeck'
    $title.ForeColor = [System.Drawing.Color]::FromArgb(245, 243, 239)
    $title.Font = New-Object System.Drawing.Font($head, [single](20 * $sc), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $title.TextAlign = 'MiddleCenter'
    $title.SetBounds(0, [int](122 * $sc), $form.ClientSize.Width, [int](34 * $sc))
    $form.Controls.Add($title)
    $sub = New-Object System.Windows.Forms.Label
    $sub.UseCompatibleTextRendering = $true
    $sub.Text = if ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'fr') { 'Chargement...' } else { 'Loading...' }
    $sub.ForeColor = [System.Drawing.Color]::FromArgb(163, 170, 177)
    $sub.Font = New-Object System.Drawing.Font($body, [single](13 * $sc), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $sub.TextAlign = 'MiddleCenter'
    $sub.SetBounds(0, [int](158 * $sc), $form.ClientSize.Width, [int](22 * $sc))
    $form.Controls.Add($sub)
    $novaPath = Join-Path $assets 'nova.png'
    $powered = New-Object System.Windows.Forms.Label
    $powered.UseCompatibleTextRendering = $true
    $powered.Text = 'Powered by Nova'
    $powered.ForeColor = [System.Drawing.Color]::FromArgb(111, 118, 126)
    $powered.Font = New-Object System.Drawing.Font($body, [single](11.5 * $sc), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $powered.AutoSize = $true
    $form.Controls.Add($powered)
    $pw = $powered.PreferredWidth
    $nw = [int](18 * $sc)
    $x = [int](($form.ClientSize.Width - $pw - $nw - 6 * $sc) / 2)
    $y = [int](212 * $sc)
    if (Test-Path $novaPath) {
        $nova = New-Object System.Windows.Forms.PictureBox
        $nova.SizeMode = 'Zoom'
        $nova.Image = [System.Drawing.Image]::FromFile($novaPath)
        $nova.SetBounds($x, $y, $nw, $nw)
        $form.Controls.Add($nova)
        $x += $nw + [int](6 * $sc)
    }
    $powered.Location = New-Object System.Drawing.Point $x, ([int]($y + ($nw - $powered.PreferredHeight) / 2))
    $form.Show()
    try {
        $round = 2
        [void]$native::DwmSetWindowAttribute($form.Handle, 33, [ref]$round, 4)
        $dark = 1
        [void]$native::DwmSetWindowAttribute($form.Handle, 20, [ref]$dark, 4)
    } catch { }
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
    return $form
}

$sources = @(
@'
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
'@,
@'
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
'@,
@'
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
'@,
@'
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
'@,
@'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Threading;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal sealed class DeployState
    {
        public string HostId, TemplateId, Mode;
        public List<string> Ports = new List<string>();
        public bool Write;
        public int Step;
    }

    internal sealed class DeployRun
    {
        public Deployer Deployer;
        public DeployPlan Plan;
        public Session Session;
        public string Step = "";
        public volatile bool Done;
        public string Error;
        public readonly Dictionary<string, string> Status = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        public readonly object Gate = new object();
        public int Version;
    }

    internal sealed class DeployPage : Pane, IPage
    {
        public static DeployRun Run;
        private readonly MainForm main;
        private readonly StepBar steps;
        private int step;

        private readonly Card setup;
        private readonly Dropdown hostPick, templatePick;
        private readonly Label hostState, templateInfo, modeHint;
        private readonly Segmented mode;
        private readonly Check optWrite;
        private readonly Btn continueBtn, advBtn;
        private bool advanced;

        private readonly Card portsCard;
        private readonly TextField selText;
        private readonly Btn allBtn, noneBtn, backBtn, commandsBtn, deployBtn;
        private readonly Faceplate plate;
        private readonly ScrollPanel plateScroll;
        private readonly EmptyState noPorts;

        private readonly Card resultsCard;
        private readonly Bar progress;
        private readonly Label stepLabel;
        private readonly ItemList results;
        private readonly Btn stopBtn, okBtn;
        private readonly Segmented resultView;
        private readonly Faceplate resultPlate;
        private readonly ScrollPanel resultScroll;
        private readonly Label legend;

        private readonly System.Windows.Forms.Timer poll;
        private int seenVersion = -1;
        private bool syncing;
        private Host host;
        private Template template;
        private bool finishedShown;

        public DeployPage(MainForm main)
        {
            this.main = main;
            Palette p = Theme.P;
            BackColor = p.Bg;

            steps = new StepBar(new[] { L.T("stepSetup"), L.T("stepPorts"), L.T("stepResults") });
            Controls.Add(steps);

            setup = new Card();
            setup.Title = L.T("setupTitle");
            setup.Icon = "tune";
            Controls.Add(setup);
            setup.Controls.Add(Caption("lblSwitch", L.T("fieldSwitch")));
            hostPick = new Dropdown();
            hostPick.Placeholder = L.T("pickSwitch");
            hostPick.Changed += delegate { SetHost(Store.FindHost(hostPick.Value as string)); };
            setup.Controls.Add(hostPick);
            hostState = Ui.Label("", Fonts.Body(12.5f * Ui.Sc), p.Muted);
            setup.Controls.Add(hostState);
            setup.Controls.Add(Caption("lblTemplate", L.T("fieldTemplate")));
            templatePick = new Dropdown();
            templatePick.Placeholder = L.T("pickTemplate");
            templatePick.Changed += delegate { SetTemplate(Store.FindTemplate(templatePick.Value as string)); };
            setup.Controls.Add(templatePick);
            templateInfo = Ui.Label("", Fonts.Body(12.5f * Ui.Sc), p.Muted);
            templateInfo.AutoSize = false;
            templateInfo.AutoEllipsis = true;
            setup.Controls.Add(templateInfo);
            setup.Controls.Add(Caption("lblMode", L.T("modeTitle")));
            mode = new Segmented(new[] { L.T("modeRange"), L.T("modeSingle") }, new[] { "select_all", "format_list_numbered" }, Store.Settings.DefaultMode == "single" ? 1 : 0);
            mode.Stretch = true;
            mode.Changed += delegate { ModeChanged(true); };
            setup.Controls.Add(mode);
            modeHint = Ui.Label("", Fonts.Body(12.5f * Ui.Sc), p.Muted);
            modeHint.AutoSize = false;
            setup.Controls.Add(modeHint);
            optWrite = new Check(L.T("optWrite"), Store.Settings.WriteMemory);
            Tips.Set(optWrite, L.T("optWriteTip"));
            setup.Controls.Add(optWrite);
            advBtn = new Btn(L.T("advancedOptions"), "expand_more", BtnKind.Ghost, delegate
            {
                advanced = !advanced;
                advBtn.Icon = advanced ? "expand_less" : "expand_more";
                advBtn.Invalidate();
                Lay();
            }).Small();
            setup.Controls.Add(advBtn);
            continueBtn = new Btn(L.T("continue"), "chevron_right", BtnKind.Primary, delegate { GoTo(1); });
            setup.Controls.Add(continueBtn);

            portsCard = new Card();
            portsCard.Icon = "settings_ethernet";
            Controls.Add(portsCard);
            selText = new TextField("", "Gi1/0/1-12, Te1/1/1", "edit", false, true);
            selText.Changed += delegate { if (!syncing) TextToSelection(); };
            portsCard.Controls.Add(selText);
            allBtn = new Btn(L.T("all"), null, BtnKind.Secondary, delegate { plate.SelectAll(); }).Small();
            noneBtn = new Btn(L.T("none"), null, BtnKind.Secondary, delegate { plate.SelectNone(); }).Small();
            portsCard.Controls.Add(allBtn);
            portsCard.Controls.Add(noneBtn);
            plate = new Faceplate();
            plate.SelectionChanged += delegate { SelectionToText(); UpdateDeployButton(); };
            plateScroll = new ScrollPanel();
            plateScroll.BackColor = p.Surface;
            plateScroll.Content.Controls.Add(plate);
            portsCard.Controls.Add(plateScroll);
            noPorts = new EmptyState(L.T("noPortsTitle"), L.T("deployNoPorts"), L.T("editSwitchShort"), "edit", delegate
            {
                if (host == null) return;
                main.Switches.EditHost(host);
                Host h = Store.FindHost(host.Id);
                if (h != null) SetHost(h);
            });
            portsCard.Controls.Add(noPorts);
            backBtn = new Btn(L.T("back"), "chevron_left", BtnKind.Secondary, delegate { GoTo(0); });
            commandsBtn = new Btn(L.T("showCommands"), "code", BtnKind.Ghost, delegate { ShowCommands(); });
            deployBtn = new Btn(L.T("deploy"), "rocket_launch", BtnKind.Primary, delegate { StartDeploy(); });
            portsCard.Controls.Add(backBtn);
            portsCard.Controls.Add(commandsBtn);
            portsCard.Controls.Add(deployBtn);

            resultsCard = new Card();
            resultsCard.Icon = "fact_check";
            Controls.Add(resultsCard);
            progress = new Bar();
            resultsCard.Controls.Add(progress);
            stepLabel = Ui.Label("", Fonts.Body(13f * Ui.Sc), p.Muted);
            stepLabel.AutoSize = false;
            stepLabel.AutoEllipsis = true;
            resultsCard.Controls.Add(stepLabel);
            results = new ItemList();
            results.HeightOf = delegate(object o) { PortResult r = (PortResult)o; return r.Message.Length > 0 ? D(58) : D(40); };
            results.Gap = 0;
            results.PaintItem = PaintResult;
            results.EmptyNova = false;
            results.Activated += delegate(object o) { PortResult r = (PortResult)o; if (r.Message.Length > 0) Dialogs.Info(main, r.Port, r.Message, Ui.StatusIcon(r.Status)); };
            resultsCard.Controls.Add(results);
            results.Visible = false;
            resultPlate = new Faceplate();
            resultPlate.Selectable = false;
            resultPlate.PortClicked += delegate(string port)
            {
                if (Run == null) return;
                PortResult r = Run.Deployer.Entry.Results.Find(delegate(PortResult x) { return string.Equals(x.Port, port, StringComparison.OrdinalIgnoreCase); });
                if (r != null && r.Message.Length > 0) Dialogs.Info(main, r.Port, r.Message, Ui.StatusIcon(r.Status));
            };
            resultScroll = new ScrollPanel();
            resultScroll.BackColor = p.Surface;
            resultScroll.Content.Controls.Add(resultPlate);
            resultsCard.Controls.Add(resultScroll);
            legend = Ui.Label(L.T("resultsLegend"), Fonts.Body(12.5f * Ui.Sc), p.Faint);
            legend.AutoSize = false;
            legend.AutoEllipsis = true;
            resultsCard.Controls.Add(legend);
            resultView = new Segmented(new[] { L.T("viewPorts"), L.T("viewList") }, new[] { "grid_view", "view_list" }, 0);
            resultView.Changed += delegate { LayResults(); };
            resultsCard.Controls.Add(resultView);
            stopBtn = new Btn(L.T("stop"), "stop", BtnKind.Danger, delegate { StopRun(); });
            okBtn = new Btn(L.T("ok"), "check", BtnKind.Primary, delegate { ClearRun(); GoTo(0); });
            resultsCard.Controls.Add(stopBtn);
            resultsCard.Controls.Add(okBtn);

            poll = new System.Windows.Forms.Timer();
            poll.Interval = 120;
            poll.Tick += delegate { Poll(); };
            poll.Start();

            FillHosts();
            FillTemplates();
            if (Store.Hosts.Count > 0) SetHost(SortedHosts()[0]);
            if (Store.Templates.Count > 0) SetTemplate(SortedTemplates()[0]);
            ModeChanged(false);
            if (Run != null) { AttachRun(); step = 2; }
            ShowStep();
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) { poll.Stop(); poll.Dispose(); }
            base.Dispose(disposing);
        }

        private int D(float v) { return Ui.D(v); }

        private static Label Caption(string name, string text)
        {
            Label l = Ui.Label(text, Fonts.Strong(13f * Ui.Sc), Theme.P.Text);
            l.Name = name;
            return l;
        }

        public void Shown()
        {
            FillHosts();
            FillTemplates();
            if (host != null) { Host h = Store.FindHost(host.Id); if (h != null) SetHost(h, true); }
            UpdateHostState();
        }

        private bool Running { get { return Run != null && !Run.Done; } }

        private List<Host> SortedHosts()
        {
            List<Host> l = new List<Host>(Store.Hosts);
            l.Sort(delegate(Host a, Host b) { return string.Compare(a.Name, b.Name, StringComparison.CurrentCultureIgnoreCase); });
            return l;
        }

        private List<Template> SortedTemplates()
        {
            List<Template> l = new List<Template>(Store.Templates);
            l.Sort(delegate(Template a, Template b) { return string.Compare(a.Name, b.Name, StringComparison.CurrentCultureIgnoreCase); });
            return l;
        }

        private void FillHosts()
        {
            hostPick.Items.Clear();
            foreach (Host h in SortedHosts())
            {
                DropItem d = new DropItem(h.Name, h.Id);
                d.Sub = h.Kind == "demo" ? h.DemoModel : h.Target;
                d.Icon = SwitchesPage.KindIcon(h);
                hostPick.Items.Add(d);
            }
            hostPick.SelectValue(host == null ? null : host.Id);
        }

        private void FillTemplates()
        {
            templatePick.Items.Clear();
            foreach (Template t in SortedTemplates())
            {
                DropItem d = new DropItem(t.Name, t.Id);
                d.Dot = Theme.Accents[Math.Max(0, Math.Min(Theme.Accents.Length - 1, t.Color))];
                templatePick.Items.Add(d);
            }
            templatePick.SelectValue(template == null ? null : template.Id);
            if (template != null && Store.FindTemplate(template.Id) == null) SetTemplate(null);
        }

        public void TemplatesChanged()
        {
            if (IsDisposed) return;
            FillTemplates();
            if (template != null)
            {
                Template t = Store.FindTemplate(template.Id);
                if (t != null) SetTemplate(t);
            }
        }

        public void SessionsChanged()
        {
            if (IsDisposed) return;
            FillHosts();
            if (host != null)
            {
                Host h = Store.FindHost(host.Id);
                if (h != null) SetHost(h, true);
            }
        }

        public void Prepare(Host h, List<string> ports, string templateId)
        {
            if (Running) { GoTo(2); return; }
            if (Run != null) ClearRun();
            if (h != null) SetHost(Store.FindHost(h.Id) ?? h);
            if (templateId != null) SetTemplate(Store.FindTemplate(templateId));
            if (ports != null) { plate.SetSelection(ports); SelectionToText(); }
            GoTo(0);
        }

        private void SetHost(Host h) { SetHost(h, false); }

        private void SetHost(Host h, bool keepSelection)
        {
            bool changed = host == null || h == null || host.Id != h.Id;
            host = h;
            hostPick.SelectValue(h == null ? null : h.Id);
            List<string> keep = keepSelection || !changed ? new List<string>(plate.Selected) : new List<string>();
            plate.SetPorts(h == null ? new List<PortInfo>() : h.Ports);
            plate.SetSelection(keep);
            UpdateHostState();
            SelectionToText();
            UpdateContinue();
            Lay();
        }

        private void UpdateHostState()
        {
            Palette p = Theme.P;
            if (host == null) { hostState.Text = ""; return; }
            Session s = Sessions.For(host.Id);
            string text;
            Color c;
            if (s != null && s.State == SessionState.Connected) { text = L.T("hostConnected"); c = p.Success; }
            else if (s != null && s.State == SessionState.Connecting) { text = L.T("stateConnecting"); c = p.Warning; }
            else { text = L.T("hostWillConnect"); c = p.Muted; }
            if (hostState.Text != text) hostState.Text = text;
            hostState.ForeColor = c;
        }

        private void SetTemplate(Template t)
        {
            template = t;
            templatePick.SelectValue(t == null ? null : t.Id);
            if (t != null && Cisco.UsesPort(t.Body) && mode.SelectedIndex == 0) mode.SelectedIndex = 1;
            templateInfo.Text = t == null ? "" : (t.Description.Length > 0 ? t.Description : L.F("linesCount", t.Lines.Count));
            ModeChanged(false);
            UpdateContinue();
        }

        private void ModeChanged(bool user)
        {
            bool usesPort = template != null && Cisco.UsesPort(template.Body);
            if (usesPort && mode.SelectedIndex == 0)
            {
                mode.SelectedIndex = 1;
                if (user) main.Notify(L.T("portVarSingle"), "info");
            }
            modeHint.Text = mode.SelectedIndex == 0 ? L.T("modeRangeHint") : L.T("modeSingleHint");
            Lay();
        }

        private void UpdateContinue()
        {
            continueBtn.Enabled = host != null && template != null;
        }

        private Dictionary<string, string> Values()
        {
            Dictionary<string, string> d = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            if (template != null) foreach (KeyValuePair<string, string> kv in template.Defaults) d[kv.Key] = kv.Value.Trim();
            return d;
        }

        private DeployPlan MakePlan()
        {
            if (host == null || template == null) return null;
            DeployPlan plan = DeployPlan.FromTemplate(host, template, Values(), plate.SelectedSorted(), mode.SelectedIndex == 0 ? "range" : "single");
            plan.Reset = template.ResetFirst;
            plan.WriteMemory = optWrite.Checked;
            return plan;
        }

        private void GoTo(int s)
        {
            if (s == 1)
            {
                if (host == null || template == null) return;
                Dictionary<string, string> vals = Values();
                foreach (string v in Cisco.Variables(template.Body))
                {
                    string val;
                    if (!vals.TryGetValue(v, out val) || val.Length == 0)
                    {
                        Dialogs.Info(main, L.T("missingValueTitle"), L.F("missingValueText", v, template.Name), "data_object");
                        return;
                    }
                }
            }
            step = s;
            ShowStep();
        }

        private void ShowStep()
        {
            steps.Current = step;
            steps.Invalidate();
            setup.Visible = step == 0;
            portsCard.Visible = step == 1;
            resultsCard.Visible = step == 2;
            if (step == 1)
            {
                portsCard.Title = host == null ? L.T("portsTitle") : L.F("portsOf", host.Name);
                SelectionToText();
                UpdateDeployButton();
            }
            Lay();
        }

        private void SetCount(string text)
        {
            portsCard.Subtitle = text;
            portsCard.Invalidate(new Rectangle(0, 0, portsCard.Width, portsCard.HeaderHeight));
        }

        private void SelectionToText()
        {
            syncing = true;
            selText.Text = Ports.Compact(plate.Selected);
            selText.Error = false;
            syncing = false;
            int n = plate.Selected.Count;
            SetCount(n == 0 ? L.T("noneSelected") : L.F("selectedCount", n));
        }

        private void TextToSelection()
        {
            List<string> errors = new List<string>();
            List<string> names = Ports.Expand(selText.Text, errors);
            List<string> missing = new List<string>();
            if (host != null) foreach (string n in names) if (host.FindPort(n) == null) missing.Add(n);
            selText.Error = errors.Count > 0 || missing.Count > 0;
            selText.Invalidate();
            Tips.Set(selText, errors.Count > 0 ? L.F("badPorts", string.Join(", ", errors.ToArray())) : missing.Count > 0 ? L.F("unknownPorts", Ports.Compact(missing)) : null);
            plate.SetSelection(names);
            int c = plate.Selected.Count;
            SetCount(c == 0 ? L.T("noneSelected") : L.F("selectedCount", c));
            UpdateDeployButton();
        }

        private void UpdateDeployButton()
        {
            int n = plate.Selected.Count;
            deployBtn.SetText(n == 0 ? L.T("deploy") : n == 1 ? L.T("deployToOne") : L.F("deployTo", n));
            deployBtn.Enabled = n > 0;
            commandsBtn.Enabled = n > 0;
            LayPorts();
        }

        private void ShowCommands()
        {
            DeployPlan plan = MakePlan();
            if (plan == null || plan.Ports.Count == 0) return;
            using (CommandsForm f = new CommandsForm(string.Join("\n", plan.Script().ToArray())))
                f.ShowDialog(main);
        }

        public void ShowPortsStep() { GoTo(1); }

        public void DeployOrStop()
        {
            if (Running) StopRun();
            else StartDeploy();
        }

        private void StopRun()
        {
            if (!Running) return;
            if (Run.Session != null) Run.Session.RequestStop();
            stopBtn.Enabled = false;
            stopBtn.SetText(L.T("stopping"));
            LayResults();
        }

        private void StartDeploy()
        {
            DeployPlan plan = MakePlan();
            if (plan == null || plan.Ports.Count == 0) return;
            Session existing = Sessions.For(host.Id);
            if (existing != null && existing.Busy) { main.Notify(L.T("busyWait"), "warn"); return; }
            if (Store.Settings.ConfirmDeploy && !Program.Rendering)
            {
                string text = L.F("confirmText", template.Name, plan.Ports.Count, host.Name, Ports.Compact(plan.Ports), plan.Script().Count);
                if (plan.WriteMemory) text += "\n\n" + L.T("confirmWrite");
                if (!Dialogs.Ask(main, L.T("confirmTitle"), text, L.F("deployTo", plan.Ports.Count), L.T("cancel"), "rocket_launch", false)) return;
            }
            Session s = existing;
            if (s == null) s = Sessions.Open(host, 120, 32);
            else if (s.State == SessionState.Closed) Sessions.StartAsync(s);
            DeployRun run = new DeployRun();
            run.Plan = plan;
            run.Session = s;
            run.Deployer = new Deployer(s, plan);
            foreach (string port in plan.Ports) run.Status[port] = "pending";
            run.Deployer.Step += delegate(string st) { lock (run.Gate) { run.Step = st; run.Version++; } };
            run.Deployer.PortChanged += delegate(PortResult r) { lock (run.Gate) { run.Status[r.Port] = r.Status; run.Version++; } };
            Run = run;
            finishedShown = false;
            Thread t = new Thread(delegate()
            {
                try { run.Deployer.Run(); }
                catch (Exception ex) { run.Error = ex.Message; Log.Error("Deploy thread: " + ex); }
                finally { run.Done = true; lock (run.Gate) run.Version++; }
            });
            t.IsBackground = true;
            t.Start();
            AttachRun();
            step = 2;
            ShowStep();
        }

        private void AttachRun()
        {
            seenVersion = -1;
            resultsCard.Title = L.F("resultsTitle", Run.Plan.TemplateName, Run.Plan.Host.Name);
            results.SetItems(Run.Deployer.Entry.Results.ConvertAll(delegate(PortResult r) { return (object)r; }), null);
            if (host == null || host.Id != Run.Plan.Host.Id) SetHost(Store.FindHost(Run.Plan.Host.Id) ?? Run.Plan.Host);
            Host rh = Store.FindHost(Run.Plan.Host.Id) ?? Run.Plan.Host;
            List<PortInfo> shown = new List<PortInfo>(rh.Ports);
            foreach (string port in Run.Plan.Ports) if (rh.FindPort(port) == null) shown.Add(new PortInfo(port, ""));
            resultPlate.SetPorts(shown);
            resultPlate.SetSelection(new string[0]);
            plate.SetSelection(Run.Plan.Ports);
            SelectionToText();
            stopBtn.Enabled = true;
            stopBtn.SetText(L.T("stop"));
            Poll();
        }

        private void ClearRun()
        {
            if (Running) return;
            Run = null;
        }

        private void Poll()
        {
            UpdateHostState();
            DeployRun run = Run;
            if (run == null) return;
            int v;
            string stepText;
            Dictionary<string, string> status;
            lock (run.Gate)
            {
                v = run.Version;
                stepText = run.Step;
                status = new Dictionary<string, string>(run.Status, StringComparer.OrdinalIgnoreCase);
            }
            if (v == seenVersion && !(run.Done && !finishedShown)) return;
            seenVersion = v;
            results.Invalidate();
            resultPlate.SetResults(status);
            Dictionary<string, string> msgs = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (PortResult pr in run.Deployer.Entry.Results) if (pr.Message.Length > 0) msgs[pr.Port] = pr.Message;
            resultPlate.Messages = msgs;
            int done = 0;
            foreach (string s in status.Values) if (s != "pending" && s != "running") done++;
            bool running = !run.Done;
            if (running)
            {
                progress.Color = Color.Empty;
                progress.SetIndeterminate(done == 0);
                progress.Value = status.Count == 0 ? 0 : (float)done / status.Count;
                stepLabel.Text = stepText;
                stepLabel.ForeColor = Theme.P.Muted;
            }
            else
            {
                finishedShown = true;
                progress.SetIndeterminate(false);
                progress.Value = 1;
                HistoryEntry e = run.Deployer.Entry;
                string overall = e.Overall;
                progress.Color = Ui.StatusColor(overall);
                string summary = L.F("doneSummary", e.Count("ok"), e.Count("warn"), e.Count("failed"), e.Count("skipped"));
                if (e.Summary.Length > 0) summary = e.Summary + "   " + summary;
                if (e.WroteMemory) summary += "   " + L.T("savedStartup");
                stepLabel.Text = summary;
                stepLabel.ForeColor = Ui.StatusColor(overall);
                if (v >= 0) main.Notify(overall == "ok" ? L.F("deployOk", e.TemplateName, e.Results.Count) : overall == "warn" ? L.T("deployWarn") : L.T("deployFailed"), overall == "ok" ? "ok" : overall == "warn" ? "warn" : "error");
                seenVersion = run.Version;
            }
            stopBtn.Visible = running;
            okBtn.Visible = !running;
            LayResults();
        }

        private void PaintResult(Graphics g, Rectangle r, object item, bool sel, bool hover)
        {
            Palette p = Theme.P;
            PortResult pr = (PortResult)item;
            string st = pr.Status;
            if (Run != null) { string s; lock (Run.Gate) { if (Run.Status.TryGetValue(pr.Port, out s)) st = s; } }
            ItemList.Row(g, r, false, hover);
            Color c = Ui.StatusColor(st);
            Icons.Draw(g, Ui.StatusIcon(st), new RectangleF(r.X + D(14), r.Y, D(22), D(40)), c, 20 * Ui.Sc, st == "ok" || st == "failed" || st == "warn");
            Ui.Text(g, pr.Port, Fonts.Mono(13.5f * Ui.Sc), new Rectangle(r.X + D(44), r.Y, D(110), D(40)), p.Text, Ui.Left);
            Ui.Text(g, L.ResultText(st), Fonts.Strong(12.5f * Ui.Sc), new Rectangle(r.X + D(150), r.Y, D(160), D(40)), c, Ui.Left);
            if (pr.Message.Length > 0)
                Ui.Text(g, pr.Message.Replace("\n", "   "), Fonts.Body(12.5f * Ui.Sc), new Rectangle(r.X + D(44), r.Y + D(32), r.Width - D(60), D(20)), p.Muted, Ui.Left);
        }

        public DeployState CaptureState()
        {
            DeployState s = new DeployState();
            s.HostId = host == null ? null : host.Id;
            s.TemplateId = template == null ? null : template.Id;
            s.Mode = mode.SelectedIndex == 0 ? "range" : "single";
            s.Ports = new List<string>(plate.Selected);
            s.Write = optWrite.Checked;
            s.Step = step;
            return s;
        }

        public void Restore(DeployState s)
        {
            if (s.HostId != null) SetHost(Store.FindHost(s.HostId));
            if (s.TemplateId != null) SetTemplate(Store.FindTemplate(s.TemplateId));
            mode.SelectedIndex = s.Mode == "single" ? 1 : 0;
            optWrite.Checked = s.Write;
            if (Run == null) { plate.SetSelection(s.Ports); SelectionToText(); }
            ModeChanged(false);
            step = Run != null ? 2 : Math.Min(1, s.Step);
            ShowStep();
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            Lay();
        }

        private void Lay()
        {
            if (steps == null || resultsCard == null) return;
            int pad = D(18);
            steps.Bounds = new Rectangle(pad, pad, Width - 2 * pad, D(44));
            int top = steps.Bottom + D(14);
            Rectangle area = new Rectangle(pad, top, Width - 2 * pad, Height - top - pad);
            if (setup.Visible) LaySetup(area);
            if (portsCard.Visible) { portsCard.Bounds = area; LayPorts(); }
            if (resultsCard.Visible) { resultsCard.Bounds = area; LayResults(); }
        }

        private void LaySetup(Rectangle area)
        {
            int w = Math.Min(D(560), area.Width);
            int x = D(24), iw = w - 2 * x;
            int y = setup.HeaderHeight + D(4);
            Control c = setup.Controls["lblSwitch"];
            c.Location = new Point(x, y); y += D(24);
            hostPick.Bounds = new Rectangle(x, y, iw, D(40)); y += D(46);
            hostState.Location = new Point(x, y); y += D(34);
            c = setup.Controls["lblTemplate"];
            c.Location = new Point(x, y); y += D(24);
            templatePick.Bounds = new Rectangle(x, y, iw, D(40)); y += D(46);
            templateInfo.Bounds = new Rectangle(x, y, iw, D(20)); y += D(34);
            advBtn.Location = new Point(x - D(8), y - D(4)); y += advBtn.Height + D(6);
            c = setup.Controls["lblMode"];
            c.Visible = mode.Visible = modeHint.Visible = optWrite.Visible = advanced;
            if (advanced)
            {
                c.Location = new Point(x, y); y += D(26);
                mode.Bounds = new Rectangle(x, y, iw, D(38)); y += D(46);
                int hh = Ui.WrapHeight(modeHint.Text, modeHint.Font, iw) + D(2);
                modeHint.Bounds = new Rectangle(x, y, iw, hh); y += hh + D(20);
                optWrite.Location = new Point(x, y); y += D(36);
            }
            y += D(8);
            continueBtn.Location = new Point(w - x - continueBtn.Width, y);
            y = continueBtn.Bottom + D(24);
            int h = Math.Min(y, area.Height);
            setup.Bounds = new Rectangle(area.X + (area.Width - w) / 2, area.Y + Math.Max(0, (area.Height - h) / 3), w, h);
        }

        private void LayPorts()
        {
            if (!portsCard.Visible) return;
            int w = portsCard.Width, h = portsCard.Height;
            bool has = host != null && host.Ports.Count > 0;
            selText.Visible = allBtn.Visible = noneBtn.Visible = has;
            commandsBtn.Visible = has;
            deployBtn.Visible = has;
            int by = D(19);
            noneBtn.Location = new Point(w - D(16) - noneBtn.Width, by);
            allBtn.Location = new Point(noneBtn.Left - D(6) - allBtn.Width, by);
            int titleW = Math.Max(Ui.Measure(portsCard.Title ?? "", Fonts.Head(15.5f * Ui.Sc)).Width, Ui.Measure(L.F("selectedCount", 888), Fonts.Body(12.5f * Ui.Sc)).Width - D(36));
            int fieldX = D(20) + D(36) + titleW + D(24);
            selText.Bounds = new Rectangle(fieldX, D(16), Math.Max(D(120), allBtn.Left - D(12) - fieldX), D(38));
            int footer = D(64);
            int fy = h - D(18) - deployBtn.Height;
            backBtn.Location = new Point(D(18), fy);
            deployBtn.Location = new Point(w - D(18) - deployBtn.Width, fy);
            commandsBtn.Location = new Point(deployBtn.Left - D(8) - commandsBtn.Width, fy);
            int top = portsCard.HeaderHeight + D(4);
            Rectangle inner = new Rectangle(D(20), top, w - D(40), h - top - footer - D(6));
            noPorts.Visible = !has;
            plateScroll.Visible = has;
            if (!has) { noPorts.Bounds = inner; return; }
            plateScroll.Bounds = inner;
            int need = plate.Layout2(inner.Width - D(14));
            plate.Bounds = new Rectangle(0, 0, inner.Width - D(14), need);
            plateScroll.SetContentHeight(need);
        }

        private void LayResults()
        {
            if (!resultsCard.Visible) return;
            int w = resultsCard.Width, h = resultsCard.Height;
            int top = resultsCard.HeaderHeight;
            progress.Bounds = new Rectangle(D(20), top, w - D(40), D(6));
            stepLabel.Bounds = new Rectangle(D(20), top + D(14), w - D(40), D(22));
            resultView.Location = new Point(w - D(18) - resultView.Width, D(12));
            int fy = h - D(18) - stopBtn.Height;
            stopBtn.Location = new Point(w - D(18) - stopBtn.Width, fy);
            okBtn.Location = new Point(w - D(18) - okBtn.Width, fy);
            bool list = resultView.SelectedIndex == 1;
            results.Visible = list;
            resultScroll.Visible = !list;
            legend.Visible = !list;
            Rectangle body = new Rectangle(D(16), stepLabel.Bottom + D(10), w - D(32), fy - D(14) - stepLabel.Bottom - D(10));
            results.Bounds = body;
            legend.Bounds = new Rectangle(D(20), fy + (stopBtn.Height - D(20)) / 2, Math.Max(D(40), okBtn.Left - D(36)), D(20));
            Rectangle pb = new Rectangle(D(20), body.Y + D(4), w - D(40), body.Height - D(4));
            resultScroll.Bounds = pb;
            int need = resultPlate.Layout2(pb.Width - D(14));
            resultPlate.Bounds = new Rectangle(0, 0, pb.Width - D(14), need);
            resultScroll.SetContentHeight(need);
        }
    }

    internal sealed class StepBar : Painted
    {
        private readonly string[] names;
        public int Current;

        public StepBar(string[] names)
        {
            this.names = names;
            Cursor = Cursors.Default;
            SetStyle(ControlStyles.Selectable, false);
            TabStop = false;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            Font f = Fonts.Strong(13.5f * Sc);
            int dot = D(26), gap = D(10), line = D(48);
            int total = 0;
            foreach (string n in names) total += dot + gap + Ui.Measure(n, f).Width;
            total += line * (names.Length - 1) + D(16) * (names.Length - 1);
            int x = (Width - total) / 2;
            int cy = Height / 2;
            for (int i = 0; i < names.Length; i++)
            {
                bool done = i < Current, cur = i == Current;
                RectangleF c = new RectangleF(x, cy - dot / 2f, dot, dot);
                Color fill = cur ? p.Orange : done ? p.OrangeSoft : p.Surface2;
                using (SolidBrush br = new SolidBrush(fill)) g.FillEllipse(br, c);
                if (!cur && !done) using (Pen pen = new Pen(p.Border, Math.Max(1f, Sc))) g.DrawEllipse(pen, c);
                if (done) Icons.Draw(g, "check", c, p.Orange, 16 * Sc, false);
                else Ui.Text(g, (i + 1).ToString(), Fonts.Strong(12.5f * Sc), Rectangle.Round(c), cur ? p.OnOrange : p.Muted, Ui.Center);
                x += dot + gap;
                int tw = Ui.Measure(names[i], f).Width;
                Ui.Text(g, names[i], f, new Rectangle(x, 0, tw + D(4), Height), cur ? p.Text : p.Muted, Ui.Left);
                x += tw;
                if (i < names.Length - 1)
                {
                    x += D(8);
                    using (Pen pen = new Pen(done ? p.Orange : p.Border, Math.Max(1.5f, 1.5f * Sc))) g.DrawLine(pen, x, cy, x + line, cy);
                    x += line + D(8);
                }
            }
        }
    }

    internal sealed class CommandsForm : DialogForm
    {
        public CommandsForm(string text) : base(L.T("showCommands"), "code", 640, 560)
        {
            CodeBox box = new CodeBox(text, true);
            box.Bounds = new Rectangle(Ui.D(20), Ui.D(16), Ui.D(600), Ui.D(560) - HeaderH - FooterH - Ui.D(32));
            Body.Controls.Add(box);
            AddButton(L.T("copy"), "content_copy", BtnKind.Ghost, delegate { try { Clipboard.SetText(text.Replace("\n", "\r\n")); MainForm.Instance.Notify(L.T("copied"), "ok"); } catch { } });
            AddButton(L.T("close"), "check", BtnKind.Primary, DialogResult.OK);
        }
    }
}
'@,
@'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal class DialogForm : Form
    {
        protected readonly Pane Body;
        protected readonly Pane Footer;
        private readonly string title;
        private readonly string icon;
        private readonly Color iconColor, iconBack;
        protected readonly List<Btn> Buttons = new List<Btn>();
        public bool Nova;

        public DialogForm(string title, string icon, int width, int height)
        {
            this.title = title;
            this.icon = icon;
            iconColor = Theme.P.Orange;
            iconBack = Theme.P.OrangeSoft;
            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.CenterParent;
            AutoScaleMode = AutoScaleMode.None;
            ShowInTaskbar = false;
            KeyPreview = true;
            DoubleBuffered = true;
            BackColor = Theme.P.Surface;
            Text = title;
            Size = new Size(Ui.D(width), Ui.D(height));
            Body = new Pane();
            Body.BackColor = Theme.P.Surface;
            Footer = new Pane();
            Footer.BackColor = Theme.P.Surface;
            Controls.Add(Body);
            Controls.Add(Footer);
            Footer.Paint += delegate(object s, PaintEventArgs e)
            {
                using (Pen pen = new Pen(Theme.P.Border)) e.Graphics.DrawLine(pen, 0, 0, Footer.Width, 0);
            };
            MouseDown += Drag;
            Body.MouseDown += Drag;
        }

        public DialogForm(string title, string icon, int width, int height, Color fore, Color back) : this(title, icon, width, height)
        {
            iconColor = fore;
            iconBack = back;
        }

        protected int HeaderH { get { return Ui.D(64); } }
        protected int FooterH { get { return Ui.D(68); } }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.ClassStyle |= 0x20000;
                return cp;
            }
        }

        protected override void OnLoad(EventArgs e)
        {
            if (Owner == null && StartPosition == FormStartPosition.CenterParent)
            {
                Rectangle work = Screen.FromPoint(Cursor.Position).WorkingArea;
                StartPosition = FormStartPosition.Manual;
                Location = new Point(work.Left + (work.Width - Width) / 2, work.Top + (work.Height - Height) / 2);
            }
            base.OnLoad(e);
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            try
            {
                int round = 2;
                Native.DwmSetWindowAttribute(Handle, 33, ref round, 4);
                Color c = Theme.P.Border;
                int colorRef = c.R | (c.G << 8) | (c.B << 16);
                Native.DwmSetWindowAttribute(Handle, 34, ref colorRef, 4);
                int dark = Theme.P.Dark ? 1 : 0;
                Native.DwmSetWindowAttribute(Handle, 20, ref dark, 4);
            }
            catch { }
        }

        protected override void OnLayout(LayoutEventArgs e)
        {
            base.OnLayout(e);
            if (Body == null) return;
            Body.Bounds = new Rectangle(0, HeaderH, ClientSize.Width, ClientSize.Height - HeaderH - FooterH);
            Footer.Bounds = new Rectangle(0, ClientSize.Height - FooterH, ClientSize.Width, FooterH);
            int x = Footer.Width - Ui.D(24);
            for (int i = Buttons.Count - 1; i >= 0; i--)
            {
                Btn b = Buttons[i];
                b.Location = new Point(x - b.Width, (FooterH - b.Height) / 2);
                x = b.Left - Ui.D(10);
            }
        }

        protected Btn AddButton(string text, string ic, BtnKind kind, DialogResult result)
        {
            Btn b = new Btn(text, ic, kind, delegate { DialogResult = result; Close(); });
            Buttons.Add(b);
            Footer.Controls.Add(b);
            PerformLayout();
            return b;
        }

        protected Btn AddButton(string text, string ic, BtnKind kind, EventHandler click)
        {
            Btn b = new Btn(text, ic, kind, click);
            Buttons.Add(b);
            Footer.Controls.Add(b);
            PerformLayout();
            return b;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            Graphics g = e.Graphics;
            Palette p = Theme.P;
            Icons.Smooth(g);
            int x = Ui.D(24);
            if (Nova)
            {
                Icons.NovaBadge(g, new RectangleF(x, Ui.D(16), Ui.D(34), Ui.D(34)));
                x += Ui.D(46);
            }
            else if (icon != null)
            {
                RectangleF ib = new RectangleF(x, Ui.D(18), Ui.D(30), Ui.D(30));
                Ui.FillRound(g, ib, 8 * Ui.Sc, iconBack);
                Icons.Draw(g, icon, ib, iconColor, 20 * Ui.Sc, false);
                x += Ui.D(42);
            }
            Ui.Text(g, title, Fonts.Head(17f * Ui.Sc), new Rectangle(x, Ui.D(14), ClientSize.Width - x - Ui.D(60), Ui.D(38)), p.Text, Ui.Left);
            using (Pen pen = new Pen(p.Border)) g.DrawLine(pen, 0, HeaderH - 1, ClientSize.Width, HeaderH - 1);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Escape) { DialogResult = DialogResult.Cancel; Close(); e.Handled = true; }
            base.OnKeyDown(e);
        }

        private void Drag(object sender, MouseEventArgs e)
        {
            if (e.Button != MouseButtons.Left || e.Y > HeaderH && sender == this) return;
            if (sender == Body) return;
            Native.ReleaseCapture();
            Native.SendMessage(Handle, Native.WM_NCLBUTTONDOWN, new IntPtr(Native.HTCAPTION), IntPtr.Zero);
        }

        protected Label AddLabel(Control parent, string text, int x, int y, int width, bool strong)
        {
            Label l = Ui.Label(text, strong ? Fonts.Strong(13.5f * Ui.Sc) : Fonts.Body(13.5f * Ui.Sc), strong ? Theme.P.Text : Theme.P.Muted);
            l.AutoSize = false;
            l.Location = new Point(x, y);
            l.Size = new Size(width, Ui.WrapHeight(text, l.Font, width) + Ui.D(2));
            parent.Controls.Add(l);
            return l;
        }
    }

    internal static class Dialogs
    {
        public static bool Ask(IWin32Window owner, string title, string text, string ok, string cancel, string icon, bool danger)
        {
            Palette p = Theme.P;
            using (DialogForm f = new MessageForm(title, text, icon, danger ? p.Danger : p.Orange, danger ? p.DangerSoft : p.OrangeSoft, false, ok, cancel, danger))
                return f.ShowDialog(owner) == DialogResult.OK;
        }

        public static void Problem(IWin32Window owner, string title, string text)
        {
            using (DialogForm f = new MessageForm(title, text, null, Color.Empty, Color.Empty, true, L.T("ok"), null, false))
                f.ShowDialog(owner);
        }

        public static void Info(IWin32Window owner, string title, string text, string icon)
        {
            using (DialogForm f = new MessageForm(title, text, icon, Theme.P.Teal, Theme.P.TealSoft, false, L.T("ok"), null, false))
                f.ShowDialog(owner);
        }

        public static string Input(IWin32Window owner, string title, string label, string value, string icon)
        {
            using (InputForm f = new InputForm(title, label, value, icon))
                return f.ShowDialog(owner) == DialogResult.OK ? f.Value : null;
        }
    }

    internal sealed class MessageForm : DialogForm
    {
        public MessageForm(string title, string text, string icon, Color fore, Color back, bool nova, string ok, string cancel, bool danger)
            : base(title, icon, 480, 220, fore, back)
        {
            Nova = nova;
            int w = Ui.D(480) - Ui.D(48);
            int th = Ui.WrapHeight(text, Fonts.Body(14f * Ui.Sc), w);
            Height = HeaderH + FooterH + Ui.D(44) + th;
            Label l = Ui.Label(text, Fonts.Body(14f * Ui.Sc), Theme.P.Text);
            l.AutoSize = false;
            l.Bounds = new Rectangle(Ui.D(24), Ui.D(22), w, th + Ui.D(4));
            Body.Controls.Add(l);
            if (cancel != null) AddButton(cancel, null, BtnKind.Secondary, DialogResult.Cancel);
            Btn b = AddButton(ok, null, danger ? BtnKind.Danger : BtnKind.Primary, DialogResult.OK);
            AcceptButton2 = b;
        }

        private Btn AcceptButton2;

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            if (AcceptButton2 != null) AcceptButton2.Focus();
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Enter) { DialogResult = DialogResult.OK; Close(); e.Handled = true; return; }
            base.OnKeyDown(e);
        }
    }

    internal sealed class InputForm : DialogForm
    {
        private readonly TextField field;
        public string Value { get { return field.Text.Trim(); } }

        public InputForm(string title, string label, string value, string icon) : base(title, icon, 460, 230)
        {
            AddLabel(Body, label, Ui.D(24), Ui.D(20), Ui.D(412), false);
            field = new TextField(value, null, null, false, false);
            field.Bounds = new Rectangle(Ui.D(24), Ui.D(48), Ui.D(412), Ui.D(40));
            field.Submit += delegate { DialogResult = DialogResult.OK; Close(); };
            Body.Controls.Add(field);
            AddButton(L.T("cancel"), null, BtnKind.Secondary, DialogResult.Cancel);
            AddButton(L.T("save"), null, BtnKind.Primary, DialogResult.OK);
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            field.Box.Focus();
            field.Box.SelectAll();
        }
    }

    internal sealed class ChoiceForm : DialogForm
    {
        public string Choice;

        public ChoiceForm(Host h) : base(L.F("portsAskTitle", h.Name), "settings_ethernet", 620, 410)
        {
            AddLabel(Body, L.T("portsAskText"), Ui.D(24), Ui.D(20), Ui.D(572), false);
            int y = Ui.D(78);
            int w = (Ui.D(572) - Ui.D(16)) / 2;
            Body.Controls.Add(Option("detect", "manage_search", L.T("portsAskDetect"), L.T("portsAskDetectText"), new Rectangle(Ui.D(24), y, w, Ui.D(176)), true));
            Body.Controls.Add(Option("manual", "edit", L.T("portsAskManual"), L.T("portsAskManualText"), new Rectangle(Ui.D(24) + w + Ui.D(16), y, w, Ui.D(176)), false));
            AddButton(L.T("later"), null, BtnKind.Ghost, DialogResult.Cancel);
        }

        private Control Option(string key, string ic, string title, string text, Rectangle r, bool primary)
        {
            OptionCard c = new OptionCard(ic, title, text, primary);
            c.Bounds = r;
            c.Click += delegate { Choice = key; DialogResult = DialogResult.OK; Close(); };
            return c;
        }
    }

    internal sealed class OptionCard : Painted
    {
        private readonly string icon, title, text;
        private readonly bool primary;

        public OptionCard(string icon, string title, string text, bool primary)
        {
            this.icon = icon;
            this.title = title;
            this.text = text;
            this.primary = primary;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            Ui.FillRound(g, r, 14 * Sc, Hover ? (primary ? p.OrangeSoft : p.HoverFill) : p.Surface2);
            Ui.StrokeRound(g, r, 14 * Sc, Hover ? p.Orange : p.Border, Hover ? 1.6f * Sc : Math.Max(1f, Sc));
            RectangleF ib = new RectangleF(D(18), D(18), D(40), D(40));
            Ui.FillRound(g, ib, 10 * Sc, primary ? p.Orange : p.TealSoft);
            Icons.Draw(g, icon, ib, primary ? p.OnOrange : p.Teal, 24 * Sc, false);
            Ui.Text(g, title, Fonts.Head(15f * Sc), new Rectangle(D(18), D(66), Width - D(36), D(24)), p.Text, Ui.Left);
            TextRenderer.DrawText(g, text, Fonts.Body(13f * Sc), new Rectangle(D(18), D(94), Width - D(36), Height - D(100)), p.Muted, Ui.Wrap);
            if (ShowRing) Ring(g, RectangleF.Inflate(r, -1, -1), 14 * Sc);
        }
    }
}
'@,
@'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal sealed class Faceplate : Painted
    {
        private sealed class Slot
        {
            public string Name;
            public PortName P;
            public Rectangle R;
        }

        private sealed class Section
        {
            public string Label;
            public Rectangle R;
            public List<Slot> Slots = new List<Slot>();
        }

        private readonly List<Section> sections = new List<Section>();
        private readonly List<Slot> order = new List<Slot>();
        private List<PortInfo> ports = new List<PortInfo>();
        public readonly HashSet<string> Selected = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        public Dictionary<string, PortStatus> Status = new Dictionary<string, PortStatus>(StringComparer.OrdinalIgnoreCase);
        public Dictionary<string, string> Results = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        public Dictionary<string, string> Messages = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        public event Action<string> PortClicked;
        public bool Selectable = true;
        public event EventHandler SelectionChanged;
        private Slot hover;
        private Slot anchor;
        private bool painting, paintAdd;
        private int laidWidth = -1;
        private readonly Timer pulse;
        private int pulseStep;

        public Faceplate()
        {
            Cursor = Cursors.Default;
            pulse = new Timer();
            pulse.Interval = 60;
            pulse.Tick += delegate { pulseStep = (pulseStep + 1) % 20; Invalidate(); };
        }

        private int PortW { get { return D(36); } }
        private int PortH { get { return D(30); } }
        private int Gap { get { return D(6); } }

        public void SetPorts(List<PortInfo> list)
        {
            ports = list ?? new List<PortInfo>();
            HashSet<string> names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (PortInfo p in ports) names.Add(p.Name);
            Selected.RemoveWhere(delegate(string n) { return !names.Contains(n); });
            laidWidth = -1;
            Layout2(Width);
            Invalidate();
        }

        public List<string> SelectedSorted()
        {
            return Ports.Sorted(Selected);
        }

        public void SetResults(Dictionary<string, string> results)
        {
            Results = results;
            bool running = false;
            foreach (string v in results.Values) if (v == "running") running = true;
            pulse.Enabled = running;
            Invalidate();
        }

        public int Layout2(int width)
        {
            sections.Clear();
            order.Clear();
            Dictionary<string, Section> byKey = new Dictionary<string, Section>();
            List<Slot> slots = new List<Slot>();
            foreach (PortInfo pi in ports)
            {
                Slot s = new Slot();
                s.Name = pi.Name;
                s.P = Ports.Parse(pi.Name);
                slots.Add(s);
            }
            slots.Sort(delegate(Slot a, Slot b)
            {
                if (a.P == null && b.P == null) return string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase);
                if (a.P == null) return 1;
                if (b.P == null) return -1;
                return a.P.CompareTo(b.P);
            });
            List<Section> groups = new List<Section>();
            foreach (Slot s in slots)
            {
                string key = s.P == null ? "?" : s.P.GroupKey;
                Section sec;
                if (!byKey.TryGetValue(key, out sec))
                {
                    sec = new Section();
                    sec.Label = s.P == null ? L.T("otherPorts") : s.P.Type + s.P.Prefix.TrimEnd('/');
                    byKey[key] = sec;
                    groups.Add(sec);
                }
                sec.Slots.Add(s);
                order.Add(s);
            }
            if (width <= 0) { laidWidth = -1; return 0; }
            int x = 0, y = 0, rowH = 0;
            int labelH = D(22);
            int maxCols = Math.Max(2, (width + Gap) / (PortW + Gap));
            int perChunk = maxCols * 2;
            foreach (Section grp in groups)
            {
                int totalCols = (grp.Slots.Count + 1) / 2;
                int chunks = Math.Max(1, (totalCols + maxCols - 1) / maxCols);
                int colsPer = (totalCols + chunks - 1) / chunks;
                perChunk = colsPer * 2;
                for (int start = 0; start < grp.Slots.Count; start += perChunk)
                {
                    List<Slot> chunk = grp.Slots.GetRange(start, Math.Min(perChunk, grp.Slots.Count - start));
                    int ccols = (chunk.Count + 1) / 2;
                    int w = ccols * (PortW + Gap) - Gap;
                    int h = labelH + PortH * 2 + Gap;
                    if (x > 0 && x + w > width)
                    {
                        x = 0;
                        y += rowH + D(14);
                        rowH = 0;
                    }
                    Section part = new Section();
                    part.Label = start == 0 ? grp.Label : "";
                    part.R = new Rectangle(x, y, w, h);
                    part.Slots = chunk;
                    for (int i = 0; i < chunk.Count; i++)
                    {
                        int col = i / 2, row = i % 2;
                        chunk[i].R = new Rectangle(x + col * (PortW + Gap), y + labelH + row * (PortH + Gap), PortW, PortH);
                    }
                    sections.Add(part);
                    x += w + D(22);
                    rowH = Math.Max(rowH, h);
                }
            }
            laidWidth = width;
            return order.Count == 0 ? 0 : y + rowH + D(4);
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            if (Width != laidWidth) Layout2(Width);
        }

        private Slot HitTest(Point p)
        {
            foreach (Slot s in order) if (Rectangle.Inflate(s.R, D(2), D(2)).Contains(p)) return s;
            return null;
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            Slot s = HitTest(e.Location);
            if (s != hover)
            {
                hover = s;
                Invalidate();
                if (s != null)
                {
                    Tips.Set(this, TipFor(s.Name));
                }
                else Tips.Set(this, null);
            }
            Cursor = s != null && (Selectable || PortClicked != null) ? Cursors.Hand : Cursors.Default;
            if (painting && s != null && Selectable)
            {
                bool changed = paintAdd ? Selected.Add(s.Name) : Selected.Remove(s.Name);
                if (changed) Raise();
            }
            base.OnMouseMove(e);
        }

        private string TipFor(string name)
        {
            List<string> parts = new List<string>();
            PortName pn = Ports.Parse(name);
            parts.Add(pn != null ? pn.Long : name);
            foreach (PortInfo p in ports) if (p.Name == name && p.Description.Length > 0) parts.Add(p.Description);
            PortStatus st;
            if (Status.TryGetValue(name, out st))
            {
                if (st.Name.Length > 0 && !parts.Contains(st.Name)) parts.Add(st.Name);
                parts.Add(L.StatusText(st.Status) + (st.Vlan.Length > 0 ? ", " + (st.Vlan == "trunk" ? L.T("trunk") : "VLAN " + st.Vlan) : ""));
            }
            string r;
            if (Results.TryGetValue(name, out r)) parts.Add(L.ResultText(r));
            string msg;
            if (Messages.TryGetValue(name, out msg) && msg.Length > 0) parts.Add(msg);
            return string.Join("\n", parts.ToArray());
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            hover = null;
            base.OnMouseLeave(e);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            if (e.Button != MouseButtons.Left) return;
            Slot s = HitTest(e.Location);
            if (s == null) return;
            if (!Selectable)
            {
                Action<string> pc = PortClicked;
                if (pc != null) pc(s.Name);
                return;
            }
            if ((ModifierKeys & Keys.Shift) != 0 && anchor != null)
            {
                int a = order.IndexOf(anchor), b = order.IndexOf(s);
                if (a > b) { int t = a; a = b; b = t; }
                for (int i = a; i <= b; i++) Selected.Add(order[i].Name);
                Raise();
                return;
            }
            paintAdd = !Selected.Contains(s.Name);
            if (paintAdd) Selected.Add(s.Name); else Selected.Remove(s.Name);
            anchor = s;
            painting = true;
            Capture = true;
            Raise();
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            painting = false;
            Capture = false;
            base.OnMouseUp(e);
        }

        private void Raise()
        {
            Invalidate();
            EventHandler h = SelectionChanged;
            if (h != null) h(this, EventArgs.Empty);
        }

        public void SelectAll()
        {
            foreach (Slot s in order) Selected.Add(s.Name);
            Raise();
        }

        public void SelectNone()
        {
            Selected.Clear();
            Raise();
        }

        public void SelectWhere(Func<string, PortStatus, bool> test)
        {
            Selected.Clear();
            foreach (Slot s in order)
            {
                PortStatus st;
                Status.TryGetValue(s.Name, out st);
                if (test(s.Name, st)) Selected.Add(s.Name);
            }
            Raise();
        }

        public void SetSelection(IEnumerable<string> names)
        {
            Selected.Clear();
            HashSet<string> have = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (Slot s in order) have.Add(s.Name);
            foreach (string n in names) if (have.Contains(n)) Selected.Add(n);
            Invalidate();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            if (laidWidth != Width) Layout2(Width);
            foreach (Section sec in sections)
            {
                if (!string.IsNullOrEmpty(sec.Label))
                {
                    Ui.Text(g, sec.Label, Fonts.Strong(12f * Sc), new Rectangle(sec.R.X, sec.R.Y, Math.Max(sec.R.Width, D(80)), D(18)), p.Muted, Ui.Left);
                    string sp = sec.Slots.Count > 0 && sec.Slots[0].P != null ? Ports.Speed(sec.Slots[0].P.Type) : "";
                    if (sp.Length > 0)
                    {
                        int lw = Ui.Measure(sec.Label, Fonts.Strong(12f * Sc)).Width;
                        Ui.Text(g, sp, Fonts.Body(11.5f * Sc), new Rectangle(sec.R.X + lw + D(6), sec.R.Y, D(60), D(18)), p.Faint, Ui.Left);
                    }
                }
                foreach (Slot s in sec.Slots) PaintPort(g, s);
            }
        }

        private void PaintPort(Graphics g, Slot s)
        {
            Palette p = Theme.P;
            bool sel = Selected.Contains(s.Name);
            bool hv = hover == s && Selectable;
            PortStatus st;
            Status.TryGetValue(s.Name, out st);
            string result;
            Results.TryGetValue(s.Name, out result);
            RectangleF r = new RectangleF(s.R.X + 0.5f, s.R.Y + 0.5f, s.R.Width - 1, s.R.Height - 1);
            bool disabled = st != null && (st.Status == "disabled");
            Color fill = sel ? (hv ? p.OrangeHover : p.Orange) : (hv ? p.HoverFill : p.Surface2);
            Color border = sel ? p.Orange : (hv ? p.Faint : p.Border);
            Color text = sel ? p.OnOrange : (disabled ? p.Faint : p.Text);
            if (result != null && !sel)
            {
                Color rc = Ui.StatusColor(result);
                if (result == "running") rc = Theme.Mix(p.Orange, p.Surface2, (float)Math.Abs(10 - pulseStep) / 14f);
                fill = Theme.Mix(rc, p.Surface, p.Dark ? 0.72f : 0.8f);
                border = rc;
            }
            Ui.FillRound(g, r, 6 * Sc, fill);
            Ui.StrokeRound(g, r, 6 * Sc, border, (result != null || sel) ? 1.5f * Sc : Math.Max(1f, Sc));
            bool sfp = s.P != null && (s.P.Type == "Te" || s.P.Type == "Twe" || s.P.Type == "Fo" || s.P.Type == "Hu");
            if (!sfp && s.P != null && s.P.Type != "Po")
            {
                float nw = r.Width * 0.36f, nh = D(4);
                RectangleF notch = new RectangleF(r.X + (r.Width - nw) / 2f, r.Bottom - nh - D(2), nw, nh);
                Ui.FillRound(g, notch, 1.5f * Sc, sel ? Color.FromArgb(70, Theme.Charcoal) : (p.Dark ? Theme.Mix(p.Border, fill, 0.2f) : p.Border));
            }
            else if (sfp)
            {
                RectangleF bar = new RectangleF(r.X + D(5), r.Bottom - D(6), r.Width - D(10), D(2));
                Ui.FillRound(g, bar, 1 * Sc, sel ? Color.FromArgb(70, Theme.Charcoal) : p.Border);
            }
            string label = s.P != null ? s.P.Number.ToString() : s.Name;
            Font f = Fonts.Strong((label.Length > 2 ? 10.5f : 11.5f) * Sc);
            Ui.Text(g, label, f, new Rectangle(s.R.X, s.R.Y - D(3), s.R.Width, s.R.Height), text, Ui.Center);
            if (st != null)
            {
                Color led = st.Status == "connected" ? p.Success : st.Status == "err-disabled" ? p.Danger : Color.Empty;
                if (!led.IsEmpty)
                {
                    float d = 6 * Sc;
                    using (SolidBrush br = new SolidBrush(led)) g.FillEllipse(br, r.Right - d - D(3), r.Y + D(3), d, d);
                }
                if (disabled && !sel)
                {
                    using (Pen pen = new Pen(Color.FromArgb(120, p.Faint), Math.Max(1f, Sc)))
                        g.DrawLine(pen, r.X + D(5), r.Bottom - D(5), r.Right - D(5), r.Y + D(5));
                }
            }
            if (result == "ok" || result == "failed" || result == "warn")
            {
                float d = 13 * Sc;
                RectangleF b = new RectangleF(r.Right - d + D(4), r.Y - D(5), d, d);
                using (SolidBrush br = new SolidBrush(Ui.StatusColor(result))) g.FillEllipse(br, b);
                Icons.Draw(g, result == "ok" ? "check" : result == "warn" ? "priority_high" : "close", b, Color.White, 10 * Sc, false);
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) pulse.Dispose();
            base.Dispose(disposing);
        }
    }
}
'@,
@'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO.Ports;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal sealed class HostDialog : DialogForm
    {
        private readonly Host host;
        private readonly bool isNew;
        private TextField name, address, port, user, pass, ports;
        private Segmented kind;
        private Dropdown com, baud, model;
        private Pane sshPane, serialPane, demoPane;
        private Label userLabel, passLabel, passHint, portsHint;
        private int passX, userX;
        public Host Result;

        public HostDialog(Host source)
            : base(source == null ? L.T("addSwitch") : L.F("editSwitch", source.Name), source == null ? "add" : "edit", 620, 640)
        {
            isNew = source == null;
            host = source == null ? new Host() : source.Clone();
            Build();
            AddButton(L.T("cancel"), null, BtnKind.Secondary, DialogResult.Cancel);
            AddButton(isNew ? L.T("addSwitchShort") : L.T("save"), "check", BtnKind.Primary, delegate { Save(); });
        }

        private int D(float v) { return Ui.D(v); }

        private Label Caption(Control parent, string text, int x, int y)
        {
            Label l = Ui.Label(text, Fonts.Strong(13f * Ui.Sc), Theme.P.Text);
            l.Location = new Point(x, y);
            parent.Controls.Add(l);
            return l;
        }

        private TextField Field(Control parent, string label, string value, string placeholder, string icon, bool pw, bool mono, int x, int y, int w)
        {
            Caption(parent, label, x, y);
            TextField f = new TextField(value, placeholder, icon, pw, mono);
            f.Bounds = new Rectangle(x, y + D(24), w, D(40));
            parent.Controls.Add(f);
            return f;
        }

        private Label Hint(Control parent, string text, int x, int y, int w)
        {
            Label l = Ui.Label(text, Fonts.Body(12.5f * Ui.Sc), Theme.P.Muted);
            l.AutoSize = false;
            l.Bounds = new Rectangle(x, y, w, Ui.WrapHeight(text, l.Font, w) + D(2));
            parent.Controls.Add(l);
            return l;
        }

        private void Build()
        {
            Pane c = Body;
            int L0 = D(24), W = D(572), half = (W - D(16)) / 2;
            int y = D(20);
            name = Field(c, L.T("fieldName"), host.Name, L.T("phName"), "label", false, false, L0, y, W);
            y += D(80);
            Caption(c, L.T("fieldKind"), L0, y);
            int sel = host.Kind == "serial" ? 1 : host.Kind == "demo" ? 2 : 0;
            kind = new Segmented(new[] { "SSH", L.T("kindSerial"), L.T("kindDemo") }, new[] { "lan", "usb", "science" }, sel);
            kind.Location = new Point(L0, y + D(24));
            kind.Changed += delegate { ShowKind(); };
            c.Controls.Add(kind);
            y += D(80);

            sshPane = new Pane { BackColor = Theme.P.Surface, Bounds = new Rectangle(0, y, D(620), D(70)) };
            address = Field(sshPane, L.T("fieldAddress"), host.Address, "10.0.1.2", "dns", false, false, L0, 0, W - D(140));
            port = Field(sshPane, L.T("fieldPort"), host.Port.ToString(), "22", null, false, false, L0 + W - D(124), 0, D(124));
            c.Controls.Add(sshPane);

            serialPane = new Pane { BackColor = Theme.P.Surface, Bounds = new Rectangle(0, y, D(620), D(70)) };
            Caption(serialPane, L.T("fieldCom"), L0, 0);
            com = new Dropdown();
            com.Bounds = new Rectangle(L0, D(24), half, D(40));
            List<string> names = new List<string>();
            try { names.AddRange(SerialPort.GetPortNames()); } catch { }
            if (!names.Contains(host.ComPort)) names.Add(host.ComPort);
            names.Sort(StringComparer.OrdinalIgnoreCase);
            foreach (string n in names) com.Items.Add(new DropItem(n, n) { Icon = "usb" });
            com.SelectValue(host.ComPort);
            serialPane.Controls.Add(com);
            Caption(serialPane, L.T("fieldBaud"), L0 + half + D(16), 0);
            baud = new Dropdown();
            baud.Bounds = new Rectangle(L0 + half + D(16), D(24), half, D(40));
            foreach (int b in new[] { 9600, 19200, 38400, 57600, 115200 }) baud.Items.Add(new DropItem(b.ToString(), b));
            baud.SelectValue(host.Baud);
            if (baud.SelectedIndex < 0) baud.SelectedIndex = 0;
            serialPane.Controls.Add(baud);
            c.Controls.Add(serialPane);

            demoPane = new Pane { BackColor = Theme.P.Surface, Bounds = new Rectangle(0, y, D(620), D(70)) };
            Caption(demoPane, L.T("fieldModel"), L0, 0);
            model = new Dropdown();
            model.Bounds = new Rectangle(L0, D(24), W, D(40));
            model.Items.Add(new DropItem("Catalyst 9300 48 ports", "C9300-48P") { Sub = "IOS XE", Icon = "router" });
            model.Items.Add(new DropItem("Catalyst 2960X 24 ports", "WS-C2960X-24PS-L") { Sub = "IOS 15", Icon = "router" });
            model.Items.Add(new DropItem("Catalyst 9200L 48 ports", "C9200L-48P-4X") { Sub = "IOS XE", Icon = "router" });
            model.Items.Add(new DropItem("Catalyst 9200L stack of 2", "C9200L-48P-4X-STACK") { Sub = "IOS XE", Icon = "router" });
            model.SelectValue(string.IsNullOrEmpty(host.DemoModel) ? "C9300-48P" : host.DemoModel);
            demoPane.Controls.Add(model);
            c.Controls.Add(demoPane);
            y += D(80);

            user = Field(c, L.T("fieldUser"), host.Username, "admin", "person", false, false, L0, y, half);
            userLabel = (Label)c.Controls[c.Controls.Count - 2];
            string pw = Secret.Reveal(host.Password);
            if (pw.Length == 0) pw = Secret.Reveal(host.Enable);
            pass = Field(c, L.T("fieldPassword"), pw, null, "key", true, false, L0 + half + D(16), y, half);
            passLabel = (Label)c.Controls[c.Controls.Count - 2];
            passX = L0 + half + D(16);
            userX = L0;
            y += D(68);
            passHint = Hint(c, L.T("passwordHint"), L0, y, W);
            y += D(36);

            List<string> names2 = new List<string>();
            foreach (PortInfo p in host.Ports) names2.Add(p.Name);
            ports = Field(c, L.T("fieldPorts"), Ports.Compact(names2), "Gi1/0/1-48, Te1/1/1-4", "settings_ethernet", false, true, L0, y, W);
            y += D(68);
            portsHint = Hint(c, L.T("portsFieldHint"), L0, y, W);
            ShowKind();
        }

        private string KindValue { get { return kind.SelectedIndex == 1 ? "serial" : kind.SelectedIndex == 2 ? "demo" : "ssh"; } }

        private void ShowKind()
        {
            string k = KindValue;
            sshPane.Visible = k == "ssh";
            serialPane.Visible = k == "serial";
            demoPane.Visible = k == "demo";
            user.Visible = userLabel.Visible = k != "demo";
            int px = k == "demo" ? userX : passX;
            pass.Left = px;
            passLabel.Left = px;
            passHint.Text = k == "demo" ? L.T("demoPasswordHint") : L.T("passwordHint");
        }

        private void Save()
        {
            bool ok = true;
            if (name.Text.Trim().Length == 0) { name.Error = true; name.Invalidate(); ok = false; }
            string k = KindValue;
            int portNo = 22;
            if (k == "ssh")
            {
                if (address.Text.Trim().Length == 0 || address.Text.Trim().Contains(" ")) { address.Error = true; address.Invalidate(); ok = false; }
                if (!int.TryParse(port.Text.Trim(), out portNo) || portNo < 1 || portNo > 65535) { port.Error = true; port.Invalidate(); ok = false; }
            }
            List<string> errors = new List<string>();
            List<string> list = Ports.Expand(ports.Text, errors);
            if (errors.Count > 0)
            {
                ports.Error = true;
                ports.Invalidate();
                portsHint.Text = L.F("badPorts", string.Join(", ", errors.ToArray()));
                portsHint.ForeColor = Theme.P.Danger;
                ok = false;
            }
            if (!ok) return;
            host.Name = name.Text.Trim();
            host.Group = "";
            host.Kind = k;
            host.Address = address.Text.Trim();
            host.Port = portNo;
            host.Legacy = true;
            host.ComPort = com.Value as string ?? "COM1";
            host.Baud = baud.Value is int ? (int)baud.Value : 9600;
            host.DemoModel = model.Value as string ?? "C9300-48P";
            host.Username = k == "demo" ? "" : user.Text.Trim();
            host.Password = Secret.Protect(pass.Text);
            host.Enable = "";
            host.Ports.Clear();
            foreach (string n in Ports.Sorted(list)) host.Ports.Add(new PortInfo(n, ""));
            if (host.Ports.Count > 0) host.PortsAsked = true;
            Result = host;
            DialogResult = DialogResult.OK;
            Close();
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            name.Box.Focus();
        }
    }
}
'@,
@'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal static class Icons
    {
        private static readonly Dictionary<string, int> map = new Dictionary<string, int>
        {
            { "router", 0xE328 }, { "lan", 0xEB2F }, { "dns", 0xE875 }, { "settings_ethernet", 0xE8BE },
            { "terminal", 0xEB8E }, { "add", 0xE145 }, { "delete", 0xE872 }, { "edit", 0xE150 },
            { "content_copy", 0xE14D }, { "content_paste", 0xE14F }, { "search", 0xE8B6 }, { "folder", 0xE2C7 },
            { "folder_open", 0xE2C8 }, { "rocket_launch", 0xEB9B }, { "bolt", 0xEA0B }, { "play_arrow", 0xE037 },
            { "stop", 0xE047 }, { "check", 0xE5CA }, { "check_circle", 0xE86C }, { "close", 0xE14C },
            { "error", 0xE000 }, { "warning", 0xE002 }, { "info", 0xE88E }, { "sync", 0xE627 },
            { "refresh", 0xE5D5 }, { "cable", 0xEFE6 }, { "usb", 0xE1E0 }, { "key", 0xE73C },
            { "lock", 0xE88D }, { "lock_open", 0xE898 }, { "visibility", 0xE417 }, { "visibility_off", 0xE8F5 },
            { "save", 0xE161 }, { "upload", 0xE2C6 }, { "download", 0xE171 }, { "history", 0xE28E },
            { "description", 0xE873 }, { "tune", 0xE429 }, { "settings", 0xE8B8 }, { "link", 0xE157 },
            { "link_off", 0xE16F }, { "power", 0xE63C }, { "power_off", 0xE646 }, { "expand_more", 0xE5CF },
            { "expand_less", 0xE5CE }, { "chevron_right", 0xE409 }, { "chevron_left", 0xE408 }, { "more_vert", 0xE5D4 },
            { "select_all", 0xE162 }, { "deselect", 0xEBB6 }, { "filter_list", 0xE152 }, { "label", 0xE892 },
            { "wifi", 0xE63E }, { "videocam", 0xE04B }, { "print", 0xE555 }, { "call", 0xE0B0 },
            { "computer", 0xE30A }, { "devices", 0xE1B1 }, { "hub", 0xE9F4 }, { "list", 0xE896 },
            { "grid_view", 0xE9B0 }, { "dashboard", 0xE871 }, { "backup", 0xE864 }, { "undo", 0xE166 },
            { "schedule", 0xE192 }, { "speed", 0xE9E4 }, { "sensors", 0xE51E }, { "auto_awesome", 0xE65F },
            { "science", 0xEA4B }, { "layers", 0xE53B }, { "code", 0xE86F }, { "keyboard", 0xE312 },
            { "help", 0xE887 }, { "article", 0xEF42 }, { "drag_indicator", 0xE945 }, { "person", 0xE7FD },
            { "shield", 0xE75B }, { "vpn_key", 0xE0DA }, { "storage", 0xE1DB }, { "memory", 0xE322 },
            { "radio_button_checked", 0xE837 }, { "radio_button_unchecked", 0xE836 }, { "circle", 0xEF4A }, { "pending", 0xEF64 },
            { "hourglass_empty", 0xE88B }, { "task_alt", 0xE2E6 }, { "cancel", 0xE5C9 }, { "block", 0xE033 },
            { "open_in_new", 0xE895 }, { "logout", 0xE9BA }, { "login", 0xEA77 }, { "note_add", 0xE89C },
            { "file_copy", 0xE173 }, { "clear_all", 0xE0B8 }, { "manage_search", 0xF02F }, { "checklist", 0xE6B1 },
            { "view_list", 0xE8EF }, { "construction", 0xEA3C }, { "device_hub", 0xE335 }, { "security", 0xE32A },
            { "tag", 0xE9EF }, { "minimize", 0xE931 }, { "crop_square", 0xE3C1 }, { "filter_none", 0xE3E0 },
            { "check_box", 0xE834 }, { "check_box_outline_blank", 0xE835 }, { "indeterminate_check_box", 0xE909 }, { "arrow_drop_down", 0xE5C5 },
            { "arrow_upward", 0xE5D8 }, { "arrow_downward", 0xE5DB }, { "swap_horiz", 0xE8D4 }, { "bookmark", 0xE866 },
            { "palette", 0xE3B7 }, { "dark_mode", 0xE51C }, { "light_mode", 0xE518 }, { "translate", 0xE8E2 },
            { "data_object", 0xEAD3 }, { "playlist_add", 0xE03B }, { "playlist_play", 0xE05F }, { "format_list_numbered", 0xE242 },
            { "keyboard_return", 0xE31B }, { "monitor_heart", 0xEAA2 }, { "fact_check", 0xF0C5 }, { "rule", 0xF1C2 },
            { "difference", 0xEB7D }, { "compare_arrows", 0xE915 }, { "wrap_text", 0xE25B }, { "text_fields", 0xE262 },
            { "pin", 0xF045 }, { "numbers", 0xEAC7 }, { "priority_high", 0xE645 }, { "restart_alt", 0xF053 },
            { "unfold_more", 0xE5D7 }, { "open_in_full", 0xF1CE },
        };

        public static string Glyph(string name)
        {
            int cp;
            if (name != null && map.TryGetValue(name, out cp)) return char.ConvertFromUtf32(cp);
            return "";
        }

        public static void Draw(Graphics g, string name, RectangleF r, Color c, float px, bool fill)
        {
            string s = Glyph(name);
            if (s.Length == 0 || !Fonts.HasSymbols) return;
            Font f = Fonts.Symbol(px, fill);
            int cx = (int)Math.Round(r.X + r.Width / 2f), cy = (int)Math.Round(r.Y + r.Height / 2f);
            int box = (int)Math.Ceiling(px) + 8;
            TextRenderer.DrawText(g, s, f, new Rectangle(cx - box / 2, cy - box / 2, box, box), c,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine | TextFormatFlags.NoClipping);
        }

        public static GraphicsPath Rounded(RectangleF r, float radius)
        {
            GraphicsPath p = new GraphicsPath();
            float d = Math.Min(radius * 2, Math.Min(r.Width, r.Height));
            if (d <= 0.5f) { p.AddRectangle(r); return p; }
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }

        public static void Smooth(Graphics g)
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        }

        public static Bitmap App(int size)
        {
            Bitmap b = new Bitmap(size, size, PixelFormat.Format32bppArgb);
            using (Graphics g = Graphics.FromImage(b))
            {
                Smooth(g);
                g.Clear(Color.Transparent);
                float s = size / 512f;
                using (GraphicsPath bg = Rounded(new RectangleF(0, 0, size, size), 112 * s))
                using (SolidBrush br = new SolidBrush(Theme.Charcoal))
                    g.FillPath(br, bg);
                float w = 76, h = 68, gap = 22;
                float x0 = 256 - (4 * w + 3 * gap) / 2f;
                float[] ys = { 150, 150 + h + 28 };
                bool[,] on = { { true, true, false, true }, { false, true, true, false } };
                for (int row = 0; row < 2; row++)
                {
                    for (int i = 0; i < 4; i++)
                    {
                        RectangleF r = new RectangleF((x0 + i * (w + gap)) * s, ys[row] * s, w * s, h * s);
                        Color c = on[row, i] ? Theme.Orange : Theme.C(0x5B6672);
                        using (GraphicsPath p = Rounded(r, 16 * s))
                        using (SolidBrush br = new SolidBrush(c))
                            g.FillPath(br, p);
                        if (size >= 32)
                        {
                            float nw = r.Width * 0.4f, nh = r.Height * 0.26f;
                            RectangleF notch = new RectangleF(r.X + (r.Width - nw) / 2f, r.Bottom - nh, nw, nh + 0.5f);
                            using (SolidBrush br = new SolidBrush(Theme.Charcoal)) g.FillRectangle(br, notch);
                        }
                    }
                }
                RectangleF bar = new RectangleF(x0 * s, 356 * s, (4 * w + 3 * gap) * s, 22 * s);
                using (GraphicsPath p = Rounded(bar, 11 * s))
                using (SolidBrush br = new SolidBrush(Color.FromArgb(110, Theme.OffWhite)))
                    g.FillPath(br, p);
            }
            return b;
        }

        public static Icon MakeIcon(int size)
        {
            using (Bitmap bmp = App(size))
            {
                IntPtr h = bmp.GetHicon();
                try
                {
                    using (Icon tmp = Icon.FromHandle(h)) return (Icon)tmp.Clone();
                }
                finally { Native.DestroyIcon(h); }
            }
        }

        private static readonly string[] NovaPaths =
        {
            "F28C28|M52 92C44 60 46 34 58 22C72 30 88 50 96 70Z",
            "F28C28|M148 92C156 60 154 34 142 22C128 30 112 50 104 70Z",
            "20252B|M60 80C56 60 58 44 63 36C72 44 80 56 86 68Z",
            "20252B|M140 80C144 60 142 44 137 36C128 44 120 56 114 68Z",
            "F28C28|M100 58C140 58 172 80 170 112C168 136 130 160 100 174C70 160 32 136 30 112C28 80 60 58 100 58Z",
            "F5F3EF|clip|M100 180C82 168 50 150 36 124C58 128 80 122 100 136C120 122 142 128 164 124C150 150 118 168 100 180Z",
            "F5F3EF|M100 74C101 81 103 83 110 84C103 85 101 87 100 94C99 87 97 85 90 84C97 83 99 81 100 74Z",
        };

        private static GraphicsPath ParsePath(string d)
        {
            GraphicsPath p = new GraphicsPath();
            List<float> nums = new List<float>();
            char cmd = ' ';
            PointF cur = PointF.Empty;
            int i = 0;
            while (true)
            {
                bool end = i >= d.Length;
                char ch = end ? 'Z' : d[i];
                if (end || char.IsLetter(ch))
                {
                    if (cmd == 'M' && nums.Count >= 2) { cur = new PointF(nums[0], nums[1]); p.StartFigure(); }
                    else if (cmd == 'C')
                    {
                        for (int k = 0; k + 5 < nums.Count; k += 6)
                        {
                            PointF c1 = new PointF(nums[k], nums[k + 1]), c2 = new PointF(nums[k + 2], nums[k + 3]), e = new PointF(nums[k + 4], nums[k + 5]);
                            p.AddBezier(cur, c1, c2, e);
                            cur = e;
                        }
                    }
                    nums.Clear();
                    if (end) break;
                    cmd = ch;
                    if (cmd == 'Z') p.CloseFigure();
                    i++;
                    continue;
                }
                if (ch == ' ' || ch == ',') { i++; continue; }
                int s = i;
                i++;
                while (i < d.Length && (char.IsDigit(d[i]) || d[i] == '.')) i++;
                nums.Add(float.Parse(d.Substring(s, i - s), CultureInfo.InvariantCulture));
            }
            return p;
        }

        public static void Nova(Graphics g, RectangleF r)
        {
            Smooth(g);
            GraphicsState state = g.Save();
            float scale = Math.Min(r.Width / 160f, r.Height / 168f);
            g.TranslateTransform(r.X + (r.Width - 160 * scale) / 2f, r.Y + (r.Height - 168 * scale) / 2f);
            g.ScaleTransform(scale, scale);
            g.TranslateTransform(-20, -14);
            using (GraphicsPath head = ParsePath(NovaPaths[4].Split('|')[1]))
            {
                foreach (string spec in NovaPaths)
                {
                    string[] parts = spec.Split('|');
                    Color c = Theme.C(int.Parse(parts[0], NumberStyles.HexNumber));
                    using (GraphicsPath path = ParsePath(parts[parts.Length - 1]))
                    using (SolidBrush br = new SolidBrush(c))
                    {
                        if (parts.Length == 3)
                        {
                            Region old = g.Clip;
                            g.SetClip(head, CombineMode.Intersect);
                            g.FillPath(br, path);
                            g.Clip = old;
                        }
                        else g.FillPath(br, path);
                    }
                }
            }
            using (SolidBrush dark = new SolidBrush(Theme.Charcoal))
            using (SolidBrush white = new SolidBrush(Color.White))
            {
                g.FillEllipse(dark, 76 - 7, 110 - 9, 14, 18);
                g.FillEllipse(dark, 124 - 7, 110 - 9, 14, 18);
                g.FillEllipse(white, 78.5f - 2.4f, 106 - 2.4f, 4.8f, 4.8f);
                g.FillEllipse(white, 126.5f - 2.4f, 106 - 2.4f, 4.8f, 4.8f);
                g.FillEllipse(dark, 100 - 9, 163 - 6.5f, 18, 13);
            }
            g.Restore(state);
        }

        public static void NovaBadge(Graphics g, RectangleF r)
        {
            Smooth(g);
            using (GraphicsPath p = Rounded(r, r.Width * 0.22f))
            using (SolidBrush br = new SolidBrush(Theme.Charcoal))
                g.FillPath(br, p);
            float pad = r.Width * 0.16f;
            Nova(g, RectangleF.Inflate(r, -pad, -pad));
        }
    }
}
'@,
@'
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
'@,
@'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal static class Install
    {
        public static string LocalDir { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SwitchDeck"); } }
        public static string DefaultTarget { get { return Path.Combine(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs"), "SwitchDeck"); } }
        private static string FlagPath { get { return Path.Combine(LocalDir, "install.json"); } }
        public static string IconPath { get { return Path.Combine(LocalDir, "SwitchDeck.ico"); } }
        public static string DesktopPath { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "SwitchDeck.lnk"); } }
        public static string StartMenuPath { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "SwitchDeck.lnk"); } }

        public static bool HasDesktop { get { return File.Exists(DesktopPath); } }
        public static bool HasStartMenu { get { return File.Exists(StartMenuPath); } }

        public static bool NeedsWelcome
        {
            get { return !File.Exists(FlagPath) && !HasDesktop && !HasStartMenu; }
        }

        public static bool IsInstalledCopy
        {
            get { return string.Equals(Path.GetFullPath(Program.AppRoot).TrimEnd('\\'), Path.GetFullPath(DefaultTarget).TrimEnd('\\'), StringComparison.OrdinalIgnoreCase); }
        }

        private const string UninstallKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\SwitchDeck";

        public static void Register(string target, string script)
        {
            try
            {
                string sys = Environment.SystemDirectory;
                string ico = Path.Combine(Path.Combine(target, "assets"), "icon.ico");
                using (Microsoft.Win32.RegistryKey k = Microsoft.Win32.Registry.CurrentUser.CreateSubKey(UninstallKey))
                {
                    k.SetValue("DisplayName", "SwitchDeck");
                    k.SetValue("DisplayVersion", Program.Version);
                    k.SetValue("DisplayIcon", File.Exists(ico) ? ico : IconPath);
                    k.SetValue("InstallLocation", target);
                    k.SetValue("UninstallString", "\"" + Path.Combine(sys, "conhost.exe") + "\" --headless \"" + Path.Combine(sys, @"WindowsPowerShell\v1.0\powershell.exe") +
                        "\" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\" --uninstall");
                    k.SetValue("NoModify", 1, Microsoft.Win32.RegistryValueKind.DWord);
                    k.SetValue("NoRepair", 1, Microsoft.Win32.RegistryValueKind.DWord);
                    k.SetValue("EstimatedSize", 2048, Microsoft.Win32.RegistryValueKind.DWord);
                }
                Log.Info("Registered in Apps");
            }
            catch (Exception ex) { Log.Warn("Register: " + ex.Message); }
        }

        public static string InstalledFolder
        {
            get
            {
                try
                {
                    using (Microsoft.Win32.RegistryKey k = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(UninstallKey))
                    {
                        string loc = k == null ? null : k.GetValue("InstallLocation") as string;
                        if (!string.IsNullOrEmpty(loc) && Directory.Exists(loc)) return loc;
                    }
                }
                catch { }
                return Directory.Exists(DefaultTarget) ? DefaultTarget : null;
            }
        }

        public static bool RunningFromInstall
        {
            get
            {
                string f = InstalledFolder;
                return f != null && string.Equals(Path.GetFullPath(Program.AppRoot).TrimEnd('\\'), Path.GetFullPath(f).TrimEnd('\\'), StringComparison.OrdinalIgnoreCase);
            }
        }

        public static string UninstallText()
        {
            string f = InstalledFolder;
            string t = f != null ? L.F("uninstallText", f) : L.T("uninstallTextNoCopy");
            if (!RunningFromInstall) t += "\n\n" + L.F("uninstallTextHere", Program.AppRoot);
            return t;
        }

        public static void Uninstall()
        {
            string folder = InstalledFolder;
            bool self = RunningFromInstall;
            try { Remove(DesktopPath); } catch (Exception ex) { Log.Warn(ex.Message); }
            try { Remove(StartMenuPath); } catch (Exception ex) { Log.Warn(ex.Message); }
            try { Microsoft.Win32.Registry.CurrentUser.DeleteSubKeyTree(UninstallKey, false); } catch (Exception ex) { Log.Warn(ex.Message); }
            try { Directory.Delete(LocalDir, true); } catch (Exception ex) { Log.Warn("Local folder: " + ex.Message); }
            List<string> targets = new List<string>();
            if (Directory.Exists(LocalDir)) targets.Add(LocalDir);
            if (folder != null && !self)
            {
                try { Directory.Delete(folder, true); Log.Info("Removed " + folder); }
                catch (Exception ex) { Log.Warn("Installed folder: " + ex.Message); targets.Add(folder); }
            }
            if (folder != null && self) targets.Add(folder);
            if (targets.Count == 0) return;
            string list = "";
            foreach (string t in targets) list += (list.Length > 0 ? "," : "") + "'" + t.Replace("'", "''") + "'";
            string sys = Environment.SystemDirectory;
            string cmd = "$p = " + Process.GetCurrentProcess().Id + "; try { Wait-Process -Id $p -Timeout 60 } catch { }; Start-Sleep -Milliseconds 500; " +
                         "foreach ($f in @(" + list + ")) { for ($i = 0; $i -lt 10 -and (Test-Path -LiteralPath $f); $i++) { Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 500 } }";
            ProcessStartInfo psi = new ProcessStartInfo(Path.Combine(sys, "conhost.exe"),
                "--headless \"" + Path.Combine(sys, @"WindowsPowerShell\v1.0\powershell.exe") + "\" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command \"" + cmd.Replace("\"", "\\\"") + "\"");
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.WorkingDirectory = Path.GetTempPath();
            Process.Start(psi);
        }

        public static void MarkAsked()
        {
            try
            {
                Directory.CreateDirectory(LocalDir);
                JObj o = new JObj();
                o["asked"] = true;
                o["script"] = Program.Script ?? "";
                o["time"] = DateTime.Now.ToString("o");
                File.WriteAllText(FlagPath, Json.Write(o));
            }
            catch (Exception ex) { Log.Warn("Install flag: " + ex.Message); }
        }

        public static void Refresh()
        {
            try
            {
                if (HasDesktop) Create(DesktopPath, Program.Script, Program.AppRoot);
                if (HasStartMenu) Create(StartMenuPath, Program.Script, Program.AppRoot);
            }
            catch (Exception ex) { Log.Warn("Shortcut refresh: " + ex.Message); }
        }

        public static void Set(bool desktop, bool startMenu)
        {
            Set(desktop, startMenu, Program.Script, Program.AppRoot);
        }

        public static void Set(bool desktop, bool startMenu, string script, string root)
        {
            if (desktop) Create(DesktopPath, script, root); else Remove(DesktopPath);
            if (startMenu) Create(StartMenuPath, script, root); else Remove(StartMenuPath);
        }

        public static string CopyTo(string target)
        {
            string src = Program.AppRoot;
            Directory.CreateDirectory(target);
            Directory.CreateDirectory(Path.Combine(target, "app"));
            File.Copy(Path.Combine(src, "SwitchDeck.cmd"), Path.Combine(target, "SwitchDeck.cmd"), true);
            File.Copy(Program.Script, Path.Combine(Path.Combine(target, "app"), "SwitchDeck.ps1"), true);
            CopyDir(Path.Combine(src, "assets"), Path.Combine(target, "assets"), true);
            string dataSrc = Path.Combine(Program.Root, "data");
            string dataDst = Path.Combine(target, "data");
            if (Directory.Exists(dataSrc) && !Directory.Exists(dataDst)) CopyDir(dataSrc, dataDst, false);
            Log.Info("Installed to " + target);
            return Path.Combine(Path.Combine(target, "app"), "SwitchDeck.ps1");
        }

        private static void CopyDir(string from, string to, bool overwrite)
        {
            if (!Directory.Exists(from)) return;
            Directory.CreateDirectory(to);
            foreach (string f in Directory.GetFiles(from))
            {
                string name = Path.GetFileName(f);
                if (name.EndsWith(".tmp")) continue;
                File.Copy(f, Path.Combine(to, name), overwrite);
            }
            foreach (string d in Directory.GetDirectories(from)) CopyDir(d, Path.Combine(to, Path.GetFileName(d)), overwrite);
        }

        public static void Launch(string script)
        {
            string sys = Environment.SystemDirectory;
            ProcessStartInfo psi = new ProcessStartInfo(Path.Combine(sys, "conhost.exe"),
                "--headless \"" + Path.Combine(sys, @"WindowsPowerShell\v1.0\powershell.exe") + "\" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\" --wait");
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.WorkingDirectory = Path.GetDirectoryName(Path.GetDirectoryName(script));
            Process.Start(psi);
            Log.Info("Started installed copy: " + script);
        }

        private static void Remove(string lnk)
        {
            if (!File.Exists(lnk)) return;
            File.Delete(lnk);
            Log.Info("Shortcut removed: " + lnk);
        }

        private static void Create(string lnk, string script, string root)
        {
            Directory.CreateDirectory(LocalDir);
            WriteIcon(IconPath);
            string sys = Environment.SystemDirectory;
            Type t = Type.GetTypeFromProgID("WScript.Shell");
            object shell = Activator.CreateInstance(t);
            try
            {
                object sc = t.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { lnk });
                Type st = sc.GetType();
                st.InvokeMember("TargetPath", BindingFlags.SetProperty, null, sc, new object[] { Path.Combine(sys, "conhost.exe") });
                st.InvokeMember("Arguments", BindingFlags.SetProperty, null, sc, new object[] {
                    "--headless \"" + Path.Combine(sys, @"WindowsPowerShell\v1.0\powershell.exe") + "\" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\"" });
                st.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, sc, new object[] { root });
                st.InvokeMember("Description", BindingFlags.SetProperty, null, sc, new object[] { "SwitchDeck" });
                st.InvokeMember("WindowStyle", BindingFlags.SetProperty, null, sc, new object[] { 7 });
                st.InvokeMember("IconLocation", BindingFlags.SetProperty, null, sc, new object[] { IconPath + ",0" });
                st.InvokeMember("Save", BindingFlags.InvokeMethod, null, sc, null);
                Marshal.FinalReleaseComObject(sc);
            }
            finally { Marshal.FinalReleaseComObject(shell); }
            Log.Info("Shortcut created: " + lnk);
        }

        public static void WriteIcon(string path)
        {
            int[] sizes = { 16, 24, 32, 48, 64, 256 };
            List<byte[]> images = new List<byte[]>();
            foreach (int s in sizes)
            {
                using (Bitmap b = Icons.App(s))
                using (MemoryStream ms = new MemoryStream())
                {
                    b.Save(ms, ImageFormat.Png);
                    images.Add(ms.ToArray());
                }
            }
            using (FileStream fs = File.Create(path))
            using (BinaryWriter w = new BinaryWriter(fs))
            {
                w.Write((short)0);
                w.Write((short)1);
                w.Write((short)sizes.Length);
                int offset = 6 + 16 * sizes.Length;
                for (int i = 0; i < sizes.Length; i++)
                {
                    w.Write((byte)(sizes[i] >= 256 ? 0 : sizes[i]));
                    w.Write((byte)(sizes[i] >= 256 ? 0 : sizes[i]));
                    w.Write((byte)0);
                    w.Write((byte)0);
                    w.Write((short)1);
                    w.Write((short)32);
                    w.Write(images[i].Length);
                    w.Write(offset);
                    offset += images[i].Length;
                }
                foreach (byte[] img in images) w.Write(img);
            }
        }

        public static void WriteAssets(string dir)
        {
            Directory.CreateDirectory(dir);
            using (Bitmap b = Icons.App(256)) b.Save(Path.Combine(dir, "logo.png"), ImageFormat.Png);
            using (Bitmap b = new Bitmap(128, 128, PixelFormat.Format32bppArgb))
            {
                using (Graphics g = Graphics.FromImage(b))
                {
                    g.Clear(Color.Transparent);
                    Icons.Nova(g, new RectangleF(0, 0, 128, 128));
                }
                b.Save(Path.Combine(dir, "nova.png"), ImageFormat.Png);
            }
            WriteIcon(Path.Combine(dir, "icon.ico"));
        }
    }

    internal sealed class WelcomeForm : DialogForm
    {
        private readonly Check desktop, startMenu;
        private readonly OptionRow installRow, hereRow;
        private readonly Label pathLabel;
        private readonly Btn changeBtn;
        private string target = Install.DefaultTarget;
        public string InstalledScript;

        public WelcomeForm() : base(L.T("welcomeInstallTitle"), null, 560, 560)
        {
            StartPosition = FormStartPosition.CenterScreen;
            ShowInTaskbar = true;
            Icon = Icons.MakeIcon(Math.Max(32, Ui.D(32)));
            Palette p = Theme.P;
            int L0 = Ui.D(24), W = Ui.D(512);
            ImageBox logo = new ImageBox(Icons.App(Ui.D(56)));
            logo.Location = new Point(L0, Ui.D(20));
            Body.Controls.Add(logo);
            Label name = Ui.Label("SwitchDeck", Fonts.Head(21f * Ui.Sc), p.Text);
            name.Location = new Point(Ui.D(96), Ui.D(18));
            Body.Controls.Add(name);
            AddLabel(Body, L.T("about"), Ui.D(98), Ui.D(52), Ui.D(430), false);

            int y = Ui.D(100);
            bool already = Install.IsInstalledCopy;
            installRow = new OptionRow(L.T("installHereTitle"), L.T("installHereText"), true);
            installRow.Bounds = new Rectangle(L0, y, W, Ui.D(104));
            installRow.Click += delegate { Pick(true); };
            Body.Controls.Add(installRow);
            pathLabel = Ui.Label(target, Fonts.Mono(12f * Ui.Sc), p.Muted);
            pathLabel.AutoSize = false;
            pathLabel.AutoEllipsis = true;
            pathLabel.BackColor = Color.Transparent;
            pathLabel.Bounds = new Rectangle(Ui.D(48), Ui.D(68), W - Ui.D(160), Ui.D(22));
            installRow.Controls.Add(pathLabel);
            changeBtn = new Btn(L.T("change"), "folder_open", BtnKind.Ghost, delegate { ChangeTarget(); }).Small();
            changeBtn.Location = new Point(W - changeBtn.Width - Ui.D(12), Ui.D(62));
            installRow.Controls.Add(changeBtn);
            y = installRow.Bottom + Ui.D(10);
            hereRow = new OptionRow(L.T("runHereTitle"), L.T("runHereText"), false);
            hereRow.Bounds = new Rectangle(L0, y, W, Ui.D(70));
            hereRow.Click += delegate { Pick(false); };
            Body.Controls.Add(hereRow);
            y = hereRow.Bottom + Ui.D(20);
            if (already)
            {
                installRow.Visible = hereRow.Visible = false;
                y = Ui.D(100);
            }

            desktop = new Check(L.T("shortcutDesktop"), true);
            desktop.Location = new Point(L0, y);
            Body.Controls.Add(desktop);
            startMenu = new Check(L.T("shortcutStart"), true);
            startMenu.Location = new Point(L0, y + Ui.D(32));
            Body.Controls.Add(startMenu);
            if (already) Height = Height - Ui.D(194);
            Pick(!already);

            AddButton(L.T("notNow"), null, BtnKind.Ghost, delegate { Install.MarkAsked(); DialogResult = DialogResult.Cancel; Close(); });
            AddButton(L.T("continue"), "check", BtnKind.Primary, delegate { Confirm(); });
        }

        private bool install;

        private void Pick(bool inst)
        {
            install = inst;
            installRow.Selected = inst;
            hereRow.Selected = !inst;
            installRow.Invalidate();
            hereRow.Invalidate();
            changeBtn.Enabled = inst;
        }

        private void ChangeTarget()
        {
            using (FolderBrowserDialog d = new FolderBrowserDialog())
            {
                d.Description = L.T("pickInstallFolder");
                d.SelectedPath = Path.GetDirectoryName(target);
                if (d.ShowDialog(this) != DialogResult.OK) return;
                target = Path.GetFileName(d.SelectedPath).Equals("SwitchDeck", StringComparison.OrdinalIgnoreCase) ? d.SelectedPath : Path.Combine(d.SelectedPath, "SwitchDeck");
                pathLabel.Text = target;
                Pick(true);
            }
        }

        private void Confirm()
        {
            try
            {
                if (install && installRow.Visible)
                {
                    string script = Install.CopyTo(target);
                    Install.Set(desktop.Checked, startMenu.Checked, script, target);
                    Install.MarkAsked();
                    InstalledScript = script;
                    Install.Register(target, script);
                }
                else
                {
                    Install.Set(desktop.Checked, startMenu.Checked);
                    Install.MarkAsked();
                }
                DialogResult = DialogResult.OK;
                Close();
            }
            catch (Exception ex)
            {
                Log.Error("Install: " + ex.Message);
                Dialogs.Problem(this, L.T("installFailed"), ex.Message);
            }
        }

        protected override void OnFormClosed(FormClosedEventArgs e)
        {
            if (DialogResult != DialogResult.OK) Install.MarkAsked();
            base.OnFormClosed(e);
        }
    }

    internal sealed class OptionRow : Painted
    {
        private readonly string title, text;
        public bool Selected;

        public OptionRow(string title, string text, bool selected)
        {
            this.title = title;
            this.text = text;
            Selected = selected;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            Ui.FillRound(g, r, 12 * Sc, Selected ? p.OrangeSoft : (Hover ? p.HoverFill : p.Surface2));
            Ui.StrokeRound(g, r, 12 * Sc, Selected ? p.Orange : p.Border, Selected ? 1.6f * Sc : Math.Max(1f, Sc));
            Icons.Draw(g, Selected ? "radio_button_checked" : "radio_button_unchecked", new RectangleF(D(14), D(14), D(22), D(22)), Selected ? p.Orange : p.Faint, 20 * Sc, false);
            Ui.Text(g, title, Fonts.Strong(14f * Sc), new Rectangle(D(48), D(13), Width - D(60), D(24)), p.Text, Ui.Left);
            Ui.Text(g, text, Fonts.Body(12.5f * Sc), new Rectangle(D(48), D(37), Width - D(60), D(22)), p.Muted, Ui.Left);
        }
    }
}
'@,
@'
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
'@,
@'
using System;
using System.Collections.Generic;
using System.Globalization;

namespace SwitchDeck
{
    internal static class L
    {
        public static string Lang = "en";

        private static readonly Dictionary<string, string[]> texts = new Dictionary<string, string[]>
        {
            { "tabSwitches", new[] { "Switches", "Switchs" } },
            { "tabTemplates", new[] { "Templates", "Modèles" } },
            { "tabDeploy", new[] { "Deploy", "Déployer" } },
            { "tabHistory", new[] { "History", "Historique" } },
            { "tabSettings", new[] { "Settings", "Paramètres" } },
            { "tabAbout", new[] { "About", "À propos" } },
            { "tabConnection", new[] { "Connection", "Connexion" } },
            { "tabPorts", new[] { "Ports", "Ports" } },

            { "ok", new[] { "OK", "OK" } },
            { "cancel", new[] { "Cancel", "Annuler" } },
            { "save", new[] { "Save", "Enregistrer" } },
            { "saved", new[] { "Saved", "Enregistré" } },
            { "add", new[] { "Add", "Ajouter" } },
            { "edit", new[] { "Edit", "Modifier" } },
            { "delete", new[] { "Delete", "Supprimer" } },
            { "duplicate", new[] { "Duplicate", "Dupliquer" } },
            { "copy", new[] { "Copy", "Copier" } },
            { "paste", new[] { "Paste", "Coller" } },
            { "copied", new[] { "Copied to the clipboard", "Copié dans le presse-papiers" } },
            { "selectAll", new[] { "Select all", "Tout sélectionner" } },
            { "copyAll", new[] { "Copy everything", "Tout copier" } },
            { "clearScreen", new[] { "Clear the screen", "Effacer l'écran" } },
            { "copyOf", new[] { "{0} copy", "{0} copie" } },
            { "later", new[] { "Not now", "Plus tard" } },
            { "replace", new[] { "Replace", "Remplacer" } },
            { "keepMine", new[] { "Keep my list", "Garder ma liste" } },
            { "discard", new[] { "Discard changes", "Abandonner" } },
            { "keepEditing", new[] { "Keep editing", "Continuer" } },
            { "stop", new[] { "Stop", "Arrêter" } },
            { "stopping", new[] { "Stopping", "Arrêt en cours" } },
            { "stopped", new[] { "Stopped by you", "Arrêté par vous" } },
            { "all", new[] { "All", "Tous" } },
            { "none", new[] { "None", "Aucun" } },
            { "trust", new[] { "Trust and connect", "Faire confiance" } },
            { "quit", new[] { "Close SwitchDeck", "Fermer SwitchDeck" } },
            { "quitTitle", new[] { "Close SwitchDeck?", "Fermer SwitchDeck ?" } },
            { "quitText", new[] { "{0} connection(s) are still open. They will be closed.", "{0} connexion(s) encore ouverte(s). Elles seront fermées." } },
            { "oops", new[] { "Something went wrong", "Un problème est survenu" } },
            { "today", new[] { "Today", "Aujourd'hui" } },
            { "yesterday", new[] { "Yesterday", "Hier" } },
            { "noMatch", new[] { "Nothing matches", "Aucun résultat" } },

            { "searchSwitches", new[] { "Search switches", "Rechercher un switch" } },
            { "addSwitch", new[] { "Add a switch", "Ajouter un switch" } },
            { "addSwitchShort", new[] { "Add switch", "Ajouter" } },
            { "editSwitch", new[] { "Edit {0}", "Modifier {0}" } },
            { "editSwitchShort", new[] { "Edit this switch", "Modifier ce switch" } },
            { "noSwitchesTitle", new[] { "No switches yet", "Aucun switch" } },
            { "noSwitchesText", new[] { "Add your first switch to get started.", "Ajoutez votre premier switch pour commencer." } },
            { "noGroup", new[] { "Other", "Autres" } },
            { "welcomeTitle", new[] { "Welcome to SwitchDeck", "Bienvenue dans SwitchDeck" } },
            { "welcomeText", new[] { "Add a switch, then connect to it or deploy a template on its ports.", "Ajoutez un switch, puis connectez-vous ou déployez un modèle sur ses ports." } },
            { "connect", new[] { "Connect", "Connexion" } },
            { "openTerminal", new[] { "Open terminal", "Ouvrir le terminal" } },
            { "disconnect", new[] { "Disconnect", "Déconnecter" } },
            { "reconnect", new[] { "Reconnect", "Reconnecter" } },
            { "overview", new[] { "Overview", "Vue d'ensemble" } },
            { "neverConnected", new[] { "Never connected", "Jamais connecté" } },
            { "lastConnected", new[] { "Last connected {0}", "Dernière connexion le {0}" } },
            { "legacyChip", new[] { "Legacy SSH", "SSH ancien" } },
            { "portsTitle", new[] { "Ports", "Ports" } },
            { "portsNone", new[] { "No ports registered yet", "Aucun port enregistré" } },
            { "portsSummary", new[] { "{0} ports   {1}", "{0} ports   {1}" } },
            { "portsShort", new[] { "{0} ports", "{0} ports" } },
            { "statusAt", new[] { "Status read at {0}", "État lu à {0}" } },
            { "detectPorts", new[] { "Detect ports", "Détecter les ports" } },
            { "refreshStatus", new[] { "Refresh status", "Actualiser l'état" } },
            { "editPorts", new[] { "Edit ports", "Modifier les ports" } },
            { "deploySelected", new[] { "Deploy", "Déployer" } },
            { "deployCount", new[] { "Deploy on {0} ports", "Déployer sur {0} ports" } },
            { "plateHint", new[] { "Click ports to select them, then deploy a template on them.", "Cliquez sur des ports pour les sélectionner, puis déployez un modèle." } },
            { "noPortsTitle", new[] { "No ports yet", "Aucun port" } },
            { "noPortsText", new[] { "SwitchDeck can read them from the switch, or you can type them yourself.", "SwitchDeck peut les lire sur le switch, ou vous pouvez les saisir vous-même." } },
            { "addManually", new[] { "Add them myself", "Les saisir moi-même" } },
            { "deployHere", new[] { "Deploy here", "Déployer ici" } },
            { "sendBreak", new[] { "Send break", "Envoyer un break" } },
            { "openSessionLogs", new[] { "Open session logs", "Ouvrir les journaux de session" } },
            { "closeSession", new[] { "Close this session", "Fermer la session" } },
            { "busyWait", new[] { "SwitchDeck is still typing on this switch. Wait or stop it first.", "SwitchDeck écrit encore sur ce switch. Attendez ou arrêtez-le." } },
            { "stateConnected", new[] { "Connected", "Connecté" } },
            { "stateConnecting", new[] { "Connecting", "Connexion" } },
            { "stateClosed", new[] { "Disconnected", "Déconnecté" } },
            { "modeUser", new[] { "User mode", "Mode utilisateur" } },
            { "modeEnable", new[] { "Privileged mode", "Mode privilégié" } },
            { "modeConfig", new[] { "Configuration mode", "Mode configuration" } },
            { "typing", new[] { "SwitchDeck is typing.", "SwitchDeck écrit." } },
            { "switchAdded", new[] { "{0} added", "{0} ajouté" } },
            { "switchDeleted", new[] { "{0} deleted", "{0} supprimé" } },
            { "deleteSwitch", new[] { "Delete this switch?", "Supprimer ce switch ?" } },
            { "deleteSwitchText", new[] { "{0} and its saved ports will be removed from SwitchDeck. Nothing changes on the switch itself.", "{0} et ses ports enregistrés seront retirés de SwitchDeck. Rien ne change sur le switch." } },

            { "hostKeyTitle", new[] { "New switch key", "Nouvelle clé de switch" } },
            { "hostKeyText", new[] { "This is the first SSH connection to {0}. Check that its key fingerprint is the one you expect:\n\n{1}\n\nSwitchDeck will remember it for next time.", "C'est la première connexion SSH à {0}. Vérifiez que l'empreinte de sa clé est bien celle attendue :\n\n{1}\n\nSwitchDeck la retiendra pour la suite." } },
            { "keyChangedTitle", new[] { "The switch key changed", "La clé du switch a changé" } },
            { "keyChangedText", new[] { "{0} answered with a different SSH key than last time. This is normal after a switch replacement or a new key, but it can also be a sign of an attack. Forget the old key and connect again?", "{0} a répondu avec une clé SSH différente de la dernière fois. C'est normal après un remplacement ou une nouvelle clé, mais cela peut aussi signaler une attaque. Oublier l'ancienne clé et se reconnecter ?" } },
            { "forgetKey", new[] { "Forget old key", "Oublier l'ancienne clé" } },
            { "passwordRejected", new[] { "The saved password was refused. Type it in the terminal or edit the switch.", "Le mot de passe enregistré a été refusé. Tapez-le dans le terminal ou modifiez le switch." } },
            { "connectingTo", new[] { "SwitchDeck: connecting to {0} ({1})", "SwitchDeck : connexion à {0} ({1})" } },
            { "connectFailed", new[] { "SwitchDeck: could not connect. {0}", "SwitchDeck : connexion impossible. {0}" } },
            { "connectionClosed", new[] { "SwitchDeck: connection closed.", "SwitchDeck : connexion fermée." } },
            { "connectionClosedWhy", new[] { "SwitchDeck: connection closed ({0}).", "SwitchDeck : connexion fermée ({0})." } },
            { "noSsh", new[] { "The Windows SSH client was not found. Add it in Settings, Apps, Optional features, OpenSSH Client.", "Le client SSH de Windows est introuvable. Ajoutez-le dans Paramètres, Applications, Fonctionnalités facultatives, Client OpenSSH." } },
            { "noAddress", new[] { "This switch has no address.", "Ce switch n'a pas d'adresse." } },
            { "notConnected", new[] { "The connection to the switch was lost.", "La connexion au switch a été perdue." } },
            { "noPrompt", new[] { "The switch did not show its prompt in time.", "Le switch n'a pas affiché son invite à temps." } },
            { "needEnable", new[] { "This switch needs an enable secret. Add it in the switch settings.", "Ce switch demande un mot de passe enable. Ajoutez-le dans les réglages du switch." } },
            { "enableRejected", new[] { "The enable secret was refused.", "Le mot de passe enable a été refusé." } },
            { "timeoutOn", new[] { "No answer from the switch after: {0}", "Pas de réponse du switch après : {0}" } },
            { "noConfigMode", new[] { "The switch did not enter configuration mode.", "Le switch n'est pas entré en mode configuration." } },
            { "noIfMode", new[] { "The switch did not open the interface.", "Le switch n'a pas ouvert l'interface." } },
            { "noPortsFound", new[] { "No ports were found in the switch answer.", "Aucun port trouvé dans la réponse du switch." } },
            { "detecting", new[] { "Reading the port list", "Lecture de la liste des ports" } },
            { "detectFailed", new[] { "Could not read the ports", "Impossible de lire les ports" } },
            { "portsDetected", new[] { "{0} ports detected and saved", "{0} ports détectés et enregistrés" } },
            { "statusUpdated", new[] { "Port status updated", "État des ports mis à jour" } },
            { "replacePortsTitle", new[] { "Replace the port list?", "Remplacer la liste des ports ?" } },
            { "replacePortsText", new[] { "This switch has {0} saved ports and the switch reports {1}. Replace the saved list with what the switch reports?", "Ce switch a {0} ports enregistrés et le switch en annonce {1}. Remplacer la liste par celle du switch ?" } },

            { "portsAskTitle", new[] { "Ports of {0}", "Ports de {0}" } },
            { "portsAskText", new[] { "SwitchDeck needs the list of ports to deploy templates. How do you want to add them?", "SwitchDeck a besoin de la liste des ports pour déployer des modèles. Comment voulez-vous les ajouter ?" } },
            { "portsAskDetect", new[] { "Detect automatically", "Détection automatique" } },
            { "portsAskDetectText", new[] { "SwitchDeck runs show interfaces status and saves every physical port.", "SwitchDeck lance show interfaces status et enregistre chaque port physique." } },
            { "portsAskManual", new[] { "Add them myself", "Les saisir moi-même" } },
            { "portsAskManualText", new[] { "Type them in the switch settings, with ranges like Gi1/0/1-48.", "Saisissez-les dans les réglages du switch, avec des plages comme Gi1/0/1-48." } },

            { "fieldName", new[] { "Name", "Nom" } },
            { "fieldGroup", new[] { "Group", "Groupe" } },
            { "fieldKind", new[] { "Connection", "Connexion" } },
            { "fieldAddress", new[] { "Address", "Adresse" } },
            { "fieldPort", new[] { "Port", "Port" } },
            { "fieldCom", new[] { "COM port", "Port COM" } },
            { "fieldBaud", new[] { "Speed", "Vitesse" } },
            { "fieldModel", new[] { "Model", "Modèle" } },
            { "fieldUser", new[] { "Username", "Utilisateur" } },
            { "fieldPassword", new[] { "Password", "Mot de passe" } },
            { "fieldEnable", new[] { "Enable secret", "Mot de passe enable" } },
            { "phName", new[] { "SW-CORE-01", "SW-COEUR-01" } },
            { "phGroup", new[] { "Building A", "Bâtiment A" } },
            { "phEnable", new[] { "Optional", "Facultatif" } },
            { "kindSerial", new[] { "Serial console", "Console série" } },
            { "kindDemo", new[] { "Lab switch", "Switch de test" } },
            { "demoTarget", new[] { "Simulated lab switch", "Switch de test simulé" } },
            { "legacySsh", new[] { "Older switch (legacy SSH)", "Switch ancien (SSH ancien)" } },
            { "legacyTip", new[] { "Turns on the older SSH algorithms that switches on IOS 12 and early IOS 15 still use.", "Active les anciens algorithmes SSH encore utilisés par les switchs en IOS 12 et premières IOS 15." } },
            { "ciscoDefault", new[] { "Cisco default", "Par défaut Cisco" } },
            { "serialHint", new[] { "8 data bits, no parity, 1 stop bit, no flow control.", "8 bits de données, sans parité, 1 bit d'arrêt, sans contrôle de flux." } },
            { "demoHint", new[] { "A simulated Catalyst for trying SwitchDeck safely.", "Un Catalyst simulé pour essayer SwitchDeck sans risque." } },
            { "resetLab", new[] { "Reset lab switch", "Réinitialiser" } },
            { "resetLabText", new[] { "The lab switch goes back to its factory configuration. Its saved configuration is erased.", "Le switch de test revient à sa configuration d'usine. Sa configuration enregistrée est effacée." } },
            { "loginTitle", new[] { "Login", "Identifiants" } },
            { "secretsHint", new[] { "Passwords are encrypted for your Windows account only.", "Les mots de passe sont chiffrés pour votre compte Windows uniquement." } },
            { "addPorts", new[] { "Add ports", "Ajouter des ports" } },
            { "addPortsHint", new[] { "Separate with commas. Ranges work: Gi1/0/1-48, Te1/1/1-4, Po1", "Séparez par des virgules. Les plages marchent : Gi1/0/1-48, Te1/1/1-4, Po1" } },
            { "badPorts", new[] { "Not understood: {0}", "Non compris : {0}" } },
            { "portsAdded", new[] { "{0} ports added", "{0} ports ajoutés" } },
            { "noPortsDialog", new[] { "Add ports above, or connect and let SwitchDeck detect them.", "Ajoutez des ports ci-dessus, ou connectez-vous et laissez SwitchDeck les détecter." } },
            { "noPortsShort", new[] { "No ports", "Aucun port" } },
            { "portCount", new[] { "{0} ports   {1}", "{0} ports   {1}" } },
            { "removeAll", new[] { "Remove all", "Tout retirer" } },
            { "removeAllText", new[] { "Remove the {0} saved ports from this switch?", "Retirer les {0} ports enregistrés de ce switch ?" } },
            { "noDescription", new[] { "No description", "Sans description" } },
            { "descriptionOf", new[] { "Description of {0}", "Description de {0}" } },
            { "descriptionHint", new[] { "Shown next to the port in SwitchDeck.", "Affichée à côté du port dans SwitchDeck." } },
            { "otherPorts", new[] { "Other", "Autres" } },
            { "trunk", new[] { "trunk", "trunk" } },

            { "searchTemplates", new[] { "Search templates", "Rechercher un modèle" } },
            { "newTemplate", new[] { "New template", "Nouveau modèle" } },
            { "newTemplateName", new[] { "New template", "Nouveau modèle" } },
            { "noTemplatesTitle", new[] { "No templates yet", "Aucun modèle" } },
            { "noTemplatesText", new[] { "Create one for each kind of port you set up.", "Créez-en un pour chaque type de port que vous configurez." } },
            { "noTemplatesBig", new[] { "A template is a named port configuration, like Wifi-Hotspot: trunk mode with VLAN 2.", "Un modèle est une configuration de port nommée, comme Wifi-Hotspot : mode trunk avec le VLAN 2." } },
            { "phTemplateName", new[] { "Template name", "Nom du modèle" } },
            { "phTemplateDesc", new[] { "What is this port for?", "À quoi sert ce port ?" } },
            { "commandsTitle", new[] { "Interface commands", "Commandes d'interface" } },
            { "commandsHint", new[] { "One command per line, as typed inside the interface. Use {{name}} for values you choose when deploying and {{port}} for the port name. Lines starting with ! are notes.", "Une commande par ligne, comme dans l'interface. Utilisez {{nom}} pour les valeurs choisies au déploiement et {{port}} pour le nom du port. Les lignes commençant par ! sont des notes." } },
            { "resetFirst", new[] { "Reset the port before applying", "Réinitialiser le port avant" } },
            { "resetFirstTip", new[] { "Sends default interface first, so old settings do not stay behind.", "Envoie d'abord default interface, pour ne pas garder d'anciens réglages." } },
            { "unsaved", new[] { "Unsaved changes", "Modifications non enregistrées" } },
            { "deploy", new[] { "Deploy", "Déployer" } },
            { "variablesTitle", new[] { "Values", "Valeurs" } },
            { "variablesNone", new[] { "This template has no values to fill. Add {{name}} in a command to create one.", "Ce modèle n'a aucune valeur à remplir. Ajoutez {{nom}} dans une commande pour en créer une." } },
            { "variablesPortOnly", new[] { "Only {{port}} is used. It is filled with each port name.", "Seul {{port}} est utilisé. Il prend le nom de chaque port." } },
            { "defaultFor", new[] { "Default for {0}", "Valeur par défaut de {0}" } },
            { "phDefault", new[] { "Empty", "Vide" } },
            { "previewTitle", new[] { "Preview", "Aperçu" } },
            { "linesCount", new[] { "{0} commands", "{0} commandes" } },
            { "nameNeeded", new[] { "Give the template a name", "Donnez un nom au modèle" } },
            { "nameTaken", new[] { "Another template already has this name", "Un autre modèle porte déjà ce nom" } },
            { "commandsNeeded", new[] { "Add at least one command", "Ajoutez au moins une commande" } },
            { "checkCommands", new[] { "Check this command", "Vérifiez cette commande" } },
            { "badLineText", new[] { "\"{0}\" is not an interface command. SwitchDeck already enters and leaves the interface and configuration mode for you.", "\"{0}\" n'est pas une commande d'interface. SwitchDeck entre et sort déjà de l'interface et du mode configuration pour vous." } },
            { "saveAnyway", new[] { "Save anyway", "Enregistrer quand même" } },
            { "templateSaved", new[] { "{0} saved", "{0} enregistré" } },
            { "templateDeleted", new[] { "{0} deleted", "{0} supprimé" } },
            { "deleteTemplate", new[] { "Delete this template?", "Supprimer ce modèle ?" } },
            { "deleteTemplateText", new[] { "{0} will be deleted. Ports already configured with it keep their configuration.", "{0} sera supprimé. Les ports déjà configurés avec lui gardent leur configuration." } },
            { "unsavedTitle", new[] { "Unsaved changes", "Modifications non enregistrées" } },
            { "unsavedText", new[] { "{0} has changes that are not saved.", "{0} a des modifications non enregistrées." } },

            { "setupTitle", new[] { "Setup", "Préparation" } },
            { "fieldSwitch", new[] { "Switch", "Switch" } },
            { "fieldTemplate", new[] { "Template", "Modèle" } },
            { "pickSwitch", new[] { "Choose a switch", "Choisissez un switch" } },
            { "pickTemplate", new[] { "Choose a template", "Choisissez un modèle" } },
            { "hostConnected", new[] { "Connected", "Connecté" } },
            { "hostWillConnect", new[] { "SwitchDeck connects when you deploy", "SwitchDeck se connecte au déploiement" } },
            { "valuesTitle", new[] { "Values", "Valeurs" } },
            { "modeTitle", new[] { "How to send it", "Méthode d'envoi" } },
            { "modeRange", new[] { "Range", "Plage" } },
            { "modeSingle", new[] { "One by one", "Un par un" } },
            { "modeRangeHint", new[] { "Uses interface range, so all ports get the commands at once. Fastest.", "Utilise interface range : tous les ports reçoivent les commandes d'un coup. Le plus rapide." } },
            { "modeSingleHint", new[] { "Opens each port in turn. Slower, but a problem on one port does not stop the others.", "Ouvre chaque port l'un après l'autre. Plus lent, mais un problème sur un port n'arrête pas les autres." } },
            { "portVarSingle", new[] { "This template uses {{port}}, so it is sent one port at a time.", "Ce modèle utilise {{port}}, il est donc envoyé port par port." } },
            { "optionsTitle", new[] { "Safety", "Sécurité" } },
            { "optReset", new[] { "Reset ports first", "Réinitialiser les ports avant" } },
            { "optCheck", new[] { "Read current config first", "Lire la config actuelle avant" } },
            { "optCheckTip", new[] { "Saves each port's configuration before the change, so you can roll back from History.", "Garde la configuration de chaque port avant le changement, pour pouvoir revenir en arrière depuis l'historique." } },
            { "optBackup", new[] { "Back up the running config", "Sauvegarder la running config" } },
            { "optBackupTip", new[] { "Saves the full running configuration to the backups folder before changing anything.", "Enregistre toute la configuration dans le dossier des sauvegardes avant tout changement." } },
            { "optVerify", new[] { "Check the result after", "Vérifier le résultat après" } },
            { "optVerifyTip", new[] { "Reads each port again and checks that every command is in its configuration.", "Relit chaque port et vérifie que chaque commande est dans sa configuration." } },
            { "optWrite", new[] { "Save to startup config", "Enregistrer en startup config" } },
            { "optWriteTip", new[] { "Runs write memory at the end, so the change survives a reboot.", "Lance write memory à la fin, pour que le changement survive à un redémarrage." } },
            { "freePorts", new[] { "Free ports", "Ports libres" } },
            { "freePortsTip", new[] { "Selects the ports with nothing plugged in.", "Sélectionne les ports sur lesquels rien n'est branché." } },
            { "refreshStatusTip", new[] { "Read the live status of every port", "Lire l'état actuel de chaque port" } },
            { "noneSelected", new[] { "No port selected", "Aucun port sélectionné" } },
            { "selectedCount", new[] { "{0} selected", "{0} sélectionnés" } },
            { "unknownPorts", new[] { "Not on this switch: {0}", "Absent de ce switch : {0}" } },
            { "deployNoPorts", new[] { "This switch has no saved ports yet. Add them in its settings, or connect once and let SwitchDeck read them.", "Ce switch n'a pas encore de ports enregistrés. Ajoutez-les dans ses réglages, ou connectez-vous une fois pour que SwitchDeck les lise." } },
            { "goToSwitch", new[] { "Open the switch", "Ouvrir le switch" } },
            { "viewPreview", new[] { "Commands", "Commandes" } },
            { "viewResults", new[] { "Results", "Résultats" } },
            { "viewCommands", new[] { "Commands", "Commandes" } },
            { "viewTranscript", new[] { "Transcript", "Transcription" } },
            { "viewBefore", new[] { "Before and after", "Avant et après" } },
            { "previewPickSwitch", new[] { "Choose a switch to see the commands", "Choisissez un switch pour voir les commandes" } },
            { "previewPickTemplate", new[] { "Choose a template to see the commands", "Choisissez un modèle pour voir les commandes" } },
            { "previewPickPorts", new[] { "Select ports to see the commands", "Sélectionnez des ports pour voir les commandes" } },
            { "deployTo", new[] { "Deploy on {0} ports", "Déployer sur {0} ports" } },
            { "deployToOne", new[] { "Deploy on 1 port", "Déployer sur 1 port" } },
            { "deployAgain", new[] { "Deploy again", "Redéployer" } },
            { "fillValue", new[] { "Fill in {0}", "Remplissez {0}" } },
            { "confirmTitle", new[] { "Deploy now?", "Déployer maintenant ?" } },
            { "confirmText", new[] { "{0} will be applied to {1} ports on {2}:\n{3}\n\nSwitchDeck will type {4} commands.", "{0} sera appliqué à {1} ports sur {2} :\n{3}\n\nSwitchDeck tapera {4} commandes." } },
            { "confirmWrite", new[] { "The change is then saved to the startup configuration.", "Le changement sera ensuite enregistré dans la configuration de démarrage." } },
            { "noResultsTitle", new[] { "No results yet", "Pas encore de résultats" } },
            { "noResultsText", new[] { "They show up here while SwitchDeck deploys.", "Ils s'affichent ici pendant le déploiement." } },
            { "openHistory", new[] { "History", "Historique" } },
            { "rollback", new[] { "Roll back", "Revenir en arrière" } },
            { "newDeploy", new[] { "New", "Nouveau" } },
            { "doneSummary", new[] { "{0} done, {2} failed, {3} skipped", "{0} faits, {2} en échec, {3} ignorés" } },
            { "savedStartup", new[] { "Saved to startup", "Enregistré en startup" } },
            { "deployOk", new[] { "{0} deployed on {1} ports", "{0} déployé sur {1} ports" } },
            { "deployWarn", new[] { "Deployed, some ports need a look", "Déployé, certains ports sont à vérifier" } },
            { "deployFailed", new[] { "The deployment did not complete", "Le déploiement n'a pas abouti" } },
            { "deploying", new[] { "Deploying", "Déploiement" } },
            { "stepReady", new[] { "Waiting for the switch prompt", "Attente de l'invite du switch" } },
            { "stepBackup", new[] { "Backing up the running configuration", "Sauvegarde de la configuration" } },
            { "stepRead", new[] { "Reading {0} ({1} of {2})", "Lecture de {0} ({1} sur {2})" } },
            { "stepConfig", new[] { "Entering configuration mode", "Passage en mode configuration" } },
            { "stepRange", new[] { "Configuring {0} ({1} of {2})", "Configuration de {0} ({1} sur {2})" } },
            { "stepPort", new[] { "Configuring {0} ({1} of {2})", "Configuration de {0} ({1} sur {2})" } },
            { "stepEnd", new[] { "Leaving configuration mode", "Sortie du mode configuration" } },
            { "stepVerify", new[] { "Checking {0} ({1} of {2})", "Vérification de {0} ({1} sur {2})" } },
            { "stepWrite", new[] { "Saving to startup config", "Enregistrement en startup config" } },
            { "notVisible", new[] { "Not found in the running config:", "Introuvable dans la running config :" } },
            { "writeFailed", new[] { "write memory did not confirm.", "write memory n'a pas confirmé." } },

            { "searchHistory", new[] { "Switch, template or port", "Switch, modèle ou port" } },
            { "noHistoryTitle", new[] { "Nothing deployed yet", "Rien de déployé" } },
            { "noHistoryText", new[] { "Every deployment is listed here.", "Chaque déploiement est listé ici." } },
            { "noHistoryBig", new[] { "Each deployment is recorded here with its commands, the switch answers and the port configuration before and after.", "Chaque déploiement est enregistré ici avec ses commandes, les réponses du switch et la configuration des ports avant et après." } },
            { "goDeploy", new[] { "Go to Deploy", "Aller à Déployer" } },
            { "openBackup", new[] { "Backup", "Sauvegarde" } },
            { "clickDetails", new[] { "Double-click for details", "Double-clic pour le détail" } },
            { "before", new[] { "Before", "Avant" } },
            { "after", new[] { "After", "Après" } },
            { "emptyConfig", new[] { "Default configuration", "Configuration par défaut" } },
            { "notRead", new[] { "Not read", "Non lu" } },
            { "noTranscript", new[] { "No transcript was recorded.", "Aucune transcription enregistrée." } },
            { "deleteEntry", new[] { "Delete this entry?", "Supprimer cette entrée ?" } },
            { "deleteEntryText", new[] { "It is removed from History. Nothing changes on the switch.", "Elle sera retirée de l'historique. Rien ne change sur le switch." } },
            { "rollbackTitle", new[] { "Roll back these ports?", "Revenir en arrière sur ces ports ?" } },
            { "rollbackText", new[] { "{0} ports on {1} will be reset and get back the configuration they had before:\n{2}", "{0} ports sur {1} seront réinitialisés et retrouveront leur configuration d'avant :\n{2}" } },
            { "rollbackEmpty", new[] { "{0} ports had no configuration recorded before, so they go back to default.", "{0} ports n'avaient aucune configuration enregistrée : ils reviennent à la configuration par défaut." } },
            { "rollbackNoHost", new[] { "This switch is no longer in SwitchDeck.", "Ce switch n'est plus dans SwitchDeck." } },
            { "rollbackNothing", new[] { "Nothing to roll back", "Rien à annuler" } },
            { "rollbackOf", new[] { "Roll back of {0}", "Retour arrière de {0}" } },
            { "rollbackStarted", new[] { "Rolling back", "Retour arrière en cours" } },
            { "rollbackOk", new[] { "Ports rolled back", "Ports restaurés" } },
            { "rollbackIssues", new[] { "Roll back finished with issues, see History", "Retour arrière terminé avec des problèmes, voir l'historique" } },

            { "setAppearance", new[] { "Appearance", "Apparence" } },
            { "setTerminal", new[] { "Terminal", "Terminal" } },
            { "setDeploy", new[] { "Deploy defaults", "Déploiement par défaut" } },
            { "setFolders", new[] { "Folders", "Dossiers" } },
            { "stepSetup", new[] { "Setup", "Préparation" } },
            { "stepPorts", new[] { "Ports", "Ports" } },
            { "stepResults", new[] { "Results", "Résultats" } },
            { "continue", new[] { "Continue", "Continuer" } },
            { "closing", new[] { "Closing...", "Fermeture..." } },
            { "uninstalling", new[] { "Uninstalling...", "Désinstallation..." } },
            { "uninstall", new[] { "Uninstall", "Désinstaller" } },
            { "uninstallRow", new[] { "Uninstall SwitchDeck", "Désinstaller SwitchDeck" } },
            { "uninstallRowHint", new[] { "Removes SwitchDeck from this PC.", "Retire SwitchDeck de ce PC." } },
            { "uninstallTitle", new[] { "Uninstall SwitchDeck?", "Désinstaller SwitchDeck ?" } },
            { "uninstallText", new[] { "This removes the shortcuts, the cache and the installed copy in {0}, with its switches and templates. Export your templates first if you want to keep them.", "Cela retire les raccourcis, le cache et la copie installée dans {0}, avec ses switchs et modèles. Exportez vos modèles avant si vous voulez les garder." } },
            { "uninstallTextNoCopy", new[] { "This removes the shortcuts and the cache from this PC.", "Cela retire les raccourcis et le cache de ce PC." } },
            { "uninstallTextHere", new[] { "The folder you are running it from is not deleted: {0}", "Le dossier depuis lequel il est lancé n'est pas supprimé : {0}" } },
            { "installHereTitle", new[] { "Install on this PC (recommended)", "Installer sur ce PC (recommandé)" } },
            { "installHereText", new[] { "SwitchDeck is copied here, so you can delete the downloaded folder.", "SwitchDeck est copié ici, vous pourrez supprimer le dossier téléchargé." } },
            { "runHereTitle", new[] { "Run from this folder", "Lancer depuis ce dossier" } },
            { "runHereText", new[] { "Nothing is copied. Keep this folder where it is.", "Rien n'est copié. Gardez ce dossier à sa place." } },
            { "change", new[] { "Change", "Modifier" } },
            { "pickInstallFolder", new[] { "Where should SwitchDeck be installed?", "Où installer SwitchDeck ?" } },
            { "installFailed", new[] { "Could not install SwitchDeck", "Impossible d'installer SwitchDeck" } },
            { "welcomeInstallTitle", new[] { "Welcome to SwitchDeck", "Bienvenue dans SwitchDeck" } },
            { "welcomeInstallText", new[] { "Set up SwitchDeck on this PC", "Installer SwitchDeck sur ce PC" } },
            { "welcomeInstallHint", new[] { "Nothing is copied: the shortcuts open SwitchDeck from where it is now. You can change this later in Settings.", "Rien n'est copié : les raccourcis ouvrent SwitchDeck là où il se trouve. Vous pourrez changer cela plus tard dans les Paramètres." } },
            { "shortcutDesktop", new[] { "Shortcut on the desktop", "Raccourci sur le bureau" } },
            { "shortcutStart", new[] { "SwitchDeck in the Start menu", "SwitchDeck dans le menu Démarrer" } },
            { "setShortcuts", new[] { "This PC", "Ce PC" } },
            { "notNow", new[] { "Not now", "Pas maintenant" } },
            { "installOpen", new[] { "Install and open", "Installer et ouvrir" } },
            { "viewPorts", new[] { "Ports", "Ports" } },
            { "viewList", new[] { "List", "Liste" } },
            { "resultsLegend", new[] { "Green: applied. Red: failed, click it to see why.", "Vert : appliqué. Rouge : en échec, cliquez pour voir pourquoi." } },
            { "advancedOptions", new[] { "Advanced options", "Options avancées" } },
            { "back", new[] { "Back", "Retour" } },
            { "close", new[] { "Close", "Fermer" } },
            { "showCommands", new[] { "Commands", "Commandes" } },
            { "portsOf", new[] { "Ports of {0}", "Ports de {0}" } },
            { "resultsTitle", new[] { "{0} on {1}", "{0} sur {1}" } },
            { "otherPorts2", new[] { "Other ports", "Autres ports" } },
            { "quitOne", new[] { "A session is still open. Closing SwitchDeck disconnects it.", "Une session est encore ouverte. Fermer SwitchDeck la déconnecte." } },
            { "quitMany", new[] { "{0} sessions are still open. Closing SwitchDeck disconnects them.", "{0} sessions sont encore ouvertes. Fermer SwitchDeck les déconnecte." } },
            { "importExport", new[] { "Import and export", "Importer et exporter" } },
            { "exportThis", new[] { "Export this template", "Exporter ce modèle" } },
            { "exportAll", new[] { "Export all templates", "Exporter tous les modèles" } },
            { "importTemplates", new[] { "Import templates", "Importer des modèles" } },
            { "templateFiles", new[] { "SwitchDeck templates", "Modèles SwitchDeck" } },
            { "exportedOne", new[] { "{0} exported", "{0} exporté" } },
            { "exportedMany", new[] { "{0} templates exported", "{0} modèles exportés" } },
            { "importedTemplates", new[] { "{0} templates imported", "{0} modèles importés" } },
            { "notTemplateFile", new[] { "{0} is not a SwitchDeck file.", "{0} n'est pas un fichier SwitchDeck." } },
            { "missingValueTitle", new[] { "A value is missing", "Une valeur manque" } },
            { "missingValueText", new[] { "{0} has no value in the template {1}. Set it in the Templates tab, then deploy again.", "{0} n'a pas de valeur dans le modèle {1}. Renseignez-la dans l'onglet Modèles, puis redéployez." } },
            { "fieldPorts", new[] { "Ports", "Ports" } },
            { "portsFieldHint", new[] { "Ranges work, like Gi1/0/1-48, Te1/1/1-4. Leave empty and SwitchDeck offers to read them on the first connection.", "Les plages marchent, comme Gi1/0/1-48, Te1/1/1-4. Laissez vide et SwitchDeck proposera de les lire à la première connexion." } },
            { "passwordHint", new[] { "Also used as the enable secret.", "Sert aussi de mot de passe enable." } },
            { "demoPasswordHint", new[] { "Enable secret of the lab switch. The default is cisco.", "Mot de passe enable du switch de test. Par défaut : cisco." } },
            { "setData", new[] { "Switches and templates", "Switchs et modèles" } },
            { "exportTitle", new[] { "Export", "Exporter" } },
            { "exportHint", new[] { "Saves your switches and templates to one file, without any password. Handy for a backup or a colleague.", "Enregistre vos switchs et modèles dans un fichier, sans aucun mot de passe. Pratique pour une sauvegarde ou un collègue." } },
            { "exportData", new[] { "Export", "Exporter" } },
            { "importTitle", new[] { "Import", "Importer" } },
            { "importHint", new[] { "Adds the switches and templates from an export file. Nothing you already have is replaced.", "Ajoute les switchs et modèles d'un fichier d'export. Rien de ce que vous avez n'est remplacé." } },
            { "importData", new[] { "Import", "Importer" } },
            { "exported", new[] { "{0} switches and {1} templates exported", "{0} switchs et {1} modèles exportés" } },
            { "imported", new[] { "{0} switches and {1} templates added", "{0} switchs et {1} modèles ajoutés" } },
            { "importFailed", new[] { "This file could not be read", "Impossible de lire ce fichier" } },
            { "importNothing", new[] { "Everything in this file is already in SwitchDeck", "Tout ce fichier est déjà dans SwitchDeck" } },
            { "quickCommands", new[] { "Commands", "Commandes" } },
            { "writeTitle", new[] { "Save the configuration?", "Enregistrer la configuration ?" } },
            { "writeText", new[] { "write memory copies the running configuration of {0} to its startup configuration.", "write memory copie la configuration en cours de {0} dans sa configuration de démarrage." } },
            { "writeNow", new[] { "Save it", "Enregistrer" } },
            { "imported2", new[] { "imported", "importé" } },
            { "language", new[] { "Language", "Langue" } },
            { "theme", new[] { "Theme", "Thème" } },
            { "light", new[] { "Light", "Clair" } },
            { "system", new[] { "System", "Système" } },
            { "dark", new[] { "Dark", "Sombre" } },
            { "followTheme", new[] { "Same as app", "Comme l'appli" } },
            { "termColors", new[] { "Terminal colors", "Couleurs du terminal" } },
            { "termColorsHint", new[] { "A dark terminal is easier to read for long sessions.", "Un terminal sombre est plus reposant sur de longues sessions." } },
            { "termSize", new[] { "Terminal text size", "Taille du texte" } },
            { "termSizeHint", new[] { "Ctrl + and Ctrl - also work inside the terminal.", "Ctrl + et Ctrl - marchent aussi dans le terminal." } },
            { "copyOnSelect", new[] { "Copy on select", "Copier à la sélection" } },
            { "copyOnSelectHint", new[] { "Selected text goes straight to the clipboard, like PuTTY.", "Le texte sélectionné va directement dans le presse-papiers, comme PuTTY." } },
            { "rightPaste", new[] { "Right-click pastes", "Clic droit pour coller" } },
            { "rightPasteHint", new[] { "Ctrl + right-click opens the menu instead.", "Ctrl + clic droit ouvre le menu à la place." } },
            { "sessionLogs", new[] { "Save session logs", "Enregistrer les sessions" } },
            { "sessionLogsHint", new[] { "Keeps a text file of every terminal session in the logs folder.", "Garde un fichier texte de chaque session dans le dossier des journaux." } },
            { "defaultUser", new[] { "Default username", "Utilisateur par défaut" } },
            { "defaultUserHint", new[] { "Filled in when you add a switch.", "Prérempli à l'ajout d'un switch." } },
            { "defaultMode", new[] { "Default method", "Méthode par défaut" } },
            { "defaultModeHint", new[] { "Range is faster, one by one is safer.", "La plage est plus rapide, un par un plus sûr." } },
            { "confirmDeploy", new[] { "Ask before deploying", "Demander avant de déployer" } },
            { "confirmDeployHint", new[] { "Shows a summary of what will change.", "Affiche un résumé de ce qui va changer." } },
            { "lineDelay", new[] { "Pause between commands", "Pause entre les commandes" } },
            { "lineDelayHint", new[] { "Helps slow serial links and busy switches.", "Aide sur les liaisons série lentes et les switchs chargés." } },
            { "logsFolder", new[] { "Logs", "Journaux" } },
            { "sessionLogsFolder", new[] { "Session logs", "Sessions" } },
            { "backupsFolder", new[] { "Backups", "Sauvegardes" } },
            { "dataFolder", new[] { "Data", "Données" } },

            { "version", new[] { "Version {0}", "Version {0}" } },
            { "about", new[] { "Connect to your Cisco switches and push saved port templates in a few clicks.", "Connectez-vous à vos switchs Cisco et déployez des modèles de port en quelques clics." } },
            { "feat1", new[] { "SSH, serial console and a lab switch for practice", "SSH, console série et un switch de test pour s'entraîner" } },
            { "feat2", new[] { "A terminal with copy on select and right-click paste", "Un terminal avec copie à la sélection et collage au clic droit" } },
            { "feat3", new[] { "Port templates you write once and reuse", "Des modèles de port écrits une fois et réutilisés" } },
            { "feat4", new[] { "Deploy on a range of ports or one port at a time", "Déploiement sur une plage de ports ou port par port" } },
            { "createdBy", new[] { "Created by Luka LAURENT", "Créé par Luka LAURENT" } },

            { "sampleGroup", new[] { "Lab", "Labo" } },
            { "sampleWifi", new[] { "Wifi access point, trunk with the Wifi VLAN", "Borne Wifi, trunk avec le VLAN Wifi" } },
            { "sampleOffice", new[] { "Desk PC in the office VLAN", "PC de bureau dans le VLAN bureautique" } },
            { "samplePhone", new[] { "IP phone with a PC behind it", "Téléphone IP avec un PC derrière" } },
            { "samplePrinter", new[] { "Network printer, named after its port", "Imprimante réseau, nommée d'après son port" } },
            { "sampleUnused", new[] { "Parked and shut down", "Mis de côté et éteint" } },
        };

        public static string T(string key)
        {
            string[] v;
            if (!texts.TryGetValue(key, out v)) return key;
            return Lang == "fr" ? v[1] : v[0];
        }

        public static string F(string key, params object[] args)
        {
            try { return string.Format(CultureInfo.CurrentCulture, T(key), args); }
            catch (FormatException) { return T(key); }
        }

        public static bool Has(string key) { return texts.ContainsKey(key); }

        public static string StatusText(string status)
        {
            bool fr = Lang == "fr";
            switch (status)
            {
                case "connected": return fr ? "Branché" : "Connected";
                case "notconnect": return fr ? "Rien de branché" : "Nothing plugged in";
                case "disabled": return fr ? "Éteint (shutdown)" : "Shut down";
                case "err-disabled": return fr ? "Bloqué (err-disabled)" : "Blocked (err-disabled)";
                case "inactive": return fr ? "Inactif" : "Inactive";
                default: return status;
            }
        }

        public static string ResultText(string result)
        {
            bool fr = Lang == "fr";
            switch (result)
            {
                case "ok": return fr ? "Appliqué" : "Applied";
                case "warn": return fr ? "À vérifier" : "Check it";
                case "failed": return fr ? "Échec" : "Failed";
                case "running": return fr ? "En cours" : "In progress";
                case "applied": return fr ? "Envoyé" : "Sent";
                case "skipped": return fr ? "Ignoré" : "Skipped";
                case "pending": return fr ? "En attente" : "Waiting";
                default: return result;
            }
        }

        public static string Pretty(string variable)
        {
            string s = variable.Replace('_', ' ').Replace('-', ' ').Trim();
            if (s.Length == 0) return variable;
            s = s.Replace("vlan", "VLAN").Replace("Vlan", "VLAN");
            return char.ToUpper(s[0], CultureInfo.CurrentCulture) + s.Substring(1);
        }

        public static string IconName(string icon)
        {
            bool fr = Lang == "fr";
            switch (icon)
            {
                case "settings_ethernet": return fr ? "Port" : "Port";
                case "wifi": return "Wifi";
                case "call": return fr ? "Téléphone" : "Phone";
                case "computer": return "PC";
                case "print": return fr ? "Imprimante" : "Printer";
                case "videocam": return fr ? "Caméra" : "Camera";
                case "lan": return fr ? "Réseau" : "Network";
                case "hub": return "Hub";
                case "router": return "Switch";
                case "dns": return fr ? "Serveur" : "Server";
                case "security": return fr ? "Sécurité" : "Security";
                case "block": return fr ? "Bloqué" : "Blocked";
                case "power_off": return fr ? "Éteint" : "Off";
                case "sensors": return fr ? "Capteur" : "Sensor";
                case "devices": return fr ? "Appareils" : "Devices";
                case "storage": return fr ? "Stockage" : "Storage";
                default: return icon;
            }
        }
    }
}
'@,
@'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal delegate void ItemPainter(Graphics g, Rectangle r, object item, bool selected, bool hover);

    internal sealed class ItemList : Painted
    {
        public readonly List<object> Items = new List<object>();
        public Func<object, int> HeightOf;
        public Func<object, bool> Selectable;
        public ItemPainter PaintItem;
        public event EventHandler SelectionChanged;
        public event Action<object> Activated;
        public event Action<object, Point> ContextRequested;
        public event Action<object, Point> ItemClicked;
        public string EmptyTitle, EmptyText;
        public bool EmptyNova = true;
        private int selected = -1, hover = -1;
        private int offset;
        private bool dragging;
        private int dragStart, dragOffset;
        public int Gap = 2;
        public int PadTop = 0;

        public ItemList()
        {
            Cursor = Cursors.Default;
            HeightOf = delegate { return Ui.D(52); };
            Selectable = delegate { return true; };
        }

        public int SelectedIndex
        {
            get { return selected; }
            set
            {
                selected = value;
                EnsureVisible(selected);
                Invalidate();
            }
        }

        public object SelectedItem { get { return selected >= 0 && selected < Items.Count ? Items[selected] : null; } }

        public void SelectItem(object item)
        {
            selected = item == null ? -1 : Items.IndexOf(item);
            EnsureVisible(selected);
            Invalidate();
        }

        public void SetItems(IEnumerable<object> items, object keepSelected)
        {
            Items.Clear();
            Items.AddRange(items);
            selected = keepSelected == null ? -1 : Items.IndexOf(keepSelected);
            Clamp();
            Invalidate();
        }

        private int Total
        {
            get
            {
                int t = PadTop;
                foreach (object o in Items) t += HeightOf(o) + D(Gap);
                return t;
            }
        }

        private int Max { get { return Math.Max(0, Total - Height); } }

        private void Clamp()
        {
            offset = Math.Max(0, Math.Min(Max, offset));
        }

        private int TopOf(int index)
        {
            int y = PadTop;
            for (int i = 0; i < index; i++) y += HeightOf(Items[i]) + D(Gap);
            return y;
        }

        private void EnsureVisible(int index)
        {
            if (index < 0 || index >= Items.Count) return;
            int y = TopOf(index), h = HeightOf(Items[index]);
            if (y < offset) offset = y;
            else if (y + h > offset + Height) offset = y + h - Height;
            Clamp();
        }

        private int HitTest(Point p)
        {
            int y = PadTop - offset;
            for (int i = 0; i < Items.Count; i++)
            {
                int h = HeightOf(Items[i]);
                if (p.Y >= y && p.Y < y + h) return i;
                y += h + D(Gap);
            }
            return -1;
        }

        private bool BarVisible { get { return Max > 0; } }

        private Rectangle Thumb
        {
            get
            {
                if (Max <= 0) return Rectangle.Empty;
                int track = Height - D(8);
                int th = Math.Max(D(30), (int)((long)track * Height / Math.Max(1, Total)));
                int y = D(4) + (int)((long)(track - th) * offset / Max);
                return new Rectangle(Width - D(7), y, D(5), th);
            }
        }

        protected override void OnMouseWheel(MouseEventArgs e)
        {
            offset -= e.Delta / 2;
            Clamp();
            int h = HitTest(e.Location);
            hover = h;
            Invalidate();
            base.OnMouseWheel(e);
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            if (dragging)
            {
                Rectangle t = Thumb;
                int track = Height - D(8) - t.Height;
                if (track > 0) offset = dragOffset + (int)((long)(e.Y - dragStart) * Max / track);
                Clamp();
                Invalidate();
                return;
            }
            int h = HitTest(e.Location);
            if (h >= 0 && !Selectable(Items[h])) h = -1;
            if (h != hover) { hover = h; Invalidate(); }
            Cursor = h >= 0 ? Cursors.Hand : Cursors.Default;
            base.OnMouseMove(e);
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            hover = -1;
            base.OnMouseLeave(e);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            Focus();
            if (BarVisible && e.X >= Width - D(10))
            {
                dragging = true;
                dragStart = e.Y;
                dragOffset = offset;
                Capture = true;
                return;
            }
            int h = HitTest(e.Location);
            if (h < 0) return;
            object item = Items[h];
            if (Selectable(item))
            {
                if (h != selected)
                {
                    selected = h;
                    Invalidate();
                    EventHandler ev = SelectionChanged;
                    if (ev != null) ev(this, EventArgs.Empty);
                }
            }
            Action<object, Point> click = ItemClicked;
            if (click != null && e.Button == MouseButtons.Left)
            {
                int y = TopOf(h) - offset;
                click(item, new Point(e.X, e.Y - y));
            }
            if (e.Button == MouseButtons.Right)
            {
                Action<object, Point> c = ContextRequested;
                if (c != null) c(item, e.Location);
            }
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            dragging = false;
            Capture = false;
            base.OnMouseUp(e);
        }

        protected override void OnMouseDoubleClick(MouseEventArgs e)
        {
            base.OnMouseDoubleClick(e);
            int h = HitTest(e.Location);
            if (h < 0 || e.Button != MouseButtons.Left) return;
            Action<object> a = Activated;
            if (a != null && Selectable(Items[h])) a(Items[h]);
        }

        protected override bool IsInputKey(Keys keyData)
        {
            return keyData == Keys.Up || keyData == Keys.Down || keyData == Keys.Enter || base.IsInputKey(keyData);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            int dir = e.KeyCode == Keys.Up ? -1 : e.KeyCode == Keys.Down ? 1 : 0;
            if (dir != 0)
            {
                int i = selected;
                do { i += dir; } while (i >= 0 && i < Items.Count && !Selectable(Items[i]));
                if (i >= 0 && i < Items.Count)
                {
                    selected = i;
                    EnsureVisible(i);
                    Invalidate();
                    EventHandler ev = SelectionChanged;
                    if (ev != null) ev(this, EventArgs.Empty);
                }
                e.Handled = true;
            }
            else if (e.KeyCode == Keys.Enter && SelectedItem != null)
            {
                Action<object> a = Activated;
                if (a != null) a(SelectedItem);
                e.Handled = true;
            }
            base.OnKeyDown(e);
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            Clamp();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            if (Items.Count == 0)
            {
                PaintEmpty(g);
                return;
            }
            int y = PadTop - offset;
            int w = Width - (BarVisible ? D(10) : 0);
            for (int i = 0; i < Items.Count; i++)
            {
                int h = HeightOf(Items[i]);
                if (y + h >= 0 && y <= Height)
                {
                    Rectangle r = new Rectangle(0, y, w, h);
                    PaintItem(g, r, Items[i], i == selected, i == hover);
                }
                y += h + D(Gap);
                if (y > Height) break;
            }
            Rectangle t = Thumb;
            if (!t.IsEmpty) Ui.FillRound(g, t, t.Width / 2f, dragging ? p.Faint : p.Track);
        }

        private void PaintEmpty(Graphics g)
        {
            Palette p = Theme.P;
            if (EmptyTitle == null) return;
            int y = Math.Max(D(16), Height / 2 - D(90));
            if (EmptyNova)
            {
                int s = D(56);
                Icons.NovaBadge(g, new RectangleF((Width - s) / 2f, y, s, s));
                y += s + D(14);
            }
            Ui.Text(g, EmptyTitle, Fonts.Strong(14.5f * Sc), new Rectangle(D(12), y, Width - D(24), D(22)), p.Text, Ui.Center);
            y += D(26);
            if (EmptyText != null)
            {
                Rectangle tr = new Rectangle(D(20), y, Width - D(40), Ui.WrapHeight(EmptyText, Fonts.Body(13f * Sc), Width - D(40)) + D(4));
                TextRenderer.DrawText(g, EmptyText, Fonts.Body(13f * Sc), tr, p.Muted, TextFormatFlags.HorizontalCenter | TextFormatFlags.WordBreak | TextFormatFlags.NoPadding);
            }
        }

        public static void Row(Graphics g, Rectangle r, bool selected, bool hover)
        {
            Palette p = Theme.P;
            RectangleF rr = new RectangleF(r.X + Ui.D(6), r.Y, r.Width - Ui.D(12), r.Height);
            if (selected) Ui.FillRound(g, rr, 10 * Ui.Sc, p.OrangeSoft);
            else if (hover) Ui.FillRound(g, rr, 10 * Ui.Sc, p.HoverFill);
            if (selected)
            {
                RectangleF bar = new RectangleF(rr.X, rr.Y + rr.Height * 0.25f, 3 * Ui.Sc, rr.Height * 0.5f);
                Ui.FillRound(g, bar, 1.5f * Ui.Sc, p.Orange);
            }
        }
    }
}
'@,
@'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal sealed class MainForm : Form
    {
        public const int MinW = 1060, MinH = 700;
        public static MainForm Instance;
        private int tab;
        private Pane header;
        private Pane content;
        private Bitmap logo;
        private readonly List<TabPill> pills = new List<TabPill>();
        private Btn maxBtn;
        public SwitchesPage Switches;
        public TemplatesPage Templates;
        public DeployPage Deploy;
        private Control current;
        private readonly Toast toast;
        private bool building;

        public MainForm(int startTab)
        {
            Instance = this;
            tab = startTab;
            Ui.Sc = DpiAtCursor() / 96f;
            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.Manual;
            AutoScaleMode = AutoScaleMode.None;
            DoubleBuffered = true;
            KeyPreview = true;
            Text = "SwitchDeck";
            Icon = Icons.MakeIcon(Math.Max(32, Ui.D(32)));
            Settings s = Store.Settings;
            Rectangle work = Screen.FromPoint(Cursor.Position).WorkingArea;
            int w = s.WindowW > 0 ? Math.Max(Ui.D(MinW), s.WindowW) : Math.Min(work.Width - Ui.D(40), Ui.D(1320));
            int h = s.WindowH > 0 ? Math.Max(Ui.D(MinH), s.WindowH) : Math.Min(work.Height - Ui.D(40), Ui.D(840));
            w = Math.Min(w, work.Width);
            h = Math.Min(h, work.Height);
            Bounds = new Rectangle(work.Left + (work.Width - w) / 2, work.Top + (work.Height - h) / 2, w, h);
            if (s.Maximized) WindowState = FormWindowState.Maximized;
            MinimumSize = new Size(Ui.D(MinW), Ui.D(MinH));
            toast = new Toast();
            Theme.Changed += delegate { if (!IsDisposed) BeginInvoke((Action)Rebuild); };
            Build();
        }

        private static float DpiAtCursor()
        {
            try
            {
                POINT p;
                Native.GetCursorPos(out p);
                IntPtr m = Native.MonitorFromPoint(p, 2);
                uint dx, dy;
                if (Native.GetDpiForMonitor(m, 0, out dx, out dy) == 0) return dx;
            }
            catch { }
            return 96;
        }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.Style |= 0x00040000 | 0x00020000 | 0x00010000 | 0x00080000;
                return cp;
            }
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            ApplyFrame();
        }

        private void ApplyFrame()
        {
            try
            {
                int round = 2;
                Native.DwmSetWindowAttribute(Handle, 33, ref round, 4);
                Color c = Theme.P.Border;
                int colorRef = c.R | (c.G << 8) | (c.B << 16);
                Native.DwmSetWindowAttribute(Handle, 34, ref colorRef, 4);
                int dark = Theme.P.Dark ? 1 : 0;
                Native.DwmSetWindowAttribute(Handle, 20, ref dark, 4);
            }
            catch { }
        }

        private const int ResizeBorder = 6;

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == Native.WM_NCCALCSIZE && m.WParam != IntPtr.Zero)
            {
                if (WindowState == FormWindowState.Maximized)
                {
                    NCCALCSIZE_PARAMS nc = (NCCALCSIZE_PARAMS)Marshal.PtrToStructure(m.LParam, typeof(NCCALCSIZE_PARAMS));
                    IntPtr mon = Native.MonitorFromWindow(Handle, 2);
                    MONITORINFO mi = new MONITORINFO();
                    mi.Size = Marshal.SizeOf(typeof(MONITORINFO));
                    if (Native.GetMonitorInfo(mon, ref mi)) nc.R0 = mi.Work;
                    Marshal.StructureToPtr(nc, m.LParam, false);
                }
                m.Result = IntPtr.Zero;
                return;
            }
            if (m.Msg == 0x86)
            {
                m.Result = (IntPtr)1;
                return;
            }
            if (m.Msg == 0x85 || m.Msg == 0xAE || m.Msg == 0xAF)
            {
                m.Result = IntPtr.Zero;
                return;
            }
            if (m.Msg == Native.WM_NCHITTEST)
            {
                base.WndProc(ref m);
                if (WindowState == FormWindowState.Maximized) return;
                Point p = PointToClient(new Point(m.LParam.ToInt32() & 0xFFFF | 0, 0));
                int x = (short)(m.LParam.ToInt32() & 0xFFFF), y = (short)((m.LParam.ToInt32() >> 16) & 0xFFFF);
                p = PointToClient(new Point(x, y));
                int b = Ui.D(ResizeBorder);
                bool l = p.X < b, r = p.X >= ClientSize.Width - b, t = p.Y < b, bo = p.Y >= ClientSize.Height - b;
                if (t && l) m.Result = (IntPtr)Native.HTTOPLEFT;
                else if (t && r) m.Result = (IntPtr)Native.HTTOPRIGHT;
                else if (bo && l) m.Result = (IntPtr)Native.HTBOTTOMLEFT;
                else if (bo && r) m.Result = (IntPtr)Native.HTBOTTOMRIGHT;
                else if (l) m.Result = (IntPtr)Native.HTLEFT;
                else if (r) m.Result = (IntPtr)Native.HTRIGHT;
                else if (t) m.Result = (IntPtr)Native.HTTOP;
                else if (bo) m.Result = (IntPtr)Native.HTBOTTOM;
                return;
            }
            if (m.Msg == Native.WM_DPICHANGED)
            {
                float next = (m.WParam.ToInt32() & 0xFFFF) / 96f;
                RECT r = (RECT)Marshal.PtrToStructure(m.LParam, typeof(RECT));
                if (Math.Abs(next - Ui.Sc) > 0.01f)
                {
                    Ui.Sc = next;
                    MinimumSize = new Size(Ui.D(MinW), Ui.D(MinH));
                    Bounds = new Rectangle(r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top);
                    Rebuild();
                }
                m.Result = IntPtr.Zero;
                return;
            }
            base.WndProc(ref m);
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            if (header == null || building) return;
            LayoutShell();
            if (maxBtn != null) { maxBtn.Icon = WindowState == FormWindowState.Maximized ? "filter_none" : "crop_square"; maxBtn.Invalidate(); }
        }

        public void Rebuild()
        {
            if (IsDisposed) return;
            Build();
        }

        public int Tab { get { return tab; } }

        public void SelectTab(int i)
        {
            if (i == tab && current != null) return;
            tab = i;
            for (int k = 0; k < pills.Count; k++) { pills[k].Selected = k == i; pills[k].Invalidate(); }
            ShowPage();
        }

        private void Build()
        {
            building = true;
            SuspendLayout();
            Palette p = Theme.P;
            BackColor = p.Bg;
            string selHost = Switches != null ? Switches.SelectedHostId : null;
            string selSession = Switches != null ? Switches.ActiveSessionHostId : null;
            string selTemplate = Templates != null ? Templates.SelectedId : null;
            DeployState deployState = Deploy != null ? Deploy.CaptureState() : null;
            List<Control> old = new List<Control>();
            foreach (Control c in Controls) old.Add(c);
            Controls.Clear();
            foreach (Control c in old) { if (c != toast) c.Dispose(); }
            pills.Clear();
            current = null;
            if (logo != null) logo.Dispose();
            logo = Icons.App(Ui.D(30));

            header = new Pane();
            header.BackColor = p.Bg;
            header.Paint += PaintHeader;
            header.MouseDown += Drag;
            header.DoubleClick += delegate { ToggleMax(); };

            string[] names = { L.T("tabSwitches"), L.T("tabDeploy"), L.T("tabTemplates"), L.T("tabSettings"), L.T("tabAbout") };
            string[] icons = { "dns", "rocket_launch", "layers", "settings", "info" };
            for (int i = 0; i < names.Length; i++)
            {
                int index = i;
                TabPill t = new TabPill(names[i], icons[i], i == tab);
                t.Click += delegate { SelectTab(index); };
                header.Controls.Add(t);
                pills.Add(t);
            }
            Btn min = new Btn(null, "minimize", BtnKind.Ghost, delegate { WindowState = FormWindowState.Minimized; }).Small();
            maxBtn = new Btn(null, WindowState == FormWindowState.Maximized ? "filter_none" : "crop_square", BtnKind.Ghost, delegate { ToggleMax(); }).Small();
            Btn close = new Btn(null, "close", BtnKind.Ghost, delegate { Close(); }).Small();
            min.Name = "min"; maxBtn.Name = "max"; close.Name = "close";
            header.Controls.Add(min);
            header.Controls.Add(maxBtn);
            header.Controls.Add(close);

            content = new Pane();
            content.BackColor = p.Bg;

            Controls.Add(content);
            Controls.Add(header);

            if (Switches != null) Switches.Detach();
            Switches = new SwitchesPage(this);
            Templates = new TemplatesPage(this);
            Deploy = new DeployPage(this);
            if (selHost != null) Switches.SelectHost(selHost);
            if (selSession != null) Switches.ShowSessionFor(selSession);
            if (selTemplate != null) Templates.Select(selTemplate);
            if (deployState != null) Deploy.Restore(deployState);
            ResumeLayout();
            building = false;
            LayoutShell();
            ShowPage();
            if (IsHandleCreated) ApplyFrame();
            Controls.Add(toast);
            toast.BringToFront();
            Invalidate(true);
        }

        private void LayoutShell()
        {
            if (header == null) return;
            int hh = Ui.D(64);
            header.Bounds = new Rectangle(0, 0, ClientSize.Width, hh);
            int x = Ui.D(64) + Ui.Measure("SwitchDeck", Fonts.Head(18f * Ui.Sc)).Width + Ui.D(22);
            int buttons = Ui.D(14) + 3 * Ui.D(34) + Ui.D(18);
            foreach (TabPill t in pills) t.SetCompact(false);
            int need = 0;
            foreach (TabPill t in pills) need += t.Width + Ui.D(2);
            if (x + need > header.Width - buttons) foreach (TabPill t in pills) t.SetCompact(true);
            foreach (TabPill t in pills)
            {
                t.Location = new Point(x, (hh - t.Height) / 2);
                x = t.Right + Ui.D(2);
            }
            int rx = header.Width - Ui.D(14);
            foreach (string n in new[] { "close", "max", "min" })
            {
                Control c = header.Controls[n];
                if (c == null) continue;
                c.Location = new Point(rx - c.Width, (hh - c.Height) / 2);
                rx = c.Left - Ui.D(2);
            }
            content.Bounds = new Rectangle(0, hh, ClientSize.Width, ClientSize.Height - hh);
            if (current != null) current.Bounds = new Rectangle(0, 0, content.Width, content.Height);
            toast.Reposition(this);
        }

        private void ShowPage()
        {
            Control next;
            switch (tab)
            {
                case 0: next = Switches; break;
                case 1: next = Deploy; break;
                case 2: next = Templates; break;
                case 3: next = new SettingsPage(this); break;
                default: next = new AboutPage(); break;
            }
            if (current == next) return;
            content.SuspendLayout();
            if (current != null)
            {
                content.Controls.Remove(current);
                if (current is SettingsPage || current is AboutPage) current.Dispose();
            }
            current = next;
            current.Bounds = new Rectangle(0, 0, content.Width, content.Height);
            content.Controls.Add(current);
            content.ResumeLayout();
            IPage page = current as IPage;
            if (page != null) page.Shown();
        }

        private void PaintHeader(object sender, PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            Palette p = Theme.P;
            Icons.Smooth(g);
            g.DrawImage(logo, Ui.D(22), (header.Height - logo.Height) / 2);
            Ui.Text(g, "SwitchDeck", Fonts.Head(18f * Ui.Sc), new Rectangle(Ui.D(62), 0, Ui.D(200), header.Height), p.Text, Ui.Left);
            using (Pen pen = new Pen(p.Border, Math.Max(1f, (float)Math.Floor(Ui.Sc))))
                g.DrawLine(pen, 0, header.Height - 1, header.Width, header.Height - 1);
        }

        private void ToggleMax()
        {
            WindowState = WindowState == FormWindowState.Maximized ? FormWindowState.Normal : FormWindowState.Maximized;
        }

        private void Drag(object sender, MouseEventArgs e)
        {
            if (e.Button != MouseButtons.Left || e.Clicks > 1) return;
            Native.ReleaseCapture();
            Native.SendMessage(Handle, Native.WM_NCLBUTTONDOWN, new IntPtr(Native.HTCAPTION), IntPtr.Zero);
        }

        protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
        {
            if (keyData == (Keys.Control | Keys.Tab) || keyData == (Keys.Control | Keys.Shift | Keys.Tab))
            {
                int dir = (keyData & Keys.Shift) != 0 ? -1 : 1;
                SelectTab((tab + dir + 5) % 5);
                return true;
            }
            if (keyData >= (Keys.Control | Keys.D1) && keyData <= (Keys.Control | Keys.D5))
            {
                SelectTab((int)(keyData & Keys.KeyCode) - (int)Keys.D1);
                return true;
            }
            return base.ProcessCmdKey(ref msg, keyData);
        }

        public void Notify(string text, string kind)
        {
            toast.Show(this, text, kind);
        }

        public static void OpenFolder(string path)
        {
            try
            {
                Directory.CreateDirectory(path);
                Process.Start("explorer.exe", "\"" + path + "\"");
            }
            catch (Exception ex) { Log.Error("Could not open folder: " + ex.Message); }
        }

        public static void OpenFile(string path)
        {
            try { Process.Start("explorer.exe", "/select,\"" + path + "\""); }
            catch (Exception ex) { Log.Error("Could not open file: " + ex.Message); }
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            int open = Sessions.OpenCount;
            if (open > 0 && e.CloseReason == CloseReason.UserClosing && !Program.Rendering && !Program.Uninstalling)
            {
                if (!Dialogs.Ask(this, L.T("quitTitle"), open == 1 ? L.T("quitOne") : L.F("quitMany", open), L.T("quit"), L.T("cancel"), "power_off", true))
                {
                    e.Cancel = true;
                    return;
                }
            }
            Settings s = Store.Settings;
            s.Maximized = WindowState == FormWindowState.Maximized;
            if (WindowState == FormWindowState.Normal) { s.WindowW = Width; s.WindowH = Height; }
            if (!Program.Rendering) Store.SaveSettings();
            Hide();
            base.OnFormClosing(e);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing && logo != null) logo.Dispose();
            base.Dispose(disposing);
        }
    }

    internal interface IPage
    {
        void Shown();
    }

    internal sealed class Toast : Painted
    {
        private string text = "";
        private string kind = "ok";
        private readonly Timer hide;

        public Toast()
        {
            Visible = false;
            Cursor = Cursors.Default;
            hide = new Timer();
            hide.Interval = 3200;
            hide.Tick += delegate { hide.Stop(); Visible = false; };
            Click += delegate { Visible = false; };
        }

        public void Show(Form f, string text, string kind)
        {
            this.text = text;
            this.kind = kind ?? "ok";
            Font ft = Fonts.Strong(13.5f * Sc);
            Width = Math.Min(D(520), Ui.Measure(text, ft).Width + D(70));
            Height = D(48);
            using (System.Drawing.Drawing2D.GraphicsPath path = Icons.Rounded(new RectangleF(0, 0, Width, Height), 12 * Sc))
                Region = new Region(path);
            Reposition(f);
            Visible = true;
            BringToFront();
            Invalidate();
            hide.Stop();
            hide.Start();
        }

        public void Reposition(Form f)
        {
            Location = new Point((f.ClientSize.Width - Width) / 2, f.ClientSize.Height - Height - D(28));
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            Palette p = Theme.P;
            g.Clear(p.Bg);
            Icons.Smooth(g);
            RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            Color bg = p.Dark ? Theme.C(0x2A3038) : Theme.Charcoal;
            Ui.FillRound(g, r, 12 * Sc, bg);
            Color ic = kind == "error" ? p.Danger : kind == "warn" ? p.Warning : kind == "info" ? Theme.C(0x93BFC4) : p.Success;
            Icons.Draw(g, kind == "error" ? "error" : kind == "warn" ? "warning" : kind == "info" ? "info" : "check_circle", new RectangleF(D(14), 0, D(24), Height), ic, 21 * Sc, true);
            Ui.Text(g, text, Fonts.Strong(13.5f * Sc), new Rectangle(D(46), 0, Width - D(60), Height), Theme.OffWhite, Ui.Left);
        }
    }
}
'@,
@'
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
'@,
@'
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace SwitchDeck
{
    [StructLayout(LayoutKind.Sequential)]
    internal struct RECT
    {
        public int Left, Top, Right, Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct POINT { public int X, Y; }

    [StructLayout(LayoutKind.Sequential)]
    internal struct COORD
    {
        public short X, Y;
        public COORD(short x, short y) { X = x; Y = y; }
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct STARTUPINFO
    {
        public int cb;
        public string lpReserved, lpDesktop, lpTitle;
        public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public short wShowWindow, cbReserved2;
        public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct STARTUPINFOEX
    {
        public STARTUPINFO StartupInfo;
        public IntPtr lpAttributeList;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct PROCESS_INFORMATION
    {
        public IntPtr hProcess, hThread;
        public int dwProcessId, dwThreadId;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct MONITORINFO
    {
        public int Size;
        public RECT Monitor;
        public RECT Work;
        public uint Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct MINMAXINFO
    {
        public POINT Reserved, MaxSize, MaxPosition, MinTrackSize, MaxTrackSize;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct NCCALCSIZE_PARAMS
    {
        public RECT R0, R1, R2;
        public IntPtr Pos;
    }

    internal static class Native
    {
        public const int WM_NCLBUTTONDOWN = 0xA1, HTCAPTION = 2, WM_DPICHANGED = 0x2E0, WM_NCHITTEST = 0x84, WM_NCCALCSIZE = 0x83;
        public const int WM_GETMINMAXINFO = 0x24, WM_SETREDRAW = 0x0B, WM_SYSCOMMAND = 0x112;
        public const int HTLEFT = 10, HTRIGHT = 11, HTTOP = 12, HTTOPLEFT = 13, HTTOPRIGHT = 14, HTBOTTOM = 15, HTBOTTOMLEFT = 16, HTBOTTOMRIGHT = 17, HTCLIENT = 1;
        public const uint EXTENDED_STARTUPINFO_PRESENT = 0x00080000, CREATE_UNICODE_ENVIRONMENT = 0x400;
        public static readonly IntPtr PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE = new IntPtr(0x00020016);

        [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
        [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hwnd);
        [DllImport("user32.dll")] public static extern bool AllowSetForegroundWindow(int processId);
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
        [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr icon);
        [DllImport("user32.dll")] public static extern bool ReleaseCapture();
        [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hwnd, int msg, IntPtr w, IntPtr l);
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int cmd);
        [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr hwnd);
        [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
        [DllImport("user32.dll")] public static extern IntPtr MonitorFromPoint(POINT p, uint flags);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);
        [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
        [DllImport("shcore.dll")] public static extern int GetDpiForMonitor(IntPtr monitor, int type, out uint dpiX, out uint dpiY);
        [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
        [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] public static extern int SetWindowTheme(IntPtr hwnd, string app, string idList);
        [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResourceEx(string file, uint flags, IntPtr reserved);
        [DllImport("user32.dll")] public static extern int GetCaretBlinkTime();
        [DllImport("user32.dll")] public static extern bool MessageBeep(uint type);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern int CreatePseudoConsole(COORD size, SafeFileHandle input, SafeFileHandle output, uint flags, out IntPtr pc);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern int ResizePseudoConsole(IntPtr pc, COORD size);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern void ClosePseudoConsole(IntPtr pc);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CreatePipe(out SafeFileHandle read, out SafeFileHandle write, IntPtr attributes, int size);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool InitializeProcThreadAttributeList(IntPtr list, int count, int flags, ref IntPtr size);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool UpdateProcThreadAttribute(IntPtr list, uint flags, IntPtr attribute, IntPtr value, IntPtr size, IntPtr previous, IntPtr returnSize);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern void DeleteProcThreadAttributeList(IntPtr list);
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool CreateProcess(string app, string cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string dir, ref STARTUPINFOEX si, out PROCESS_INFORMATION pi);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(IntPtr h);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool TerminateProcess(IntPtr h, uint code);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern uint WaitForSingleObject(IntPtr h, uint ms);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool GetExitCodeProcess(IntPtr h, out uint code);

        public static void SetRedraw(IntPtr hwnd, bool on)
        {
            SendMessage(hwnd, WM_SETREDRAW, new IntPtr(on ? 1 : 0), IntPtr.Zero);
        }
    }
}
'@,
@'
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
'@,
@'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows.Forms;

[assembly: AssemblyTitle("SwitchDeck")]
[assembly: AssemblyVersion("1.0.0.0")]

namespace SwitchDeck
{
    public static class Program
    {
        private const string Id = "Local\\SwitchDeck-6c1e2f94";
        internal static string Script;
        internal static string Root;
        internal static bool Rendering;

        public static string Version
        {
            get { Version v = typeof(Program).Assembly.GetName().Version; return v.Major + "." + v.Minor + "." + v.Build; }
        }

        internal static string DataDir { get { return Path.Combine(Root, "data"); } }
        internal static string LogsDir { get { return Path.Combine(Root, "logs"); } }
        internal static string AssetsDir { get { return Path.Combine(AppRoot, "assets"); } }
        internal static string AppRoot;

        private static Form splash;

        public static void CloseSplash()
        {
            Form f = splash;
            splash = null;
            if (f == null) return;
            try { f.Close(); f.Dispose(); } catch { }
        }

        public static int RunFromScript(string scriptPath, string[] args)
        {
            return RunFromScript(scriptPath, args, null);
        }

        public static int RunFromScript(string scriptPath, string[] args, object splashForm)
        {
            object o = splashForm;
            if (o != null && !(o is Form))
            {
                PropertyInfo pi = o.GetType().GetProperty("BaseObject");
                if (pi != null) o = pi.GetValue(o, null);
            }
            splash = o as Form;
            try { return Run(scriptPath, args); }
            finally { CloseSplash(); }
        }

        internal static bool Uninstalling;

        private static void Finish(bool uninstall)
        {
            using (SplashForm sp = new SplashForm(uninstall ? L.T("uninstalling") : L.T("closing")))
            {
                sp.Show();
                sp.Refresh();
                DateTime start = DateTime.Now;
                Thread t = new Thread(delegate()
                {
                    try { Sessions.CloseAll(); } catch { }
                    if (uninstall) { try { Install.Uninstall(); } catch (Exception ex) { Log.Error("Uninstall: " + ex.Message); } }
                });
                t.IsBackground = true;
                t.Start();
                while (t.IsAlive || (DateTime.Now - start).TotalMilliseconds < 900)
                {
                    Application.DoEvents();
                    Thread.Sleep(15);
                }
                sp.Close();
            }
            Log.Info(uninstall ? "SwitchDeck uninstalled" : "SwitchDeck closed");
        }

        private static int Run(string scriptPath, string[] args)
        {
            Script = scriptPath;
            AppRoot = Path.GetDirectoryName(Path.GetDirectoryName(scriptPath));
            string home = Environment.GetEnvironmentVariable("SWITCHDECK_HOME");
            Root = string.IsNullOrEmpty(home) ? AppRoot : home;
            try { Native.SetProcessDpiAwarenessContext(new IntPtr(-4)); } catch { }

            List<string> a = new List<string>(args ?? new string[0]);
            if (a.Contains("--exit")) { Signal(Id + "-exit"); return 0; }
            int wa = a.IndexOf("--write-assets");
            if (wa >= 0 && wa + 1 < a.Count) { Install.WriteAssets(a[wa + 1]); return 0; }
            if (a.Contains("--selftest")) return SelfTest.Run();
            int sshi = a.IndexOf("--sshtest");
            if (sshi >= 0 && sshi + 1 < a.Count) return SelfTest.SshTest(int.Parse(a[sshi + 1]));
            if (a.Contains("--demo-shell")) return DemoShell(a);
            Fonts.Load(Path.Combine(AssetsDir, "fonts"));
            Store.Load();
            L.Lang = Store.Settings.Language;
            Theme.Apply(Store.Settings.Theme, Store.Settings.TermTheme);
            int render = a.IndexOf("--render-ui");
            if (render >= 0 && render + 1 < a.Count) { DevRender.Run(a[render + 1], a); return 0; }

            bool created;
            using (Mutex mutex = new Mutex(true, Id, out created))
            {
                if (a.Contains("--uninstall"))
                {
                    if (!created)
                    {
                        Signal(Id + "-exit");
                        try { created = mutex.WaitOne(20000); }
                        catch (AbandonedMutexException) { created = true; }
                    }
                    try { Application.EnableVisualStyles(); } catch { }
                    CloseSplash();
                    if (!Dialogs.Ask(null, L.T("uninstallTitle"), Install.UninstallText(), L.T("uninstall"), L.T("cancel"), "delete", true)) return 0;
                    Finish(true);
                    return 0;
                }
                if (!created && a.Contains("--wait"))
                {
                    try { created = mutex.WaitOne(20000); }
                    catch (AbandonedMutexException) { created = true; }
                }
                if (!created)
                {
                    CloseSplash();
                    Signal(Id + "-show");
                    return 0;
                }
                try { Application.EnableVisualStyles(); } catch { }
                try { Application.SetCompatibleTextRenderingDefault(false); } catch { }
                try { Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException); } catch { }
                Application.ThreadException += delegate(object s, ThreadExceptionEventArgs e)
                {
                    Log.Error("Unhandled: " + e.Exception);
                    try { Dialogs.Problem(MainForm.Instance, L.T("oops"), e.Exception.Message); } catch { }
                };
                AppDomain.CurrentDomain.UnhandledException += delegate(object s, UnhandledExceptionEventArgs e) { Log.Error("Fatal: " + e.ExceptionObject); };
                Log.Info("SwitchDeck " + Version + " started");

                using (EventWaitHandle show = new EventWaitHandle(false, EventResetMode.AutoReset, Id + "-show"))
                using (EventWaitHandle exit = new EventWaitHandle(false, EventResetMode.AutoReset, Id + "-exit"))
                {
                    if (Install.NeedsWelcome)
                    {
                        string launched = null;
                        using (WelcomeForm w = new WelcomeForm())
                        {
                            CloseSplash();
                            w.ShowDialog();
                            launched = w.InstalledScript;
                        }
                        if (launched != null)
                        {
                            mutex.ReleaseMutex();
                            Install.Launch(launched);
                            return 0;
                        }
                    }
                    else Install.Refresh();
                    MainForm form = new MainForm(0);
                    form.Shown += delegate { CloseSplash(); };
                    Thread watcher = new Thread(delegate()
                    {
                        try
                        {
                            WaitHandle[] handles = { show, exit };
                            while (true)
                            {
                                int i = WaitHandle.WaitAny(handles);
                                if (form.IsDisposed) return;
                                if (i == 0) form.BeginInvoke((Action)delegate
                                {
                                    if (form.WindowState == FormWindowState.Minimized) form.WindowState = FormWindowState.Normal;
                                    form.Activate();
                                    Native.SetForegroundWindow(form.Handle);
                                });
                                else { form.BeginInvoke((Action)delegate { Program.Rendering = true; form.Close(); }); return; }
                            }
                        }
                        catch { }
                    });
                    watcher.IsBackground = true;
                    watcher.Start();
                    Application.Run(form);
                }
                Finish(Uninstalling);
                try { mutex.ReleaseMutex(); } catch { }
            }
            return 0;
        }

        private static int DemoShell(List<string> a)
        {
            Store.Settings = new Settings();
            int mi = a.IndexOf("--model");
            string model = mi >= 0 && mi + 1 < a.Count ? a[mi + 1] : "C9300-48P";
            DemoSwitch d = new DemoSwitch("shell-" + model, model, "cisco");
            Stream stdout = Console.OpenStandardOutput();
            object gate = new object();
            d.Output = delegate(string s)
            {
                byte[] b = Encoding.ASCII.GetBytes(s);
                lock (gate) { stdout.Write(b, 0, b.Length); stdout.Flush(); }
            };
            bool quit = false;
            d.Quit = delegate { quit = true; };
            d.Boot();
            Stream stdin = Console.OpenStandardInput();
            byte[] buf = new byte[1024];
            while (!quit)
            {
                int n = stdin.Read(buf, 0, buf.Length);
                if (n <= 0) break;
                for (int i = 0; i < n && !quit; i++) d.Key((char)buf[i]);
            }
            return 0;
        }

        private static void Signal(string name)
        {
            try { Native.AllowSetForegroundWindow(-1); } catch { }
            try
            {
                using (EventWaitHandle ev = EventWaitHandle.OpenExisting(name)) ev.Set();
            }
            catch { }
        }
    }

    internal static class Log
    {
        private static readonly object gate = new object();

        public static void Info(string message) { Write("INFO", message); }
        public static void Warn(string message) { Write("WARN", message); }
        public static void Error(string message) { Write("ERROR", message); }

        private static void Write(string level, string message)
        {
            try
            {
                lock (gate)
                {
                    if (Program.Root == null) return;
                    Directory.CreateDirectory(Program.LogsDir);
                    string path = Path.Combine(Program.LogsDir, "SwitchDeck.log");
                    FileInfo fi = new FileInfo(path);
                    if (fi.Exists && fi.Length > 2 * 1024 * 1024)
                    {
                        File.Copy(path, Path.Combine(Program.LogsDir, "SwitchDeck.old.log"), true);
                        File.Delete(path);
                    }
                    File.AppendAllText(path, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") + " " + level + " " + message + Environment.NewLine, Encoding.UTF8);
                }
            }
            catch { }
        }
    }

    internal static class Samples
    {
        public static void AddHosts()
        {
            Host a = new Host();
            a.Name = "Lab Core 9300";
            a.Kind = "demo";
            a.DemoModel = "C9300-48P";
            a.Password = Secret.Protect("cisco");
            Store.Hosts.Add(a);
            Host b = new Host();
            b.Name = "Lab Floor 2960X";
            b.Kind = "demo";
            b.DemoModel = "WS-C2960X-24PS-L";
            b.Password = Secret.Protect("cisco");
            Store.Hosts.Add(b);
            AddC9200();
        }

        public static void AddC9200()
        {
            Host a = new Host();
            a.Name = "Lab Access 9200L";
            a.Kind = "demo";
            a.DemoModel = "C9200L-48P-4X";
            a.Password = Secret.Protect("cisco");
            Store.Hosts.Add(a);
            Host b = new Host();
            b.Name = "Lab Stack 9200L";
            b.Kind = "demo";
            b.DemoModel = "C9200L-48P-4X-STACK";
            b.Password = Secret.Protect("cisco");
            Store.Hosts.Add(b);
        }

        public static void AddTemplates()
        {
            Add("Wifi-Hotspot", L.T("sampleWifi"), 0, "wifi",
                "description {{description}}\nswitchport mode trunk\nswitchport trunk allowed vlan {{vlan}}\nspanning-tree portfast trunk\nno shutdown",
                new[] { "description", "Wifi-Hotspot", "vlan", "2" }, false);
            Add("Office PC", L.T("sampleOffice"), 1, "computer",
                "description {{description}}\nswitchport mode access\nswitchport access vlan {{vlan}}\nspanning-tree portfast\nspanning-tree bpduguard enable\nno shutdown",
                new[] { "description", "Office-PC", "vlan", "10" }, true);
            Add("IP Phone + PC", L.T("samplePhone"), 2, "call",
                "description {{description}}\nswitchport mode access\nswitchport access vlan {{data_vlan}}\nswitchport voice vlan {{voice_vlan}}\nspanning-tree portfast\nno shutdown",
                new[] { "description", "Phone-PC", "data_vlan", "10", "voice_vlan", "20" }, true);
            Add("Printer", L.T("samplePrinter"), 3, "print",
                "description Printer {{port}}\nswitchport mode access\nswitchport access vlan {{vlan}}\nspanning-tree portfast\nno shutdown",
                new[] { "vlan", "30" }, true);
            Add("Unused port", L.T("sampleUnused"), 7, "power_off",
                "! Parks the port in an unused VLAN and shuts it down\ndescription Unused\nswitchport mode access\nswitchport access vlan {{vlan}}\nshutdown",
                new[] { "vlan", "999" }, true);
        }

        private static void Add(string name, string desc, int color, string icon, string body, string[] defaults, bool reset)
        {
            Template t = new Template();
            t.Name = name;
            t.Description = desc;
            t.Color = color;
            t.Icon = icon;
            t.Body = body;
            t.ResetFirst = reset;
            for (int i = 0; i + 1 < defaults.Length; i += 2) t.Defaults[defaults[i]] = defaults[i + 1];
            Store.Templates.Add(t);
        }
    }
}
'@,
@'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal static class SelfTest
    {
        private static int failed, passed;

        private static void Ok(bool cond, string name)
        {
            if (cond) passed++;
            else { failed++; Console.WriteLine("FAIL " + name); }
        }

        private static void Eq(object a, object b, string name)
        {
            bool same = Equals(a, b) || (a != null && b != null && a.ToString() == b.ToString());
            if (!same) Console.WriteLine("     expected [" + b + "] got [" + a + "]");
            Ok(same, name);
        }

        public static int SshTest(int port)
        {
            string home = Path.Combine(Path.GetTempPath(), "switchdeck-sshtest-" + Guid.NewGuid().ToString("N").Substring(0, 8));
            Program.Root = home;
            Store.Settings = new Settings();
            Store.Settings.SessionLogs = true;
            L.Lang = "en";
            try
            {
                Host h = new Host();
                h.Name = "ssh-lab";
                h.Kind = "ssh";
                h.Address = "127.0.0.1";
                h.Port = port;
                h.Username = "admin";
                h.Password = Secret.Protect("lab123");
                h.Enable = Secret.Protect("cisco");
                h.Legacy = true;
                Console.WriteLine("args: " + Ssh.Arguments(h));
                h.Legacy = false;
                int prompts = 0;
                Session s = new Session(h, 120, 30);
                s.HostKeyPrompt += delegate(string fp) { prompts++; Console.WriteLine("host key prompt: " + fp); s.AnswerHostKey(true); };
                s.Notice += delegate(string n) { Console.WriteLine("notice: " + n); };
                DateTime t0 = DateTime.Now;
                s.Start();
                try { s.WaitReady(60000); }
                catch
                {
                    Console.WriteLine("SCREEN [" + s.Term.Text(s.Term.FirstAbs, s.Term.EndAbs).TrimEnd() + "]");
                    Console.WriteLine("cursor line [" + s.CursorLine + "] col " + s.Term.CursorCol + " state " + s.State + " open " + s.IsOpen);
                    throw;
                }
                Console.WriteLine("ready in " + (int)(DateTime.Now - t0).TotalMilliseconds + " ms, prompt [" + s.CursorLine + "]");
                Ok(prompts == 1, "ssh host key asked once");
                Ok(s.CursorLine.EndsWith("#"), "ssh auto enable");
                List<PortStatus> found = Deployer.Detect(s);
                Eq(found.Count, 56, "ssh detect");
                foreach (PortStatus p in found) h.Ports.Add(new PortInfo(p.Port, p.Name));
                Template t = new Template();
                t.Name = "Office";
                t.Body = "description {{d}}\nswitchport mode access\nswitchport access vlan 10\nno shutdown";
                Dictionary<string, string> v = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                v["d"] = "Desk over ssh";
                DeployPlan plan = DeployPlan.FromTemplate(h, t, v, Ports.Expand("Gi1/0/30-36, Gi1/0/40", null), "range");
                plan.Check = true; plan.Verify = true; plan.Backup = true; plan.Reset = true;
                Deployer d = new Deployer(s, plan);
                d.Run();
                Console.WriteLine("deploy: " + d.Entry.Overall + " " + d.Entry.Summary);
                foreach (PortResult r in d.Entry.Results) if (r.Status != "ok") Console.WriteLine("  " + r.Port + " " + r.Status + " " + r.Message);
                Eq(d.Entry.Overall, "ok", "ssh deploy");
                string big = s.Run("show running-config", 30000);
                Ok(big.Contains("interface GigabitEthernet1/0/30") && big.Contains("Desk over ssh"), "ssh long output");
                s.Disconnect();
                Thread.Sleep(500);
                Session s2 = new Session(h, 120, 30);
                int prompts2 = 0;
                s2.HostKeyPrompt += delegate(string fp) { prompts2++; s2.AnswerHostKey(true); };
                s2.Start();
                s2.WaitReady(60000);
                Ok(prompts2 == 0, "ssh known host remembered");
                s2.Dispose();
                Host bad = h.Clone();
                bad.Password = Secret.Protect("wrong");
                Session s3 = new Session(bad, 120, 30);
                bool rejected = false;
                s3.Notice += delegate(string n) { if (n == "password-rejected") rejected = true; };
                s3.Start();
                DateTime end = DateTime.Now.AddSeconds(25);
                while (!rejected && DateTime.Now < end) Thread.Sleep(100);
                Ok(rejected, "ssh wrong password noticed");
                Console.WriteLine("tail: " + s3.Term.Text(s3.Term.CursorAbs - 3, s3.Term.CursorAbs + 1).Replace("\n", " | "));
                s3.Dispose();
            }
            catch (Exception ex)
            {
                failed++;
                Console.WriteLine("CRASH " + ex);
            }
            Console.WriteLine("passed " + passed + ", failed " + failed);
            return failed == 0 ? 0 : 1;
        }

        public static int Run()
        {
            string home = Path.Combine(Path.GetTempPath(), "switchdeck-selftest-" + Guid.NewGuid().ToString("N").Substring(0, 8));
            Program.Root = home;
            Store.Settings = new Settings();
            Store.Settings.SessionLogs = false;
            L.Lang = "en";
            try
            {
                TestPorts();
                TestCisco();
                TestVt();
                TestDemo();
                TestJson();
                TestDeploy();
                TestStack();
                TestInstall();
            }
            catch (Exception ex)
            {
                failed++;
                Console.WriteLine("CRASH " + ex);
            }
            Console.WriteLine("passed " + passed + ", failed " + failed);
            try { Directory.Delete(home, true); } catch { }
            return failed == 0 ? 0 : 1;
        }

        private static void TestPorts()
        {
            List<string> err = new List<string>();
            List<string> p = Ports.Expand("Gi1/0/1-4, Te1/1/1, 6, gigabitethernet2/0/10 - 11, po1, Fa0", err);
            Eq(string.Join(" ", p.ToArray()), "Gi1/0/1 Gi1/0/2 Gi1/0/3 Gi1/0/4 Te1/1/1 Te1/1/6 Gi2/0/10 Gi2/0/11 Po1 Fa0", "expand");
            Eq(err.Count, 0, "expand errors");
            Ports.Expand("Gi1/0/9-3, Zz1, Gi1/0/1-Te1/0/4", err);
            Eq(err.Count, 3, "expand bad");
            Eq(Ports.Expand("Gi1/0/1-4, 6-7", null).Count, 6, "prefix shorthand");
            Eq(Ports.Expand("Gi1/0/1-4, 6-7", null)[5], "Gi1/0/7", "prefix shorthand name");
            Eq(Ports.Normalize("TenGigabitEthernet1/1/2"), "Te1/1/2", "normalize long");
            Eq(Ports.Normalize("g1/0/3"), "Gi1/0/3", "normalize short");
            Eq(Ports.Normalize("Twe1/1/1"), "Twe1/1/1", "twe");
            Eq(Ports.Normalize("t1/1/1"), null, "ambiguous t");
            List<string> names = new List<string>();
            foreach (int i in new[] { 1, 2, 3, 5, 7, 8, 9, 11, 13, 15, 17 }) names.Add("Gi1/0/" + i);
            List<string> cmds = Ports.RangeCommands(names);
            Eq(cmds.Count, 2, "range chunks");
            Eq(cmds[0], "Gi1/0/1 - 3 , Gi1/0/5 , Gi1/0/7 - 9 , Gi1/0/11 , Gi1/0/13", "range text");
            Eq(Ports.Compact(new[] { "Gi1/0/2", "Gi1/0/1", "Te1/1/1", "Gi1/0/3" }), "Gi1/0/1-3, Te1/1/1", "compact");
            Eq(string.Join(",", Ports.Sorted(new[] { "Te1/1/1", "Gi2/0/1", "Gi1/0/10", "Gi1/0/2" }).ToArray()), "Gi1/0/2,Gi1/0/10,Te1/1/1,Gi2/0/1", "sort");
            Ok(Ports.IsVirtual("Vl10") && Ports.IsVirtual("Vlan1") && Ports.IsVirtual("Lo0") && !Ports.IsVirtual("Gi1/0/1") && !Ports.IsVirtual("Po1"), "virtual");
        }

        private static void TestCisco()
        {
            string status = "\nPort         Name               Status       Vlan       Duplex  Speed Type\n" +
                "Gi1/0/1      AP-Hall-01         connected    trunk      a-full a-1000 10/100/1000BaseTX\n" +
                "Gi1/0/2                         notconnect   1            auto   auto 10/100/1000BaseTX\n" +
                "Gi1/0/3      Desk with spaces   err-disabled 10           auto   auto 10/100/1000BaseTX\n" +
                "Te1/1/1                         notconnect   1            full    10G Not Present\n" +
                "Vl1                             connected    routed       auto   auto\n" +
                "Po1          Uplink             connected    trunk      a-full a-10G \n";
            List<PortStatus> l = Cisco.ParseStatus(status);
            Eq(l.Count, 5, "status count");
            Eq(l[0].Name, "AP-Hall-01", "status desc");
            Eq(l[0].Vlan, "trunk", "status vlan");
            Eq(l[2].Name, "Desk with spaces", "status spaces");
            Eq(l[2].Status, "err-disabled", "status err");
            Eq(l[4].Port, "Po1", "status po");
            Ok(Cisco.IsPrompt("SW-CORE-01#") && Cisco.IsPrompt("sw1(config-if-range)#") && Cisco.IsPrompt("Switch>") && !Cisco.IsPrompt("Password:"), "prompt");
            Eq(Cisco.Mode("sw1(config-if)#"), "config-if", "mode");
            Ok(Cisco.IsError("% Invalid input detected at '^' marker."), "error");
            List<string> vars = Cisco.Variables("description {{description}}\nswitchport access vlan {{ vlan }}\ndescription {{port}} {{vlan}}");
            Eq(string.Join(",", vars.ToArray()), "description,vlan", "variables");
            Dictionary<string, string> vals = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            vals["vlan"] = "20";
            Eq(Cisco.Render("switchport access vlan {{vlan}} {{port}}", vals, "Gi1/0/1"), "switchport access vlan 20 Gi1/0/1", "render");
            string body = Cisco.InterfaceBody("Building configuration...\n\nCurrent configuration : 105 bytes\n!\ninterface GigabitEthernet1/0/1\n description AP\n switchport mode trunk\nend\n");
            Eq(body, "description AP\nswitchport mode trunk", "interface body");
            Eq(Cisco.CheckApplied(new List<string> { "description AP", "switchport mode trunk", "no shutdown" }, body), null, "check ok");
            Ok(Cisco.CheckApplied(new List<string> { "switchport mode access" }, body) != null, "check missing");
        }

        private static void TestVt()
        {
            Vt vt = new Vt(20, 5);
            vt.Feed("hello\r\nworld");
            Eq(vt.LineText(vt.FirstAbs), "hello", "vt line");
            Eq(vt.CursorLineText(), "world", "vt cursor line");
            vt.Feed("\x1b[1;1Hxy\x1b[K");
            Eq(vt.LineText(vt.FirstAbs), "xy", "vt cup erase");
            vt.Feed("\x1b[5;1H" + new string('a', 25));
            Eq(vt.Text(vt.CursorAbs - 1, vt.CursorAbs + 1).TrimEnd('\n'), new string('a', 25), "vt wrap join");
            for (int i = 0; i < 30; i++) vt.Feed("\r\nline" + i);
            Ok(vt.EndAbs - vt.FirstAbs > 20, "vt scrollback");
            Eq(vt.CursorLineText(), "line29", "vt scrolled");
            vt.Feed("\x1b[31mred\x1b[0m");
            TermLine tl = vt.LineAt(vt.CursorAbs);
            Eq(tl.Cells[6].Fg, (byte)1, "vt sgr");
            vt.Feed("\b\b\b   \b\b\b");
            Eq(vt.CursorLineText(), "line29", "vt backspace");
            vt.Resize(40, 8);
            Eq(vt.CursorLineText(), "line29", "vt resize keeps cursor line");
        }

        private static void TestStack()
        {
            Session s = DemoSession("C9200L-48P-4X-STACK");
            List<PortStatus> found = Deployer.Detect(s);
            Eq(found.Count, 104, "stack detect");
            Ok(found.Exists(delegate(PortStatus p) { return p.Port == "Gi2/0/48"; }) && found.Exists(delegate(PortStatus p) { return p.Port == "Te2/1/4"; }), "stack member 2 ports");
            string v = s.Run("show version", 10000);
            Ok(v.Contains("C9200L-48P-4X") && !v.Contains("4X-STACK") && v.Contains("     2 "), "stack show version");
            Template t = new Template();
            t.Name = "x";
            t.Body = "description Stack test\nswitchport access vlan 10";
            DeployPlan plan = DeployPlan.FromTemplate(s.Host, t, null, Ports.Expand("Gi1/0/1-3, Gi2/0/1-3, Gi2/0/10", null), "range");
            plan.Verify = true;
            Deployer d = new Deployer(s, plan);
            d.Run();
            Eq(d.Entry.Overall, "ok", "stack range deploy");
            s.Dispose();
            Session one = DemoSession("C9200L-48P-4X");
            Eq(Deployer.Detect(one).Count, 52, "9200L single detect");
            one.Dispose();
        }

        private static void TestInstall()
        {
            string dir = Path.Combine(Program.Root, "install-test");
            Directory.CreateDirectory(dir);
            string ico = Path.Combine(dir, "t.ico");
            Install.WriteIcon(ico);
            using (Icon i = new Icon(ico, 48, 48)) Eq(i.Width, 48, "ico 48");
            Program.Script = @"C:\Test Folder\app\SwitchDeck.ps1";
            Program.AppRoot = @"C:\Test Folder";
            string lnk = Path.Combine(dir, "t.lnk");
            typeof(Install).GetMethod("Create", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static).Invoke(null, new object[] { lnk, Program.Script, Program.AppRoot });
            Ok(File.Exists(lnk), "shortcut created");
            Type t = Type.GetTypeFromProgID("WScript.Shell");
            object shell = Activator.CreateInstance(t);
            object sc = t.InvokeMember("CreateShortcut", System.Reflection.BindingFlags.InvokeMethod, null, shell, new object[] { lnk });
            string target = (string)sc.GetType().InvokeMember("TargetPath", System.Reflection.BindingFlags.GetProperty, null, sc, null);
            string args = (string)sc.GetType().InvokeMember("Arguments", System.Reflection.BindingFlags.GetProperty, null, sc, null);
            Ok(target.ToLowerInvariant().EndsWith("conhost.exe") && args.Contains("--headless") && args.Contains("SwitchDeck.ps1"), "shortcut target");
        }

        private static void TestDemo()
        {
            DemoSwitch d = new DemoSwitch("t1", "C9300-48P", "cisco");
            d.BootSilently();
            string o = d.RunScript("conf t\rint range gi1/0/5 - 8 , gi1/0/10\rsw mo acc\rswitchport access vlan 30\rdesc Test port\rshut\rend\rterm len 0\rsh run int gi1/0/6\r");
            Ok(o.Contains(" switchport access vlan 30") && o.Contains(" description Test port") && o.Contains(" shutdown"), "demo range config");
            o = d.RunScript("conf t\rint gi1/0/6\rno shut\rno desc\rend\rsh run int gi1/0/6\r");
            Ok(!o.Contains(" shutdown") && !o.Contains("description"), "demo negation");
            o = d.RunScript("conf t\rint gi1/0/6\rswitchport mode trunkk\rend\r");
            Ok(o.Contains("% Invalid input"), "demo invalid");
            o = d.RunScript("conf t\rint gi1/0/6\rsw\rend\r");
            Ok(!o.Contains("%"), "demo bare switchport");
            o = d.RunScript("sh int status\r");
            Eq(Cisco.ParseStatus(o).Count, 56, "demo status ports");
            o = d.RunScript("conf t\rint range gi1/0/1-2,gi1/0/4,gi1/0/6,gi1/0/8,gi1/0/10,gi1/0/12\rend\r");
            Ok(o.Contains("Command rejected"), "demo range limit");
            o = d.RunScript("conf t\rint gi1/0/20\rswitchport trunk allowed vlan 2,4-6\rswitchport trunk allowed vlan add 10\rswitchport trunk allowed vlan remove 5\rdo sh run int gi1/0/20\rend\r");
            Ok(o.Contains("switchport trunk allowed vlan 2,4,6,10"), "demo allowed vlan");
            d = new DemoSwitch("t2", "WS-C2960X-24PS-L", "");
            d.BootSilently();
            o = d.RunScript("term len 0\rsh int status\r");
            List<PortStatus> l = Cisco.ParseStatus(o);
            Eq(l.Count, 29, "2960 status ports");
            Ok(l.Exists(delegate(PortStatus s) { return s.Port == "Fa0"; }), "2960 Fa0");
        }

        private static void TestJson()
        {
            Host h = new Host();
            h.Name = "a\"b\\c\nd";
            h.Ports.Add(new PortInfo("Gi1/0/1", "é desc"));
            Host back = Host.FromJson(Json.ParseObj(Json.Write(h.ToJson())));
            Eq(back.Name, h.Name, "json escape");
            Eq(back.Ports[0].Description, "é desc", "json unicode");
            Template t = new Template();
            t.Defaults["vlan"] = "2";
            Eq(Template.FromJson(Json.ParseObj(Json.Write(t.ToJson()))).Defaults["vlan"], "2", "json dict");
        }

        private static Session DemoSession(string model)
        {
            Host h = new Host();
            h.Name = "Test " + model;
            h.Kind = "demo";
            h.DemoModel = model;
            h.Enable = Secret.Protect("cisco");
            Session s = new Session(h, 100, 30);
            s.Start();
            s.WaitReady(15000);
            return s;
        }

        private static void TestDeploy()
        {
            Session s = DemoSession("C9300-48P");
            Ok(s.CursorLine.EndsWith("#"), "auto enable");
            List<PortStatus> found = Deployer.Detect(s);
            Eq(found.Count, 56, "detect count");
            Host h = s.Host;
            foreach (PortStatus p in found) h.Ports.Add(new PortInfo(p.Port, p.Name));

            Template t = new Template();
            t.Name = "Wifi-Hotspot";
            t.Body = "description {{description}}\nswitchport mode trunk\nswitchport trunk allowed vlan {{vlan}}\nspanning-tree portfast trunk\nno shutdown";
            Dictionary<string, string> v = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            v["description"] = "Wifi AP";
            v["vlan"] = "2";
            List<string> ports = Ports.Expand("Gi1/0/3-9, Gi1/0/11, Gi1/0/13, Gi1/0/15, Gi1/0/17, Gi1/0/47", null);
            DeployPlan plan = DeployPlan.FromTemplate(h, t, v, ports, "range");
            plan.Backup = true; plan.Check = true; plan.Verify = true; plan.WriteMemory = true;
            Deployer d = new Deployer(s, plan);
            d.Run();
            Eq(d.Entry.Overall, "ok", "range deploy overall");
            Eq(d.Entry.Count("ok"), 12, "range deploy count");
            Ok(d.Entry.WroteMemory, "write memory");
            Ok(File.Exists(d.Entry.Backup), "backup file");
            PortResult r47 = d.Entry.Results.Find(delegate(PortResult r) { return r.Port == "Gi1/0/47"; });
            Ok(r47.Before.Contains("shutdown") && !r47.After.Contains("\nshutdown") && r47.After.Contains("allowed vlan 2"), "before after captured");
            foreach (string line in Cisco.SplitLines(d.Entry.Transcript)) if (line.Contains("interface range")) { Ok(line.Contains(" , "), "range syntax sent"); break; }

            Template pr = new Template();
            pr.Name = "Printer";
            pr.Body = "description Printer {{port}}\nswitchport access vlan 30\nswitchport mode access\nswitchport trunk allowed vlan 99999";
            DeployPlan plan2 = DeployPlan.FromTemplate(h, pr, v, new[] { "Gi1/0/20", "Gi1/0/21" }, "single");
            plan2.Reset = true; plan2.Verify = true;
            Deployer d2 = new Deployer(s, plan2);
            d2.Run();
            Eq(d2.Entry.Count("failed"), 2, "single deploy catches invalid line");
            Ok(d2.Entry.Results[0].Message.Contains("99999"), "single deploy error message");
            Ok(d2.Entry.Results[0].After.Contains("description Printer Gi1/0/20"), "port variable rendered");

            DeployPlan back = Deployer.RollbackPlan(d.Entry, h);
            Deployer d3 = new Deployer(s, back);
            d3.Run();
            Eq(d3.Entry.Overall, "ok", "rollback overall");
            PortResult b47 = d3.Entry.Results.Find(delegate(PortResult r) { return r.Port == "Gi1/0/47"; });
            Ok(b47.After.Contains("shutdown") && b47.After.Contains("vlan 999"), "rollback restored");

            s.BeginBusy("x");
            s.RequestStop();
            bool stopped = false;
            try { s.Run("show version", 5000); } catch (StopException) { stopped = true; }
            s.EndBusy();
            Ok(stopped, "stop request");
            s.Dispose();

            Session s2 = DemoSession("WS-C2960X-24PS-L");
            Ok(s2.CursorLine.EndsWith("#") || s2.CursorLine.EndsWith(">"), "2960 prompt");
            s2.Host.Enable = "";
            List<PortStatus> f2 = Deployer.Detect(s2);
            Eq(f2.Count, 29, "2960 detect");
            string o = s2.Run("show running-config", 20000);
            Ok(o.Contains("hostname SW-FLOOR2") && o.Trim().EndsWith("end"), "long output through pager");
            s2.Dispose();
        }
    }

    internal static class DevRender
    {
        [DllImport("user32.dll")] private static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);

        public static void Run(string dir, List<string> args)
        {
            Directory.CreateDirectory(dir);
            Program.Rendering = true;
            try { Application.EnableVisualStyles(); } catch { }
            Application.SetCompatibleTextRenderingDefault(false);
            string[] themes = args.Contains("--dark-only") ? new[] { "dark" } : args.Contains("--light-only") ? new[] { "light" } : new[] { "light", "dark" };
            string[] langs = args.Contains("--fr") ? new[] { "en", "fr" } : new[] { "en" };
            int w = 1320, h = 840;
            int wi = args.IndexOf("--size");
            if (wi >= 0 && wi + 2 < args.Count) { w = int.Parse(args[wi + 1]); h = int.Parse(args[wi + 2]); }
            Store.Settings.WindowW = w;
            Store.Settings.WindowH = h;
            Store.Settings.Maximized = false;
            MainForm f = new MainForm(0);
            f.StartPosition = FormStartPosition.Manual;
            f.Location = new Point(-32000 + 10, 10);
            f.ShowInTaskbar = false;
            f.Show();
            f.Size = new Size(Ui.D(w), Ui.D(h));
            Pump(300);
            Host lab = Store.Hosts.Count > 0 ? Store.Hosts[0] : null;
            if (lab != null && args.Contains("--live"))
            {
                f.Switches.Connect(lab);
                WaitFor(delegate { Session s = Sessions.For(lab.Id); return s != null && s.State == SessionState.Connected && s.AtPrompt; }, 15000);
                Pump(800);
                if (args.Contains("--perf"))
                {
                    TerminalView tv = FindTerm(f);
                    Session ps = Sessions.For(lab.Id);
                    System.Diagnostics.Stopwatch sw = System.Diagnostics.Stopwatch.StartNew();
                    for (int i = 0; i < 20; i++) ps.UserSend("show interfaces status\r");
                    Pump(1500);
                    System.Reflection.MethodInfo op = typeof(TerminalView).GetMethod("OnPaint", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
                    using (Bitmap bmp = new Bitmap(tv.Width, tv.Height))
                    using (Graphics gg = Graphics.FromImage(bmp))
                    {
                        sw.Restart();
                        for (int i = 0; i < 30; i++) op.Invoke(tv, new object[] { new PaintEventArgs(gg, new Rectangle(0, 0, tv.Width, tv.Height)) });
                    }
                    Console.WriteLine("TERM size " + tv.Width + "x" + tv.Height + " cols " + ps.Term.Cols + " rows " + ps.Term.Rows);
                    Console.WriteLine("PAINT avg ms " + (sw.ElapsedMilliseconds / 30.0));
                    long start = ps.Term.CursorAbs;
                    sw.Restart();
                    for (int i = 0; i < 60; i++)
                    {
                        Key(tv, 0x0D);
                        DateTime until = DateTime.Now.AddMilliseconds(33);
                        while (DateTime.Now < until) { Application.DoEvents(); Thread.Sleep(1); }
                    }
                    long sentAt = sw.ElapsedMilliseconds;
                    long lagEnd = sentAt;
                    while (ps.Term.CursorAbs - start < 60 && sw.ElapsedMilliseconds < sentAt + 10000) { Application.DoEvents(); Thread.Sleep(1); lagEnd = sw.ElapsedMilliseconds; }
                    Console.WriteLine("ENTER x60 sent in " + sentAt + " ms, all prompts after " + lagEnd + " ms, lines " + (ps.Term.CursorAbs - start));
                }
                if (args.Contains("--typing"))
                {
                    TerminalView tv = FindTerm(f);
                    if (tv != null)
                    {
                        Type("sh vlan br\r", tv);
                        Pump(800);
                        Type("conf t\rint gi1/0/2", tv);
                        Key(tv, 0x09);
                        Type("?", tv);
                        Pump(400);
                        Type("\rdesc Typed by keys\rend\rsh run int gi1/0/2\r", tv);
                        Pump(1200);
                        Shot(f, Path.Combine(dir, "typing.png"));
                        Session ts = Sessions.For(lab.Id);
                        Console.WriteLine("TYPING " + (ts.Term.Text(ts.Term.FirstAbs, ts.Term.EndAbs).Contains("description Typed by keys") ? "OK" : "FAIL"));
                    }
                    else Console.WriteLine("TYPING no terminal");
                }
                if (args.Contains("--scenario"))
                {
                    Session ses = Sessions.For(lab.Id);
                    List<PortStatus> found = null;
                    Thread t = new Thread(delegate() { try { found = Deployer.Detect(ses); } catch (Exception ex) { Log.Error("render detect: " + ex.Message); } });
                    t.Start();
                    while (t.IsAlive) Pump(50);
                    if (found != null)
                    {
                        lab.Ports.Clear();
                        foreach (PortStatus st in found) lab.Ports.Add(new PortInfo(st.Port, st.Name));
                        lab.PortsAsked = true;
                        Store.ReplaceHost(lab);
                    }
                    ses.Run("show version", 5000);
                    Template wifi = Store.Templates.Find(delegate(Template x) { return x.Name == "Wifi-Hotspot"; });
                    f.Deploy.Prepare(lab, Ports.Expand("Gi1/0/3-9, Gi1/0/11-12, Gi1/0/47", null), wifi == null ? null : wifi.Id);
                    f.SelectTab(1);
                    Pump(300);
                    Shot(f, Path.Combine(dir, "scenario-deploy-1-setup.png"));
                    f.Deploy.ShowPortsStep();
                    Pump(300);
                    Shot(f, Path.Combine(dir, "scenario-deploy-2-ports.png"));
                    f.Deploy.Prepare(lab, new List<string>(), null);
                    f.Deploy.ShowPortsStep();
                    Pump(200);
                    foreach (Control c in AllControls(f))
                    {
                        Btn b = c as Btn;
                        if (b == null || b.Text != L.T("all") || !b.Visible) continue;
                        Point center = b.PointToScreen(new Point(b.Width / 2, b.Height / 2));
                        Control top = f.GetChildAtPoint(f.PointToClient(center), GetChildAtPointSkip.Invisible);
                        Control deepest = top;
                        while (deepest != null)
                        {
                            Control next = deepest.GetChildAtPoint(deepest.PointToClient(center), GetChildAtPointSkip.Invisible);
                            if (next == null) break;
                            deepest = next;
                        }
                        typeof(Control).GetMethod("OnClick", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance).Invoke(b, new object[] { EventArgs.Empty });
                        Pump(200);
                        Console.WriteLine("AFTER CLICK subtitle: " + ((Card)b.Parent).Subtitle);
                        Point local = new Point(b.Width / 2, b.Height / 2);
                        SendMessage(b.Handle, 0x201, (IntPtr)1, (IntPtr)((local.Y << 16) | local.X));
                        SendMessage(b.Handle, 0x202, IntPtr.Zero, (IntPtr)((local.Y << 16) | local.X));
                        Pump(200);
                        Console.WriteLine("AFTER MOUSE subtitle: " + ((Card)b.Parent).Subtitle);
                        Console.WriteLine("ALLBTN bounds " + b.Bounds + " parent " + b.Parent.GetType().Name + " hit " + (deepest == null ? "null" : deepest.GetType().Name + " " + deepest.Bounds + " text " + deepest.Text));
                    }
                    f.Deploy.DeployOrStop();
                    Pump(700);
                    Shot(f, Path.Combine(dir, "scenario-deploy-running.png"));
                    WaitFor(delegate { return DeployPage.Run != null && DeployPage.Run.Done; }, 60000);
                    Pump(600);
                    f.SelectTab(0);
                    f.Switches.ShowSessionFor(lab.Id);
                    Pump(400);
                }
            }
            foreach (string theme in themes)
            {
                foreach (string lang in langs)
                {
                    L.Lang = lang;
                    Store.Settings.Language = lang;
                    Theme.Apply(theme, "dark");
                    Pump(200);
                    f.Rebuild();
                    Pump(300);
                    string prefix = Path.Combine(dir, theme + "-" + lang + "-");
                    for (int t = 0; t < 5; t++)
                    {
                        f.SelectTab(t);
                        Pump(350);
                        Shot(f, prefix + t + "-" + new[] { "switches", "deploy", "templates", "settings", "about" }[t] + ".png");
                    }
                    if (lab != null)
                    {
                        f.SelectTab(0);
                        f.Switches.SelectHost(lab.Id);
                        Pump(300);
                        Shot(f, prefix + "0b-overview.png");
                    }
                }
            }
            if (args.Contains("--dialogs"))
            {
                foreach (string theme in themes)
                {
                    Theme.Apply(theme, "dark");
                    L.Lang = "en";
                    f.Rebuild();
                    Pump(200);
                    DialogShot(f, new HostDialog(lab), Path.Combine(dir, theme + "-dlg-host.png"));
                    DialogShot(f, new HostDialog(null), Path.Combine(dir, theme + "-dlg-host-new.png"));
                    if (lab != null) DialogShot(f, new ChoiceForm(lab), Path.Combine(dir, theme + "-dlg-choice.png"));
                    DialogShot(f, new MessageForm("Deploy now?", "Wifi-Hotspot will be applied to 12 ports on Lab Core 9300:\nGi1/0/3-9, Gi1/0/11\n\nSwitchDeck will type 24 commands.", "rocket_launch", Theme.P.Orange, Theme.P.OrangeSoft, false, "Deploy on 12 ports", "Cancel", false), Path.Combine(dir, theme + "-dlg-confirm.png"));
                    StringBuilder cmds = new StringBuilder();
                    cmds.AppendLine("configure terminal");
                    for (int i = 1; i <= 20; i++) { cmds.AppendLine("interface Gi1/0/" + i); cmds.AppendLine(" description Wifi-Hotspot"); cmds.AppendLine(" switchport mode trunk"); cmds.AppendLine(" exit"); }
                    DialogShot(f, new CommandsForm(cmds.ToString().Replace("\r", "")), Path.Combine(dir, theme + "-dlg-commands.png"));
                    DialogShot(f, new WelcomeForm(), Path.Combine(dir, theme + "-dlg-welcome.png"));
                    Host stack = Store.Hosts.Find(delegate(Host x) { return x.DemoModel.EndsWith("-STACK"); });
                    if (stack != null)
                    {
                        stack.Ports.Clear();
                        foreach (DemoIf di in DemoSwitch.Factory(stack.DemoModel).Ifs) stack.Ports.Add(new PortInfo(di.Name, ""));
                        f.SelectTab(1);
                        f.Deploy.Prepare(stack, Ports.Expand("Gi1/0/1-6, Gi2/0/10-14", null), null);
                        f.Deploy.ShowPortsStep();
                        Pump(300);
                        Shot(f, Path.Combine(dir, theme + "-stack-ports.png"));
                    }
                    DialogShot(f, new MessageForm("Could not read the ports", "The switch did not show its prompt in time.", null, Color.Empty, Color.Empty, true, "OK", null, false), Path.Combine(dir, theme + "-dlg-problem.png"));
                }
            }
            Sessions.CloseAll();
            f.Close();
            f.Dispose();
        }

        [DllImport("user32.dll")] private static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, IntPtr l);

        private static List<Control> AllControls(Control c)
        {
            List<Control> r = new List<Control>();
            foreach (Control k in c.Controls) { r.Add(k); r.AddRange(AllControls(k)); }
            return r;
        }

        private static TerminalView FindTerm(Control c)
        {
            foreach (Control k in c.Controls)
            {
                if (k is TerminalView) return (TerminalView)k;
                TerminalView t = FindTerm(k);
                if (t != null) return t;
            }
            return null;
        }

        private static void Type(string text, TerminalView tv)
        {
            foreach (char ch in text)
            {
                if (ch == '\r') { Key(tv, 0x0D); continue; }
                SendMessage(tv.Handle, 0x102, (IntPtr)ch, IntPtr.Zero);
                Pump(15);
            }
        }

        private static void Key(TerminalView tv, int vk)
        {
            tv.Focus();
            Message m = Message.Create(tv.Handle, 0x100, (IntPtr)vk, IntPtr.Zero);
            if (!tv.PreProcessMessage(ref m)) SendMessage(tv.Handle, 0x100, (IntPtr)vk, IntPtr.Zero);
            Pump(30);
        }

        private static void DialogShot(Form owner, Form d, string path)
        {
            d.StartPosition = FormStartPosition.Manual;
            d.Location = new Point(-32000 + 10, 10);
            d.ShowInTaskbar = false;
            d.Show(owner);
            Pump(500);
            d.Refresh();
            using (Bitmap b = new Bitmap(d.Width, d.Height))
            {
                d.DrawToBitmap(b, new Rectangle(0, 0, d.Width, d.Height));
                b.Save(path, ImageFormat.Png);
            }
            d.Close();
            d.Dispose();
        }

        public static void Pump(int ms)
        {
            DateTime end = DateTime.Now.AddMilliseconds(ms);
            while (DateTime.Now < end)
            {
                Application.DoEvents();
                Thread.Sleep(15);
            }
        }

        public static void WaitFor(Func<bool> cond, int ms)
        {
            DateTime end = DateTime.Now.AddMilliseconds(ms);
            while (DateTime.Now < end && !cond()) Pump(50);
        }

        public static void Shot(Form f, string path)
        {
            f.Refresh();
            Pump(120);
            f.Refresh();
            using (Bitmap b = new Bitmap(f.Width, f.Height))
            {
                using (Graphics g = Graphics.FromImage(b))
                {
                    IntPtr hdc = g.GetHdc();
                    bool ok = PrintWindow(f.Handle, hdc, 2);
                    g.ReleaseHdc(hdc);
                    if (!ok) f.DrawToBitmap(b, new Rectangle(0, 0, f.Width, f.Height));
                }
                b.Save(path, ImageFormat.Png);
            }
        }
    }
}
'@,
@'
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

namespace SwitchDeck
{
    internal enum SessionState { Connecting, Connected, Closed }

    internal sealed class StopException : Exception
    {
        public StopException() : base(L.T("stopped")) { }
    }

    internal sealed class Session : IDisposable
    {
        private static readonly Regex Ansi = new Regex(@"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b[()][0-9A-Za-z]|\x1b[=>78DEMc]", RegexOptions.Compiled);
        private static readonly Regex HostKeyRx = new Regex(@"continue connecting \(yes/no(/\[fingerprint\])?\)\?\s*$", RegexOptions.Compiled);
        private static readonly Regex PasswordRx = new Regex(@"(?i)(password|passcode)\s*:\s*$", RegexOptions.Compiled);
        private static readonly Regex UserRx = new Regex(@"(?i)(username|login)\s*:\s*$", RegexOptions.Compiled);

        public readonly Host Host;
        public readonly Vt Term;
        private ITransport transport;
        private readonly Decoder decoder = Encoding.UTF8.GetDecoder();
        private readonly StringBuilder tail = new StringBuilder();
        private DateTime lastData = DateTime.Now;
        private int passwordsSent, enableSent, usersSent;
        private bool hostKeyAsked, enableTried, keyChanged;
        private bool prepared;
        private volatile bool busy;
        private volatile bool stopRequested;
        private StreamWriter logWriter;
        private readonly object logGate = new object();
        private readonly StringBuilder transcript = new StringBuilder();
        private bool capture;

        public SessionState State = SessionState.Connecting;
        public string Hostname = "";
        public string CloseReason;
        public string Status = "";
        public DateTime Started = DateTime.Now;

        public event Action Changed;
        public event Action<string> HostKeyPrompt;
        public event Action<string> Notice;

        public Session(Host host, int cols, int rows)
        {
            Host = host;
            Term = new Vt(cols, rows);
            Term.Reply += delegate(string s) { RawSend(s); };
        }

        public bool Busy { get { return busy; } }

        private string EnableSecret
        {
            get
            {
                string e = Secret.Reveal(Host.Enable);
                return e.Length > 0 ? e : Secret.Reveal(Host.Password);
            }
        }
        public bool IsOpen { get { return transport != null && transport.IsOpen; } }
        public bool HostKeyChanged { get { return keyChanged; } }

        public void Start()
        {
            ITransport old = transport;
            transport = null;
            if (old != null)
            {
                old.Data -= OnData;
                old.Closed -= OnClosed;
                try { old.Dispose(); } catch { }
            }
            State = SessionState.Connecting;
            CloseReason = null;
            passwordsSent = enableSent = usersSent = 0;
            hostKeyAsked = enableTried = keyChanged = prepared = false;
            Started = DateTime.Now;
            OpenLog();
            Banner(L.F("connectingTo", Host.Name, Host.Target));
            try
            {
                if (Host.Kind == "serial") transport = new SerialTransport(Host.ComPort, Host.Baud);
                else if (Host.Kind == "demo") transport = new DemoTransport(new DemoSwitch(Host.Id, Host.DemoModel, EnableSecret));
                else
                {
                    string exe = Ssh.Exe;
                    if (exe == null) throw new InvalidOperationException(L.T("noSsh"));
                    if (Host.Address.Trim().Length == 0) throw new InvalidOperationException(L.T("noAddress"));
                    transport = new ConPtyTransport(exe, Ssh.Arguments(Host));
                }
                transport.Data += OnData;
                transport.Closed += OnClosed;
                transport.Start(Term.Cols, Term.Rows);
                if (Host.Kind == "serial")
                {
                    State = SessionState.Connected;
                    Thread.Sleep(200);
                    RawSend("\r");
                }
                Log.Info("Session opened: " + Host.Name + " (" + Host.Kind + " " + Host.Target + ")");
            }
            catch (Exception ex)
            {
                Log.Error("Could not connect to " + Host.Name + ": " + ex.Message);
                CloseReason = ex.Message;
                State = SessionState.Closed;
                Banner(L.F("connectFailed", ex.Message));
                if (transport != null) { try { transport.Dispose(); } catch { } transport = null; }
            }
            Raise();
        }

        private void Banner(string text)
        {
            Term.Feed("\x1b[0m\r\n\x1b[38;5;208m" + text + "\x1b[0m\r\n");
            Raise();
        }

        private void OpenLog()
        {
            lock (logGate)
            {
                CloseLog();
                if (!Store.Settings.SessionLogs) return;
                try
                {
                    string dir = Path.Combine(Program.LogsDir, "sessions");
                    Directory.CreateDirectory(dir);
                    string file = Path.Combine(dir, Store.SafeName(Host.Name) + "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".log");
                    logWriter = new StreamWriter(file, true, new UTF8Encoding(false));
                    logWriter.AutoFlush = true;
                    logWriter.WriteLine("# " + Host.Name + " " + Host.Target + " " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
                }
                catch (Exception ex) { Log.Warn("Session log: " + ex.Message); logWriter = null; }
            }
        }

        private void CloseLog()
        {
            if (logWriter != null)
            {
                try { logWriter.Dispose(); } catch { }
                logWriter = null;
            }
        }

        private void OnData(byte[] buf, int n)
        {
            char[] chars = new char[decoder.GetCharCount(buf, 0, n)];
            decoder.GetChars(buf, 0, n, chars, 0);
            string s = new string(chars);
            lastData = DateTime.Now;
            Term.Feed(s);
            string plain = Ansi.Replace(s, "");
            lock (logGate)
            {
                if (logWriter != null)
                {
                    try { logWriter.Write(plain.Replace("\r\n", "\n").Replace("\r", "").Replace("\n", Environment.NewLine)); } catch { }
                }
                if (capture && transcript.Length < 400000) transcript.Append(plain.Replace("\r", ""));
            }
            tail.Append(plain);
            if (tail.Length > 600) tail.Remove(0, tail.Length - 600);
            Watch();
            Raise();
        }

        private long answeredAbs = -1;

        private void Watch()
        {
            string t = tail.ToString();
            long curAbs = Term.CursorAbs;
            string lastLine = Term.CursorLineText();
            if (t.Contains("REMOTE HOST IDENTIFICATION HAS CHANGED") && !keyChanged)
            {
                keyChanged = true;
                Action<string> nt = Notice;
                if (nt != null) nt("hostkey-changed");
            }
            if (Host.Kind == "ssh" && !hostKeyAsked && (HostKeyRx.IsMatch(lastLine) || HostKeyRx.IsMatch(t.TrimEnd())))
            {
                hostKeyAsked = true;
                answeredAbs = curAbs;
                string fp = "";
                Match m = Regex.Match(t, @"key fingerprint is (\S+?)\.?\s");
                if (m.Success) fp = m.Groups[1].Value;
                Match kt = Regex.Match(t, @"(\S+) key fingerprint is");
                if (kt.Success) fp = kt.Groups[1].Value + " " + fp;
                Action<string> h = HostKeyPrompt;
                if (h != null) ThreadPool.QueueUserWorkItem(delegate { h(fp); });
                else RawSend("no\r");
                return;
            }
            bool fresh = curAbs != answeredAbs;
            if (fresh && UserRx.IsMatch(lastLine) && lastLine.Length < 40 && usersSent < 2 && Host.Username.Length > 0 && Host.Kind != "ssh")
            {
                answeredAbs = curAbs;
                usersSent++;
                RawSend(Host.Username + "\r");
                return;
            }
            if (fresh && PasswordRx.IsMatch(lastLine) && lastLine.Length < 80)
            {
                answeredAbs = curAbs;
                bool enablePrompt = enableTried && State == SessionState.Connected;
                if (enablePrompt)
                {
                    if (enableSent == 0 && !busy)
                    {
                        enableSent++;
                        RawSend(EnableSecret + "\r");
                    }
                    return;
                }
                string pw = Secret.Reveal(Host.Password);
                if (passwordsSent == 0 && pw.Length > 0)
                {
                    passwordsSent++;
                    RawSend(pw + "\r");
                    return;
                }
                if (passwordsSent == 1)
                {
                    passwordsSent++;
                    Action<string> nt = Notice;
                    if (nt != null) nt("password-rejected");
                }
                return;
            }
            string trimmed = lastLine.TrimEnd();
            if (Cisco.IsPrompt(trimmed))
            {
                if (State != SessionState.Connected)
                {
                    State = SessionState.Connected;
                    Host.LastConnected = DateTime.Now;
                }
                Hostname = Cisco.Hostname(trimmed);
                if (trimmed.EndsWith(">") && !enableTried && EnableSecret.Length > 0 && !busy)
                {
                    enableTried = true;
                    RawSend("enable\r");
                }
                else if (trimmed.EndsWith("#") && !enableTried) enableTried = true;
            }
        }

        private void ClearTail() { tail.Length = 0; }

        public void AnswerHostKey(bool trust)
        {
            RawSend(trust ? "yes\r" : "no\r");
        }

        private void OnClosed(string reason)
        {
            State = SessionState.Closed;
            CloseReason = reason;
            Banner(reason == null ? L.T("connectionClosed") : L.F("connectionClosedWhy", reason));
            lock (logGate) CloseLog();
            Log.Info("Session closed: " + Host.Name + (reason == null ? "" : " (" + reason + ")"));
            Raise();
        }

        private void Raise()
        {
            Action c = Changed;
            if (c != null) c();
        }

        public void RawSend(string s)
        {
            ITransport t = transport;
            if (t == null || !t.IsOpen) return;
            t.Write(Encoding.UTF8.GetBytes(s));
        }

        public void UserSend(string s)
        {
            if (busy) return;
            RawSend(s);
        }

        public void Resize(int cols, int rows)
        {
            Term.Resize(cols, rows);
            ITransport t = transport;
            if (t != null) t.Resize(cols, rows);
        }

        public void SendBreak()
        {
            ITransport t = transport;
            if (t != null) t.SendBreak();
        }

        public void Disconnect()
        {
            ITransport t = transport;
            transport = null;
            if (t != null)
            {
                try { t.Dispose(); } catch { }
            }
            if (State != SessionState.Closed)
            {
                State = SessionState.Closed;
                Banner(L.T("connectionClosed"));
                lock (logGate) CloseLog();
            }
            Raise();
        }

        public void Reconnect()
        {
            Disconnect();
            Start();
        }

        public void Dispose()
        {
            ITransport t = transport;
            transport = null;
            if (t != null) { try { t.Dispose(); } catch { } }
            lock (logGate) CloseLog();
        }

        public void BeginBusy(string status)
        {
            busy = true;
            stopRequested = false;
            Status = status;
            Raise();
        }

        public void EndBusy()
        {
            busy = false;
            Status = "";
            Raise();
        }

        public void SetStatus(string status)
        {
            Status = status;
            Raise();
        }

        public void RequestStop() { stopRequested = true; }
        public bool StopRequested { get { return stopRequested; } }

        public void BeginTranscript()
        {
            lock (logGate) { transcript.Length = 0; capture = true; }
        }

        public string EndTranscript()
        {
            lock (logGate)
            {
                capture = false;
                string r = transcript.ToString();
                transcript.Length = 0;
                return r;
            }
        }

        private void Check()
        {
            if (stopRequested) throw new StopException();
            if (State == SessionState.Connecting && (DateTime.Now - Started).TotalSeconds < 120) return;
            if (!IsOpen) throw new InvalidOperationException(State == SessionState.Closed && CloseReason != null ? CloseReason : L.T("notConnected"));
        }

        public string CursorLine { get { return Term.CursorLineText().TrimEnd(); } }

        public bool AtPrompt
        {
            get
            {
                string l = CursorLine;
                return Cisco.IsPrompt(l) && Term.CursorCol >= l.Length;
            }
        }

        public void WaitReady(int timeoutMs)
        {
            DateTime end = DateTime.Now.AddMilliseconds(timeoutMs);
            bool nudged = false;
            while (true)
            {
                Check();
                if (State == SessionState.Connected && AtPrompt && (DateTime.Now - lastData).TotalMilliseconds > 250)
                {
                    if (!CursorLine.EndsWith(">") || EnableSecret.Length == 0 || enableSent > 0 || (DateTime.Now - lastData).TotalMilliseconds > 2500)
                        return;
                }
                if (!nudged && State == SessionState.Connected && (DateTime.Now - lastData).TotalMilliseconds > 1500 && !AtPrompt)
                {
                    nudged = true;
                    RawSend("\r");
                }
                if (DateTime.Now > end) throw new TimeoutException(L.T("noPrompt"));
                Thread.Sleep(40);
            }
        }

        public void Prepare()
        {
            if (prepared) return;
            Run("terminal length 0", 8000);
            Run("terminal width 512", 8000);
            prepared = true;
        }

        public void EnsureEnable()
        {
            string l = CursorLine;
            if (l.EndsWith("#")) return;
            string secret = EnableSecret;
            long start = Term.CursorAbs;
            RawSend("enable\r");
            DateTime end = DateTime.Now.AddSeconds(10);
            bool sent = false;
            while (DateTime.Now < end)
            {
                Check();
                Thread.Sleep(50);
                string cur = CursorLine;
                if (PasswordRx.IsMatch(cur) && !sent)
                {
                    if (secret.Length == 0) { RawSend("\x03"); throw new InvalidOperationException(L.T("needEnable")); }
                    sent = true;
                    enableSent++;
                    RawSend(secret + "\r");
                    continue;
                }
                if (Term.CursorAbs > start && AtPrompt && (DateTime.Now - lastData).TotalMilliseconds > 150)
                {
                    if (CursorLine.EndsWith("#")) return;
                    throw new InvalidOperationException(L.T("enableRejected"));
                }
            }
            throw new TimeoutException(L.T("noPrompt"));
        }

        public string Run(string command, int timeoutMs)
        {
            return Run(command, timeoutMs, false);
        }

        public string Run(string command, int timeoutMs, bool confirm)
        {
            Check();
            long start = Term.CursorAbs;
            int delay = Store.Settings.LineDelay;
            if (delay > 0) Thread.Sleep(delay);
            RawSend(command + "\r");
            DateTime end = DateTime.Now.AddMilliseconds(timeoutMs);
            DateTime sentAt = DateTime.Now;
            while (true)
            {
                Thread.Sleep(25);
                Check();
                string cur = CursorLine;
                double idle = (DateTime.Now - lastData).TotalMilliseconds;
                if (cur.EndsWith("--More--") || cur.Trim() == "--More--")
                {
                    RawSend(" ");
                    continue;
                }
                if (confirm && idle > 250 && (cur.EndsWith("[confirm]") || cur.EndsWith("]?") || cur.EndsWith("[yes/no]:")))
                {
                    RawSend(cur.EndsWith("[yes/no]:") ? "yes\r" : "\r");
                    end = DateTime.Now.AddMilliseconds(timeoutMs);
                    continue;
                }
                if (Term.CursorAbs > start && AtPrompt && idle > 120 && (DateTime.Now - sentAt).TotalMilliseconds > 60)
                {
                    long stop = Term.CursorAbs;
                    string text = Term.Text(start, stop);
                    List<string> lines = Cisco.SplitLines(text);
                    int skip = 0;
                    for (int i = 0; i < lines.Count; i++)
                    {
                        if (lines[i].Contains(command.Length > 20 ? command.Substring(0, 20) : command)) { skip = i + 1; break; }
                    }
                    StringBuilder sb = new StringBuilder();
                    for (int i = skip; i < lines.Count; i++)
                    {
                        string l = lines[i].Replace("--More--", "").TrimEnd();
                        sb.Append(l).Append('\n');
                    }
                    return sb.ToString().TrimEnd('\n');
                }
                if (DateTime.Now > end) throw new TimeoutException(L.F("timeoutOn", command));
            }
        }
    }
}
'@,
@'
using System;
using System.Collections.Generic;
using System.Threading;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal static class Sessions
    {
        public static readonly List<Session> All = new List<Session>();
        public static readonly Dictionary<string, Dictionary<string, PortStatus>> StatusCache = new Dictionary<string, Dictionary<string, PortStatus>>();
        public static readonly Dictionary<string, DateTime> StatusTime = new Dictionary<string, DateTime>();
        public static event Action ListChanged;
        public static event Action<Session> StateChanged;

        public static int OpenCount
        {
            get
            {
                int n = 0;
                foreach (Session s in All) if (s.State != SessionState.Closed) n++;
                return n;
            }
        }

        public static Session For(string hostId)
        {
            foreach (Session s in All) if (s.Host.Id == hostId) return s;
            return null;
        }

        public static Session Open(Host host, int cols, int rows)
        {
            Session existing = For(host.Id);
            if (existing != null)
            {
                if (existing.State == SessionState.Closed) StartAsync(existing);
                return existing;
            }
            Session s = new Session(host, cols, rows);
            SessionState last = SessionState.Connecting;
            s.Changed += delegate
            {
                if (s.State != last)
                {
                    last = s.State;
                    Action<Session> h = StateChanged;
                    if (h != null) Post(delegate { h(s); });
                }
            };
            SwitchesPage.WireSession(s);
            All.Add(s);
            Raise();
            StartAsync(s);
            return s;
        }

        public static void StartAsync(Session s)
        {
            if (s.State == SessionState.Closed)
            {
                s.State = SessionState.Connecting;
                s.Started = DateTime.Now;
            }
            Thread t = new Thread(delegate()
            {
                try
                {
                    s.Start();
                }
                catch (Exception ex) { Log.Error("Session start: " + ex); }
            });
            t.IsBackground = true;
            t.Start();
        }

        public static void Close(Session s)
        {
            s.Disconnect();
            s.Dispose();
            All.Remove(s);
            Raise();
        }

        public static void CloseAll()
        {
            foreach (Session s in All.ToArray())
            {
                try { s.Dispose(); } catch { }
            }
            All.Clear();
        }

        private static void Raise()
        {
            Action h = ListChanged;
            if (h != null) h();
        }

        public static void Post(Action a)
        {
            MainForm f = MainForm.Instance;
            if (f == null || f.IsDisposed || !f.IsHandleCreated) return;
            try { f.BeginInvoke(a); } catch { }
        }

        public static void SaveStatus(string hostId, List<PortStatus> list)
        {
            Dictionary<string, PortStatus> d = new Dictionary<string, PortStatus>(StringComparer.OrdinalIgnoreCase);
            foreach (PortStatus p in list) d[p.Port] = p;
            StatusCache[hostId] = d;
            StatusTime[hostId] = DateTime.Now;
        }

        public static Dictionary<string, PortStatus> StatusOf(string hostId)
        {
            Dictionary<string, PortStatus> d;
            return StatusCache.TryGetValue(hostId, out d) ? d : new Dictionary<string, PortStatus>(StringComparer.OrdinalIgnoreCase);
        }
    }
}
'@,
@'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal sealed class SettingsPage : Pane, IPage
    {
        private readonly MainForm main;
        private readonly ScrollPanel scroll;
        private readonly List<Card> cards = new List<Card>();
        private readonly List<List<Row>> rows = new List<List<Row>>();

        private sealed class Row
        {
            public string Title, Hint;
            public Control Control;
            public Label TitleLabel, HintLabel;
        }

        public SettingsPage(MainForm main)
        {
            this.main = main;
            BackColor = Theme.P.Bg;
            scroll = new ScrollPanel();
            scroll.BackColor = Theme.P.Bg;
            Controls.Add(scroll);
            Settings s = Store.Settings;

            Card look = AddCard(L.T("setAppearance"), "palette");
            Segmented lang = new Segmented(new[] { "English", "Français" }, s.Language == "fr" ? 1 : 0);
            lang.Changed += delegate { string v = lang.SelectedIndex == 1 ? "fr" : "en"; BeginInvoke((Action)delegate { s.Language = v; L.Lang = v; Store.SaveSettings(); main.Rebuild(); main.SelectTab(3); }); };
            AddRow(look, L.T("language"), null, lang);
            string[] modes = { "light", "system", "dark" };
            Segmented theme = new Segmented(new[] { L.T("light"), L.T("system"), L.T("dark") }, new[] { "light_mode", "computer", "dark_mode" }, Array.IndexOf(modes, s.Theme));
            theme.Changed += delegate { string v = modes[theme.SelectedIndex]; BeginInvoke((Action)delegate { s.Theme = v; Store.SaveSettings(); Theme.Apply(v, s.TermTheme); }); };
            AddRow(look, L.T("theme"), null, theme);
            string[] tmodes = { "dark", "light", "theme" };
            Segmented tt = new Segmented(new[] { L.T("dark"), L.T("light"), L.T("followTheme") }, Math.Max(0, Array.IndexOf(tmodes, s.TermTheme)));
            tt.Changed += delegate { string v = tmodes[tt.SelectedIndex]; BeginInvoke((Action)delegate { s.TermTheme = v; Store.SaveSettings(); Theme.Apply(s.Theme, v); }); };
            AddRow(look, L.T("termColors"), L.T("termColorsHint"), tt);
            float[] sizes = { 12, 13, 14, 16, 18 };
            int si = Array.IndexOf(sizes, s.TermFontSize);
            Segmented ts = new Segmented(new[] { "12", "13", "14", "16", "18" }, si < 0 ? 2 : si);
            ts.Changed += delegate { s.TermFontSize = sizes[ts.SelectedIndex]; Store.SaveSettings(); main.Switches.ApplyTermFont(); };
            AddRow(look, L.T("termSize"), L.T("termSizeHint"), ts);

            Card term = AddCard(L.T("setTerminal"), "terminal");
            AddToggle(term, L.T("copyOnSelect"), L.T("copyOnSelectHint"), s.CopyOnSelect, delegate(bool v) { s.CopyOnSelect = v; });
            AddToggle(term, L.T("rightPaste"), L.T("rightPasteHint"), s.RightClickPaste, delegate(bool v) { s.RightClickPaste = v; });

            Card dep = AddCard(L.T("setDeploy"), "rocket_launch");
            Segmented dm = new Segmented(new[] { L.T("modeRange"), L.T("modeSingle") }, s.DefaultMode == "single" ? 1 : 0);
            dm.Changed += delegate { s.DefaultMode = dm.SelectedIndex == 1 ? "single" : "range"; Store.SaveSettings(); };
            AddRow(dep, L.T("defaultMode"), L.T("defaultModeHint"), dm);
            AddToggle(dep, L.T("confirmDeploy"), L.T("confirmDeployHint"), s.ConfirmDeploy, delegate(bool v) { s.ConfirmDeploy = v; });
            AddToggle(dep, L.T("optWrite"), L.T("optWriteTip"), s.WriteMemory, delegate(bool v) { s.WriteMemory = v; });
            int[] delays = { 0, 50, 150, 300 };
            int di = Array.IndexOf(delays, s.LineDelay);
            Segmented dl = new Segmented(new[] { L.T("none"), "50 ms", "150 ms", "300 ms" }, di < 0 ? 0 : di);
            dl.Changed += delegate { s.LineDelay = delays[dl.SelectedIndex]; Store.SaveSettings(); };
            AddRow(dep, L.T("lineDelay"), L.T("lineDelayHint"), dl);

            Card pc = AddCard(L.T("setShortcuts"), "computer");
            Toggle tDesk = new Toggle(Install.HasDesktop);
            tDesk.Changed += delegate { ApplyShortcuts(tDesk.Checked, null); };
            AddRow(pc, L.T("shortcutDesktop"), null, tDesk);
            Toggle tStart = new Toggle(Install.HasStartMenu);
            tStart.Changed += delegate { ApplyShortcuts(null, tStart.Checked); };
            AddRow(pc, L.T("shortcutStart"), null, tStart);
            Btn un = new Btn(L.T("uninstall"), "delete", BtnKind.Danger, delegate
            {
                if (!Dialogs.Ask(main, L.T("uninstallTitle"), Install.UninstallText(), L.T("uninstall"), L.T("cancel"), "delete", true)) return;
                Program.Uninstalling = true;
                main.Close();
            }).Small();
            AddRow(pc, L.T("uninstallRow"), L.T("uninstallRowHint"), un);

            Card folders = AddCard(L.T("setFolders"), "folder_open");
            Pane btns = new Pane();
            btns.BackColor = Theme.P.Surface;
            string[] names = { L.T("logsFolder"), L.T("dataFolder") };
            string[] paths = { Program.LogsDir, Program.DataDir };
            int x = 0;
            for (int i = 0; i < names.Length; i++)
            {
                string path = paths[i];
                Btn b = new Btn(names[i], "folder_open", BtnKind.Secondary, delegate { MainForm.OpenFolder(path); }).Small();
                b.Location = new Point(x, 0);
                btns.Controls.Add(b);
                x = b.Right + Ui.D(8);
            }
            btns.Size = new Size(x, Ui.D(34));
            folders.Controls.Add(btns);
            rows[rows.Count - 1].Add(new Row { Control = btns });
            Lay();
        }

        private int D(float v) { return Ui.D(v); }

        private void ApplyShortcuts(bool? desktop, bool? startMenu)
        {
            try
            {
                Install.Set(desktop ?? Install.HasDesktop, startMenu ?? Install.HasStartMenu);
                main.Notify(L.T("saved"), "ok");
            }
            catch (Exception ex) { Dialogs.Problem(main, L.T("oops"), ex.Message); }
        }

        public void Shown() { }

        private Card AddCard(string title, string icon)
        {
            Card c = new Card();
            c.Title = title;
            c.Icon = icon;
            scroll.Content.Controls.Add(c);
            cards.Add(c);
            rows.Add(new List<Row>());
            return c;
        }

        private void AddRow(Card card, string title, string hint, Control control)
        {
            Row r = new Row { Title = title, Hint = hint, Control = control };
            r.TitleLabel = Ui.Label(title, Fonts.Strong(14f * Ui.Sc), Theme.P.Text);
            card.Controls.Add(r.TitleLabel);
            if (hint != null)
            {
                r.HintLabel = Ui.Label(hint, Fonts.Body(12.5f * Ui.Sc), Theme.P.Muted);
                card.Controls.Add(r.HintLabel);
            }
            card.Controls.Add(control);
            rows[cards.IndexOf(card)].Add(r);
        }

        private void AddToggle(Card card, string title, string hint, bool value, Action<bool> set)
        {
            Toggle t = new Toggle(value);
            t.Changed += delegate { set(t.Checked); Store.SaveSettings(); };
            AddRow(card, title, hint, t);
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            Lay();
        }

        private void Lay()
        {
            if (scroll == null) return;
            scroll.Bounds = new Rectangle(0, 0, Width, Height);
            int maxW = D(860);
            int w = Math.Min(maxW, Width - D(48) - D(12));
            int x = Math.Max(D(24), (Width - D(12) - w) / 2);
            int y = D(24);
            for (int c = 0; c < cards.Count; c++)
            {
                Card card = cards[c];
                int ry = card.HeaderHeight;
                card.Dividers.Clear();
                card.Bounds = new Rectangle(x, y, w, D(100));
                for (int i = 0; i < rows[c].Count; i++)
                {
                    Row r = rows[c][i];
                    if (r.TitleLabel == null)
                    {
                        r.Control.Location = new Point(D(20), ry);
                        ry += r.Control.Height + D(20);
                        continue;
                    }
                    int ctlW = r.Control.Width;
                    int textW = w - D(60) - ctlW;
                    int hintH = r.HintLabel != null ? Ui.WrapHeight(r.Hint, r.HintLabel.Font, Math.Max(D(80), textW)) : 0;
                    int h = Math.Max(D(56), D(20) + r.TitleLabel.PreferredHeight + (hintH > 0 ? hintH + D(4) : 0) + D(18));
                    if (i > 0) card.Dividers.Add(ry);
                    if (r.HintLabel != null)
                    {
                        int block = r.TitleLabel.PreferredHeight + D(4) + hintH;
                        int ty = ry + (h - block) / 2;
                        r.TitleLabel.Location = new Point(D(20), ty);
                        r.HintLabel.MaximumSize = new Size(Math.Max(D(80), textW), 0);
                        r.HintLabel.Location = new Point(D(20), ty + r.TitleLabel.PreferredHeight + D(4));
                    }
                    else r.TitleLabel.Location = new Point(D(20), ry + (h - r.TitleLabel.PreferredHeight) / 2);
                    r.Control.Location = new Point(w - D(20) - ctlW, ry + (h - r.Control.Height) / 2);
                    ry += h;
                }
                card.Height = ry + D(6);
                y = card.Bottom + D(18);
            }
            scroll.SetContentHeight(y + D(6));
        }
    }

    internal sealed class AboutPage : Pane, IPage
    {
        public AboutPage()
        {
            BackColor = Theme.P.Bg;
        }

        public void Shown() { }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            Graphics g = e.Graphics;
            Palette p = Theme.P;
            Icons.Smooth(g);
            int w = Width;
            int cardW = Math.Min(Ui.D(560), w - Ui.D(48));
            int textW = cardW - Ui.D(80);
            int aboutH = Ui.WrapHeight(L.T("about"), Fonts.Body(15f * Ui.Sc), textW);
            int featH = 0;
            string[] feats = { L.T("feat1"), L.T("feat2"), L.T("feat3"), L.T("feat4") };
            foreach (string f in feats) featH += Math.Max(Ui.D(28), Ui.WrapHeight(f, Fonts.Body(13.5f * Ui.Sc), textW - Ui.D(36)) + Ui.D(10));
            int total = Ui.D(96) + Ui.D(18) + Ui.D(34) + Ui.D(26) + Ui.D(20) + aboutH + Ui.D(26) + featH + Ui.D(30) + Ui.D(24);
            int y = Math.Max(Ui.D(28), (Height - total) / 2);
            using (Bitmap icon = Icons.App(Ui.D(96))) g.DrawImage(icon, (w - icon.Width) / 2, y);
            y += Ui.D(96) + Ui.D(18);
            Ui.Text(g, "SwitchDeck", Fonts.Head(26f * Ui.Sc), new Rectangle(0, y, w, Ui.D(34)), p.Text, Ui.Center);
            y += Ui.D(34);
            Ui.Text(g, L.F("version", Program.Version), Fonts.Body(13.5f * Ui.Sc), new Rectangle(0, y, w, Ui.D(22)), p.Muted, Ui.Center);
            y += Ui.D(26) + Ui.D(20);
            int tx = (w - textW) / 2;
            TextRenderer.DrawText(g, L.T("about"), Fonts.Body(15f * Ui.Sc), new Rectangle(tx, y, textW, aboutH + Ui.D(4)), p.Text, TextFormatFlags.HorizontalCenter | TextFormatFlags.WordBreak | TextFormatFlags.NoPadding);
            y += aboutH + Ui.D(26);
            string[] icons = { "dns", "terminal", "layers", "rocket_launch" };
            for (int i = 0; i < feats.Length; i++)
            {
                int fh = Math.Max(Ui.D(28), Ui.WrapHeight(feats[i], Fonts.Body(13.5f * Ui.Sc), textW - Ui.D(36)) + Ui.D(10));
                RectangleF ib = new RectangleF(tx, y + Ui.D(1), Ui.D(24), Ui.D(24));
                Ui.FillRound(g, ib, 7 * Ui.Sc, p.OrangeSoft);
                Icons.Draw(g, icons[i], ib, p.Orange, 16 * Ui.Sc, false);
                TextRenderer.DrawText(g, feats[i], Fonts.Body(13.5f * Ui.Sc), new Rectangle(tx + Ui.D(36), y + Ui.D(3), textW - Ui.D(36), fh), p.Muted, Ui.Wrap);
                y += fh;
            }
            y += Ui.D(30);
            Ui.Text(g, L.T("createdBy"), Fonts.Body(13f * Ui.Sc), new Rectangle(0, Math.Max(y, Height - Ui.D(40)), w, Ui.D(22)), p.Muted, Ui.Center);
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            Invalidate();
        }
    }
}
'@,
@'
using System;
using System.Drawing;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal sealed class SplashForm : Form
    {
        private readonly string text;
        private Bitmap logo;

        public SplashForm(string text)
        {
            this.text = text;
            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.CenterScreen;
            ShowInTaskbar = true;
            Text = "SwitchDeck";
            BackColor = Theme.Charcoal;
            DoubleBuffered = true;
            AutoScaleMode = AutoScaleMode.None;
            ClientSize = new Size(Ui.D(360), Ui.D(250));
            try { Icon = Icons.MakeIcon(Math.Max(32, Ui.D(32))); } catch { }
            logo = Icons.App(Ui.D(72));
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            try
            {
                int round = 2;
                Native.DwmSetWindowAttribute(Handle, 33, ref round, 4);
                int dark = 1;
                Native.DwmSetWindowAttribute(Handle, 20, ref dark, 4);
            }
            catch { }
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            Icons.Smooth(g);
            int w = ClientSize.Width;
            g.DrawImage(logo, (w - logo.Width) / 2, Ui.D(40));
            Ui.Text(g, "SwitchDeck", Fonts.Head(20f * Ui.Sc), new Rectangle(0, Ui.D(122), w, Ui.D(34)), Theme.OffWhite, Ui.Center);
            Ui.Text(g, text, Fonts.Body(13f * Ui.Sc), new Rectangle(0, Ui.D(158), w, Ui.D(22)), Theme.C(0xA3AAB1), Ui.Center);
            Font f = Fonts.Body(11.5f * Ui.Sc);
            string p = "Powered by Nova";
            int pw = Ui.Measure(p, f).Width, nw = Ui.D(18);
            int x = (w - pw - nw - Ui.D(6)) / 2, y = Ui.D(212);
            Icons.Nova(g, new RectangleF(x, y, nw, nw));
            Ui.Text(g, p, f, new Rectangle(x + nw + Ui.D(6), y, pw + Ui.D(4), nw), Theme.C(0x6F767E), Ui.Left);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing && logo != null) { logo.Dispose(); logo = null; }
            base.Dispose(disposing);
        }
    }
}
'@,
@'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal sealed class SwitchesPage : Pane, IPage
    {
        private readonly MainForm main;
        private readonly Pane side;
        private readonly TextField search;
        private readonly ItemList list;
        private readonly Btn addBtn;
        private readonly SessionStrip strip;
        private readonly Pane area;
        private Host selected;
        private Session active;
        private ScrollPanel overview;
        private Pane termPanel;
        private TerminalView term;
        private Pane toolbar, busyBar;
        private Label busyText;
        private Chip stateChip;
        private Label promptLabel;
        private Btn connBtn, moreBtn, stopBtn, quickBtn;
        private readonly System.Windows.Forms.Timer refresh;
        private readonly HashSet<Session> asked = new HashSet<Session>();

        public SwitchesPage(MainForm main)
        {
            this.main = main;
            Palette p = Theme.P;
            BackColor = p.Bg;
            side = new Pane();
            side.BackColor = p.Bg;
            Controls.Add(side);
            search = new TextField("", L.T("searchSwitches"), "search", false, false);
            search.Changed += delegate { Fill(); };
            side.Controls.Add(search);
            list = new ItemList();
            list.HeightOf = delegate(object o) { return D(58); };
            list.PaintItem = PaintHost;
            list.EmptyTitle = L.T("noSwitchesTitle");
            list.EmptyText = L.T("noSwitchesText");
            list.SelectionChanged += delegate { Host h = list.SelectedItem as Host; if (h != null) ShowHost(h); };
            list.Activated += delegate(object o) { Host h = o as Host; if (h != null) Connect(h); };
            list.ContextRequested += delegate(object o, Point pt) { if (o is Host) HostMenu((Host)o, list, pt); };
            side.Controls.Add(list);
            addBtn = new Btn(L.T("addSwitch"), "add", BtnKind.Primary, delegate { AddHost(); });
            side.Controls.Add(addBtn);

            strip = new SessionStrip();
            strip.Selected += delegate(Session s) { if (s == null) ShowOverview(); else ShowSession(s); };
            strip.CloseRequested += delegate(Session s) { CloseSession(s); };
            Controls.Add(strip);
            area = new Pane();
            area.BackColor = p.Bg;
            Controls.Add(area);

            Store.HostsChanged += OnHostsChanged;
            Sessions.ListChanged += OnSessionsChanged;
            Sessions.StateChanged += OnSessionState;
            refresh = new System.Windows.Forms.Timer();
            refresh.Interval = 250;
            refresh.Tick += delegate { RefreshSessionUi(); };
            refresh.Start();

            Fill();
            if (Store.Hosts.Count > 0) ShowHost(FirstHost());
            else ShowOverview();
            strip.SetSessions(Sessions.All, null);
        }

        public void Detach()
        {
            Store.HostsChanged -= OnHostsChanged;
            Sessions.ListChanged -= OnSessionsChanged;
            Sessions.StateChanged -= OnSessionState;
            refresh.Stop();
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) { Detach(); refresh.Dispose(); }
            base.Dispose(disposing);
        }

        private int D(float v) { return Ui.D(v); }

        public string SelectedHostId { get { return selected == null ? null : selected.Id; } }

        public string ActiveSessionHostId { get { return active == null ? null : active.Host.Id; } }

        public void ShowSessionFor(string hostId)
        {
            Session s = Sessions.For(hostId);
            if (s != null) { strip.SetSessions(Sessions.All, s); ShowSession(s); }
        }

        public void SelectHost(string id)
        {
            Host h = Store.FindHost(id);
            if (h != null) ShowHost(h);
        }

        public void Shown()
        {
            if (active != null && term != null) term.Focus();
        }

        private Host FirstHost()
        {
            foreach (object o in list.Items) if (o is Host) return (Host)o;
            return Store.Hosts.Count > 0 ? Store.Hosts[0] : null;
        }

        private void OnHostsChanged()
        {
            if (IsDisposed) return;
            if (selected != null) selected = Store.FindHost(selected.Id);
            Fill();
            if (active == null) ShowOverview();
        }

        private void OnSessionsChanged()
        {
            if (IsDisposed) return;
            strip.SetSessions(Sessions.All, active);
            list.Invalidate();
            main.Deploy.SessionsChanged();
        }

        private void OnSessionState(Session s)
        {
            if (IsDisposed) return;
            list.Invalidate();
            strip.Invalidate();
            if (s == active) UpdateToolbar();
            if (s.State == SessionState.Connected && !asked.Contains(s))
            {
                Host h = Store.FindHost(s.Host.Id);
                if (h != null && h.Ports.Count == 0 && !h.PortsAsked && !Program.Rendering)
                {
                    asked.Add(s);
                    BeginInvoke((Action)delegate { AskPorts(s); });
                }
            }
            main.Deploy.SessionsChanged();
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            Lay();
        }

        private void Lay()
        {
            if (side == null) return;
            int sw = D(300);
            int pad = D(18);
            side.Bounds = new Rectangle(0, 0, sw, Height);
            search.Bounds = new Rectangle(pad, pad, sw - pad - D(8), D(40));
            addBtn.Width = sw - pad - D(8);
            addBtn.Location = new Point(pad, Height - pad - addBtn.Height);
            list.Bounds = new Rectangle(pad - D(6), search.Bottom + D(12), sw - pad + D(4) - D(8), addBtn.Top - search.Bottom - D(24));
            int x = sw;
            strip.Bounds = new Rectangle(x, pad - D(2), Width - x - pad, D(44));
            area.Bounds = new Rectangle(x, strip.Bottom + D(10), Width - x - pad, Height - strip.Bottom - D(10) - pad);
            LayArea();
        }

        private void Fill()
        {
            string q = search.Text.Trim();
            List<object> items = new List<object>();
            List<Host> hosts = new List<Host>(Store.Hosts);
            hosts.Sort(delegate(Host a, Host b) { return string.Compare(a.Name, b.Name, StringComparison.CurrentCultureIgnoreCase); });
            foreach (Host h in hosts)
            {
                if (q.Length > 0 && h.Name.IndexOf(q, StringComparison.CurrentCultureIgnoreCase) < 0 && h.Address.IndexOf(q, StringComparison.OrdinalIgnoreCase) < 0) continue;
                items.Add(h);
            }
            list.EmptyTitle = q.Length > 0 ? L.T("noMatch") : L.T("noSwitchesTitle");
            list.EmptyText = q.Length > 0 ? null : L.T("noSwitchesText");
            list.SetItems(items, selected);
        }

        private void PaintHost(Graphics g, Rectangle r, object item, bool sel, bool hover)
        {
            Palette p = Theme.P;
            Host h = (Host)item;
            ItemList.Row(g, r, sel, hover);
            RectangleF ib = new RectangleF(r.X + D(16), r.Y + (r.Height - D(34)) / 2f, D(34), D(34));
            Ui.FillRound(g, ib, 9 * Ui.Sc, sel ? p.Surface : p.Surface2);
            if (!sel) Ui.StrokeRound(g, ib, 9 * Ui.Sc, p.Border, 1);
            Icons.Draw(g, KindIcon(h), ib, sel ? p.Orange : p.Muted, 19 * Ui.Sc, false);
            Session s = Sessions.For(h.Id);
            if (s != null)
            {
                Color dot = s.State == SessionState.Connected ? p.Success : s.State == SessionState.Connecting ? p.Warning : p.Faint;
                float d = 10 * Ui.Sc;
                RectangleF dr = new RectangleF(ib.Right - d + D(2), ib.Bottom - d + D(2), d, d);
                using (SolidBrush br = new SolidBrush(sel ? p.OrangeSoft : (hover ? p.HoverFill : p.Bg))) g.FillEllipse(br, RectangleF.Inflate(dr, 2 * Ui.Sc, 2 * Ui.Sc));
                using (SolidBrush br = new SolidBrush(dot)) g.FillEllipse(br, dr);
            }
            int tx = (int)ib.Right + D(12);
            Ui.Text(g, h.Name, Fonts.Strong(14f * Ui.Sc), new Rectangle(tx, r.Y + D(9), r.Right - tx - D(12), D(22)), p.Text, Ui.Left);
            Ui.Text(g, KindName(h) + "   " + (h.Kind == "demo" ? h.DemoModel : h.Target), Fonts.Body(12.5f * Ui.Sc), new Rectangle(tx, r.Y + D(30), r.Right - tx - D(12), D(20)), p.Muted, Ui.Left);
        }

        public static string KindName(Host h)
        {
            return h.Kind == "serial" ? L.T("kindSerial") : h.Kind == "demo" ? L.T("kindDemo") : "SSH";
        }

        public static string KindIcon(Host h)
        {
            return h.Kind == "serial" ? "usb" : h.Kind == "demo" ? "science" : "router";
        }

        private void ShowHost(Host h)
        {
            selected = h;
            list.SelectItem(h);
            active = null;
            strip.SetSessions(Sessions.All, null);
            ShowOverview();
        }

        private void ClearArea()
        {
            area.SuspendLayout();
            foreach (Control c in new List<Control>(ToList(area.Controls))) { area.Controls.Remove(c); c.Dispose(); }
            area.ResumeLayout();
            overview = null;
            termPanel = null;
            term = null;
            toolbar = busyBar = null;
        }

        private static IEnumerable<Control> ToList(Control.ControlCollection cc)
        {
            List<Control> l = new List<Control>();
            foreach (Control c in cc) l.Add(c);
            return l;
        }

        private void ShowOverview()
        {
            active = null;
            strip.Active = null;
            strip.Invalidate();
            ClearArea();
            overview = new ScrollPanel();
            overview.BackColor = Theme.P.Bg;
            area.Controls.Add(overview);
            BuildOverview();
            LayArea();
        }

        private void BuildOverview()
        {
            Palette p = Theme.P;
            Pane c = overview.Content;
            Host h = selected;
            if (h == null)
            {
                EmptyState es = new EmptyState(L.T("welcomeTitle"), L.T("welcomeText"), L.T("addSwitch"), "add", delegate { AddHost(); });
                es.Name = "empty";
                c.Controls.Add(es);
                return;
            }
            Card head = new Card();
            head.Name = "head";
            c.Controls.Add(head);
            Glyph gl = new Glyph(KindIcon(h), D(64), p.OrangeSoft, p.Orange);
            gl.Location = new Point(D(22), D(22));
            head.Controls.Add(gl);
            Label nm = Ui.Label(h.Name, Fonts.Head(22f * Ui.Sc), p.Text);
            nm.AutoSize = false;
            nm.AutoEllipsis = true;
            nm.Name = "name";
            nm.Bounds = new Rectangle(D(100), D(20), D(300), D(36));
            head.Controls.Add(nm);
            string info = KindName(h) + "   " + (h.Kind == "demo" ? h.DemoModel : h.Target) + (h.Kind != "demo" && h.Username.Length > 0 ? "   " + h.Username : "");
            Label sub = Ui.Label(info, Fonts.Body(14f * Ui.Sc), p.Muted);
            sub.AutoSize = false;
            sub.AutoEllipsis = true;
            sub.Name = "sub";
            sub.Bounds = new Rectangle(D(102), D(58), D(300), D(24));
            head.Controls.Add(sub);
            Session s = Sessions.For(h.Id);
            bool live = s != null && s.State != SessionState.Closed;
            Btn connect = new Btn(live ? L.T("openTerminal") : L.T("connect"), live ? "terminal" : "play_arrow", BtnKind.Primary, delegate { Connect(h); });
            connect.Name = "connect";
            Btn edit = new Btn(L.T("edit"), "edit", BtnKind.Secondary, delegate { EditHost(h); });
            edit.Name = "edit";
            Btn del = new Btn(null, "delete", BtnKind.Ghost, delegate { DeleteHost(h); });
            del.Name = "more";
            del.Tip = L.T("delete");
            head.Controls.Add(connect);
            head.Controls.Add(edit);
            head.Controls.Add(del);
        }

        private void LayArea()
        {
            if (area == null) return;
            if (overview != null)
            {
                overview.Bounds = new Rectangle(0, 0, area.Width, area.Height);
                Pane c = overview.Content;
                int w = area.Width - D(12);
                int y = 0;
                Control empty = c.Controls["empty"];
                if (empty != null)
                {
                    empty.Bounds = new Rectangle(0, 0, w, Math.Max(D(360), area.Height - D(4)));
                    overview.SetContentHeight(empty.Height);
                    return;
                }
                Card head = c.Controls["head"] as Card;
                if (head != null)
                {
                    head.Bounds = new Rectangle(0, y, w, D(108));
                    Control more = head.Controls["more"], edit = head.Controls["edit"], connect = head.Controls["connect"];
                    more.Location = new Point(head.Width - D(20) - more.Width, D(35));
                    edit.Location = new Point(more.Left - D(8) - edit.Width, D(35));
                    connect.Location = new Point(edit.Left - D(10) - connect.Width, D(35));
                    int tw = Math.Max(D(100), connect.Left - D(100) - D(16));
                    head.Controls["name"].Width = tw;
                    head.Controls["sub"].Width = tw;
                    y = head.Bottom + D(8);
                }
                overview.SetContentHeight(y);
            }
            if (termPanel != null)
            {
                termPanel.Bounds = new Rectangle(0, 0, area.Width, area.Height);
                int tb = D(56);
                toolbar.Bounds = new Rectangle(0, 0, termPanel.Width, tb);
                LayToolbar();
                int top = tb + D(10);
                if (busyBar.Visible)
                {
                    busyBar.Bounds = new Rectangle(0, top, termPanel.Width, D(48));
                    LayBusy();
                    top = busyBar.Bottom + D(10);
                }
                Control frame = termPanel.Controls["frame"];
                frame.Bounds = new Rectangle(0, top, termPanel.Width, termPanel.Height - top);
                term.Bounds = new Rectangle(D(2), D(2), frame.Width - D(4), frame.Height - D(4));
            }
        }

        private void LayToolbar()
        {
            if (toolbar == null) return;
            int h = toolbar.Height;
            stateChip.Location = new Point(D(16), (h - stateChip.Height) / 2);
            int x = toolbar.Width - D(12);
            foreach (Btn b in new[] { moreBtn, connBtn, quickBtn })
            {
                b.Location = new Point(x - b.Width, (h - b.Height) / 2);
                x = b.Left - D(6);
            }
            int lh = D(22);
            promptLabel.Bounds = new Rectangle(stateChip.Right + D(12), (h - lh) / 2, Math.Max(D(10), x - stateChip.Right - D(22)), lh);
        }

        private void LayBusy()
        {
            Control sp = busyBar.Controls["spin"];
            sp.Location = new Point(D(16), (busyBar.Height - sp.Height) / 2);
            stopBtn.Location = new Point(busyBar.Width - D(10) - stopBtn.Width, (busyBar.Height - stopBtn.Height) / 2);
            busyText.Bounds = new Rectangle(D(48), (busyBar.Height - D(22)) / 2, Math.Max(D(10), stopBtn.Left - D(60)), D(22));
        }

        private void ShowSession(Session s)
        {
            active = s;
            strip.Active = s;
            strip.Invalidate();
            selected = Store.FindHost(s.Host.Id) ?? s.Host;
            list.SelectItem(selected);
            ClearArea();
            Palette p = Theme.P;
            termPanel = new Pane();
            termPanel.BackColor = p.Bg;
            toolbar = new Card();
            stateChip = new Chip("", "circle", p.Surface2, p.Muted);
            toolbar.Controls.Add(stateChip);
            promptLabel = Ui.Label("", Fonts.Mono(13f * Ui.Sc), p.Muted);
            promptLabel.AutoSize = false;
            promptLabel.AutoEllipsis = true;
            promptLabel.TextAlign = ContentAlignment.MiddleLeft;
            toolbar.Controls.Add(promptLabel);
            connBtn = new Btn(L.T("disconnect"), "link_off", BtnKind.Secondary, delegate { ToggleConnection(); }).Small();
            moreBtn = new Btn(null, "more_vert", BtnKind.Ghost, null).Small();
            moreBtn.Click += delegate { TerminalMenu(); };
            quickBtn = new Btn(L.T("deploy"), "rocket_launch", BtnKind.Secondary, null).Small();
            quickBtn.Click += delegate { if (selected != null) { main.Deploy.Prepare(selected, null, null); main.SelectTab(1); } };
            toolbar.Controls.Add(quickBtn);
            toolbar.Controls.Add(connBtn);
            toolbar.Controls.Add(moreBtn);
            termPanel.Controls.Add(toolbar);

            busyBar = new Card();
            ((Card)busyBar).Fill = p.OrangeSoft;
            Spinner spin = new Spinner(D(22));
            spin.Name = "spin";
            busyBar.Controls.Add(spin);
            busyText = Ui.Label("", Fonts.Strong(13.5f * Ui.Sc), p.Text);
            busyText.AutoSize = false;
            busyText.AutoEllipsis = true;
            busyText.TextAlign = ContentAlignment.MiddleLeft;
            busyBar.Controls.Add(busyText);
            stopBtn = new Btn(L.T("stop"), "stop", BtnKind.Danger, delegate { if (active != null) active.RequestStop(); }).Small();
            busyBar.Controls.Add(stopBtn);
            busyBar.Visible = false;
            termPanel.Controls.Add(busyBar);

            TermFrame frame = new TermFrame();
            frame.Name = "frame";
            term = new TerminalView();
            term.FontChanged2 += delegate { };
            frame.Controls.Add(term);
            termPanel.Controls.Add(frame);
            area.Controls.Add(termPanel);
            term.Session = s;
            LayArea();
            UpdateToolbar();
            term.Focus();
        }

        private void RefreshSessionUi()
        {
            if (active == null || termPanel == null) return;
            UpdateToolbar();
        }

        private string lastToolbarKey;

        private void UpdateToolbar()
        {
            if (active == null || toolbar == null) return;
            Palette p = Theme.P;
            Session s = active;
            string key = s.State + "|" + s.Busy + "|" + s.Status + "|" + s.Hostname + "|" + s.CursorLine.Length;
            string prompt = s.State == SessionState.Connected ? s.CursorLine : "";
            string mode = Cisco.Mode(prompt);
            key += "|" + mode;
            if (key == lastToolbarKey) return;
            lastToolbarKey = key;
            if (s.State == SessionState.Connected)
            {
                stateChip.Back = p.SuccessSoft; stateChip.Fore = p.Success; stateChip.SetText(L.T("stateConnected"));
            }
            else if (s.State == SessionState.Connecting)
            {
                stateChip.Back = p.WarningSoft; stateChip.Fore = p.Warning; stateChip.SetText(L.T("stateConnecting"));
            }
            else
            {
                stateChip.Back = p.Surface2; stateChip.Fore = p.Muted; stateChip.SetText(L.T("stateClosed"));
            }
            string ml = mode == "user" ? L.T("modeUser") : mode == "enable" ? L.T("modeEnable") : mode.StartsWith("config") ? L.T("modeConfig") : "";
            promptLabel.Text = s.Hostname.Length > 0 ? s.Hostname + (ml.Length > 0 ? "   " + ml : "") : s.Host.Target;
            bool open = s.State != SessionState.Closed;
            connBtn.SetText(open ? L.T("disconnect") : L.T("reconnect"));
            connBtn.Icon = open ? "link_off" : "refresh";
            connBtn.Kind = open ? BtnKind.Secondary : BtnKind.Primary;
            quickBtn.Enabled = !s.Busy;
            bool busy = s.Busy;
            if (busyBar.Visible != busy)
            {
                busyBar.Visible = busy;
                LayArea();
            }
            if (busy) busyText.Text = L.T("typing") + "   " + s.Status;
            LayToolbar();
            toolbar.Invalidate();
        }

        private void ToggleConnection()
        {
            if (active == null) return;
            if (active.State == SessionState.Closed) Sessions.StartAsync(active);
            else active.Disconnect();
            UpdateToolbar();
            if (term != null) term.Focus();
        }

        public void ApplyTermFont()
        {
            if (term != null) term.SetFont();
        }

        private void TerminalMenu()
        {
            ContextMenuStrip m = ThemedMenu.Make();
            ThemedMenu.Item(m, L.T("copyAll"), "file_copy", delegate { term.CopyAll(); main.Notify(L.T("copied"), "ok"); });
            ThemedMenu.Item(m, L.T("paste"), "content_paste", delegate { term.Paste(); });
            ThemedMenu.Item(m, L.T("clearScreen"), "clear_all", delegate { active.Term.Clear(); });
            if (active.Host.Kind == "serial") ThemedMenu.Item(m, L.T("sendBreak"), "bolt", delegate { active.SendBreak(); });
            m.Items.Add(new ToolStripSeparator());
            ThemedMenu.Item(m, L.T("detectPorts"), "manage_search", delegate { DetectFor(selected); }).Enabled = active.State == SessionState.Connected && !active.Busy;
            ThemedMenu.Item(m, L.T("editSwitchShort"), "edit", delegate { EditHost(selected); });
            m.Items.Add(new ToolStripSeparator());
            ToolStripMenuItem close = ThemedMenu.Item(m, L.T("closeSession"), "close", delegate { CloseSession(active); });
            close.Tag = "danger";
            m.Show(moreBtn, new Point(moreBtn.Width - m.PreferredSize.Width, moreBtn.Height + D(4)));
        }

        private void CloseSession(Session s)
        {
            if (s == null) return;
            if (s.Busy)
            {
                main.Notify(L.T("busyWait"), "warn");
                return;
            }
            Sessions.Close(s);
            if (active == s) ShowOverview();
        }

        public void Connect(Host h)
        {
            if (h == null) return;
            Session s = Sessions.For(h.Id);
            if (s == null)
            {
                s = Sessions.Open(h, 120, 32);
            }
            else if (s.State == SessionState.Closed) Sessions.StartAsync(s);
            strip.SetSessions(Sessions.All, s);
            ShowSession(s);
        }

        public static void WireSession(Session s)
        {
            MainForm main = MainForm.Instance;
            s.HostKeyPrompt += delegate(string fp)
            {
                if (Program.Rendering) { s.AnswerHostKey(true); return; }
                Sessions.Post(delegate
                {
                    bool trust = Dialogs.Ask(main, L.T("hostKeyTitle"), L.F("hostKeyText", s.Host.Name, fp.Length > 0 ? fp : "?"), L.T("trust"), L.T("cancel"), "key", false);
                    s.AnswerHostKey(trust);
                });
            };
            s.Notice += delegate(string what)
            {
                Sessions.Post(delegate
                {
                    if (what == "password-rejected") main.Notify(L.T("passwordRejected"), "error");
                    else if (what == "hostkey-changed")
                    {
                        if (Dialogs.Ask(main, L.T("keyChangedTitle"), L.F("keyChangedText", s.Host.Name), L.T("forgetKey"), L.T("cancel"), "warning", true))
                        {
                            Ssh.ForgetKey(s.Host.Address);
                            if (s.Host.Port != 22) Ssh.ForgetKey("[" + s.Host.Address + "]:" + s.Host.Port);
                            Sessions.StartAsync(s);
                        }
                    }
                });
            };
        }

        private void AskPorts(Session s)
        {
            Host h = Store.FindHost(s.Host.Id);
            if (h == null) return;
            using (ChoiceForm f = new ChoiceForm(h))
            {
                DialogResult r = f.ShowDialog(main);
                h.PortsAsked = true;
                Store.ReplaceHost(h);
                if (r != DialogResult.OK) return;
                if (f.Choice == "detect") DetectFor(h);
                else EditHost(h);
            }
        }

        public void DetectFor(Host h)
        {
            if (h == null) return;
            Session s = Sessions.For(h.Id);
            if (s == null || s.State == SessionState.Closed)
            {
                Connect(h);
                s = Sessions.For(h.Id);
            }
            else if (active != s) ShowSession(s);
            if (s.Busy) { main.Notify(L.T("busyWait"), "warn"); return; }
            Session ses = s;
            Thread t = new Thread(delegate()
            {
                try
                {
                    List<PortStatus> found = Deployer.Detect(ses);
                    Sessions.Post(delegate { ApplyDetected(h.Id, found); });
                }
                catch (Exception ex)
                {
                    Log.Warn("Detect on " + h.Name + ": " + ex.Message);
                    Sessions.Post(delegate { Dialogs.Problem(main, L.T("detectFailed"), ex.Message); });
                }
            });
            t.IsBackground = true;
            t.Start();
        }

        private void ApplyDetected(string hostId, List<PortStatus> found)
        {
            Host h = Store.FindHost(hostId);
            if (h == null) return;
            h.Ports.Clear();
            foreach (PortStatus st in found) h.Ports.Add(new PortInfo(st.Port, ""));
            h.PortsAsked = true;
            Store.ReplaceHost(h);
            main.Notify(L.F("portsDetected", found.Count), "ok");
            main.Deploy.SessionsChanged();
        }

        private void HostMenu(Host h, Control at, Point pt)
        {
            ContextMenuStrip m = ThemedMenu.Make();
            Session s = Sessions.For(h.Id);
            ThemedMenu.Item(m, s != null && s.State != SessionState.Closed ? L.T("openTerminal") : L.T("connect"), "play_arrow", delegate { Connect(h); });
            ThemedMenu.Item(m, L.T("deployHere"), "rocket_launch", delegate { main.Deploy.Prepare(h, null, null); main.SelectTab(1); });
            m.Items.Add(new ToolStripSeparator());
            ThemedMenu.Item(m, L.T("edit"), "edit", delegate { EditHost(h); });
            ThemedMenu.Item(m, L.T("duplicate"), "content_copy", delegate { Duplicate(h); });
            m.Items.Add(new ToolStripSeparator());
            ToolStripMenuItem del = ThemedMenu.Item(m, L.T("delete"), "delete", delegate { DeleteHost(h); });
            del.Tag = "danger";
            m.Closed += delegate { BeginInvoke((Action)m.Dispose); };
            m.Show(at, pt);
        }

        private void AddHost()
        {
            using (HostDialog d = new HostDialog(null))
            {
                if (d.ShowDialog(main) != DialogResult.OK || d.Result == null) return;
                Store.ReplaceHost(d.Result);
                ShowHost(d.Result);
                main.Notify(L.F("switchAdded", d.Result.Name), "ok");
            }
        }

        public void EditHost(Host h)
        {
            if (h == null) return;
            using (HostDialog d = new HostDialog(h))
            {
                if (d.ShowDialog(main) != DialogResult.OK || d.Result == null) return;
                Store.ReplaceHost(d.Result);
                selected = d.Result;
                foreach (Session s in Sessions.All) if (s.Host.Id == h.Id) CopyInto(d.Result, s.Host);
                if (active == null) ShowOverview();
                main.Notify(L.T("saved"), "ok");
            }
        }

        private static void CopyInto(Host from, Host to)
        {
            to.Name = from.Name; to.Group = from.Group; to.Kind = from.Kind; to.Address = from.Address; to.Port = from.Port;
            to.Username = from.Username; to.Password = from.Password; to.Enable = from.Enable; to.Legacy = from.Legacy;
            to.ComPort = from.ComPort; to.Baud = from.Baud; to.DemoModel = from.DemoModel;
            to.Ports = new List<PortInfo>(from.Ports);
        }

        private void Duplicate(Host h)
        {
            Host c = h.Clone();
            c.Id = Guid.NewGuid().ToString("N");
            c.Name = L.F("copyOf", h.Name);
            c.LastConnected = DateTime.MinValue;
            Store.ReplaceHost(c);
            ShowHost(c);
        }

        private void DeleteHost(Host h)
        {
            if (!Dialogs.Ask(main, L.T("deleteSwitch"), L.F("deleteSwitchText", h.Name), L.T("delete"), L.T("cancel"), "delete", true)) return;
            Session s = Sessions.For(h.Id);
            if (s != null) Sessions.Close(s);
            Store.Hosts.Remove(h);
            if (h.Kind == "demo") DemoSwitch.Forget(h.Id);
            Store.SaveHosts();
            selected = FirstHost();
            ShowOverview();
            main.Notify(L.F("switchDeleted", h.Name), "ok");
        }
    }

    internal sealed class TermFrame : Pane
    {
        protected override void OnPaintBackground(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.Clear(Parent != null ? Parent.BackColor : Theme.P.Bg);
            Icons.Smooth(g);
            RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            Ui.FillRound(g, r, 12 * Ui.Sc, Theme.T.Bg);
            Ui.StrokeRound(g, r, 12 * Ui.Sc, Theme.P.Dark || Theme.TermMode == "dark" ? Theme.Mix(Theme.T.Bg, Color.White, 0.08f) : Theme.P.Border, Math.Max(1f, Ui.Sc));
        }

        protected override void OnLayout(LayoutEventArgs e)
        {
            base.OnLayout(e);
            using (System.Drawing.Drawing2D.GraphicsPath p = Icons.Rounded(new RectangleF(0, 0, Width, Height), 12 * Ui.Sc))
                Region = new Region(p);
        }
    }

    internal sealed class EmptyState : Pane
    {
        private readonly string title, text;
        private readonly Btn action;

        public EmptyState(string title, string text, string actionText, string icon, EventHandler click)
        {
            this.title = title;
            this.text = text;
            BackColor = Color.Transparent;
            if (actionText != null)
            {
                action = new Btn(actionText, icon, BtnKind.Primary, click);
                Controls.Add(action);
            }
        }

        protected override void OnParentChanged(EventArgs e)
        {
            base.OnParentChanged(e);
            if (Parent != null) BackColor = Parent.BackColor == Color.Transparent ? Theme.P.Bg : Parent.BackColor;
        }

        private int ContentTop
        {
            get
            {
                int h = Ui.D(72) + Ui.D(16) + Ui.D(28) + Ui.WrapHeight(text, Fonts.Body(14f * Ui.Sc), Math.Min(Width - Ui.D(40), Ui.D(440))) + Ui.D(22) + Ui.D(40);
                return Math.Max(Ui.D(10), (Height - h) / 2);
            }
        }

        protected override void OnLayout(LayoutEventArgs e)
        {
            base.OnLayout(e);
            if (action == null) return;
            int tw = Math.Min(Width - Ui.D(40), Ui.D(440));
            int y = ContentTop + Ui.D(72) + Ui.D(16) + Ui.D(28) + Ui.WrapHeight(text, Fonts.Body(14f * Ui.Sc), tw) + Ui.D(22);
            int total = action.Width;
            int x = (Width - total) / 2;
            action.Location = new Point(x, y);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            Palette p = Theme.P;
            Icons.Smooth(g);
            int y = ContentTop;
            int s = Ui.D(72);
            Icons.NovaBadge(g, new RectangleF((Width - s) / 2f, y, s, s));
            y += s + Ui.D(16);
            Ui.Text(g, title, Fonts.Head(17f * Ui.Sc), new Rectangle(0, y, Width, Ui.D(28)), p.Text, Ui.Center);
            y += Ui.D(28);
            int tw = Math.Min(Width - Ui.D(40), Ui.D(440));
            TextRenderer.DrawText(g, text, Fonts.Body(14f * Ui.Sc), new Rectangle((Width - tw) / 2, y, tw, Ui.WrapHeight(text, Fonts.Body(14f * Ui.Sc), tw) + Ui.D(4)), p.Muted,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.WordBreak | TextFormatFlags.NoPadding);
        }
    }

    internal sealed class SessionStrip : Painted
    {
        private readonly List<Session> sessions = new List<Session>();
        public Session Active;
        public event Action<Session> Selected;
        public event Action<Session> CloseRequested;
        private readonly List<KeyValuePair<Rectangle, Session>> tabs = new List<KeyValuePair<Rectangle, Session>>();
        private int hover = -2;
        private bool hoverClose;
        private readonly System.Windows.Forms.Timer tick;

        public SessionStrip()
        {
            Cursor = Cursors.Default;
            tick = new System.Windows.Forms.Timer();
            tick.Interval = 400;
            tick.Tick += delegate { Invalidate(); };
            tick.Start();
        }

        public void SetSessions(List<Session> all, Session active)
        {
            sessions.Clear();
            sessions.AddRange(all);
            Active = active;
            Invalidate();
        }

        private void LayoutTabs(Graphics g)
        {
            tabs.Clear();
            int x = 0;
            Font f = Fonts.Strong(13.5f * Sc);
            int ow = Ui.Measure(L.T("overview"), f).Width + D(52);
            tabs.Add(new KeyValuePair<Rectangle, Session>(new Rectangle(x, 0, ow, Height), null));
            x += ow + D(6);
            int avail = Width - x;
            int each = sessions.Count == 0 ? 0 : Math.Min(D(230), Math.Max(D(110), avail / Math.Max(1, sessions.Count) - D(6)));
            foreach (Session s in sessions)
            {
                int w = Math.Min(each, Ui.Measure(s.Host.Name, f).Width + D(70));
                tabs.Add(new KeyValuePair<Rectangle, Session>(new Rectangle(x, 0, w, Height), s));
                x += w + D(6);
            }
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            LayoutTabs(g);
            Font f = Fonts.Strong(13.5f * Sc);
            for (int i = 0; i < tabs.Count; i++)
            {
                Rectangle r = tabs[i].Key;
                Session s = tabs[i].Value;
                bool act = s == Active;
                bool hv = hover == i;
                RectangleF rr = new RectangleF(r.X + 0.5f, r.Y + 0.5f, r.Width - 1, r.Height - 1);
                if (act)
                {
                    Ui.FillRound(g, rr, 10 * Sc, p.Surface);
                    Ui.StrokeRound(g, rr, 10 * Sc, p.Border, Math.Max(1f, Sc));
                }
                else if (hv) Ui.FillRound(g, rr, 10 * Sc, p.HoverFill);
                int x = r.X + D(14);
                if (s == null)
                {
                    Icons.Draw(g, "dashboard", new RectangleF(x, r.Y, D(20), r.Height), act ? p.Orange : p.Muted, 19 * Sc, act);
                    Ui.Text(g, L.T("overview"), f, new Rectangle(x + D(26), r.Y, r.Right - x - D(30), r.Height), act ? p.Text : p.Muted, Ui.Left);
                    continue;
                }
                Color dot = s.State == SessionState.Connected ? p.Success : s.State == SessionState.Connecting ? p.Warning : p.Faint;
                if (s.Busy && DateTime.Now.Millisecond < 500) dot = p.Orange;
                float d = 9 * Sc;
                using (SolidBrush br = new SolidBrush(dot)) g.FillEllipse(br, x, r.Y + (r.Height - d) / 2f, d, d);
                Ui.Text(g, s.Host.Name, f, new Rectangle(x + D(18), r.Y, r.Width - D(18) - D(46), r.Height), act ? p.Text : p.Muted, Ui.Left);
                RectangleF cb = new RectangleF(r.Right - D(32), r.Y + (r.Height - D(24)) / 2f, D(24), D(24));
                if (hv || act)
                {
                    if (hv && hoverClose) Ui.FillRound(g, cb, 6 * Sc, p.HoverFill);
                    Icons.Draw(g, "close", cb, hv && hoverClose ? p.Text : p.Faint, 16 * Sc, false);
                }
            }
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            int h = -2;
            bool hc = false;
            for (int i = 0; i < tabs.Count; i++)
            {
                if (!tabs[i].Key.Contains(e.Location)) continue;
                h = i;
                hc = tabs[i].Value != null && e.X > tabs[i].Key.Right - D(34);
            }
            if (h != hover || hc != hoverClose) { hover = h; hoverClose = hc; Invalidate(); }
            Cursor = h >= 0 ? Cursors.Hand : Cursors.Default;
            base.OnMouseMove(e);
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            hover = -2;
            base.OnMouseLeave(e);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            for (int i = 0; i < tabs.Count; i++)
            {
                if (!tabs[i].Key.Contains(e.Location)) continue;
                Session s = tabs[i].Value;
                if (s != null && (e.Button == MouseButtons.Middle || (e.Button == MouseButtons.Left && e.X > tabs[i].Key.Right - D(34))))
                {
                    Action<Session> c = CloseRequested;
                    if (c != null) c(s);
                    return;
                }
                if (e.Button != MouseButtons.Left) return;
                Active = s;
                Invalidate();
                Action<Session> h = Selected;
                if (h != null) h(s);
                return;
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing) tick.Dispose();
            base.Dispose(disposing);
        }
    }
}
'@,
@'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal sealed class TemplatesPage : Pane, IPage
    {
        private readonly MainForm main;
        private readonly Pane side;
        private readonly TextField search;
        private readonly ItemList list;
        private readonly Btn addBtn;
        private readonly Pane area;
        private Template editing;
        private Template original;
        private bool dirty;
        private bool loading;
        private Card editor, varsCard, previewCard;
        private TextField name, description;
        private Btn exportBtn, listMenuBtn;
        private CodeBox body, preview;
        private Toggle reset;
        private ColorPicker colors;
        private Dropdown iconPick;
        private Btn saveBtn, deployBtn, dupBtn, delBtn;
        private Label dirtyLabel, bodyHint, varsEmpty;
        private readonly Dictionary<string, TextField> varFields = new Dictionary<string, TextField>(StringComparer.OrdinalIgnoreCase);
        private readonly Timer varTimer;
        private EmptyState empty;

        public static readonly string[] IconChoices = { "settings_ethernet", "wifi", "call", "computer", "print", "videocam", "lan", "hub", "router", "dns", "security", "block", "power_off", "sensors", "devices", "storage" };

        public TemplatesPage(MainForm main)
        {
            this.main = main;
            Palette p = Theme.P;
            BackColor = p.Bg;
            side = new Pane();
            Controls.Add(side);
            search = new TextField("", L.T("searchTemplates"), "search", false, false);
            search.Changed += delegate { Fill(); };
            side.Controls.Add(search);
            listMenuBtn = new Btn(null, "more_vert", BtnKind.Ghost, null);
            listMenuBtn.Tip = L.T("importExport");
            listMenuBtn.Click += delegate { ListMenu(); };
            side.Controls.Add(listMenuBtn);
            list = new ItemList();
            list.HeightOf = delegate { return D(62); };
            list.PaintItem = PaintTemplate;
            list.EmptyTitle = L.T("noTemplatesTitle");
            list.EmptyText = L.T("noTemplatesText");
            list.SelectionChanged += delegate
            {
                Template t = list.SelectedItem as Template;
                if (t == null || (editing != null && t.Id == editing.Id)) return;
                if (!ConfirmLeave()) { list.SelectItem(FindInList(editing)); return; }
                Open(t);
            };
            list.ContextRequested += delegate(object o, Point pt) { TemplateMenu((Template)o, pt); };
            side.Controls.Add(list);
            addBtn = new Btn(L.T("newTemplate"), "add", BtnKind.Primary, delegate { NewTemplate(); });
            side.Controls.Add(addBtn);
            area = new Pane();
            Controls.Add(area);
            varTimer = new Timer();
            varTimer.Interval = 300;
            varTimer.Tick += delegate { varTimer.Stop(); BuildVars(); UpdatePreview(); };
            Store.TemplatesChanged += OnTemplatesChanged;
            BuildEditor();
            Fill();
            if (Store.Templates.Count > 0) Open(SortedTemplates()[0]);
            else ShowEmpty();
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                Store.TemplatesChanged -= OnTemplatesChanged;
                varTimer.Dispose();
            }
            base.Dispose(disposing);
        }

        private int D(float v) { return Ui.D(v); }

        public string SelectedId { get { return editing == null ? null : editing.Id; } }

        public void Select(string id)
        {
            Template t = Store.FindTemplate(id);
            if (t != null) Open(t);
        }

        public void Shown() { }

        public bool Dirty { get { return dirty; } }

        private void OnTemplatesChanged()
        {
            if (IsDisposed) return;
            Fill();
        }

        private object FindInList(Template t)
        {
            if (t == null) return null;
            foreach (object o in list.Items) if (((Template)o).Id == t.Id) return o;
            return null;
        }

        private List<Template> SortedTemplates()
        {
            List<Template> l = new List<Template>(Store.Templates);
            l.Sort(delegate(Template a, Template b) { return string.Compare(a.Name, b.Name, StringComparison.CurrentCultureIgnoreCase); });
            return l;
        }

        private void Fill()
        {
            string q = search.Text.Trim();
            List<object> items = new List<object>();
            foreach (Template t in SortedTemplates())
                if (q.Length == 0 || t.Name.IndexOf(q, StringComparison.CurrentCultureIgnoreCase) >= 0 || t.Description.IndexOf(q, StringComparison.CurrentCultureIgnoreCase) >= 0 || t.Body.IndexOf(q, StringComparison.OrdinalIgnoreCase) >= 0)
                    items.Add(t);
            list.EmptyTitle = q.Length > 0 ? L.T("noMatch") : L.T("noTemplatesTitle");
            list.EmptyText = q.Length > 0 ? null : L.T("noTemplatesText");
            list.SetItems(items, null);
            if (editing != null) list.SelectItem(FindInList(editing));
        }

        private void PaintTemplate(Graphics g, Rectangle r, object item, bool sel, bool hover)
        {
            Palette p = Theme.P;
            Template t = (Template)item;
            bool isEditing = editing != null && editing.Id == t.Id;
            ItemList.Row(g, r, sel, hover);
            Color accent = Theme.Accents[Math.Max(0, Math.Min(Theme.Accents.Length - 1, t.Color))];
            RectangleF ib = new RectangleF(r.X + D(16), r.Y + (r.Height - D(36)) / 2f, D(36), D(36));
            Ui.FillRound(g, ib, 10 * Ui.Sc, Theme.Mix(accent, p.Surface, p.Dark ? 0.7f : 0.82f));
            Icons.Draw(g, t.Icon, ib, accent, 20 * Ui.Sc, false);
            int tx = (int)ib.Right + D(12);
            string nm = isEditing && dirty ? (name.Text.Trim().Length > 0 ? name.Text.Trim() : t.Name) : t.Name;
            Ui.Text(g, nm, Fonts.Strong(14f * Ui.Sc), new Rectangle(tx, r.Y + D(10), r.Right - tx - D(30), D(22)), p.Text, Ui.Left);
            if (isEditing && dirty)
                using (SolidBrush br = new SolidBrush(p.Orange)) g.FillEllipse(br, r.Right - D(26), r.Y + D(17), D(8), D(8));
            int lines = t.Lines.Count;
            List<string> vars = Cisco.Variables(t.Body);
            string sub = t.Description.Length > 0 ? t.Description : L.F("linesCount", lines);
            Ui.Text(g, sub, Fonts.Body(12.5f * Ui.Sc), new Rectangle(tx, r.Y + D(32), r.Right - tx - D(14), D(20)), p.Muted, Ui.Left);
        }

        private void BuildEditor()
        {
            Palette p = Theme.P;
            editor = new Card();
            area.Controls.Add(editor);
            name = new TextField("", L.T("phTemplateName"), null, false, false);
            name.Box.Font = Fonts.Head(17f * Ui.Sc);
            name.Changed += delegate { Changed(); list.Invalidate(); };
            editor.Controls.Add(name);
            iconPick = new Dropdown();
            foreach (string ic in IconChoices) iconPick.Items.Add(new DropItem(L.IconName(ic), ic) { Icon = ic });
            iconPick.Changed += delegate { Changed(); };
            editor.Controls.Add(iconPick);
            colors = new ColorPicker();
            colors.Changed += delegate { Changed(); };
            editor.Controls.Add(colors);
            description = new TextField("", L.T("phTemplateDesc"), "description", false, false);
            description.Changed += delegate { Changed(); };
            editor.Controls.Add(description);
            Label cmd = Ui.Label(L.T("commandsTitle"), Fonts.Head(14.5f * Ui.Sc), p.Text);
            cmd.Name = "cmdTitle";
            editor.Controls.Add(cmd);
            bodyHint = Ui.Label(L.T("commandsHint"), Fonts.Body(12.5f * Ui.Sc), p.Muted);
            editor.Controls.Add(bodyHint);
            body = new CodeBox("", false);
            body.Changed += delegate { Changed(); varTimer.Stop(); varTimer.Start(); };
            editor.Controls.Add(body);
            reset = new Toggle(false);
            reset.Changed += delegate { Changed(); UpdatePreview(); };
            editor.Controls.Add(reset);
            Label rl = Ui.Label(L.T("resetFirst"), Fonts.Body(13.5f * Ui.Sc), p.Text);
            rl.Name = "resetLabel";
            editor.Controls.Add(rl);
            Tips.Set(rl, L.T("resetFirstTip"));
            dirtyLabel = Ui.Label(L.T("unsaved"), Fonts.Body(12.5f * Ui.Sc), p.Orange);
            dirtyLabel.Visible = false;
            editor.Controls.Add(dirtyLabel);
            saveBtn = new Btn(L.T("save"), "save", BtnKind.Primary, delegate { Save(); });
            deployBtn = new Btn(L.T("deploy"), "rocket_launch", BtnKind.Secondary, delegate
            {
                if (dirty && !Save()) return;
                main.Deploy.Prepare(null, null, editing.Id);
                main.SelectTab(1);
            });
            dupBtn = new Btn(null, "content_copy", BtnKind.Ghost, delegate { Duplicate(editing); });
            dupBtn.Tip = L.T("duplicate");
            delBtn = new Btn(null, "delete", BtnKind.Ghost, delegate { Delete(editing); });
            delBtn.Tip = L.T("delete");
            editor.Controls.Add(saveBtn);
            editor.Controls.Add(deployBtn);
            editor.Controls.Add(dupBtn);
            exportBtn = new Btn(null, "upload", BtnKind.Ghost, delegate
            {
                if (editing == null) return;
                if (dirty && !Save()) return;
                Template t = Store.FindTemplate(editing.Id);
                if (t != null) Transfer.ExportTemplates(main, new List<Template> { t }, t.Name);
            });
            exportBtn.Tip = L.T("exportThis");
            editor.Controls.Add(exportBtn);
            editor.Controls.Add(delBtn);

            varsCard = new Card();
            varsCard.Title = L.T("variablesTitle");
            varsCard.Icon = "data_object";
            area.Controls.Add(varsCard);
            varsEmpty = Ui.Label(L.T("variablesNone"), Fonts.Body(13f * Ui.Sc), p.Muted);
            varsCard.Controls.Add(varsEmpty);

            previewCard = new Card();
            previewCard.Title = L.T("previewTitle");
            previewCard.Icon = "code";
            area.Controls.Add(previewCard);
            preview = new CodeBox("", true);
            previewCard.Controls.Add(preview);

            ctrlKeys = true;
        }

        private bool ctrlKeys;

        protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
        {
            if (ctrlKeys && keyData == (Keys.Control | Keys.S) && editing != null) { Save(); return true; }
            return base.ProcessCmdKey(ref msg, keyData);
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            Lay();
        }

        private void Lay()
        {
            if (side == null) return;
            int sw = D(300), pad = D(18);
            side.Bounds = new Rectangle(0, 0, sw, Height);
            listMenuBtn.Location = new Point(sw - D(8) - listMenuBtn.Width, pad + (D(40) - listMenuBtn.Height) / 2);
            search.Bounds = new Rectangle(pad, pad, listMenuBtn.Left - pad - D(6), D(40));
            addBtn.Width = sw - pad - D(8);
            addBtn.Location = new Point(pad, Height - pad - addBtn.Height);
            list.Bounds = new Rectangle(pad - D(6), search.Bottom + D(12), sw - pad + D(4) - D(8), addBtn.Top - search.Bottom - D(24));
            area.Bounds = new Rectangle(sw, pad, Width - sw - pad, Height - 2 * pad);
            if (empty != null) { empty.Bounds = new Rectangle(0, 0, area.Width, area.Height); return; }
            int colW = Math.Max(D(270), Math.Min(D(380), area.Width / 3));
            int ew = area.Width - colW - D(16);
            editor.Bounds = new Rectangle(0, 0, ew, area.Height);
            int x = D(22), w = ew - D(44);
            int iconW = D(150);
            name.Bounds = new Rectangle(x, D(22), w, D(44));
            int ry = name.Bottom + D(12);
            if (w >= D(560))
            {
                colors.Location = new Point(x + w - colors.Width, ry - D(4));
                iconPick.Bounds = new Rectangle(colors.Left - D(12) - iconW, ry, iconW, D(40));
                description.Bounds = new Rectangle(x, ry, iconPick.Left - x - D(12), D(40));
            }
            else
            {
                description.Bounds = new Rectangle(x, ry, w, D(40));
                ry = description.Bottom + D(12);
                iconPick.Bounds = new Rectangle(x, ry, iconW, D(40));
                colors.Location = new Point(iconPick.Right + D(14), ry - D(4));
            }
            Control ct = editor.Controls["cmdTitle"];
            ct.Location = new Point(x, Math.Max(description.Bottom, iconPick.Bottom) + D(22));
            bodyHint.Location = new Point(x, ct.Bottom + D(4));
            bodyHint.MaximumSize = new Size(w, 0);
            int footer = D(70);
            int by = bodyHint.Bottom + D(12);
            int resetRow = D(44);
            body.Bounds = new Rectangle(x, by, w, Math.Max(D(120), editor.Height - by - footer - resetRow));
            reset.Location = new Point(x, body.Bottom + D(12));
            Control rl = editor.Controls["resetLabel"];
            rl.Location = new Point(reset.Right + D(10), reset.Top + (reset.Height - rl.Height) / 2);
            int fy = editor.Height - D(20) - saveBtn.Height;
            saveBtn.Location = new Point(x + w - saveBtn.Width, fy);
            deployBtn.Location = new Point(saveBtn.Left - D(8) - deployBtn.Width, fy);
            dirtyLabel.Location = new Point(deployBtn.Left - D(14) - dirtyLabel.Width, fy + (saveBtn.Height - dirtyLabel.Height) / 2);
            delBtn.Location = new Point(x - D(6), fy);
            dupBtn.Location = new Point(delBtn.Right + D(4), fy);
            exportBtn.Location = new Point(dupBtn.Right + D(4), fy);

            int cx = ew + D(16);
            int varsH = Math.Max(D(150), Math.Min(D(64) + varFields.Count * D(72) + D(10), area.Height / 2));
            if (varFields.Count == 0) varsH = D(118);
            varsCard.Bounds = new Rectangle(cx, 0, colW, varsH);
            varsEmpty.Location = new Point(D(20), varsCard.HeaderHeight);
            varsEmpty.MaximumSize = new Size(colW - D(40), 0);
            int vy = varsCard.HeaderHeight;
            foreach (KeyValuePair<string, TextField> kv in varFields)
            {
                Control lab = varsCard.Controls["l_" + kv.Key];
                lab.Location = new Point(D(20), vy);
                kv.Value.Bounds = new Rectangle(D(20), vy + D(22), colW - D(40), D(38));
                vy += D(72);
            }
            previewCard.Bounds = new Rectangle(cx, varsCard.Bottom + D(16), colW, area.Height - varsCard.Bottom - D(16));
            preview.Bounds = new Rectangle(D(16), previewCard.HeaderHeight, colW - D(32), previewCard.Height - previewCard.HeaderHeight - D(16));
        }

        private void ShowEmpty()
        {
            editing = null;
            original = null;
            editor.Visible = varsCard.Visible = previewCard.Visible = false;
            if (empty == null)
            {
                empty = new EmptyState(L.T("noTemplatesTitle"), L.T("noTemplatesBig"), L.T("newTemplate"), "add", delegate { NewTemplate(); });
                area.Controls.Add(empty);
            }
            Lay();
        }

        private void Open(Template t)
        {
            if (empty != null) { area.Controls.Remove(empty); empty.Dispose(); empty = null; }
            editor.Visible = varsCard.Visible = previewCard.Visible = true;
            loading = true;
            original = t;
            editing = t.Clone();
            name.Text = editing.Name;
            description.Text = editing.Description;
            body.Text = editing.Body;
            reset.Checked = editing.ResetFirst;
            colors.Selected = editing.Color;
            iconPick.SelectValue(editing.Icon);
            if (iconPick.SelectedIndex < 0) iconPick.SelectedIndex = 0;
            loading = false;
            SetDirty(false);
            BuildVars();
            UpdatePreview();
            list.SelectItem(FindInList(editing));
            Lay();
        }

        private void Changed()
        {
            if (loading || editing == null) return;
            SetDirty(true);
            UpdatePreview();
        }

        private void SetDirty(bool d)
        {
            dirty = d;
            dirtyLabel.Visible = d;
            saveBtn.Enabled = d;
            list.Invalidate();
        }

        private void BuildVars()
        {
            if (editing == null) return;
            List<string> vars = Cisco.Variables(body.Text);
            Dictionary<string, string> keep = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (KeyValuePair<string, TextField> kv in varFields) keep[kv.Key] = kv.Value.Text;
            bool same = vars.Count == varFields.Count;
            if (same) foreach (string v in vars) if (!varFields.ContainsKey(v)) same = false;
            if (!same)
            {
                foreach (KeyValuePair<string, TextField> kv in varFields)
                {
                    Control lab = varsCard.Controls["l_" + kv.Key];
                    varsCard.Controls.Remove(lab); lab.Dispose();
                    varsCard.Controls.Remove(kv.Value); kv.Value.Dispose();
                }
                varFields.Clear();
                foreach (string v in vars)
                {
                    string def;
                    if (!keep.TryGetValue(v, out def) && !editing.Defaults.TryGetValue(v, out def)) def = "";
                    Label lab = Ui.Label(L.F("defaultFor", v), Fonts.Strong(12.5f * Ui.Sc), Theme.P.Text);
                    lab.Name = "l_" + v;
                    varsCard.Controls.Add(lab);
                    TextField f = new TextField(def, L.T("phDefault"), null, false, true);
                    f.Changed += delegate { Changed(); };
                    varsCard.Controls.Add(f);
                    varFields[v] = f;
                }
            }
            varsEmpty.Visible = vars.Count == 0;
            if (Cisco.UsesPort(body.Text)) varsEmpty.Text = L.T("variablesPortOnly");
            else varsEmpty.Text = L.T("variablesNone");
            Lay();
        }

        private Dictionary<string, string> Values()
        {
            Dictionary<string, string> d = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (KeyValuePair<string, TextField> kv in varFields) d[kv.Key] = kv.Value.Text;
            return d;
        }

        private void UpdatePreview()
        {
            if (editing == null || preview == null) return;
            Template t = Current();
            List<string> lines = new List<string>();
            lines.Add("interface range Gi1/0/1 - 4");
            Dictionary<string, string> vals = Values();
            foreach (string l in t.Lines) lines.Add(" " + Cisco.Render(l, vals, "Gi1/0/1"));
            lines.Add(" exit");
            if (t.ResetFirst) lines.Insert(0, "default interface range Gi1/0/1 - 4");
            preview.Text = string.Join("\n", lines.ToArray());
        }

        private Template Current()
        {
            Template t = editing.Clone();
            t.Name = name.Text.Trim();
            t.Description = description.Text.Trim();
            t.Body = body.Text.Replace("\r\n", "\n").TrimEnd();
            t.ResetFirst = reset.Checked;
            t.Color = colors.Selected;
            t.Icon = iconPick.Value as string ?? "settings_ethernet";
            t.Defaults.Clear();
            foreach (KeyValuePair<string, string> kv in Values()) if (kv.Value.Length > 0) t.Defaults[kv.Key] = kv.Value;
            return t;
        }

        private bool Save()
        {
            if (editing == null) return false;
            Template t = Current();
            if (t.Name.Length == 0) { name.Error = true; name.Invalidate(); name.Box.Focus(); main.Notify(L.T("nameNeeded"), "warn"); return false; }
            if (t.Lines.Count == 0) { main.Notify(L.T("commandsNeeded"), "warn"); body.Box.Focus(); return false; }
            foreach (Template other in Store.Templates)
                if (other.Id != t.Id && string.Equals(other.Name, t.Name, StringComparison.CurrentCultureIgnoreCase))
                {
                    name.Error = true; name.Invalidate();
                    main.Notify(L.T("nameTaken"), "warn");
                    return false;
                }
            string bad = BadLine(t);
            if (bad != null && !Dialogs.Ask(main, L.T("checkCommands"), L.F("badLineText", bad), L.T("saveAnyway"), L.T("cancel"), "warning", false)) return false;
            t.Modified = DateTime.Now;
            Store.ReplaceTemplate(t);
            editing = t.Clone();
            original = t;
            SetDirty(false);
            Fill();
            main.Notify(L.F("templateSaved", t.Name), "ok");
            main.Deploy.TemplatesChanged();
            return true;
        }

        private static string BadLine(Template t)
        {
            foreach (string l in t.Lines)
            {
                string n = Cisco.Norm(l);
                if (n.StartsWith("interface ") || n == "end" || n.StartsWith("conf") || n == "exit" || n.StartsWith("write") || n.StartsWith("copy ")) return l;
            }
            return null;
        }

        public bool ConfirmLeave()
        {
            if (!dirty || editing == null) return true;
            if (Dialogs.Ask(main, L.T("unsavedTitle"), L.F("unsavedText", name.Text.Trim().Length > 0 ? name.Text.Trim() : editing.Name), L.T("discard"), L.T("keepEditing"), "edit", true))
            {
                SetDirty(false);
                return true;
            }
            return false;
        }

        private void NewTemplate()
        {
            if (!ConfirmLeave()) return;
            Template t = new Template();
            t.Name = UniqueName(L.T("newTemplateName"));
            t.Body = "description {{description}}\nswitchport mode access\nswitchport access vlan {{vlan}}\nspanning-tree portfast\nno shutdown";
            t.Defaults["description"] = "";
            t.Defaults["vlan"] = "10";
            t.Color = Store.Templates.Count % Theme.Accents.Length;
            Store.ReplaceTemplate(t);
            Fill();
            Open(t);
            name.Box.Focus();
            name.Box.SelectAll();
        }

        private static string UniqueName(string baseName)
        {
            string n = baseName;
            int i = 2;
            while (Store.Templates.Exists(delegate(Template t) { return string.Equals(t.Name, n, StringComparison.CurrentCultureIgnoreCase); })) n = baseName + " " + i++;
            return n;
        }

        private void Duplicate(Template t)
        {
            if (t == null) return;
            if (!ConfirmLeave()) return;
            Template src = Store.FindTemplate(t.Id) ?? t;
            Template c = src.Clone();
            c.Id = Guid.NewGuid().ToString("N");
            c.Name = UniqueName(L.F("copyOf", src.Name));
            Store.ReplaceTemplate(c);
            Fill();
            Open(c);
            main.Deploy.TemplatesChanged();
        }

        private void Delete(Template t)
        {
            if (t == null) return;
            Template src = Store.FindTemplate(t.Id);
            if (src == null) return;
            if (!Dialogs.Ask(main, L.T("deleteTemplate"), L.F("deleteTemplateText", src.Name), L.T("delete"), L.T("cancel"), "delete", true)) return;
            Store.Templates.Remove(src);
            Store.SaveTemplates();
            SetDirty(false);
            Fill();
            List<Template> all = SortedTemplates();
            if (all.Count > 0) Open(all[0]); else ShowEmpty();
            main.Notify(L.F("templateDeleted", src.Name), "ok");
            main.Deploy.TemplatesChanged();
        }

        private void ListMenu()
        {
            ContextMenuStrip m = ThemedMenu.Make();
            ThemedMenu.Item(m, L.T("exportAll"), "upload", delegate
            {
                if (!ConfirmLeave()) return;
                Transfer.ExportTemplates(main, SortedTemplates(), "SwitchDeck-templates");
            }).Enabled = Store.Templates.Count > 0;
            ThemedMenu.Item(m, L.T("importTemplates"), "download", delegate
            {
                if (!ConfirmLeave()) return;
                Template t = Transfer.ImportTemplates(main);
                Fill();
                if (t != null) Open(t);
            });
            m.Closed += delegate { BeginInvoke((Action)m.Dispose); };
            m.Show(listMenuBtn, new Point(0, listMenuBtn.Height + D(4)));
        }

        private void TemplateMenu(Template t, Point pt)
        {
            ContextMenuStrip m = ThemedMenu.Make();
            ThemedMenu.Item(m, L.T("deploy"), "rocket_launch", delegate { main.Deploy.Prepare(null, null, t.Id); main.SelectTab(1); });
            ThemedMenu.Item(m, L.T("duplicate"), "content_copy", delegate { Duplicate(t); });
            ThemedMenu.Item(m, L.T("exportThis"), "upload", delegate { Transfer.ExportTemplates(main, new List<Template> { t }, t.Name); });
            m.Items.Add(new ToolStripSeparator());
            ToolStripMenuItem del = ThemedMenu.Item(m, L.T("delete"), "delete", delegate { Delete(t); });
            del.Tag = "danger";
            m.Closed += delegate { BeginInvoke((Action)m.Dispose); };
            m.Show(list, pt);
        }
    }

    internal sealed class ColorPicker : Painted
    {
        private int selected;
        private int hover = -1;
        public event EventHandler Changed;

        public ColorPicker()
        {
            Size = new Size(D(4 * 28), D(48));
            Cursor = Cursors.Hand;
        }

        public int Selected
        {
            get { return selected; }
            set { selected = value; Invalidate(); }
        }

        private const int PerRow = 4;

        private RectangleF Dot(int i)
        {
            int row = i / PerRow, col = i % PerRow;
            return new RectangleF(col * D(28) + D(5), row * D(24) + D(4), D(16), D(16));
        }

        private int Hit(Point p)
        {
            for (int i = 0; i < Theme.Accents.Length; i++) if (RectangleF.Inflate(Dot(i), D(5), D(1)).Contains(p)) return i;
            return -1;
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            int h = Hit(e.Location);
            if (h != hover) { hover = h; Invalidate(); }
            base.OnMouseMove(e);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            int h = Hit(e.Location);
            if (h < 0 || h == selected) return;
            selected = h;
            Invalidate();
            EventHandler c = Changed;
            if (c != null) c(this, EventArgs.Empty);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            for (int i = 0; i < Theme.Accents.Length; i++)
            {
                RectangleF r = Dot(i);
                if (i == selected)
                {
                    using (Pen pen = new Pen(Theme.Accents[i], 2f * Sc)) g.DrawEllipse(pen, RectangleF.Inflate(r, 2.5f * Sc, 2.5f * Sc));
                }
                using (SolidBrush br = new SolidBrush(i == hover && i != selected ? Theme.Mix(Theme.Accents[i], Color.White, 0.2f) : Theme.Accents[i]))
                    g.FillEllipse(br, i == selected ? RectangleF.Inflate(r, -1.5f * Sc, -1.5f * Sc) : r);
            }
        }
    }
}
'@,
@'
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
'@,
@'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Text;
using System.IO;
using Microsoft.Win32;

namespace SwitchDeck
{
    internal sealed class Palette
    {
        public bool Dark;
        public Color Bg, Surface, Surface2, Border, Track, HoverFill, Text, Muted, Faint;
        public Color Orange, OrangeHover, OrangeSoft, OnOrange;
        public Color Teal, TealSoft, Success, SuccessSoft, Warning, WarningSoft, Danger, DangerSoft;
        public Color Shadow;
    }

    internal sealed class TermPalette
    {
        public Color Bg, Fg, Dim, Cursor, Selection, Bar;
        public Color[] Ansi = new Color[16];
    }

    internal static class Theme
    {
        public static Palette P = Make(false);
        public static TermPalette T = MakeTerm(true);
        public static event Action Changed;

        public static Color C(int rgb) { return Color.FromArgb(255, (rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255); }

        public static readonly Color Charcoal = C(0x20252B);
        public static readonly Color Orange = C(0xF28C28);
        public static readonly Color OffWhite = C(0xF5F3EF);
        public static readonly Color TealBase = C(0x527C82);

        public static readonly Color[] Accents =
        {
            C(0xF28C28), C(0x527C82), C(0x3E9B6A), C(0xE0A526), C(0xD64545), C(0x7A6FC7), C(0x3D8BD1), C(0x9AA0A6)
        };

        public static Palette Make(bool dark)
        {
            Palette p = new Palette();
            p.Dark = dark;
            p.Orange = Orange;
            p.OnOrange = Charcoal;
            if (!dark)
            {
                p.Bg = C(0xF5F3EF); p.Surface = C(0xFFFFFF); p.Surface2 = C(0xFAF9F7); p.Border = C(0xE5E7EB);
                p.Track = C(0xD3D6DB); p.HoverFill = C(0xEFECE7);
                p.Text = C(0x20252B); p.Muted = C(0x5E656D); p.Faint = C(0x9AA0A6);
                p.OrangeHover = C(0xE07B18); p.OrangeSoft = C(0xFDEEDD);
                p.Teal = C(0x527C82); p.TealSoft = C(0xE4EDEE);
                p.Success = C(0x3E9B6A); p.SuccessSoft = C(0xE2F2E9);
                p.Warning = C(0xC98E12); p.WarningSoft = C(0xFBF1D9);
                p.Danger = C(0xD64545); p.DangerSoft = C(0xFBE4E4);
                p.Shadow = Color.FromArgb(26, 32, 37, 43);
            }
            else
            {
                p.Bg = C(0x16191D); p.Surface = C(0x20252B); p.Surface2 = C(0x2A3038); p.Border = C(0x343B44);
                p.Track = C(0x434B55); p.HoverFill = C(0x2C323A);
                p.Text = C(0xF5F3EF); p.Muted = C(0xA3AAB1); p.Faint = C(0x6F767E);
                p.OrangeHover = C(0xF59D47); p.OrangeSoft = C(0x3A2D21);
                p.Teal = C(0x6A979D); p.TealSoft = C(0x243337);
                p.Success = C(0x52B582); p.SuccessSoft = C(0x1F3229);
                p.Warning = C(0xE0A526); p.WarningSoft = C(0x3A3120);
                p.Danger = C(0xE36A6A); p.DangerSoft = C(0x3D2426);
                p.Shadow = Color.FromArgb(90, 0, 0, 0);
            }
            return p;
        }

        public static TermPalette MakeTerm(bool dark)
        {
            TermPalette t = new TermPalette();
            if (dark)
            {
                t.Bg = C(0x14171B); t.Fg = C(0xE6E3DD); t.Dim = C(0x7D848C); t.Cursor = Orange;
                t.Selection = Color.FromArgb(255, 0x3E, 0x4A, 0x57); t.Bar = C(0x1B1F24);
                int[] a = { 0x1E2227, 0xE36A6A, 0x52B582, 0xE0A526, 0x5A9BD8, 0xB48EE0, 0x6A979D, 0xD8D5CF,
                            0x5E656D, 0xF08A8A, 0x7DCFA2, 0xF2C45A, 0x86B8EA, 0xCDB0F0, 0x93BFC4, 0xFFFFFF };
                for (int i = 0; i < 16; i++) t.Ansi[i] = C(a[i]);
            }
            else
            {
                t.Bg = C(0xFFFFFF); t.Fg = C(0x20252B); t.Dim = C(0x8A9098); t.Cursor = C(0xE07B18);
                t.Selection = C(0xFBDDBD); t.Bar = C(0xFAF9F7);
                int[] a = { 0x20252B, 0xC13B3B, 0x2E8257, 0xA57409, 0x2F6FB0, 0x7A4FB8, 0x456A70, 0x8A9098,
                            0x5E656D, 0xD64545, 0x3E9B6A, 0xC98E12, 0x3D8BD1, 0x9466D1, 0x527C82, 0x20252B };
                for (int i = 0; i < 16; i++) t.Ansi[i] = C(a[i]);
            }
            return t;
        }

        public static string Mode = "system";
        public static string TermMode = "dark";

        public static void Apply(string mode, string termMode)
        {
            Mode = mode;
            TermMode = termMode;
            bool dark = mode == "dark" || (mode == "system" && SystemIsDark());
            P = Make(dark);
            T = MakeTerm(termMode == "dark" || (termMode == "theme" && dark));
            Action h = Changed;
            if (h != null) h();
        }

        public static bool SystemIsDark()
        {
            try
            {
                using (RegistryKey k = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"))
                {
                    object v = k == null ? null : k.GetValue("AppsUseLightTheme");
                    return v is int && (int)v == 0;
                }
            }
            catch { return false; }
        }

        public static Color Mix(Color a, Color b, float t)
        {
            return Color.FromArgb(
                (int)Math.Round(a.R + (b.R - a.R) * t),
                (int)Math.Round(a.G + (b.G - a.G) * t),
                (int)Math.Round(a.B + (b.B - a.B) * t));
        }
    }

    internal static class Fonts
    {
        private static readonly Dictionary<string, Font> cache = new Dictionary<string, Font>();
        private static readonly PrivateFontCollection pfc = new PrivateFontCollection();
        private static readonly Dictionary<string, FontFamily> families = new Dictionary<string, FontFamily>(StringComparer.OrdinalIgnoreCase);
        private static string head, body, strong, mono, monoBold, symbols, symbolsFill;
        private static bool loaded;

        public static void Load(string dir)
        {
            if (loaded) return;
            loaded = true;
            string[] files = { "Poppins-SemiBold.ttf", "Poppins-Medium.ttf", "Inter-Regular.ttf", "Inter-SemiBold.ttf",
                               "JetBrainsMono-Regular.ttf", "JetBrainsMono-Bold.ttf", "Symbols.ttf", "Symbols-Fill.ttf" };
            foreach (string f in files)
            {
                string path = Path.Combine(dir, f);
                if (!File.Exists(path)) continue;
                try
                {
                    Native.AddFontResourceEx(path, 0x10, IntPtr.Zero);
                    pfc.AddFontFile(path);
                }
                catch (Exception ex) { Log.Warn("Font " + f + ": " + ex.Message); }
            }
            foreach (FontFamily fam in pfc.Families) families[fam.Name] = fam;
            head = Pick("SD Poppins SemiBold", "Segoe UI Semibold");
            body = Pick("SD Inter", "Segoe UI");
            strong = Pick("SD Inter SemiBold", "Segoe UI Semibold");
            mono = Pick("SD JetBrains Mono", "Consolas");
            monoBold = Pick("SD JetBrains Mono Bold", "Consolas");
            symbols = Pick("SD Symbols", null);
            symbolsFill = Pick("SD Symbols Fill", symbols);
        }

        public static bool HasSymbols { get { return symbols != null; } }

        private static string Pick(string name, string fallback)
        {
            return families.ContainsKey(name) ? name : fallback;
        }

        public static Font Head(float px) { return Get(head ?? "Segoe UI Semibold", px); }
        public static Font Body(float px) { return Get(body ?? "Segoe UI", px); }
        public static Font Strong(float px) { return Get(strong ?? "Segoe UI Semibold", px); }
        public static Font Mono(float px) { return Get(mono ?? "Consolas", px); }
        public static Font MonoBold(float px) { return Get(monoBold ?? "Consolas", px); }
        public static Font Symbol(float px, bool fill) { return Get((fill ? symbolsFill : symbols) ?? "Segoe UI Symbol", px); }

        private static Font Get(string family, float px)
        {
            px = (float)Math.Round(px, 1);
            string key = family + "|" + px;
            Font f;
            lock (cache)
            {
                if (!cache.TryGetValue(key, out f))
                {
                    FontFamily fam;
                    if (families.TryGetValue(family, out fam)) f = new Font(fam, px, FontStyle.Regular, GraphicsUnit.Pixel);
                    else f = new Font(family, px, FontStyle.Regular, GraphicsUnit.Pixel);
                    cache[key] = f;
                }
            }
            return f;
        }
    }
}
'@,
@'
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal static class Transfer
    {
        public static void ExportTemplates(MainForm main, List<Template> templates, string fileName)
        {
            if (templates.Count == 0) return;
            using (SaveFileDialog d = new SaveFileDialog())
            {
                d.Filter = L.T("templateFiles") + " (*.json)|*.json";
                d.FileName = Store.SafeName(fileName) + ".json";
                if (d.ShowDialog(main) != DialogResult.OK) return;
                try
                {
                    JObj o = new JObj();
                    o["app"] = "SwitchDeck";
                    o["kind"] = "templates";
                    o["version"] = Program.Version;
                    List<object> list = new List<object>();
                    foreach (Template t in templates) list.Add(t.ToJson());
                    o["templates"] = list;
                    File.WriteAllText(d.FileName, Json.Write(o), new UTF8Encoding(false));
                    Log.Info("Exported " + templates.Count + " templates to " + d.FileName);
                    main.Notify(templates.Count == 1 ? L.F("exportedOne", templates[0].Name) : L.F("exportedMany", templates.Count), "ok");
                }
                catch (Exception ex)
                {
                    Log.Error("Export: " + ex.Message);
                    Dialogs.Problem(main, L.T("oops"), ex.Message);
                }
            }
        }

        public static Template ImportTemplates(MainForm main)
        {
            using (OpenFileDialog d = new OpenFileDialog())
            {
                d.Filter = L.T("templateFiles") + " (*.json)|*.json";
                d.Multiselect = true;
                if (d.ShowDialog(main) != DialogResult.OK) return null;
                Template last = null;
                int added = 0;
                try
                {
                    foreach (string file in d.FileNames)
                    {
                        JObj o = Json.ParseObj(File.ReadAllText(file, Encoding.UTF8));
                        if (o.Str("app") != "SwitchDeck") throw new FormatException(L.F("notTemplateFile", Path.GetFileName(file)));
                        foreach (JObj j in o.Objs("templates"))
                        {
                            Template t = Template.FromJson(j);
                            if (t.Name.Trim().Length == 0) continue;
                            if (Store.FindTemplate(t.Id) != null) t.Id = Guid.NewGuid().ToString("N");
                            string baseName = t.Name;
                            int n = 2;
                            while (Store.Templates.Exists(delegate(Template x) { return string.Equals(x.Name, t.Name, StringComparison.CurrentCultureIgnoreCase); }))
                                t.Name = baseName + " " + n++;
                            Store.Templates.Add(t);
                            last = t;
                            added++;
                        }
                    }
                }
                catch (Exception ex)
                {
                    Log.Error("Import: " + ex.Message);
                    Dialogs.Problem(main, L.T("importFailed"), ex.Message);
                }
                if (added > 0)
                {
                    Store.SaveTemplates();
                    main.Deploy.TemplatesChanged();
                    Log.Info("Imported " + added + " templates");
                    main.Notify(L.F("importedTemplates", added), "ok");
                }
                return last;
            }
        }
    }
}
'@,
@'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.IO.Ports;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32.SafeHandles;

namespace SwitchDeck
{
    internal interface ITransport : IDisposable
    {
        event Action<byte[], int> Data;
        event Action<string> Closed;
        void Start(int cols, int rows);
        void Write(byte[] data);
        void Resize(int cols, int rows);
        void SendBreak();
        bool IsOpen { get; }
        bool LocalEcho { get; }
    }

    internal sealed class ConPtyTransport : ITransport
    {
        private readonly string app, args;
        private IntPtr pc = IntPtr.Zero;
        private PROCESS_INFORMATION pi;
        private FileStream input, output;
        private Thread reader, waiter;
        private volatile bool open;
        private int closedFlag;
        private readonly object writeGate = new object();
        public event Action<byte[], int> Data;
        public event Action<string> Closed;

        public ConPtyTransport(string app, string args)
        {
            this.app = app;
            this.args = args;
        }

        public bool IsOpen { get { return open; } }
        public bool LocalEcho { get { return false; } }

        public void Start(int cols, int rows)
        {
            SafeFileHandle inRead, inWrite, outRead, outWrite;
            if (!Native.CreatePipe(out inRead, out inWrite, IntPtr.Zero, 0)) throw new Win32Exception();
            if (!Native.CreatePipe(out outRead, out outWrite, IntPtr.Zero, 0)) throw new Win32Exception();
            int hr = Native.CreatePseudoConsole(new COORD((short)Math.Max(20, cols), (short)Math.Max(5, rows)), inRead, outWrite, 0, out pc);
            if (hr != 0) throw new Win32Exception(hr);
            inRead.Dispose();
            outWrite.Dispose();

            IntPtr size = IntPtr.Zero;
            Native.InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref size);
            IntPtr list = Marshal.AllocHGlobal(size);
            try
            {
                if (!Native.InitializeProcThreadAttributeList(list, 1, 0, ref size)) throw new Win32Exception();
                if (!Native.UpdateProcThreadAttribute(list, 0, Native.PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, pc, (IntPtr)IntPtr.Size, IntPtr.Zero, IntPtr.Zero))
                    throw new Win32Exception();
                STARTUPINFOEX si = new STARTUPINFOEX();
                si.StartupInfo.cb = Marshal.SizeOf(typeof(STARTUPINFOEX));
                si.StartupInfo.dwFlags = 0x100;
                si.lpAttributeList = list;
                string cmd = "\"" + app + "\" " + args;
                if (!Native.CreateProcess(null, cmd, IntPtr.Zero, IntPtr.Zero, false, Native.EXTENDED_STARTUPINFO_PRESENT, IntPtr.Zero, Path.GetDirectoryName(app), ref si, out pi))
                    throw new Win32Exception();
                Native.DeleteProcThreadAttributeList(list);
            }
            finally { Marshal.FreeHGlobal(list); }

            input = new FileStream(inWrite, FileAccess.Write, 1);
            output = new FileStream(outRead, FileAccess.Read, 1);
            open = true;
            reader = new Thread(ReadLoop);
            reader.IsBackground = true;
            reader.Name = "pty-read";
            reader.Start();
            waiter = new Thread(WaitLoop);
            waiter.IsBackground = true;
            waiter.Name = "pty-wait";
            waiter.Start();
        }

        private void ReadLoop()
        {
            byte[] buf = new byte[16384];
            try
            {
                while (true)
                {
                    int n = output.Read(buf, 0, buf.Length);
                    if (n <= 0) break;
                    Action<byte[], int> d = Data;
                    if (d != null) d(buf, n);
                }
            }
            catch (Exception ex) { if (open) Log.Info("pty read ended: " + ex.Message); }
            Finish(null);
        }

        private void WaitLoop()
        {
            try
            {
                Native.WaitForSingleObject(pi.hProcess, 0xFFFFFFFF);
                uint code;
                Native.GetExitCodeProcess(pi.hProcess, out code);
                Thread.Sleep(150);
                ClosePc();
                Finish(code == 0 ? null : "exit " + code);
            }
            catch { }
        }

        private void ClosePc()
        {
            IntPtr h = Interlocked.Exchange(ref pc, IntPtr.Zero);
            if (h != IntPtr.Zero)
            {
                Thread t = new Thread(delegate() { try { Native.ClosePseudoConsole(h); } catch { } });
                t.IsBackground = true;
                t.Start();
                t.Join(3000);
            }
        }

        private void Finish(string reason)
        {
            if (Interlocked.Exchange(ref closedFlag, 1) != 0) return;
            open = false;
            Action<string> c = Closed;
            if (c != null) c(reason);
        }

        public void Write(byte[] data)
        {
            if (!open) return;
            try
            {
                lock (writeGate)
                {
                    input.Write(data, 0, data.Length);
                    input.Flush();
                }
            }
            catch (Exception ex) { Log.Warn("pty write: " + ex.Message); }
        }

        public void Resize(int cols, int rows)
        {
            IntPtr h = pc;
            if (h != IntPtr.Zero) Native.ResizePseudoConsole(h, new COORD((short)Math.Max(20, cols), (short)Math.Max(5, rows)));
        }

        public void SendBreak() { }

        public void Dispose()
        {
            open = false;
            try { if (pi.hProcess != IntPtr.Zero) Native.TerminateProcess(pi.hProcess, 1); } catch { }
            ClosePc();
            try { if (input != null) input.Dispose(); } catch { }
            try { if (output != null) output.Dispose(); } catch { }
            try
            {
                if (pi.hProcess != IntPtr.Zero) Native.CloseHandle(pi.hProcess);
                if (pi.hThread != IntPtr.Zero) Native.CloseHandle(pi.hThread);
            }
            catch { }
            pi = new PROCESS_INFORMATION();
            Finish(null);
        }
    }

    internal static class Ssh
    {
        private static HashSet<string> kex, ciphers, keys, macs;

        public static string Exe
        {
            get
            {
                string p = Path.Combine(Environment.SystemDirectory, @"OpenSSH\ssh.exe");
                if (File.Exists(p)) return p;
                string sysnative = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), @"Sysnative\OpenSSH\ssh.exe");
                return File.Exists(sysnative) ? sysnative : null;
            }
        }

        public static string KeyGen
        {
            get
            {
                string p = Path.Combine(Environment.SystemDirectory, @"OpenSSH\ssh-keygen.exe");
                return File.Exists(p) ? p : null;
            }
        }

        public static string KnownHosts { get { return Path.Combine(Program.DataDir, "known_hosts"); } }

        private static HashSet<string> Query(string what)
        {
            HashSet<string> r = new HashSet<string>(StringComparer.Ordinal);
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo(Exe, "-Q " + what);
                psi.UseShellExecute = false;
                psi.RedirectStandardOutput = true;
                psi.CreateNoWindow = true;
                using (Process p = Process.Start(psi))
                {
                    string all = p.StandardOutput.ReadToEnd();
                    p.WaitForExit(3000);
                    foreach (string l in all.Split('\n')) if (l.Trim().Length > 0) r.Add(l.Trim());
                }
            }
            catch (Exception ex) { Log.Warn("ssh -Q " + what + ": " + ex.Message); }
            return r;
        }

        private static string Plus(HashSet<string> have, params string[] wanted)
        {
            List<string> ok = new List<string>();
            foreach (string w in wanted) if (have.Contains(w)) ok.Add(w);
            return ok.Count == 0 ? null : "+" + string.Join(",", ok.ToArray());
        }

        public static string Arguments(Host h)
        {
            StringBuilder sb = new StringBuilder();
            Directory.CreateDirectory(Program.DataDir);
            sb.Append("-o \"UserKnownHostsFile=" + KnownHosts + "\" ");
            sb.Append("-o StrictHostKeyChecking=ask -o ConnectTimeout=12 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 ");
            sb.Append("-o NumberOfPasswordPrompts=3 -o PreferredAuthentications=keyboard-interactive,password,publickey ");
            sb.Append("-o HashKnownHosts=no -o LogLevel=ERROR ");
            if (h.Kind == "ssh")
            {
                if (kex == null)
                {
                    kex = Query("kex"); ciphers = Query("cipher"); keys = Query("key"); macs = Query("mac");
                }
                string k = Plus(kex, "diffie-hellman-group14-sha1", "diffie-hellman-group-exchange-sha1", "diffie-hellman-group1-sha1");
                string c = Plus(ciphers, "aes128-cbc", "aes256-cbc", "3des-cbc");
                string hk = Plus(keys, "ssh-rsa");
                string m = Plus(macs, "hmac-sha1", "hmac-sha1-96");
                if (k != null) sb.Append("-o KexAlgorithms=" + k + " ");
                if (c != null) sb.Append("-o Ciphers=" + c + " ");
                if (hk != null) sb.Append("-o HostKeyAlgorithms=" + hk + " -o PubkeyAcceptedAlgorithms=" + hk + " ");
                if (m != null) sb.Append("-o MACs=" + m + " ");
            }
            if (h.Port > 0 && h.Port != 22) sb.Append("-p " + h.Port + " ");
            if (h.Username.Length > 0) sb.Append("-l \"" + h.Username.Replace("\"", "") + "\" ");
            sb.Append(h.Address.Trim());
            return sb.ToString();
        }

        public static void ForgetKey(string address)
        {
            try
            {
                if (KeyGen == null || !File.Exists(KnownHosts)) return;
                ProcessStartInfo psi = new ProcessStartInfo(KeyGen, "-R \"" + address + "\" -f \"" + KnownHosts + "\"");
                psi.UseShellExecute = false;
                psi.CreateNoWindow = true;
                psi.RedirectStandardOutput = true;
                psi.RedirectStandardError = true;
                using (Process p = Process.Start(psi)) p.WaitForExit(5000);
                Log.Info("Removed saved key for " + address);
            }
            catch (Exception ex) { Log.Warn("ssh-keygen -R: " + ex.Message); }
        }
    }

    internal sealed class SerialTransport : ITransport
    {
        private readonly string portName;
        private readonly int baud;
        private SerialPort port;
        private volatile bool open;
        private int closedFlag;
        public event Action<byte[], int> Data;
        public event Action<string> Closed;

        public SerialTransport(string portName, int baud)
        {
            this.portName = portName;
            this.baud = baud;
        }

        public bool IsOpen { get { return open; } }
        public bool LocalEcho { get { return false; } }

        public void Start(int cols, int rows)
        {
            port = new SerialPort(portName, baud, Parity.None, 8, StopBits.One);
            port.Handshake = Handshake.None;
            port.DtrEnable = true;
            port.RtsEnable = true;
            port.ReadTimeout = 500;
            port.WriteTimeout = 2000;
            port.Encoding = Encoding.GetEncoding(28591);
            port.Open();
            open = true;
            Thread t = new Thread(ReadLoop);
            t.IsBackground = true;
            t.Name = "serial-read";
            t.Start();
        }

        private void ReadLoop()
        {
            byte[] buf = new byte[4096];
            string reason = null;
            while (open)
            {
                try
                {
                    int n = port.BaseStream.Read(buf, 0, buf.Length);
                    if (n > 0)
                    {
                        Action<byte[], int> d = Data;
                        if (d != null) d(buf, n);
                    }
                }
                catch (TimeoutException) { }
                catch (IOException ex) { if (open) reason = ex.Message; break; }
                catch (InvalidOperationException ex) { if (open) reason = ex.Message; break; }
                catch (UnauthorizedAccessException ex) { if (open) reason = ex.Message; break; }
            }
            Finish(reason);
        }

        private void Finish(string reason)
        {
            if (Interlocked.Exchange(ref closedFlag, 1) != 0) return;
            open = false;
            Action<string> c = Closed;
            if (c != null) c(reason);
        }

        public void Write(byte[] data)
        {
            if (!open) return;
            try { port.Write(data, 0, data.Length); }
            catch (Exception ex) { Log.Warn("serial write: " + ex.Message); }
        }

        public void Resize(int cols, int rows) { }

        public void SendBreak()
        {
            if (!open) return;
            try
            {
                port.BreakState = true;
                Thread.Sleep(400);
                port.BreakState = false;
            }
            catch (Exception ex) { Log.Warn("serial break: " + ex.Message); }
        }

        public void Dispose()
        {
            open = false;
            try { if (port != null) { port.Close(); port.Dispose(); } } catch { }
            Finish(null);
        }
    }

    internal sealed class DemoTransport : ITransport
    {
        private readonly DemoSwitch device;
        private readonly Queue<byte[]> inbox = new Queue<byte[]>();
        private readonly AutoResetEvent signal = new AutoResetEvent(false);
        private volatile bool open;
        private int closedFlag;
        public event Action<byte[], int> Data;
        public event Action<string> Closed;

        public DemoTransport(DemoSwitch device)
        {
            this.device = device;
        }

        public bool IsOpen { get { return open; } }
        public bool LocalEcho { get { return false; } }

        public void Start(int cols, int rows)
        {
            open = true;
            device.Output = Emit;
            device.Quit = delegate { Finish(null); };
            Thread t = new Thread(Loop);
            t.IsBackground = true;
            t.Name = "demo-switch";
            t.Start();
        }

        private void Emit(string s)
        {
            if (!open) return;
            byte[] b = Encoding.UTF8.GetBytes(s);
            Action<byte[], int> d = Data;
            if (d != null) d(b, b.Length);
        }

        private void Loop()
        {
            try
            {
                Thread.Sleep(350);
                device.Boot();
                while (open)
                {
                    signal.WaitOne(200);
                    while (open)
                    {
                        byte[] b;
                        lock (inbox)
                        {
                            if (inbox.Count == 0) break;
                            b = inbox.Dequeue();
                        }
                        foreach (byte x in b) { if (!open) break; device.Key((char)x); }
                    }
                }
            }
            catch (Exception ex) { Log.Error("Demo switch: " + ex); Finish(ex.Message); }
        }

        private void Finish(string reason)
        {
            if (Interlocked.Exchange(ref closedFlag, 1) != 0) return;
            open = false;
            Action<string> c = Closed;
            if (c != null) c(reason);
        }

        public void Write(byte[] data)
        {
            if (!open) return;
            lock (inbox) inbox.Enqueue((byte[])data.Clone());
            signal.Set();
        }

        public void Resize(int cols, int rows) { }
        public void SendBreak() { }

        public void Dispose()
        {
            open = false;
            signal.Set();
            Finish(null);
        }
    }
}
'@,
@'
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
'@
)

try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    if (-not $quiet) { try { $splash = Show-Splash } catch { $splash = $null } }
    $joined = [string]::Join("`n", [string[]]$sources)
    $sha = [Security.Cryptography.SHA256]::Create()
    $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($joined))).Replace('-', '').Substring(0, 24)
    $cacheDir = Join-Path $env:LOCALAPPDATA 'SwitchDeck\cache'
    $cacheFile = Join-Path $cacheDir ($hash + '.bin')
    $assembly = $null
    if (Test-Path $cacheFile) {
        try { $assembly = [Reflection.Assembly]::Load([IO.File]::ReadAllBytes($cacheFile)) } catch { $assembly = $null }
    }
    if ($null -eq $assembly) {
        $provider = New-Object Microsoft.CSharp.CSharpCodeProvider
        $cp = New-Object System.CodeDom.Compiler.CompilerParameters
        $out = Join-Path ([IO.Path]::GetTempPath()) ('SwitchDeck-' + [Guid]::NewGuid().ToString('N') + '.dll')
        $cp.GenerateInMemory = $false
        $cp.GenerateExecutable = $false
        $cp.OutputAssembly = $out
        $cp.CompilerOptions = '/optimize+'
        foreach ($r in 'System.dll','System.Core.dll','System.Drawing.dll','System.Windows.Forms.dll','System.Security.dll') {
            [void]$cp.ReferencedAssemblies.Add($r)
        }
        if ($splash) { [System.Windows.Forms.Application]::DoEvents() }
        $result = $provider.CompileAssemblyFromSource($cp, [string[]]$sources)
        if ($result.Errors.HasErrors) {
            $msg = ($result.Errors | Where-Object { -not $_.IsWarning } | Select-Object -First 5 | ForEach-Object { $_.ToString() }) -join "`n"
            throw "SwitchDeck could not start:`n$msg"
        }
        $bytes = [IO.File]::ReadAllBytes($out)
        Remove-Item $out -ErrorAction SilentlyContinue
        Remove-Item ([IO.Path]::ChangeExtension($out, '.pdb')) -ErrorAction SilentlyContinue
        try {
            New-Item -ItemType Directory -Force $cacheDir | Out-Null
            Get-ChildItem $cacheDir -Filter *.bin -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
            [IO.File]::WriteAllBytes($cacheFile, $bytes)
        } catch { }
        $assembly = [Reflection.Assembly]::Load($bytes)
    }
    if ($splash) { [System.Windows.Forms.Application]::DoEvents() }
    $program = $assembly.GetType('SwitchDeck.Program')
    $method = $program.GetMethod('RunFromScript', [Type[]]@([string], [string[]], [object]))
    $splashObj = $null
    if ($splash) { $splashObj = $splash.psobject.BaseObject }
    $code = $method.Invoke($null, [object[]]@($scriptPath, [string[]]$args, $splashObj))
    exit $code
}
catch {
    $err = $_.Exception
    while ($err.InnerException) { $err = $err.InnerException }
    if ($splash) { try { $splash.Close() } catch { } }
    try {
        $logDir = Join-Path (Split-Path -Parent (Split-Path -Parent $scriptPath)) 'logs'
        New-Item -ItemType Directory -Force $logDir | Out-Null
        Add-Content -Path (Join-Path $logDir 'SwitchDeck.log') -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') + ' ERROR launcher: ' + $err.ToString())
    } catch { }
    if (-not $quiet) { [System.Windows.Forms.MessageBox]::Show($err.Message, 'SwitchDeck', 'OK', 'Error') | Out-Null }
    else { Write-Host $err.ToString() }
    exit 1
}
