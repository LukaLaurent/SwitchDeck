using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal static class Icons
    {
        private static readonly Dictionary<string, int> map = new Dictionary<string, int>
        {
            { "router", 0xE328 }, { "lan", 0xEB2F }, { "dns", 0xE875 }, { "settings_ethernet", 0xE8BE },
            { "terminal", 0xEB8E }, { "add", 0xE145 }, { "delete", 0xE872 }, { "edit", 0xE150 },
            { "content_copy", 0xE14D }, { "content_paste", 0xE14F }, { "search", 0xE8B6 }, { "folder", 0xE2C7 },
            { "folder_open", 0xE2C8 }, { "rocket_launch", 0xEB9B }, { "bolt", 0xEA0B }, { "play_arrow", 0xE037 },
            { "stop", 0xE047 }, { "check", 0xE5CA }, { "check_circle", 0xE86C }, { "close", 0xE14C },
            { "error", 0xE000 }, { "warning", 0xE002 }, { "info", 0xE88E }, { "sync", 0xE627 },
            { "refresh", 0xE5D5 }, { "cable", 0xEFE6 }, { "usb", 0xE1E0 }, { "key", 0xE73C },
            { "lock", 0xE88D }, { "lock_open", 0xE898 }, { "visibility", 0xE417 }, { "visibility_off", 0xE8F5 },
            { "save", 0xE161 }, { "upload", 0xE2C6 }, { "download", 0xE171 }, { "history", 0xE28E },
            { "description", 0xE873 }, { "tune", 0xE429 }, { "settings", 0xE8B8 }, { "link", 0xE157 },
            { "link_off", 0xE16F }, { "power", 0xE63C }, { "power_off", 0xE646 }, { "expand_more", 0xE5CF },
            { "expand_less", 0xE5CE }, { "chevron_right", 0xE409 }, { "chevron_left", 0xE408 }, { "more_vert", 0xE5D4 },
            { "select_all", 0xE162 }, { "deselect", 0xEBB6 }, { "filter_list", 0xE152 }, { "label", 0xE892 },
            { "wifi", 0xE63E }, { "videocam", 0xE04B }, { "print", 0xE555 }, { "call", 0xE0B0 },
            { "computer", 0xE30A }, { "devices", 0xE1B1 }, { "hub", 0xE9F4 }, { "list", 0xE896 },
            { "grid_view", 0xE9B0 }, { "dashboard", 0xE871 }, { "backup", 0xE864 }, { "undo", 0xE166 },
            { "schedule", 0xE192 }, { "speed", 0xE9E4 }, { "sensors", 0xE51E }, { "auto_awesome", 0xE65F },
            { "science", 0xEA4B }, { "layers", 0xE53B }, { "code", 0xE86F }, { "keyboard", 0xE312 },
            { "help", 0xE887 }, { "article", 0xEF42 }, { "drag_indicator", 0xE945 }, { "person", 0xE7FD },
            { "shield", 0xE75B }, { "vpn_key", 0xE0DA }, { "storage", 0xE1DB }, { "memory", 0xE322 },
            { "radio_button_checked", 0xE837 }, { "radio_button_unchecked", 0xE836 }, { "circle", 0xEF4A }, { "pending", 0xEF64 },
            { "hourglass_empty", 0xE88B }, { "task_alt", 0xE2E6 }, { "cancel", 0xE5C9 }, { "block", 0xE033 },
            { "open_in_new", 0xE895 }, { "logout", 0xE9BA }, { "login", 0xEA77 }, { "note_add", 0xE89C },
            { "file_copy", 0xE173 }, { "clear_all", 0xE0B8 }, { "manage_search", 0xF02F }, { "checklist", 0xE6B1 },
            { "view_list", 0xE8EF }, { "construction", 0xEA3C }, { "device_hub", 0xE335 }, { "security", 0xE32A },
            { "tag", 0xE9EF }, { "minimize", 0xE931 }, { "crop_square", 0xE3C1 }, { "filter_none", 0xE3E0 },
            { "check_box", 0xE834 }, { "check_box_outline_blank", 0xE835 }, { "indeterminate_check_box", 0xE909 }, { "arrow_drop_down", 0xE5C5 },
            { "arrow_upward", 0xE5D8 }, { "arrow_downward", 0xE5DB }, { "swap_horiz", 0xE8D4 }, { "bookmark", 0xE866 },
            { "palette", 0xE3B7 }, { "dark_mode", 0xE51C }, { "light_mode", 0xE518 }, { "translate", 0xE8E2 },
            { "data_object", 0xEAD3 }, { "playlist_add", 0xE03B }, { "playlist_play", 0xE05F }, { "format_list_numbered", 0xE242 },
            { "keyboard_return", 0xE31B }, { "monitor_heart", 0xEAA2 }, { "fact_check", 0xF0C5 }, { "rule", 0xF1C2 },
            { "difference", 0xEB7D }, { "compare_arrows", 0xE915 }, { "wrap_text", 0xE25B }, { "text_fields", 0xE262 },
            { "pin", 0xF045 }, { "numbers", 0xEAC7 }, { "priority_high", 0xE645 }, { "restart_alt", 0xF053 },
            { "unfold_more", 0xE5D7 }, { "open_in_full", 0xF1CE },
        };

        public static string Glyph(string name)
        {
            int cp;
            if (name != null && map.TryGetValue(name, out cp)) return char.ConvertFromUtf32(cp);
            return "";
        }

        public static void Draw(Graphics g, string name, RectangleF r, Color c, float px, bool fill)
        {
            string s = Glyph(name);
            if (s.Length == 0 || !Fonts.HasSymbols) return;
            Font f = Fonts.Symbol(px, fill);
            int cx = (int)Math.Round(r.X + r.Width / 2f), cy = (int)Math.Round(r.Y + r.Height / 2f);
            int box = (int)Math.Ceiling(px) + 8;
            TextRenderer.DrawText(g, s, f, new Rectangle(cx - box / 2, cy - box / 2, box, box), c,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine | TextFormatFlags.NoClipping);
        }

        public static GraphicsPath Rounded(RectangleF r, float radius)
        {
            GraphicsPath p = new GraphicsPath();
            float d = Math.Min(radius * 2, Math.Min(r.Width, r.Height));
            if (d <= 0.5f) { p.AddRectangle(r); return p; }
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }

        public static void Smooth(Graphics g)
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        }

        public static Bitmap App(int size)
        {
            Bitmap b = new Bitmap(size, size, PixelFormat.Format32bppArgb);
            using (Graphics g = Graphics.FromImage(b))
            {
                Smooth(g);
                g.Clear(Color.Transparent);
                float s = size / 512f;
                using (GraphicsPath bg = Rounded(new RectangleF(0, 0, size, size), 112 * s))
                using (SolidBrush br = new SolidBrush(Theme.Charcoal))
                    g.FillPath(br, bg);
                float w = 76, h = 68, gap = 22;
                float x0 = 256 - (4 * w + 3 * gap) / 2f;
                float[] ys = { 150, 150 + h + 28 };
                bool[,] on = { { true, true, false, true }, { false, true, true, false } };
                for (int row = 0; row < 2; row++)
                {
                    for (int i = 0; i < 4; i++)
                    {
                        RectangleF r = new RectangleF((x0 + i * (w + gap)) * s, ys[row] * s, w * s, h * s);
                        Color c = on[row, i] ? Theme.Orange : Theme.C(0x5B6672);
                        using (GraphicsPath p = Rounded(r, 16 * s))
                        using (SolidBrush br = new SolidBrush(c))
                            g.FillPath(br, p);
                        if (size >= 32)
                        {
                            float nw = r.Width * 0.4f, nh = r.Height * 0.26f;
                            RectangleF notch = new RectangleF(r.X + (r.Width - nw) / 2f, r.Bottom - nh, nw, nh + 0.5f);
                            using (SolidBrush br = new SolidBrush(Theme.Charcoal)) g.FillRectangle(br, notch);
                        }
                    }
                }
                RectangleF bar = new RectangleF(x0 * s, 356 * s, (4 * w + 3 * gap) * s, 22 * s);
                using (GraphicsPath p = Rounded(bar, 11 * s))
                using (SolidBrush br = new SolidBrush(Color.FromArgb(110, Theme.OffWhite)))
                    g.FillPath(br, p);
            }
            return b;
        }

        public static Icon MakeIcon(int size)
        {
            using (Bitmap bmp = App(size))
            {
                IntPtr h = bmp.GetHicon();
                try
                {
                    using (Icon tmp = Icon.FromHandle(h)) return (Icon)tmp.Clone();
                }
                finally { Native.DestroyIcon(h); }
            }
        }

        private static readonly string[] NovaPaths =
        {
            "F28C28|M52 92C44 60 46 34 58 22C72 30 88 50 96 70Z",
            "F28C28|M148 92C156 60 154 34 142 22C128 30 112 50 104 70Z",
            "20252B|M60 80C56 60 58 44 63 36C72 44 80 56 86 68Z",
            "20252B|M140 80C144 60 142 44 137 36C128 44 120 56 114 68Z",
            "F28C28|M100 58C140 58 172 80 170 112C168 136 130 160 100 174C70 160 32 136 30 112C28 80 60 58 100 58Z",
            "F5F3EF|clip|M100 180C82 168 50 150 36 124C58 128 80 122 100 136C120 122 142 128 164 124C150 150 118 168 100 180Z",
            "F5F3EF|M100 74C101 81 103 83 110 84C103 85 101 87 100 94C99 87 97 85 90 84C97 83 99 81 100 74Z",
        };

        private static GraphicsPath ParsePath(string d)
        {
            GraphicsPath p = new GraphicsPath();
            List<float> nums = new List<float>();
            char cmd = ' ';
            PointF cur = PointF.Empty;
            int i = 0;
            while (true)
            {
                bool end = i >= d.Length;
                char ch = end ? 'Z' : d[i];
                if (end || char.IsLetter(ch))
                {
                    if (cmd == 'M' && nums.Count >= 2) { cur = new PointF(nums[0], nums[1]); p.StartFigure(); }
                    else if (cmd == 'C')
                    {
                        for (int k = 0; k + 5 < nums.Count; k += 6)
                        {
                            PointF c1 = new PointF(nums[k], nums[k + 1]), c2 = new PointF(nums[k + 2], nums[k + 3]), e = new PointF(nums[k + 4], nums[k + 5]);
                            p.AddBezier(cur, c1, c2, e);
                            cur = e;
                        }
                    }
                    nums.Clear();
                    if (end) break;
                    cmd = ch;
                    if (cmd == 'Z') p.CloseFigure();
                    i++;
                    continue;
                }
                if (ch == ' ' || ch == ',') { i++; continue; }
                int s = i;
                i++;
                while (i < d.Length && (char.IsDigit(d[i]) || d[i] == '.')) i++;
                nums.Add(float.Parse(d.Substring(s, i - s), CultureInfo.InvariantCulture));
            }
            return p;
        }

        public static void Nova(Graphics g, RectangleF r)
        {
            Smooth(g);
            GraphicsState state = g.Save();
            float scale = Math.Min(r.Width / 160f, r.Height / 168f);
            g.TranslateTransform(r.X + (r.Width - 160 * scale) / 2f, r.Y + (r.Height - 168 * scale) / 2f);
            g.ScaleTransform(scale, scale);
            g.TranslateTransform(-20, -14);
            using (GraphicsPath head = ParsePath(NovaPaths[4].Split('|')[1]))
            {
                foreach (string spec in NovaPaths)
                {
                    string[] parts = spec.Split('|');
                    Color c = Theme.C(int.Parse(parts[0], NumberStyles.HexNumber));
                    using (GraphicsPath path = ParsePath(parts[parts.Length - 1]))
                    using (SolidBrush br = new SolidBrush(c))
                    {
                        if (parts.Length == 3)
                        {
                            Region old = g.Clip;
                            g.SetClip(head, CombineMode.Intersect);
                            g.FillPath(br, path);
                            g.Clip = old;
                        }
                        else g.FillPath(br, path);
                    }
                }
            }
            using (SolidBrush dark = new SolidBrush(Theme.Charcoal))
            using (SolidBrush white = new SolidBrush(Color.White))
            {
                g.FillEllipse(dark, 76 - 7, 110 - 9, 14, 18);
                g.FillEllipse(dark, 124 - 7, 110 - 9, 14, 18);
                g.FillEllipse(white, 78.5f - 2.4f, 106 - 2.4f, 4.8f, 4.8f);
                g.FillEllipse(white, 126.5f - 2.4f, 106 - 2.4f, 4.8f, 4.8f);
                g.FillEllipse(dark, 100 - 9, 163 - 6.5f, 18, 13);
            }
            g.Restore(state);
        }

        public static void NovaBadge(Graphics g, RectangleF r)
        {
            Smooth(g);
            using (GraphicsPath p = Rounded(r, r.Width * 0.22f))
            using (SolidBrush br = new SolidBrush(Theme.Charcoal))
                g.FillPath(br, p);
            float pad = r.Width * 0.16f;
            Nova(g, RectangleF.Inflate(r, -pad, -pad));
        }
    }
}
