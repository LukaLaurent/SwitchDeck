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
