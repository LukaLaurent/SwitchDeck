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
