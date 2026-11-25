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
