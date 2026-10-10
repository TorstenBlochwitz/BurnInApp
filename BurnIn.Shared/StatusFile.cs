using System;
using System.IO;
using System.Text;

namespace BurnIn.Shared
{
    /// <summary>
    /// Message severity levels used by <see cref="StatusFile"/>.
    /// Converted from MATLAB class by Torsten Blochwitz Electronics & Software for InfraSolid
    /// </summary>
    public enum MsgLevel
    {
        INFO,
        DEBUG,
        SETUP,
        WARNING,
        ERROR
    }

    /// <summary>
    /// Writes tab separated status messages to a log file.
    /// Converted from MATLAB class by Torsten Blochwitz Electronics & Software for InfraSolid
    /// </summary>
    public class StatusFile
    {
        public string FileName { get; private set; } = string.Empty;
        public string AppNameVersion { get; private set; } = string.Empty;
        public bool PrintToConsole { get; set; } = false;
        public bool Debug { get; set; } = true;

        public StatusFile(string folder, string appNameVersion)
        {
            AppNameVersion = appNameVersion ?? string.Empty;

            // build file name
            DateTime now = DateTime.Now;
            string dDate = now.ToString("yyyy-MM-dd");
            string strTime = now.ToString("HH_mm_ss");
            FileName = Path.Combine(folder, $"{dDate}-{strTime}_Status.txt");

            if (!string.IsNullOrEmpty(folder))
            {
                // generate folder if it is not existing
                if (!Directory.Exists(folder))
                {
                    try
                    {
                        Directory.CreateDirectory(folder);
                    }
                    catch
                    {
                        System.Diagnostics.Debug.WriteLine($"Folder: {folder} could not be created! Cannot create a status file!");
                    }
                }
            }

            // generate file and store header
            try
            {
                File.WriteAllText(FileName, "Date\tTime\tType\tText\n");
            }
            catch
            {
            }

            // add first message
            AddMsg(MsgLevel.INFO, $"{AppNameVersion} started by user '{Environment.UserName}'");
        }

        public void Close()
        {
            if (Debug)
            {
                AddMsg(MsgLevel.DEBUG, $"{AppNameVersion} closing");
            }
            AddMsg(MsgLevel.INFO, $"{AppNameVersion} closed");
        }

        public int AddMsg(MsgLevel level, string text)
        {
            int ret = 1;
            DateTime now = DateTime.Now;
            string dDate = now.ToString("yyyy-MM-dd");
            string dTime = now.ToString("HH:mm:ss");
            string strLevel = level switch
            {
                MsgLevel.INFO => "Info",
                MsgLevel.DEBUG => "Debug",
                MsgLevel.SETUP => "Setup",
                MsgLevel.WARNING => "Warning",
                MsgLevel.ERROR => "Error",
                _ => ""
            };

            text ??= string.Empty;
            text = text.Replace("\r\n", " ").Replace("\n", " ").Replace("\t", " ").Replace("'", "").Replace("\"", "");

            string[] row = { dDate, dTime, strLevel, text };
            try
            {
                File.AppendAllText(FileName, string.Join("\t", row) + "\n");
            }
            catch
            {
                ret = 0;
            }

            if ((PrintToConsole && (level == MsgLevel.WARNING || level == MsgLevel.ERROR || level == MsgLevel.DEBUG)) || ret == 0)
            {
                var sb = new StringBuilder();
                foreach (var field in row)
                {
                    sb.Append(field).Append('\t');
                }
                System.Diagnostics.Debug.WriteLine(sb.ToString());
            }

            return ret;
        }
    }
}

