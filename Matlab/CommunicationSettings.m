classdef CommunicationSettings < handle
    %Settings for BurnIn
    %   Data which is to be stored between sessions
    
    properties (Access = public)
        opt struct = struct( ...
        'transportMode', 0, ... %0: Ethernet, 1: WiFi or Accesspoint, 2: Auto (try Ethernet, then WiF, then Accesspoint
        'ethMAC', "06:00:00:AE:99:48",...
        'ethIP', "192.168.2.30",...
        'ethSubnet', "255.255.255.0",...
        'ethGateway', "192.168.2.0",...
        'wifiAPName', "BurnInBoard1",...
        'wifiSSID', "WLAN-206409",...
        'wifiPassword', "12345678", ...
        'apPassWord', "12345678")

        fileName = "";
    end
    
    methods
        function this = CommunicationSettings(fileName)
            this.fileName = fileName;
            this.loadFromFile(fileName);
        end
        function delete(this) 
            this.saveToFile(this.fileName);
        end
        function ret = saveToFile(this, fileName)
            if ~contains(fileName, ".mat")
                fileName = fileName + ".mat";
            end
            this.fileName = fileName;
            % extract folder
            [folderSettings, ~, ~] = fileparts(fileName);
            if convertCharsToStrings(folderSettings) ~= ""
                %generate folder if it is not existing
                if ~exist(folderSettings, 'dir')
                    if ~mkdir(folderSettings)
                        fprintf("Folder: %s could not be created! Cannot create a status file!", folderSettings);
                    end
                end
            end

            try
                %save() does not allow "this.DMM6500_ID" as variable name, for
                %that reason we use a temporary variable
                tmpOpt = this.opt;
                save(fileName, "-struct", "tmpOpt");
                ret = 1;
            catch e
                ret = 0;
            end
        end
        function this = loadFromFile(this, fileName)
            try
                if ~contains(fileName, ".mat")
                    fileName = fileName + ".mat";
                end
                tmpOpt = load(fileName);
                this.opt = tmpOpt;
            catch exception
                fprintf("Settings could not be loaded from %s (%s).\n", fileName, exception.message);
            end
        end
    end
end

