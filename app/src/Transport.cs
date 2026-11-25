using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.IO.Ports;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32.SafeHandles;

namespace SwitchDeck
{
    internal interface ITransport : IDisposable
    {
        event Action<byte[], int> Data;
        event Action<string> Closed;
        void Start(int cols, int rows);
        void Write(byte[] data);
        void Resize(int cols, int rows);
        void SendBreak();
        bool IsOpen { get; }
        bool LocalEcho { get; }
    }

    internal sealed class ConPtyTransport : ITransport
    {
        private readonly string app, args;
        private IntPtr pc = IntPtr.Zero;
        private PROCESS_INFORMATION pi;
        private FileStream input, output;
        private Thread reader, waiter;
        private volatile bool open;
        private int closedFlag;
        private readonly object writeGate = new object();
        public event Action<byte[], int> Data;
        public event Action<string> Closed;

        public ConPtyTransport(string app, string args)
        {
            this.app = app;
            this.args = args;
        }

        public bool IsOpen { get { return open; } }
        public bool LocalEcho { get { return false; } }

        public void Start(int cols, int rows)
        {
            SafeFileHandle inRead, inWrite, outRead, outWrite;
            if (!Native.CreatePipe(out inRead, out inWrite, IntPtr.Zero, 0)) throw new Win32Exception();
            if (!Native.CreatePipe(out outRead, out outWrite, IntPtr.Zero, 0)) throw new Win32Exception();
            int hr = Native.CreatePseudoConsole(new COORD((short)Math.Max(20, cols), (short)Math.Max(5, rows)), inRead, outWrite, 0, out pc);
            if (hr != 0) throw new Win32Exception(hr);
            inRead.Dispose();
            outWrite.Dispose();

            IntPtr size = IntPtr.Zero;
            Native.InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref size);
            IntPtr list = Marshal.AllocHGlobal(size);
            try
            {
                if (!Native.InitializeProcThreadAttributeList(list, 1, 0, ref size)) throw new Win32Exception();
                if (!Native.UpdateProcThreadAttribute(list, 0, Native.PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, pc, (IntPtr)IntPtr.Size, IntPtr.Zero, IntPtr.Zero))
                    throw new Win32Exception();
                STARTUPINFOEX si = new STARTUPINFOEX();
                si.StartupInfo.cb = Marshal.SizeOf(typeof(STARTUPINFOEX));
                si.StartupInfo.dwFlags = 0x100;
                si.lpAttributeList = list;
                string cmd = "\"" + app + "\" " + args;
                if (!Native.CreateProcess(null, cmd, IntPtr.Zero, IntPtr.Zero, false, Native.EXTENDED_STARTUPINFO_PRESENT, IntPtr.Zero, Path.GetDirectoryName(app), ref si, out pi))
                    throw new Win32Exception();
                Native.DeleteProcThreadAttributeList(list);
            }
            finally { Marshal.FreeHGlobal(list); }

            input = new FileStream(inWrite, FileAccess.Write, 1);
            output = new FileStream(outRead, FileAccess.Read, 1);
            open = true;
            reader = new Thread(ReadLoop);
            reader.IsBackground = true;
            reader.Name = "pty-read";
            reader.Start();
            waiter = new Thread(WaitLoop);
            waiter.IsBackground = true;
            waiter.Name = "pty-wait";
            waiter.Start();
        }

        private void ReadLoop()
        {
            byte[] buf = new byte[16384];
            try
            {
                while (true)
                {
                    int n = output.Read(buf, 0, buf.Length);
                    if (n <= 0) break;
                    Action<byte[], int> d = Data;
                    if (d != null) d(buf, n);
                }
            }
            catch (Exception ex) { if (open) Log.Info("pty read ended: " + ex.Message); }
            Finish(null);
        }

        private void WaitLoop()
        {
            try
            {
                Native.WaitForSingleObject(pi.hProcess, 0xFFFFFFFF);
                uint code;
                Native.GetExitCodeProcess(pi.hProcess, out code);
                Thread.Sleep(150);
                ClosePc();
                Finish(code == 0 ? null : "exit " + code);
            }
            catch { }
        }

        private void ClosePc()
        {
            IntPtr h = Interlocked.Exchange(ref pc, IntPtr.Zero);
            if (h != IntPtr.Zero)
            {
                Thread t = new Thread(delegate() { try { Native.ClosePseudoConsole(h); } catch { } });
                t.IsBackground = true;
                t.Start();
                t.Join(3000);
            }
        }

        private void Finish(string reason)
        {
            if (Interlocked.Exchange(ref closedFlag, 1) != 0) return;
            open = false;
            Action<string> c = Closed;
            if (c != null) c(reason);
        }

        public void Write(byte[] data)
        {
            if (!open) return;
            try
            {
                lock (writeGate)
                {
                    input.Write(data, 0, data.Length);
                    input.Flush();
                }
            }
            catch (Exception ex) { Log.Warn("pty write: " + ex.Message); }
        }

