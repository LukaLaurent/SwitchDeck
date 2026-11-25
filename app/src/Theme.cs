using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Text;
using System.IO;
using Microsoft.Win32;

namespace SwitchDeck
{
    internal sealed class Palette
    {
        public bool Dark;
        public Color Bg, Surface, Surface2, Border, Track, HoverFill, Text, Muted, Faint;
        public Color Orange, OrangeHover, OrangeSoft, OnOrange;
        public Color Teal, TealSoft, Success, SuccessSoft, Warning, WarningSoft, Danger, DangerSoft;
        public Color Shadow;
    }

    internal sealed class TermPalette
    {
        public Color Bg, Fg, Dim, Cursor, Selection, Bar;
        public Color[] Ansi = new Color[16];
    }

    internal static class Theme
    {
        public static Palette P = Make(false);
        public static TermPalette T = MakeTerm(true);
        public static event Action Changed;

        public static Color C(int rgb) { return Color.FromArgb(255, (rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255); }

        public static readonly Color Charcoal = C(0x20252B);
        public static readonly Color Orange = C(0xF28C28);
        public static readonly Color OffWhite = C(0xF5F3EF);
        public static readonly Color TealBase = C(0x527C82);

        public static readonly Color[] Accents =
        {
            C(0xF28C28), C(0x527C82), C(0x3E9B6A), C(0xE0A526), C(0xD64545), C(0x7A6FC7), C(0x3D8BD1), C(0x9AA0A6)
        };

        public static Palette Make(bool dark)
        {
            Palette p = new Palette();
            p.Dark = dark;
            p.Orange = Orange;
            p.OnOrange = Charcoal;
            if (!dark)
            {
                p.Bg = C(0xF5F3EF); p.Surface = C(0xFFFFFF); p.Surface2 = C(0xFAF9F7); p.Border = C(0xE5E7EB);
                p.Track = C(0xD3D6DB); p.HoverFill = C(0xEFECE7);
                p.Text = C(0x20252B); p.Muted = C(0x5E656D); p.Faint = C(0x9AA0A6);
                p.OrangeHover = C(0xE07B18); p.OrangeSoft = C(0xFDEEDD);
                p.Teal = C(0x527C82); p.TealSoft = C(0xE4EDEE);
                p.Success = C(0x3E9B6A); p.SuccessSoft = C(0xE2F2E9);
                p.Warning = C(0xC98E12); p.WarningSoft = C(0xFBF1D9);
                p.Danger = C(0xD64545); p.DangerSoft = C(0xFBE4E4);
                p.Shadow = Color.FromArgb(26, 32, 37, 43);
            }
            else
            {
                p.Bg = C(0x16191D); p.Surface = C(0x20252B); p.Surface2 = C(0x2A3038); p.Border = C(0x343B44);
                p.Track = C(0x434B55); p.HoverFill = C(0x2C323A);
                p.Text = C(0xF5F3EF); p.Muted = C(0xA3AAB1); p.Faint = C(0x6F767E);
                p.OrangeHover = C(0xF59D47); p.OrangeSoft = C(0x3A2D21);
                p.Teal = C(0x6A979D); p.TealSoft = C(0x243337);
                p.Success = C(0x52B582); p.SuccessSoft = C(0x1F3229);
                p.Warning = C(0xE0A526); p.WarningSoft = C(0x3A3120);
                p.Danger = C(0xE36A6A); p.DangerSoft = C(0x3D2426);
                p.Shadow = Color.FromArgb(90, 0, 0, 0);
            }
            return p;
        }

        public static TermPalette MakeTerm(bool dark)
        {
            TermPalette t = new TermPalette();
            if (dark)
            {
                t.Bg = C(0x14171B); t.Fg = C(0xE6E3DD); t.Dim = C(0x7D848C); t.Cursor = Orange;
                t.Selection = Color.FromArgb(255, 0x3E, 0x4A, 0x57); t.Bar = C(0x1B1F24);
                int[] a = { 0x1E2227, 0xE36A6A, 0x52B582, 0xE0A526, 0x5A9BD8, 0xB48EE0, 0x6A979D, 0xD8D5CF,
                            0x5E656D, 0xF08A8A, 0x7DCFA2, 0xF2C45A, 0x86B8EA, 0xCDB0F0, 0x93BFC4, 0xFFFFFF };
                for (int i = 0; i < 16; i++) t.Ansi[i] = C(a[i]);
            }
            else
            {
                t.Bg = C(0xFFFFFF); t.Fg = C(0x20252B); t.Dim = C(0x8A9098); t.Cursor = C(0xE07B18);
                t.Selection = C(0xFBDDBD); t.Bar = C(0xFAF9F7);
                int[] a = { 0x20252B, 0xC13B3B, 0x2E8257, 0xA57409, 0x2F6FB0, 0x7A4FB8, 0x456A70, 0x8A9098,
                            0x5E656D, 0xD64545, 0x3E9B6A, 0xC98E12, 0x3D8BD1, 0x9466D1, 0x527C82, 0x20252B };
                for (int i = 0; i < 16; i++) t.Ansi[i] = C(a[i]);
            }
            return t;
        }

        public static string Mode = "system";
        public static string TermMode = "dark";

        public static void Apply(string mode, string termMode)
        {
            Mode = mode;
            TermMode = termMode;
            bool dark = mode == "dark" || (mode == "system" && SystemIsDark());
            P = Make(dark);
            T = MakeTerm(termMode == "dark" || (termMode == "theme" && dark));
            Action h = Changed;
            if (h != null) h();
        }

        public static bool SystemIsDark()
        {
            try
            {
                using (RegistryKey k = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"))
                {
                    object v = k == null ? null : k.GetValue("AppsUseLightTheme");
                    return v is int && (int)v == 0;
                }
            }
            catch { return false; }
        }

        public static Color Mix(Color a, Color b, float t)
        {
            return Color.FromArgb(
                (int)Math.Round(a.R + (b.R - a.R) * t),
                (int)Math.Round(a.G + (b.G - a.G) * t),
                (int)Math.Round(a.B + (b.B - a.B) * t));
        }
    }

    internal static class Fonts
    {
        private static readonly Dictionary<string, Font> cache = new Dictionary<string, Font>();
        private static readonly PrivateFontCollection pfc = new PrivateFontCollection();
        private static readonly Dictionary<string, FontFamily> families = new Dictionary<string, FontFamily>(StringComparer.OrdinalIgnoreCase);
        private static string head, body, strong, mono, monoBold, symbols, symbolsFill;
        private static bool loaded;

        public static void Load(string dir)
        {
            if (loaded) return;
            loaded = true;
            string[] files = { "Poppins-SemiBold.ttf", "Poppins-Medium.ttf", "Inter-Regular.ttf", "Inter-SemiBold.ttf",
                               "JetBrainsMono-Regular.ttf", "JetBrainsMono-Bold.ttf", "Symbols.ttf", "Symbols-Fill.ttf" };
            foreach (string f in files)
            {
                string path = Path.Combine(dir, f);
                if (!File.Exists(path)) continue;
                try
                {
                    Native.AddFontResourceEx(path, 0x10, IntPtr.Zero);
                    pfc.AddFontFile(path);
                }
                catch (Exception ex) { Log.Warn("Font " + f + ": " + ex.Message); }
            }
            foreach (FontFamily fam in pfc.Families) families[fam.Name] = fam;
            head = Pick("SD Poppins SemiBold", "Segoe UI Semibold");
            body = Pick("SD Inter", "Segoe UI");
            strong = Pick("SD Inter SemiBold", "Segoe UI Semibold");
            mono = Pick("SD JetBrains Mono", "Consolas");
            monoBold = Pick("SD JetBrains Mono Bold", "Consolas");
            symbols = Pick("SD Symbols", null);
            symbolsFill = Pick("SD Symbols Fill", symbols);
        }

        public static bool HasSymbols { get { return symbols != null; } }

        private static string Pick(string name, string fallback)
        {
            return families.ContainsKey(name) ? name : fallback;
        }

        public static Font Head(float px) { return Get(head ?? "Segoe UI Semibold", px); }
        public static Font Body(float px) { return Get(body ?? "Segoe UI", px); }
        public static Font Strong(float px) { return Get(strong ?? "Segoe UI Semibold", px); }
        public static Font Mono(float px) { return Get(mono ?? "Consolas", px); }
        public static Font MonoBold(float px) { return Get(monoBold ?? "Consolas", px); }
        public static Font Symbol(float px, bool fill) { return Get((fill ? symbolsFill : symbols) ?? "Segoe UI Symbol", px); }

        private static Font Get(string family, float px)
        {
            px = (float)Math.Round(px, 1);
            string key = family + "|" + px;
            Font f;
            lock (cache)
            {
                if (!cache.TryGetValue(key, out f))
                {
                    FontFamily fam;
                    if (families.TryGetValue(family, out fam)) f = new Font(fam, px, FontStyle.Regular, GraphicsUnit.Pixel);
                    else f = new Font(family, px, FontStyle.Regular, GraphicsUnit.Pixel);
                    cache[key] = f;
                }
            }
            return f;
        }
    }
}
