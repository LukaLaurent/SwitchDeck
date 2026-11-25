using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal static class Install
    {
        public static string LocalDir { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SwitchDeck"); } }
        public static string DefaultTarget { get { return Path.Combine(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs"), "SwitchDeck"); } }
        private static string FlagPath { get { return Path.Combine(LocalDir, "install.json"); } }
        public static string IconPath { get { return Path.Combine(LocalDir, "SwitchDeck.ico"); } }
        public static string DesktopPath { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "SwitchDeck.lnk"); } }
        public static string StartMenuPath { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "SwitchDeck.lnk"); } }

        public static bool HasDesktop { get { return File.Exists(DesktopPath); } }
        public static bool HasStartMenu { get { return File.Exists(StartMenuPath); } }

        public static bool NeedsWelcome
        {
            get { return !File.Exists(FlagPath) && !HasDesktop && !HasStartMenu; }
        }

        public static bool IsInstalledCopy
        {
            get { return string.Equals(Path.GetFullPath(Program.AppRoot).TrimEnd('\\'), Path.GetFullPath(DefaultTarget).TrimEnd('\\'), StringComparison.OrdinalIgnoreCase); }
        }

        private const string UninstallKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\SwitchDeck";

        public static void Register(string target, string script)
        {
            try
            {
                string sys = Environment.SystemDirectory;
                string ico = Path.Combine(Path.Combine(target, "assets"), "icon.ico");
                using (Microsoft.Win32.RegistryKey k = Microsoft.Win32.Registry.CurrentUser.CreateSubKey(UninstallKey))
                {
                    k.SetValue("DisplayName", "SwitchDeck");
                    k.SetValue("DisplayVersion", Program.Version);
                    k.SetValue("DisplayIcon", File.Exists(ico) ? ico : IconPath);
                    k.SetValue("InstallLocation", target);
                    k.SetValue("UninstallString", "\"" + Path.Combine(sys, "conhost.exe") + "\" --headless \"" + Path.Combine(sys, @"WindowsPowerShell\v1.0\powershell.exe") +
                        "\" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\" --uninstall");
                    k.SetValue("NoModify", 1, Microsoft.Win32.RegistryValueKind.DWord);
                    k.SetValue("NoRepair", 1, Microsoft.Win32.RegistryValueKind.DWord);
                    k.SetValue("EstimatedSize", 2048, Microsoft.Win32.RegistryValueKind.DWord);
                }
                Log.Info("Registered in Apps");
            }
            catch (Exception ex) { Log.Warn("Register: " + ex.Message); }
        }

        public static string InstalledFolder
        {
            get
            {
                try
                {
                    using (Microsoft.Win32.RegistryKey k = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(UninstallKey))
                    {
                        string loc = k == null ? null : k.GetValue("InstallLocation") as string;
                        if (!string.IsNullOrEmpty(loc) && Directory.Exists(loc)) return loc;
                    }
                }
                catch { }
                return Directory.Exists(DefaultTarget) ? DefaultTarget : null;
            }
        }

        public static bool RunningFromInstall
        {
            get
            {
                string f = InstalledFolder;
                return f != null && string.Equals(Path.GetFullPath(Program.AppRoot).TrimEnd('\\'), Path.GetFullPath(f).TrimEnd('\\'), StringComparison.OrdinalIgnoreCase);
            }
        }

        public static string UninstallText()
        {
            string f = InstalledFolder;
            string t = f != null ? L.F("uninstallText", f) : L.T("uninstallTextNoCopy");
            if (!RunningFromInstall) t += "\n\n" + L.F("uninstallTextHere", Program.AppRoot);
            return t;
        }

        public static void Uninstall()
        {
            string folder = InstalledFolder;
            bool self = RunningFromInstall;
            try { Remove(DesktopPath); } catch (Exception ex) { Log.Warn(ex.Message); }
            try { Remove(StartMenuPath); } catch (Exception ex) { Log.Warn(ex.Message); }
            try { Microsoft.Win32.Registry.CurrentUser.DeleteSubKeyTree(UninstallKey, false); } catch (Exception ex) { Log.Warn(ex.Message); }
            try { Directory.Delete(LocalDir, true); } catch (Exception ex) { Log.Warn("Local folder: " + ex.Message); }
            List<string> targets = new List<string>();
            if (Directory.Exists(LocalDir)) targets.Add(LocalDir);
            if (folder != null && !self)
            {
                try { Directory.Delete(folder, true); Log.Info("Removed " + folder); }
                catch (Exception ex) { Log.Warn("Installed folder: " + ex.Message); targets.Add(folder); }
            }
            if (folder != null && self) targets.Add(folder);
            if (targets.Count == 0) return;
            string list = "";
            foreach (string t in targets) list += (list.Length > 0 ? "," : "") + "'" + t.Replace("'", "''") + "'";
            string sys = Environment.SystemDirectory;
            string cmd = "$p = " + Process.GetCurrentProcess().Id + "; try { Wait-Process -Id $p -Timeout 60 } catch { }; Start-Sleep -Milliseconds 500; " +
                         "foreach ($f in @(" + list + ")) { for ($i = 0; $i -lt 10 -and (Test-Path -LiteralPath $f); $i++) { Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 500 } }";
            ProcessStartInfo psi = new ProcessStartInfo(Path.Combine(sys, "conhost.exe"),
                "--headless \"" + Path.Combine(sys, @"WindowsPowerShell\v1.0\powershell.exe") + "\" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command \"" + cmd.Replace("\"", "\\\"") + "\"");
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.WorkingDirectory = Path.GetTempPath();
            Process.Start(psi);
        }

        public static void MarkAsked()
        {
            try
            {
                Directory.CreateDirectory(LocalDir);
                JObj o = new JObj();
                o["asked"] = true;
                o["script"] = Program.Script ?? "";
                o["time"] = DateTime.Now.ToString("o");
                File.WriteAllText(FlagPath, Json.Write(o));
            }
            catch (Exception ex) { Log.Warn("Install flag: " + ex.Message); }
        }

        public static void Refresh()
        {
            try
            {
                if (HasDesktop) Create(DesktopPath, Program.Script, Program.AppRoot);
                if (HasStartMenu) Create(StartMenuPath, Program.Script, Program.AppRoot);
            }
            catch (Exception ex) { Log.Warn("Shortcut refresh: " + ex.Message); }
        }

        public static void Set(bool desktop, bool startMenu)
        {
            Set(desktop, startMenu, Program.Script, Program.AppRoot);
        }

        public static void Set(bool desktop, bool startMenu, string script, string root)
        {
            if (desktop) Create(DesktopPath, script, root); else Remove(DesktopPath);
            if (startMenu) Create(StartMenuPath, script, root); else Remove(StartMenuPath);
        }

        public static string CopyTo(string target)
        {
            string src = Program.AppRoot;
            Directory.CreateDirectory(target);
            Directory.CreateDirectory(Path.Combine(target, "app"));
            File.Copy(Path.Combine(src, "SwitchDeck.cmd"), Path.Combine(target, "SwitchDeck.cmd"), true);
            File.Copy(Program.Script, Path.Combine(Path.Combine(target, "app"), "SwitchDeck.ps1"), true);
            CopyDir(Path.Combine(src, "assets"), Path.Combine(target, "assets"), true);
            string dataSrc = Path.Combine(Program.Root, "data");
            string dataDst = Path.Combine(target, "data");
            if (Directory.Exists(dataSrc) && !Directory.Exists(dataDst)) CopyDir(dataSrc, dataDst, false);
            Log.Info("Installed to " + target);
            return Path.Combine(Path.Combine(target, "app"), "SwitchDeck.ps1");
        }

        private static void CopyDir(string from, string to, bool overwrite)
        {
            if (!Directory.Exists(from)) return;
            Directory.CreateDirectory(to);
            foreach (string f in Directory.GetFiles(from))
            {
                string name = Path.GetFileName(f);
                if (name.EndsWith(".tmp")) continue;
                File.Copy(f, Path.Combine(to, name), overwrite);
            }
            foreach (string d in Directory.GetDirectories(from)) CopyDir(d, Path.Combine(to, Path.GetFileName(d)), overwrite);
        }

        public static void Launch(string script)
        {
            string sys = Environment.SystemDirectory;
            ProcessStartInfo psi = new ProcessStartInfo(Path.Combine(sys, "conhost.exe"),
                "--headless \"" + Path.Combine(sys, @"WindowsPowerShell\v1.0\powershell.exe") + "\" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\" --wait");
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.WorkingDirectory = Path.GetDirectoryName(Path.GetDirectoryName(script));
            Process.Start(psi);
            Log.Info("Started installed copy: " + script);
        }

        private static void Remove(string lnk)
        {
            if (!File.Exists(lnk)) return;
            File.Delete(lnk);
            Log.Info("Shortcut removed: " + lnk);
        }

        private static void Create(string lnk, string script, string root)
        {
            Directory.CreateDirectory(LocalDir);
            WriteIcon(IconPath);
            string sys = Environment.SystemDirectory;
            Type t = Type.GetTypeFromProgID("WScript.Shell");
            object shell = Activator.CreateInstance(t);
            try
            {
                object sc = t.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { lnk });
                Type st = sc.GetType();
                st.InvokeMember("TargetPath", BindingFlags.SetProperty, null, sc, new object[] { Path.Combine(sys, "conhost.exe") });
                st.InvokeMember("Arguments", BindingFlags.SetProperty, null, sc, new object[] {
                    "--headless \"" + Path.Combine(sys, @"WindowsPowerShell\v1.0\powershell.exe") + "\" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\"" });
                st.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, sc, new object[] { root });
                st.InvokeMember("Description", BindingFlags.SetProperty, null, sc, new object[] { "SwitchDeck" });
                st.InvokeMember("WindowStyle", BindingFlags.SetProperty, null, sc, new object[] { 7 });
                st.InvokeMember("IconLocation", BindingFlags.SetProperty, null, sc, new object[] { IconPath + ",0" });
                st.InvokeMember("Save", BindingFlags.InvokeMethod, null, sc, null);
                Marshal.FinalReleaseComObject(sc);
            }
            finally { Marshal.FinalReleaseComObject(shell); }
            Log.Info("Shortcut created: " + lnk);
        }

        public static void WriteIcon(string path)
        {
            int[] sizes = { 16, 24, 32, 48, 64, 256 };
            List<byte[]> images = new List<byte[]>();
            foreach (int s in sizes)
            {
                using (Bitmap b = Icons.App(s))
                using (MemoryStream ms = new MemoryStream())
                {
                    b.Save(ms, ImageFormat.Png);
                    images.Add(ms.ToArray());
                }
            }
            using (FileStream fs = File.Create(path))
            using (BinaryWriter w = new BinaryWriter(fs))
            {
                w.Write((short)0);
                w.Write((short)1);
                w.Write((short)sizes.Length);
                int offset = 6 + 16 * sizes.Length;
                for (int i = 0; i < sizes.Length; i++)
                {
                    w.Write((byte)(sizes[i] >= 256 ? 0 : sizes[i]));
                    w.Write((byte)(sizes[i] >= 256 ? 0 : sizes[i]));
                    w.Write((byte)0);
                    w.Write((byte)0);
                    w.Write((short)1);
                    w.Write((short)32);
                    w.Write(images[i].Length);
                    w.Write(offset);
                    offset += images[i].Length;
                }
                foreach (byte[] img in images) w.Write(img);
            }
        }

        public static void WriteAssets(string dir)
        {
            Directory.CreateDirectory(dir);
            using (Bitmap b = Icons.App(256)) b.Save(Path.Combine(dir, "logo.png"), ImageFormat.Png);
            using (Bitmap b = new Bitmap(128, 128, PixelFormat.Format32bppArgb))
            {
                using (Graphics g = Graphics.FromImage(b))
                {
                    g.Clear(Color.Transparent);
                    Icons.Nova(g, new RectangleF(0, 0, 128, 128));
                }
                b.Save(Path.Combine(dir, "nova.png"), ImageFormat.Png);
            }
            WriteIcon(Path.Combine(dir, "icon.ico"));
        }
    }

    internal sealed class WelcomeForm : DialogForm
    {
        private readonly Check desktop, startMenu;
        private readonly OptionRow installRow, hereRow;
        private readonly Label pathLabel;
        private readonly Btn changeBtn;
        private string target = Install.DefaultTarget;
        public string InstalledScript;

        public WelcomeForm() : base(L.T("welcomeInstallTitle"), null, 560, 560)
        {
            StartPosition = FormStartPosition.CenterScreen;
            ShowInTaskbar = true;
            Icon = Icons.MakeIcon(Math.Max(32, Ui.D(32)));
            Palette p = Theme.P;
            int L0 = Ui.D(24), W = Ui.D(512);
            ImageBox logo = new ImageBox(Icons.App(Ui.D(56)));
            logo.Location = new Point(L0, Ui.D(20));
            Body.Controls.Add(logo);
            Label name = Ui.Label("SwitchDeck", Fonts.Head(21f * Ui.Sc), p.Text);
            name.Location = new Point(Ui.D(96), Ui.D(18));
            Body.Controls.Add(name);
            AddLabel(Body, L.T("about"), Ui.D(98), Ui.D(52), Ui.D(430), false);

            int y = Ui.D(100);
            bool already = Install.IsInstalledCopy;
            installRow = new OptionRow(L.T("installHereTitle"), L.T("installHereText"), true);
            installRow.Bounds = new Rectangle(L0, y, W, Ui.D(104));
            installRow.Click += delegate { Pick(true); };
            Body.Controls.Add(installRow);
            pathLabel = Ui.Label(target, Fonts.Mono(12f * Ui.Sc), p.Muted);
            pathLabel.AutoSize = false;
            pathLabel.AutoEllipsis = true;
            pathLabel.BackColor = Color.Transparent;
            pathLabel.Bounds = new Rectangle(Ui.D(48), Ui.D(68), W - Ui.D(160), Ui.D(22));
            installRow.Controls.Add(pathLabel);
            changeBtn = new Btn(L.T("change"), "folder_open", BtnKind.Ghost, delegate { ChangeTarget(); }).Small();
            changeBtn.Location = new Point(W - changeBtn.Width - Ui.D(12), Ui.D(62));
            installRow.Controls.Add(changeBtn);
            y = installRow.Bottom + Ui.D(10);
            hereRow = new OptionRow(L.T("runHereTitle"), L.T("runHereText"), false);
            hereRow.Bounds = new Rectangle(L0, y, W, Ui.D(70));
            hereRow.Click += delegate { Pick(false); };
            Body.Controls.Add(hereRow);
            y = hereRow.Bottom + Ui.D(20);
            if (already)
            {
                installRow.Visible = hereRow.Visible = false;
                y = Ui.D(100);
            }

            desktop = new Check(L.T("shortcutDesktop"), true);
            desktop.Location = new Point(L0, y);
            Body.Controls.Add(desktop);
            startMenu = new Check(L.T("shortcutStart"), true);
            startMenu.Location = new Point(L0, y + Ui.D(32));
            Body.Controls.Add(startMenu);
            if (already) Height = Height - Ui.D(194);
            Pick(!already);

            AddButton(L.T("notNow"), null, BtnKind.Ghost, delegate { Install.MarkAsked(); DialogResult = DialogResult.Cancel; Close(); });
            AddButton(L.T("continue"), "check", BtnKind.Primary, delegate { Confirm(); });
        }

        private bool install;

        private void Pick(bool inst)
        {
            install = inst;
            installRow.Selected = inst;
            hereRow.Selected = !inst;
            installRow.Invalidate();
            hereRow.Invalidate();
            changeBtn.Enabled = inst;
        }

        private void ChangeTarget()
        {
            using (FolderBrowserDialog d = new FolderBrowserDialog())
            {
                d.Description = L.T("pickInstallFolder");
                d.SelectedPath = Path.GetDirectoryName(target);
                if (d.ShowDialog(this) != DialogResult.OK) return;
                target = Path.GetFileName(d.SelectedPath).Equals("SwitchDeck", StringComparison.OrdinalIgnoreCase) ? d.SelectedPath : Path.Combine(d.SelectedPath, "SwitchDeck");
                pathLabel.Text = target;
                Pick(true);
            }
        }

        private void Confirm()
        {
            try
            {
                if (install && installRow.Visible)
                {
                    string script = Install.CopyTo(target);
                    Install.Set(desktop.Checked, startMenu.Checked, script, target);
                    Install.MarkAsked();
                    InstalledScript = script;
                    Install.Register(target, script);
                }
                else
                {
                    Install.Set(desktop.Checked, startMenu.Checked);
                    Install.MarkAsked();
                }
                DialogResult = DialogResult.OK;
                Close();
            }
            catch (Exception ex)
            {
                Log.Error("Install: " + ex.Message);
                Dialogs.Problem(this, L.T("installFailed"), ex.Message);
            }
        }

        protected override void OnFormClosed(FormClosedEventArgs e)
        {
            if (DialogResult != DialogResult.OK) Install.MarkAsked();
            base.OnFormClosed(e);
        }
    }

    internal sealed class OptionRow : Painted
    {
        private readonly string title, text;
        public bool Selected;

        public OptionRow(string title, string text, bool selected)
        {
            this.title = title;
            this.text = text;
            Selected = selected;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = Prepare(e);
            Palette p = Theme.P;
            RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            Ui.FillRound(g, r, 12 * Sc, Selected ? p.OrangeSoft : (Hover ? p.HoverFill : p.Surface2));
            Ui.StrokeRound(g, r, 12 * Sc, Selected ? p.Orange : p.Border, Selected ? 1.6f * Sc : Math.Max(1f, Sc));
            Icons.Draw(g, Selected ? "radio_button_checked" : "radio_button_unchecked", new RectangleF(D(14), D(14), D(22), D(22)), Selected ? p.Orange : p.Faint, 20 * Sc, false);
            Ui.Text(g, title, Fonts.Strong(14f * Sc), new Rectangle(D(48), D(13), Width - D(60), D(24)), p.Text, Ui.Left);
            Ui.Text(g, text, Fonts.Body(12.5f * Sc), new Rectangle(D(48), D(37), Width - D(60), D(22)), p.Muted, Ui.Left);
        }
    }
}
