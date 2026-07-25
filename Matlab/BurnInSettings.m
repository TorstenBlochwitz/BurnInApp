classdef BurnInSettings < handle
    %Settings for BurnIn
    %   Data which is to be stored between sessions
    
    properties (Access = public)
        DMM6500_ID = "USB0::0x05E6::0x6500::04546108::INSTR";
        MBC_Port = "COM";
        I2CAddrOffset = 0;
        folder = "C:\temp";
        postfix =  "Measurement";
        fileName = "";
        folderStatus = "C:\temp";
        folderBurnInProfiles = "C:\temp";
        numberOfMeasurementsForMeanValues = 5;
        storeSelfTestResult = true;
        storeSelfTestResultPeriod = 30; % in minutes
        brightnessPosLEDs = 50; % in percent
        brightnessStatusLEDs = 50;
        autoTableSwitchOff = false;
        autoTableSwitchOffTime = 5; % in minutes
        IPAddress = ["192.168.2.30","","","","","","",""];
        MBCmode = MBCModeEnum.I2C;
        comSettingsHaveChanged = false;
    end
    
    methods
        function this = BurnInSettings(fileName)
            if ispc
                this.folder = "C:\temp";
                this.postfix =  "Measurement";
                this.folderStatus = "C:\temp";
                this.folderBurnInProfiles = "C:\temp";
            else
                this.folder = "~/BurnInApp/";
                this.postfix =  "Measurement";
                this.folderStatus = "~/BurnInApp/Status/";
                this.folderBurnInProfiles = "~/BurnInApp/Profiles/";
            end
            this.fileName = fileName;
            this.loadFromFile(fileName);
        end
        function delete(this) 
            this.saveToFile(this.fileName);
        end
        function ret = saveToFile(this, fileName)
            %Stores all settings in fileName.mat
            %save() does not allow "this.DMM6500_ID" as variable name, for
            %that reason we use temporary variables
            DMM6500_ID = this.DMM6500_ID;
            MBC_Port = this.MBC_Port;
            I2CAddrOffset = this.I2CAddrOffset;
            folder = this.folder;
            folderStatus = this.folderStatus;
            folderBurnInProfiles = this.folderBurnInProfiles;
            postfix = this.postfix;
            numberOfMeasurementsForMeanValues = this.numberOfMeasurementsForMeanValues;
            storeSelfTestResult = this.storeSelfTestResult;
            storeSelfTestResultPeriod = this.storeSelfTestResultPeriod;
            brightnessPosLEDs = this.brightnessPosLEDs;
            brightnessStatusLEDs = this.brightnessStatusLEDs;
            autoTableSwitchOff = this.autoTableSwitchOff;
            autoTableSwitchOffTime = this.autoTableSwitchOffTime;
            IPAddress = this.IPAddress;
            MBCmode = this.MBCmode;

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
                        fprintf("Folder: %s could not be created! Cannot store the settings file!", folderSettings);
                    end
                end
            end

            try
                save(fileName, "DMM6500_ID", "MBC_Port", "I2CAddrOffset", "folder", "postfix", "folderStatus", "storeSelfTestResult", "storeSelfTestResultPeriod", "numberOfMeasurementsForMeanValues", "brightnessPosLEDs", "brightnessStatusLEDs", "folderBurnInProfiles","autoTableSwitchOff", "autoTableSwitchOffTime", "IPAddress", "MBCmode");
                ret = 1;
            catch e
                ret = 0;
            end
        end
        function this = loadFromFile(this, fileName)
            %Loads all settings in fileName.mat
            %load() does not allow "this.DMM6500_ID" as variable name, for
            %that reason we use temporary variables
            try
                if ~contains(fileName, ".mat")
                    fileName = fileName + ".mat";
                end
                load(fileName, "DMM6500_ID", "MBC_Port", "I2CAddrOffset", "folder", "postfix", "folderStatus", "storeSelfTestResult", "storeSelfTestResultPeriod", "numberOfMeasurementsForMeanValues", "brightnessPosLEDs", "brightnessStatusLEDs", "folderBurnInProfiles","autoTableSwitchOff", "autoTableSwitchOffTime", "IPAddress", "MBCmode");
                this.DMM6500_ID = DMM6500_ID;
                this.MBC_Port = MBC_Port;
                this.I2CAddrOffset = I2CAddrOffset;
                this.folder = folder;
                this.folderStatus = folderStatus;
                this.folderBurnInProfiles = folderBurnInProfiles;
                this.postfix = postfix;
                this.numberOfMeasurementsForMeanValues = numberOfMeasurementsForMeanValues;
                this.storeSelfTestResult = storeSelfTestResult;
                this.storeSelfTestResultPeriod = storeSelfTestResultPeriod;
                this.brightnessPosLEDs = brightnessPosLEDs;
                this.brightnessStatusLEDs = brightnessStatusLEDs;
                this.autoTableSwitchOff = autoTableSwitchOff;
                this.autoTableSwitchOffTime = autoTableSwitchOffTime;
                this.IPAddress = IPAddress;
                this.MBCmode = MBCmode;
            catch exception
                fprintf("Settings could not be loaded from %s (%s).\n", fileName, exception.message);
            end
        end
         
        function MBCPort = GetMBCPort(this)
            if this.MBCmode == MBCModeEnum.I2C
                if this.MBC_Port == ""
                    MBCPort = "COM";
                else
                    MBCPort = sprintf("%s", this.MBC_Port);
                end
            else
                MBCPort = "";
            end
        end
    end
end

