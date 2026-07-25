classdef StatusFile < handle
    properties
        fileName = "";
        appNameVersion = "";
        printToConsole = false;
        debug = true;
    end

    methods
        function this = StatusFile(folder, appNameVersion)
            this.appNameVersion = sprintf("%s", appNameVersion);
            %build file name
            dDate = datetime('now', 'Format', 'yyyy-MM-dd');
            dTime = datetime('now', 'Format', 'HH:mm:ss');
            strTime = strrep(sprintf("%s", dTime), ':', '_');
            this.fileName = fullfile(folder, sprintf('%s-%s_Status.txt', dDate, strTime));
            %fprintf("Statusfile: %s\n", this.fileName);
            if convertCharsToStrings(folder) ~= ""
                %generate folder if it is not existing
                if ~exist(folder, 'dir')
                    if ~mkdir(folder)
                        fprintf("Folder: %s could not be created! Cannot create a status file!", folder);
                    end
                end
            end
            %generate file and store header
            strHeader = ["Date", "Time", "Type", "Text"];
            try
                writematrix(strHeader, this.fileName,'Delimiter','tab');
            catch
            end
            %add first message
            this.addMsg(msgLevel.INFO, sprintf("%s started by user '%s'", this.appNameVersion, getenv('username')));
        end
        function delete(this)
            if this.debug
                st = dbstack('-completenames', 1);
                this.addMsg(msgLevel.DEBUG, sprintf("%s closing", this.appNameVersion));
                for i = 1:1:size(st,1)
                    this.addMsg(msgLevel.DEBUG, sprintf('CallStack %d: %s %s line: %d', i, st(i).file, st(i).name, st(i).line));
                end
            end
            this.addMsg(msgLevel.INFO, sprintf("%s closed", this.appNameVersion));
        end
        function ret = addMsg(this, level, text)
            ret = 1;
            dDate = datetime('now', 'Format', 'yyyy-MM-dd');
            dTime = datetime('now', 'Format', 'HH:mm:ss');
            strLevel = "";
            switch level
                case msgLevel.INFO
                    strLevel = "Info";
                case msgLevel.DEBUG
                    strLevel = "Debug";
                case msgLevel.SETUP
                    strLevel = "Setup";
                case msgLevel.WARNING
                    strLevel = "Warning";
                case msgLevel.ERROR
                    strLevel = "Error";
            end
            text = strrep(text, newline, ' ');
            text = strrep(text, '\t', ' ');
            text = strrep(text, '''', '');
            text = strrep(text, '"', '');
            strRow = [sprintf("%s", dDate), sprintf("%s", dTime), strLevel, convertCharsToStrings(text)];
            try
                writematrix(strRow, this.fileName,'Delimiter','tab', 'WriteMode','append');
            catch
                ret = 0;
            end
            if (this.printToConsole && ((level == msgLevel.WARNING) || (level == msgLevel.ERROR) || (level == msgLevel.DEBUG))) || (ret == 0)
                for i=1:1:size(strRow,2)
                    fprintf("%s\t", strRow(i));
                end
                fprintf("\n\n");
            end
        end
    end
end