        public void Resize(int cols, int rows)
        {
            IntPtr h = pc;
            if (h != IntPtr.Zero) Native.ResizePseudoConsole(h, new COORD((short)Math.Max(20, cols), (short)Math.Max(5, rows)));
        }

        public void SendBreak() { }

        public void Dispose()
        {
            open = false;
            try { if (pi.hProcess != IntPtr.Zero) Native.TerminateProcess(pi.hProcess, 1); } catch { }
            ClosePc();
            try { if (input != null) input.Dispose(); } catch { }
            try { if (output != null) output.Dispose(); } catch { }
            try
            {
                if (pi.hProcess != IntPtr.Zero) Native.CloseHandle(pi.hProcess);
                if (pi.hThread != IntPtr.Zero) Native.CloseHandle(pi.hThread);
            }
            catch { }
            pi = new PROCESS_INFORMATION();
            Finish(null);
        }
    }

    internal static class Ssh
    {
        private static HashSet<string> kex, ciphers, keys, macs;

        public static string Exe
        {
            get
            {
                string p = Path.Combine(Environment.SystemDirectory, @"OpenSSH\ssh.exe");
                if (File.Exists(p)) return p;
                string sysnative = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), @"Sysnative\OpenSSH\ssh.exe");
                return File.Exists(sysnative) ? sysnative : null;
            }
        }

        public static string KeyGen
        {
            get
            {
                string p = Path.Combine(Environment.SystemDirectory, @"OpenSSH\ssh-keygen.exe");
                return File.Exists(p) ? p : null;
            }
        }

        public static string KnownHosts { get { return Path.Combine(Program.DataDir, "known_hosts"); } }

        private static HashSet<string> Query(string what)
        {
            HashSet<string> r = new HashSet<string>(StringComparer.Ordinal);
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo(Exe, "-Q " + what);
                psi.UseShellExecute = false;
                psi.RedirectStandardOutput = true;
                psi.CreateNoWindow = true;
                using (Process p = Process.Start(psi))
                {
                    string all = p.StandardOutput.ReadToEnd();
                    p.WaitForExit(3000);
                    foreach (string l in all.Split('\n')) if (l.Trim().Length > 0) r.Add(l.Trim());
                }
            }
            catch (Exception ex) { Log.Warn("ssh -Q " + what + ": " + ex.Message); }
            return r;
        }

        private static string Plus(HashSet<string> have, params string[] wanted)
        {
            List<string> ok = new List<string>();
            foreach (string w in wanted) if (have.Contains(w)) ok.Add(w);
            return ok.Count == 0 ? null : "+" + string.Join(",", ok.ToArray());
        }

        public static string Arguments(Host h)
        {
            StringBuilder sb = new StringBuilder();
            Directory.CreateDirectory(Program.DataDir);
            sb.Append("-o \"UserKnownHostsFile=" + KnownHosts + "\" ");
            sb.Append("-o StrictHostKeyChecking=ask -o ConnectTimeout=12 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 ");
            sb.Append("-o NumberOfPasswordPrompts=3 -o PreferredAuthentications=keyboard-interactive,password,publickey ");
            sb.Append("-o HashKnownHosts=no -o LogLevel=ERROR ");
            if (h.Kind == "ssh")
            {
                if (kex == null)
                {
                    kex = Query("kex"); ciphers = Query("cipher"); keys = Query("key"); macs = Query("mac");
                }
                string k = Plus(kex, "diffie-hellman-group14-sha1", "diffie-hellman-group-exchange-sha1", "diffie-hellman-group1-sha1");
                string c = Plus(ciphers, "aes128-cbc", "aes256-cbc", "3des-cbc");
                string hk = Plus(keys, "ssh-rsa");
                string m = Plus(macs, "hmac-sha1", "hmac-sha1-96");
                if (k != null) sb.Append("-o KexAlgorithms=" + k + " ");
                if (c != null) sb.Append("-o Ciphers=" + c + " ");
                if (hk != null) sb.Append("-o HostKeyAlgorithms=" + hk + " -o PubkeyAcceptedAlgorithms=" + hk + " ");
                if (m != null) sb.Append("-o MACs=" + m + " ");
            }
            if (h.Port > 0 && h.Port != 22) sb.Append("-p " + h.Port + " ");
            if (h.Username.Length > 0) sb.Append("-l \"" + h.Username.Replace("\"", "") + "\" ");
            sb.Append(h.Address.Trim());
            return sb.ToString();
        }

        public static void ForgetKey(string address)
        {
            try
            {
                if (KeyGen == null || !File.Exists(KnownHosts)) return;
                ProcessStartInfo psi = new ProcessStartInfo(KeyGen, "-R \"" + address + "\" -f \"" + KnownHosts + "\"");
                psi.UseShellExecute = false;
                psi.CreateNoWindow = true;
                psi.RedirectStandardOutput = true;
                psi.RedirectStandardError = true;
                using (Process p = Process.Start(psi)) p.WaitForExit(5000);
                Log.Info("Removed saved key for " + address);
            }
            catch (Exception ex) { Log.Warn("ssh-keygen -R: " + ex.Message); }
        }
    }

    internal sealed class SerialTransport : ITransport
    {
        private readonly string portName;
        private readonly int baud;
        private SerialPort port;
        private volatile bool open;
        private int closedFlag;
        public event Action<byte[], int> Data;
        public event Action<string> Closed;

        public SerialTransport(string portName, int baud)
        {
            this.portName = portName;
            this.baud = baud;
        }

        public bool IsOpen { get { return open; } }
        public bool LocalEcho { get { return false; } }

        public void Start(int cols, int rows)
        {
            port = new SerialPort(portName, baud, Parity.None, 8, StopBits.One);
            port.Handshake = Handshake.None;
            port.DtrEnable = true;
            port.RtsEnable = true;
            port.ReadTimeout = 500;
            port.WriteTimeout = 2000;
            port.Encoding = Encoding.GetEncoding(28591);
            port.Open();
            open = true;
            Thread t = new Thread(ReadLoop);
            t.IsBackground = true;
            t.Name = "serial-read";
            t.Start();
        }

        private void ReadLoop()
        {
            byte[] buf = new byte[4096];
            string reason = null;
            while (open)
            {
                try
                {
                    int n = port.BaseStream.Read(buf, 0, buf.Length);
                    if (n > 0)
                    {
                        Action<byte[], int> d = Data;
                        if (d != null) d(buf, n);
                    }
                }
                catch (TimeoutException) { }
                catch (IOException ex) { if (open) reason = ex.Message; break; }
                catch (InvalidOperationException ex) { if (open) reason = ex.Message; break; }
                catch (UnauthorizedAccessException ex) { if (open) reason = ex.Message; break; }
            }
            Finish(reason);
        }

        private void Finish(string reason)
        {
            if (Interlocked.Exchange(ref closedFlag, 1) != 0) return;
            open = false;
            Action<string> c = Closed;
            if (c != null) c(reason);
        }

        public void Write(byte[] data)
        {
            if (!open) return;
            try { port.Write(data, 0, data.Length); }
            catch (Exception ex) { Log.Warn("serial write: " + ex.Message); }
        }

        public void Resize(int cols, int rows) { }

        public void SendBreak()
        {
            if (!open) return;
            try
            {
                port.BreakState = true;
                Thread.Sleep(400);
                port.BreakState = false;
            }
            catch (Exception ex) { Log.Warn("serial break: " + ex.Message); }
        }

        public void Dispose()
        {
            open = false;
            try { if (port != null) { port.Close(); port.Dispose(); } } catch { }
            Finish(null);
        }
    }

    internal sealed class DemoTransport : ITransport
    {
        private readonly DemoSwitch device;
        private readonly Queue<byte[]> inbox = new Queue<byte[]>();
        private readonly AutoResetEvent signal = new AutoResetEvent(false);
        private volatile bool open;
        private int closedFlag;
        public event Action<byte[], int> Data;
        public event Action<string> Closed;

        public DemoTransport(DemoSwitch device)
        {
            this.device = device;
        }

        public bool IsOpen { get { return open; } }
        public bool LocalEcho { get { return false; } }

        public void Start(int cols, int rows)
        {
            open = true;
            device.Output = Emit;
            device.Quit = delegate { Finish(null); };
            Thread t = new Thread(Loop);
            t.IsBackground = true;
            t.Name = "demo-switch";
            t.Start();
        }

        private void Emit(string s)
        {
            if (!open) return;
            byte[] b = Encoding.UTF8.GetBytes(s);
            Action<byte[], int> d = Data;
            if (d != null) d(b, b.Length);
        }

        private void Loop()
        {
            try
            {
                Thread.Sleep(350);
                device.Boot();
                while (open)
                {
                    signal.WaitOne(200);
                    while (open)
                    {
                        byte[] b;
                        lock (inbox)
                        {
                            if (inbox.Count == 0) break;
                            b = inbox.Dequeue();
                        }
                        foreach (byte x in b) { if (!open) break; device.Key((char)x); }
                    }
                }
            }
            catch (Exception ex) { Log.Error("Demo switch: " + ex); Finish(ex.Message); }
        }

        private void Finish(string reason)
        {
            if (Interlocked.Exchange(ref closedFlag, 1) != 0) return;
            open = false;
            Action<string> c = Closed;
            if (c != null) c(reason);
        }

        public void Write(byte[] data)
        {
            if (!open) return;
            lock (inbox) inbox.Enqueue((byte[])data.Clone());
            signal.Set();
        }

        public void Resize(int cols, int rows) { }
        public void SendBreak() { }

        public void Dispose()
        {
            open = false;
            signal.Set();
            Finish(null);
        }
    }
}
