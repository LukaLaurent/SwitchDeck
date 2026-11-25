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
