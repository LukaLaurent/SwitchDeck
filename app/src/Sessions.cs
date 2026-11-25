using System;
using System.Collections.Generic;
using System.Threading;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal static class Sessions
    {
        public static readonly List<Session> All = new List<Session>();
        public static readonly Dictionary<string, Dictionary<string, PortStatus>> StatusCache = new Dictionary<string, Dictionary<string, PortStatus>>();
        public static readonly Dictionary<string, DateTime> StatusTime = new Dictionary<string, DateTime>();
        public static event Action ListChanged;
        public static event Action<Session> StateChanged;

        public static int OpenCount
        {
            get
            {
                int n = 0;
                foreach (Session s in All) if (s.State != SessionState.Closed) n++;
                return n;
            }
        }

        public static Session For(string hostId)
        {
            foreach (Session s in All) if (s.Host.Id == hostId) return s;
            return null;
        }

        public static Session Open(Host host, int cols, int rows)
        {
            Session existing = For(host.Id);
            if (existing != null)
            {
                if (existing.State == SessionState.Closed) StartAsync(existing);
                return existing;
            }
            Session s = new Session(host, cols, rows);
            SessionState last = SessionState.Connecting;
            s.Changed += delegate
            {
                if (s.State != last)
                {
                    last = s.State;
                    Action<Session> h = StateChanged;
                    if (h != null) Post(delegate { h(s); });
                }
            };
            SwitchesPage.WireSession(s);
            All.Add(s);
            Raise();
            StartAsync(s);
            return s;
        }

        public static void StartAsync(Session s)
        {
            if (s.State == SessionState.Closed)
            {
                s.State = SessionState.Connecting;
                s.Started = DateTime.Now;
            }
            Thread t = new Thread(delegate()
            {
                try
                {
                    s.Start();
                }
                catch (Exception ex) { Log.Error("Session start: " + ex); }
            });
            t.IsBackground = true;
            t.Start();
        }

        public static void Close(Session s)
        {
            s.Disconnect();
            s.Dispose();
            All.Remove(s);
            Raise();
        }

        public static void CloseAll()
        {
            foreach (Session s in All.ToArray())
            {
                try { s.Dispose(); } catch { }
            }
            All.Clear();
        }

        private static void Raise()
        {
            Action h = ListChanged;
            if (h != null) h();
        }

        public static void Post(Action a)
        {
            MainForm f = MainForm.Instance;
            if (f == null || f.IsDisposed || !f.IsHandleCreated) return;
            try { f.BeginInvoke(a); } catch { }
        }

        public static void SaveStatus(string hostId, List<PortStatus> list)
        {
            Dictionary<string, PortStatus> d = new Dictionary<string, PortStatus>(StringComparer.OrdinalIgnoreCase);
            foreach (PortStatus p in list) d[p.Port] = p;
            StatusCache[hostId] = d;
            StatusTime[hostId] = DateTime.Now;
        }

        public static Dictionary<string, PortStatus> StatusOf(string hostId)
        {
            Dictionary<string, PortStatus> d;
            return StatusCache.TryGetValue(hostId, out d) ? d : new Dictionary<string, PortStatus>(StringComparer.OrdinalIgnoreCase);
        }
    }
}
