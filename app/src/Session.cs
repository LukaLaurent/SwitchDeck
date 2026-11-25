using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

namespace SwitchDeck
{
    internal enum SessionState { Connecting, Connected, Closed }

    internal sealed class StopException : Exception
    {
        public StopException() : base(L.T("stopped")) { }
    }

    internal sealed class Session : IDisposable
    {
        private static readonly Regex Ansi = new Regex(@"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b[()][0-9A-Za-z]|\x1b[=>78DEMc]", RegexOptions.Compiled);
        private static readonly Regex HostKeyRx = new Regex(@"continue connecting \(yes/no(/\[fingerprint\])?\)\?\s*$", RegexOptions.Compiled);
        private static readonly Regex PasswordRx = new Regex(@"(?i)(password|passcode)\s*:\s*$", RegexOptions.Compiled);
        private static readonly Regex UserRx = new Regex(@"(?i)(username|login)\s*:\s*$", RegexOptions.Compiled);

        public readonly Host Host;
        public readonly Vt Term;
        private ITransport transport;
        private readonly Decoder decoder = Encoding.UTF8.GetDecoder();
        private readonly StringBuilder tail = new StringBuilder();
        private DateTime lastData = DateTime.Now;
        private int passwordsSent, enableSent, usersSent;
        private bool hostKeyAsked, enableTried, keyChanged;
        private bool prepared;
        private volatile bool busy;
        private volatile bool stopRequested;
        private StreamWriter logWriter;
        private readonly object logGate = new object();
        private readonly StringBuilder transcript = new StringBuilder();
        private bool capture;

        public SessionState State = SessionState.Connecting;
        public string Hostname = "";
        public string CloseReason;
        public string Status = "";
        public DateTime Started = DateTime.Now;

        public event Action Changed;
        public event Action<string> HostKeyPrompt;
        public event Action<string> Notice;

        public Session(Host host, int cols, int rows)
        {
            Host = host;
            Term = new Vt(cols, rows);
            Term.Reply += delegate(string s) { RawSend(s); };
        }

        public bool Busy { get { return busy; } }

        private string EnableSecret
        {
            get
            {
                string e = Secret.Reveal(Host.Enable);
                return e.Length > 0 ? e : Secret.Reveal(Host.Password);
            }
        }
        public bool IsOpen { get { return transport != null && transport.IsOpen; } }
        public bool HostKeyChanged { get { return keyChanged; } }

        public void Start()
        {
            ITransport old = transport;
            transport = null;
            if (old != null)
            {
                old.Data -= OnData;
                old.Closed -= OnClosed;
                try { old.Dispose(); } catch { }
            }
            State = SessionState.Connecting;
            CloseReason = null;
            passwordsSent = enableSent = usersSent = 0;
            hostKeyAsked = enableTried = keyChanged = prepared = false;
            Started = DateTime.Now;
            OpenLog();
            Banner(L.F("connectingTo", Host.Name, Host.Target));
            try
            {
                if (Host.Kind == "serial") transport = new SerialTransport(Host.ComPort, Host.Baud);
                else if (Host.Kind == "demo") transport = new DemoTransport(new DemoSwitch(Host.Id, Host.DemoModel, EnableSecret));
                else
                {
                    string exe = Ssh.Exe;
                    if (exe == null) throw new InvalidOperationException(L.T("noSsh"));
                    if (Host.Address.Trim().Length == 0) throw new InvalidOperationException(L.T("noAddress"));
                    transport = new ConPtyTransport(exe, Ssh.Arguments(Host));
                }
                transport.Data += OnData;
                transport.Closed += OnClosed;
                transport.Start(Term.Cols, Term.Rows);
                if (Host.Kind == "serial")
                {
                    State = SessionState.Connected;
                    Thread.Sleep(200);
                    RawSend("\r");
                }
                Log.Info("Session opened: " + Host.Name + " (" + Host.Kind + " " + Host.Target + ")");
            }
            catch (Exception ex)
            {
                Log.Error("Could not connect to " + Host.Name + ": " + ex.Message);
                CloseReason = ex.Message;
                State = SessionState.Closed;
                Banner(L.F("connectFailed", ex.Message));
                if (transport != null) { try { transport.Dispose(); } catch { } transport = null; }
            }
            Raise();
        }

