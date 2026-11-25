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
