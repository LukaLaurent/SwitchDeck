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