        private void Banner(string text)
        {
            Term.Feed("\x1b[0m\r\n\x1b[38;5;208m" + text + "\x1b[0m\r\n");
            Raise();
        }

        private void OpenLog()
        {
            lock (logGate)
            {
                CloseLog();
                if (!Store.Settings.SessionLogs) return;
                try
                {
                    string dir = Path.Combine(Program.LogsDir, "sessions");
                    Directory.CreateDirectory(dir);
                    string file = Path.Combine(dir, Store.SafeName(Host.Name) + "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".log");
                    logWriter = new StreamWriter(file, true, new UTF8Encoding(false));
                    logWriter.AutoFlush = true;
                    logWriter.WriteLine("# " + Host.Name + " " + Host.Target + " " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
                }
                catch (Exception ex) { Log.Warn("Session log: " + ex.Message); logWriter = null; }
            }
        }

        private void CloseLog()
        {
            if (logWriter != null)
            {
                try { logWriter.Dispose(); } catch { }
                logWriter = null;
            }
        }

        private void OnData(byte[] buf, int n)
        {
            char[] chars = new char[decoder.GetCharCount(buf, 0, n)];
            decoder.GetChars(buf, 0, n, chars, 0);
            string s = new string(chars);
            lastData = DateTime.Now;
            Term.Feed(s);
            string plain = Ansi.Replace(s, "");
            lock (logGate)
            {
                if (logWriter != null)
                {
                    try { logWriter.Write(plain.Replace("\r\n", "\n").Replace("\r", "").Replace("\n", Environment.NewLine)); } catch { }
                }
                if (capture && transcript.Length < 400000) transcript.Append(plain.Replace("\r", ""));
            }
            tail.Append(plain);
            if (tail.Length > 600) tail.Remove(0, tail.Length - 600);
            Watch();
            Raise();
        }

        private long answeredAbs = -1;

        private void Watch()
        {
            string t = tail.ToString();
            long curAbs = Term.CursorAbs;
            string lastLine = Term.CursorLineText();
            if (t.Contains("REMOTE HOST IDENTIFICATION HAS CHANGED") && !keyChanged)
            {
                keyChanged = true;
                Action<string> nt = Notice;
                if (nt != null) nt("hostkey-changed");
            }
            if (Host.Kind == "ssh" && !hostKeyAsked && (HostKeyRx.IsMatch(lastLine) || HostKeyRx.IsMatch(t.TrimEnd())))
            {
                hostKeyAsked = true;
                answeredAbs = curAbs;
                string fp = "";
                Match m = Regex.Match(t, @"key fingerprint is (\S+?)\.?\s");
                if (m.Success) fp = m.Groups[1].Value;
                Match kt = Regex.Match(t, @"(\S+) key fingerprint is");
                if (kt.Success) fp = kt.Groups[1].Value + " " + fp;
                Action<string> h = HostKeyPrompt;
                if (h != null) ThreadPool.QueueUserWorkItem(delegate { h(fp); });
                else RawSend("no\r");
                return;
            }
            bool fresh = curAbs != answeredAbs;
            if (fresh && UserRx.IsMatch(lastLine) && lastLine.Length < 40 && usersSent < 2 && Host.Username.Length > 0 && Host.Kind != "ssh")
            {
                answeredAbs = curAbs;
                usersSent++;
                RawSend(Host.Username + "\r");
                return;
            }
            if (fresh && PasswordRx.IsMatch(lastLine) && lastLine.Length < 80)
            {
                answeredAbs = curAbs;
                bool enablePrompt = enableTried && State == SessionState.Connected;
                if (enablePrompt)
                {
                    if (enableSent == 0 && !busy)
                    {
                        enableSent++;
                        RawSend(EnableSecret + "\r");
                    }
                    return;
                }
                string pw = Secret.Reveal(Host.Password);
                if (passwordsSent == 0 && pw.Length > 0)
                {
                    passwordsSent++;
                    RawSend(pw + "\r");
                    return;
                }
                if (passwordsSent == 1)
                {
                    passwordsSent++;
                    Action<string> nt = Notice;
                    if (nt != null) nt("password-rejected");
                }
                return;
            }
            string trimmed = lastLine.TrimEnd();
            if (Cisco.IsPrompt(trimmed))
            {
                if (State != SessionState.Connected)
                {
                    State = SessionState.Connected;
                    Host.LastConnected = DateTime.Now;
                }
                Hostname = Cisco.Hostname(trimmed);
                if (trimmed.EndsWith(">") && !enableTried && EnableSecret.Length > 0 && !busy)
                {
                    enableTried = true;
                    RawSend("enable\r");
                }
                else if (trimmed.EndsWith("#") && !enableTried) enableTried = true;
            }
        }

        private void ClearTail() { tail.Length = 0; }

        public void AnswerHostKey(bool trust)
        {
            RawSend(trust ? "yes\r" : "no\r");
        }

        private void OnClosed(string reason)
        {
            State = SessionState.Closed;
            CloseReason = reason;
            Banner(reason == null ? L.T("connectionClosed") : L.F("connectionClosedWhy", reason));
            lock (logGate) CloseLog();
            Log.Info("Session closed: " + Host.Name + (reason == null ? "" : " (" + reason + ")"));
            Raise();
        }

        private void Raise()
        {
            Action c = Changed;
            if (c != null) c();
        }

        public void RawSend(string s)
        {
            ITransport t = transport;
            if (t == null || !t.IsOpen) return;
            t.Write(Encoding.UTF8.GetBytes(s));
        }

        public void UserSend(string s)
        {
            if (busy) return;
            RawSend(s);
        }

        public void Resize(int cols, int rows)
        {
            Term.Resize(cols, rows);
            ITransport t = transport;
            if (t != null) t.Resize(cols, rows);
        }

        public void SendBreak()
        {
            ITransport t = transport;
            if (t != null) t.SendBreak();
        }

        public void Disconnect()
        {
            ITransport t = transport;
            transport = null;
            if (t != null)
            {
                try { t.Dispose(); } catch { }
            }
            if (State != SessionState.Closed)
            {
                State = SessionState.Closed;
                Banner(L.T("connectionClosed"));
                lock (logGate) CloseLog();
            }
            Raise();
        }

        public void Reconnect()
        {
            Disconnect();
            Start();
        }

        public void Dispose()
        {
            ITransport t = transport;
            transport = null;
            if (t != null) { try { t.Dispose(); } catch { } }
            lock (logGate) CloseLog();
        }

        public void BeginBusy(string status)
        {
            busy = true;
            stopRequested = false;
            Status = status;
            Raise();
        }

        public void EndBusy()
        {
            busy = false;
            Status = "";
            Raise();
        }

        public void SetStatus(string status)
        {
            Status = status;
            Raise();
        }

        public void RequestStop() { stopRequested = true; }
        public bool StopRequested { get { return stopRequested; } }

        public void BeginTranscript()
        {
            lock (logGate) { transcript.Length = 0; capture = true; }
        }

        public string EndTranscript()
        {
            lock (logGate)
            {
                capture = false;
                string r = transcript.ToString();
                transcript.Length = 0;
                return r;
            }
        }

        private void Check()
        {
            if (stopRequested) throw new StopException();
            if (State == SessionState.Connecting && (DateTime.Now - Started).TotalSeconds < 120) return;
            if (!IsOpen) throw new InvalidOperationException(State == SessionState.Closed && CloseReason != null ? CloseReason : L.T("notConnected"));
        }

        public string CursorLine { get { return Term.CursorLineText().TrimEnd(); } }

        public bool AtPrompt
        {
            get
            {
                string l = CursorLine;
                return Cisco.IsPrompt(l) && Term.CursorCol >= l.Length;
            }
        }

        public void WaitReady(int timeoutMs)
        {
            DateTime end = DateTime.Now.AddMilliseconds(timeoutMs);
            bool nudged = false;
            while (true)
            {
                Check();
                if (State == SessionState.Connected && AtPrompt && (DateTime.Now - lastData).TotalMilliseconds > 250)
                {
                    if (!CursorLine.EndsWith(">") || EnableSecret.Length == 0 || enableSent > 0 || (DateTime.Now - lastData).TotalMilliseconds > 2500)
                        return;
                }
                if (!nudged && State == SessionState.Connected && (DateTime.Now - lastData).TotalMilliseconds > 1500 && !AtPrompt)
                {
                    nudged = true;
                    RawSend("\r");
                }
                if (DateTime.Now > end) throw new TimeoutException(L.T("noPrompt"));
                Thread.Sleep(40);
            }
        }

        public void Prepare()
        {
            if (prepared) return;
            Run("terminal length 0", 8000);
            Run("terminal width 512", 8000);
            prepared = true;
        }

        public void EnsureEnable()
        {
            string l = CursorLine;
            if (l.EndsWith("#")) return;
            string secret = EnableSecret;
            long start = Term.CursorAbs;
            RawSend("enable\r");
            DateTime end = DateTime.Now.AddSeconds(10);
            bool sent = false;
            while (DateTime.Now < end)
            {
                Check();
                Thread.Sleep(50);
                string cur = CursorLine;
                if (PasswordRx.IsMatch(cur) && !sent)
                {
                    if (secret.Length == 0) { RawSend("\x03"); throw new InvalidOperationException(L.T("needEnable")); }
                    sent = true;
                    enableSent++;
                    RawSend(secret + "\r");
                    continue;
                }
                if (Term.CursorAbs > start && AtPrompt && (DateTime.Now - lastData).TotalMilliseconds > 150)
                {
                    if (CursorLine.EndsWith("#")) return;
                    throw new InvalidOperationException(L.T("enableRejected"));
                }
            }
            throw new TimeoutException(L.T("noPrompt"));
        }

        public string Run(string command, int timeoutMs)
        {
            return Run(command, timeoutMs, false);
        }

        public string Run(string command, int timeoutMs, bool confirm)
        {
            Check();
            long start = Term.CursorAbs;
            int delay = Store.Settings.LineDelay;
            if (delay > 0) Thread.Sleep(delay);
            RawSend(command + "\r");
            DateTime end = DateTime.Now.AddMilliseconds(timeoutMs);
            DateTime sentAt = DateTime.Now;
            while (true)
            {
                Thread.Sleep(25);
                Check();
                string cur = CursorLine;
                double idle = (DateTime.Now - lastData).TotalMilliseconds;
                if (cur.EndsWith("--More--") || cur.Trim() == "--More--")
                {
                    RawSend(" ");
                    continue;
                }
                if (confirm && idle > 250 && (cur.EndsWith("[confirm]") || cur.EndsWith("]?") || cur.EndsWith("[yes/no]:")))
                {
                    RawSend(cur.EndsWith("[yes/no]:") ? "yes\r" : "\r");
                    end = DateTime.Now.AddMilliseconds(timeoutMs);
                    continue;
                }
                if (Term.CursorAbs > start && AtPrompt && idle > 120 && (DateTime.Now - sentAt).TotalMilliseconds > 60)
                {
                    long stop = Term.CursorAbs;
                    string text = Term.Text(start, stop);
                    List<string> lines = Cisco.SplitLines(text);
                    int skip = 0;
                    for (int i = 0; i < lines.Count; i++)
                    {
                        if (lines[i].Contains(command.Length > 20 ? command.Substring(0, 20) : command)) { skip = i + 1; break; }
                    }
                    StringBuilder sb = new StringBuilder();
                    for (int i = skip; i < lines.Count; i++)
                    {
                        string l = lines[i].Replace("--More--", "").TrimEnd();
                        sb.Append(l).Append('\n');
                    }
                    return sb.ToString().TrimEnd('\n');
                }
                if (DateTime.Now > end) throw new TimeoutException(L.F("timeoutOn", command));
            }
        }
    }
}
