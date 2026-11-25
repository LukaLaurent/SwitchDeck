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
