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
