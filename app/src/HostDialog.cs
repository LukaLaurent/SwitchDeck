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
