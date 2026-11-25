using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Windows.Forms;

namespace SwitchDeck
{
    internal static class Transfer
    {
        public static void ExportTemplates(MainForm main, List<Template> templates, string fileName)
        {
            if (templates.Count == 0) return;
            using (SaveFileDialog d = new SaveFileDialog())
            {
                d.Filter = L.T("templateFiles") + " (*.json)|*.json";
                d.FileName = Store.SafeName(fileName) + ".json";
                if (d.ShowDialog(main) != DialogResult.OK) return;
                try
                {
                    JObj o = new JObj();
                    o["app"] = "SwitchDeck";
                    o["kind"] = "templates";
                    o["version"] = Program.Version;
                    List<object> list = new List<object>();
                    foreach (Template t in templates) list.Add(t.ToJson());
                    o["templates"] = list;
                    File.WriteAllText(d.FileName, Json.Write(o), new UTF8Encoding(false));
                    Log.Info("Exported " + templates.Count + " templates to " + d.FileName);
                    main.Notify(templates.Count == 1 ? L.F("exportedOne", templates[0].Name) : L.F("exportedMany", templates.Count), "ok");
                }
                catch (Exception ex)
                {
                    Log.Error("Export: " + ex.Message);
                    Dialogs.Problem(main, L.T("oops"), ex.Message);
                }
            }
        }

        public static Template ImportTemplates(MainForm main)
        {
            using (OpenFileDialog d = new OpenFileDialog())
            {
                d.Filter = L.T("templateFiles") + " (*.json)|*.json";
                d.Multiselect = true;
                if (d.ShowDialog(main) != DialogResult.OK) return null;
                Template last = null;
                int added = 0;
                try
                {
                    foreach (string file in d.FileNames)
                    {
                        JObj o = Json.ParseObj(File.ReadAllText(file, Encoding.UTF8));
                        if (o.Str("app") != "SwitchDeck") throw new FormatException(L.F("notTemplateFile", Path.GetFileName(file)));
                        foreach (JObj j in o.Objs("templates"))
                        {
                            Template t = Template.FromJson(j);
                            if (t.Name.Trim().Length == 0) continue;
                            if (Store.FindTemplate(t.Id) != null) t.Id = Guid.NewGuid().ToString("N");
                            string baseName = t.Name;
                            int n = 2;
                            while (Store.Templates.Exists(delegate(Template x) { return string.Equals(x.Name, t.Name, StringComparison.CurrentCultureIgnoreCase); }))
                                t.Name = baseName + " " + n++;
                            Store.Templates.Add(t);
                            last = t;
                            added++;
                        }
                    }
                }
                catch (Exception ex)
                {
                    Log.Error("Import: " + ex.Message);
                    Dialogs.Problem(main, L.T("importFailed"), ex.Message);
                }
                if (added > 0)
                {
                    Store.SaveTemplates();
                    main.Deploy.TemplatesChanged();
                    Log.Info("Imported " + added + " templates");
                    main.Notify(L.F("importedTemplates", added), "ok");
                }
                return last;
            }
        }
    }
}
