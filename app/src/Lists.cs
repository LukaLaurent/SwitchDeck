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
