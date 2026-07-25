classdef BurnInProfile < handle
        
    properties
        fileName = '';
        completeFileName = '';
        currProfileStep = 0;
        startTime;
        stopTime;
        lastTimeCurrentStep;
        remainingDurationStep;
        lastMeasurementTime;
        profileStatus ProfileStatusEnum;
        p = struct(...
        'Name', '',...
        'Duration', duration(0,0,0),... %Zero means, it takes the time it takes
        'PowerPerChannel', [0.0, 0.0],...
        'MaxCurrent', [0.0, 0.0],...
        'MaxVoltage', [0.0, 0.0],...
        'Frequency', [0.0, 0.0],...
        'DutyCycle', [0.0, 0.0],...
        'Measure', 0.0,...              %Do at least one measurement in this step
        'ComputeVDuT', [0, 0],...       %Compute VDC using Rmean to compensate Rshunt
        'MeasurementHappened', 0.0);    %Did a measurement happen in this step?
        Type = ["",""]; %TODO: define an enumeration class for TO8, TO39 and other types
        NumberOfChannels = [0.0, 0.0];
        Resistance = [0.0, 0.0];
        Deviation = [0.0, 0.0];
        MeasurementRate = 0;
        lastChance4Measurement = false; %is set to true if before leaving a step, no measurement happened, but is required
    end
    
    methods
        function this = BurnInProfile()
            this.p = [];
            this.profileStatus = ProfileStatusEnum.EMPTY;
            this.resetProfileTiming();
        end
        function resetProfileTiming(this)
            this.currProfileStep = 0;
            for i=1:1:size(this.p, 2)
                this.remainingDurationStep(i) = this.p(i).Duration;
                this.p(i).MeasurementHappened = 0;
            end
            %just for initialization
            this.lastMeasurementTime = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss');
        end

        function [ret, status] = readFromExcelFile(this, strFile)
            ret = 1;
            this.p = [];
            this.currProfileStep = 0;
            this.fileName = '';
            this.completeFileName = '';
            this.Type = ["",""];
            this.NumberOfChannels = [0.0, 0.0];
            this.Resistance = [0.0 0.0];
            this.Deviation = [0.0 0.0];
            this.MeasurementRate = 0;
            status = '';
            try
                %Read from Excel File
                profile = readtable(strFile, 'Sheet','Profile');
                data = readtable(strFile, 'Sheet','Data');
            catch e
                ret = 0;
                status = sprintf('Loading %s failed!\nError: %s.', strFile, e.message);
            end
            if ret == 1
                try
                    %Check and store data
                    for i=1:1:size(profile,1)
                        this.p(i).Name = char(profile.Name(i));
                        % if Duration is given in Excel Sheet as 'hh:mm
                        %this.p(i).Duration = duration(content.Duration(i), 'InputFormat', 'hh:mm');
                        % if Duration is given in Excel Sheet as hh:mm
                        this.p(i).Duration = duration(days(profile.Duration(i)), 'Format', 'hh:mm');
                        this.p(i).PowerPerChannel(1) = profile.PowerPerChannel1(i);
                        this.p(i).MaxCurrent(1) = profile.MaxCurrent1(i);
                        this.p(i).MaxVoltage(1) = profile.MaxVoltage1(i);
                        this.p(i).Frequency(1) = profile.Frequency1(i);
                        this.p(i).DutyCycle(1) = profile.DutyCycle1(i);
                        this.p(i).PowerPerChannel(2) = profile.PowerPerChannel2(i);
                        this.p(i).MaxCurrent(2) = profile.MaxCurrent2(i);
                        this.p(i).MaxVoltage(2) = profile.MaxVoltage2(i);
                        this.p(i).Frequency(2) = profile.Frequency2(i);
                        this.p(i).DutyCycle(2) = profile.DutyCycle2(i);
                        try
                            this.p(i).ComputeVDuT(1) = profile.ComputeVDuT1(i);
                        catch
                            this.p(i).ComputeVDuT(1) = 0; %if the Excel Sheet does not contain the ComputeVDuT1 column
                        end
                        try
                            this.p(i).ComputeVDuT(2) = profile.ComputeVDuT2(i);
                        catch
                            this.p(i).ComputeVDuT(2) = 0; %if the Excel Sheet does not contain the ComputeVDuT2 column
                        end
                        try
                            this.p(i).Measure = profile.Measure(i);
                        catch
                            this.p(i).Measure = 0.0;    %if the Excel Sheet does not contain the Measure column
                        end
                        this.p(i).MeasurementHappened = 0;
                    end
                catch e
                    ret = 0;
                    status = sprintf('Error: Loading %s failed!\nError in row %d: %s.', strFile, i, e.message);
                end
                if ret == 1
                    this.remainingDurationStep = duration(nan(size(profile,1),3));
                    %check durations
                    for i=1:1:size(profile,1)
                        minuts = sum(minutes(this.p(i).Duration));
                        if minuts > 65535
                            status = sprintf('Error: Loading %s failed!\n\nError in row %d: Duration of %d min is larger than 65535 min. This is not supported!\n\nSplit this profile step into steps with smaller durations!', strFile, i, minuts);
                            ret = 0;
                            break
                        else
                            this.remainingDurationStep(i) = this.p(i).Duration;
                        end
                    end
                end
                if ret == 1
                    try
                        this.Type(1) = convertCharsToStrings(data.Type1(1));
                        this.NumberOfChannels(1) = data.NumberOfChannels1(1);
                        this.Resistance(1)= data.Resistance1(1);
                        this.Deviation(1) = data.Deviation1(1);
                        this.Type(2) = convertCharsToStrings(data.Type2(1));
                        this.NumberOfChannels(2) = data.NumberOfChannels2(1);
                        this.Resistance(2)= data.Resistance2(1);
                        this.Deviation(2) = data.Deviation2(1);
                        this.MeasurementRate = duration(minutes(data.MeasurementRate(1)));
                    catch e
                        ret = 0;
                        status = sprintf('Loading %s failed!\nError in Sheet ''Data'': %s.', strFile, e.message);
                    end
                end
            end
            if ret == 1
                if this.getNoSteps() > 0
                    str = strsplit(strFile, filesep);
                    this.fileName = char(str(end));
                    this.completeFileName = strFile;
                    this.profileStatus = ProfileStatusEnum.READY_TO_RUN;
                else
                    this.p = [];
                    ret = 0;
                    status = sprintf('Error: The file %s does not contain profile data.', strFile);                    
                end
            end
            if ret == 0
                this.p = [];
                this.Type = ["", ""];
                this.NumberOfChannels = [0.0, 0.0];
                this.Resistance = [0.0, 0.0];
                this.Deviation = [0.0, 0.0];
                this.MeasurementRate = 0;
            end
        end
        function n = getNoSteps(this)
            n= size(this.p, 2);
        end
        function dur = getDuration(this)
            dur = duration(0,0,0);
            for i=1:1:size(this.p,2)
                if this.profileStatus == ProfileStatusEnum.RUNNING
                    if size(this.remainingDurationStep, 1) < i
                        dur = dur + this.p(i).Duration;
                    else
                        dur = dur + this.remainingDurationStep(i);
                    end
                else
                    dur = dur + this.p(i).Duration;
                end
            end
            if this.profileStatus ~= ProfileStatusEnum.RUNNING
                %add estimated duration for initial measurements
                dur = dur + minutes(10);
            end
        end
        function strFile = getFileName(this)
            strFile = this.fileName;
        end
        function strFile = getCompleteFileName(this)
            strFile = this.completeFileName;
        end
        function name = getCurrProfileName(this)
            if this.currProfileStep < 1
                name = "Initial checks";
                if this.getNoSteps() > 0
                    if convertCharsToStrings(this.p(1).Name) == "Skip initial check"
                        name = convertCharsToStrings(this.p(1).Name);
                    end
                end
            else
                name = convertCharsToStrings(this.p(this.currProfileStep).Name);
            end
        end
        function str = getCurrName(this)
            str = "";
            if this.currProfileStep > this.getNoSteps()
                str = "Unknown";
            else
                switch this.profileStatus
                    case ProfileStatusEnum.RUNNING
                        str = "";
                    case ProfileStatusEnum.RUN_REQUESTED
                        str = ": Start requested.";
                    case ProfileStatusEnum.STOP_REQUESTED_ERROR
                        str = ": Stop (Error) requested!";
                    case ProfileStatusEnum.STOP_REQUESTED_MANUALLY
                        str = ": Stop requested.";
                    case ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR
                        str = ": Continue requested";
                    case ProfileStatusEnum.CONTINUE_REQUESTED
                        str = ": Continue requested";
                    case ProfileStatusEnum.RESET_REQUESTED
                        str = ": Reset requested.";
                    case ProfileStatusEnum.STOPPED_MANUALLY
                        str = ": Stopped manually!";
                    case ProfileStatusEnum.STOPPED_ERROR
                        str = ": Stopped because of an Error!";
                    case ProfileStatusEnum.STOPPED_SHORTCIRCUIT
                        str = ": Shortcut! Remove marked Emitters!";
                    case ProfileStatusEnum.FINISHED
                        str = ": Finished!";
                end
                name = this.getCurrProfileName();
                str = sprintf("%s%s", name, str);
            end
        end
        function status = getStatus(this)
            status = this.profileStatus;
        end
        function setStatus(this, status)
            this.profileStatus = status;
        end
        function [p, v, f, dutyCycle] = getCurrProfileElectrics(this, n)
            index = max(this.currProfileStep, 1);
            if this.currProfileStep <= this.getNoSteps()
                p = this.p(index).PowerPerChannel(n);
                v = this.p(index).MaxVoltage(n);
                f = this.p(index).Frequency(n);
                dutyCycle = this.p(index).DutyCycle(n);
            else
                p = 0;
                v = 0;
                f = 0;
                dutyCycle = 0;
            end
        end
        function [strMsg, VDCstatus, v] = getCurrVoltage(this, n, Rmean, numberOfEmitters)
            strMsg = "";
            VDCstatus = VDCStatusEnum.UNKNOWN;
            v = 0;
            index = max(this.currProfileStep, 1);
            if (this.currProfileStep <= this.getNoSteps())
                if((n == 2) && (numberOfEmitters <= this.NumberOfChannels(1)))
                    %less than maximum possible emitter on first bank -> switch off VDC2 if no emitters
                    strMsg = sprintf("VDC%d = 0 V, OFF (no emitters plugged in).", n);
                    VDCstatus = VDCStatusEnum.OFF_OK;
                    v = 0;
                    return
                elseif(this.p(index).PowerPerChannel(n) == 0.0) && (this.p(index).MaxVoltage(n) == 0.0)
                    strMsg = sprintf("VDC%d = 0 V, OFF (PowerPerChannel = 0.0 W,MaxVoltage = 0.0 V).", n);
                    VDCstatus = VDCStatusEnum.OFF_OK;
                    v = 0;
                    return
                elseif (this.p(index).PowerPerChannel(n) == 0.0) && (this.p(index).MaxVoltage(n) > 0.0)
                    % use MaxVoltage
                    v = this.p(index).MaxVoltage(n);
                    VDCstatus = VDCStatusEnum.ON_OK_V_CONTROLED;
                    strMsg = sprintf("VDC%d = %f V (using MaxVoltage).", n, v);
                    if this.p(index).ComputeVDuT(n) == 1
                        if Rmean > 0.0
                            v = v * (0.82 + Rmean) / Rmean;
                            strMsg = sprintf("%s VDC%d adjusted to %f V to compensate shunt!", strMsg, n, v);
                        else
                            strMsg = sprintf("%s VDC%d could not be adjusted to compensate shunt, because Rmean == 0 Ohm!", strMsg, n);
                        end
                    end
                elseif (Rmean > 0.0)
                    % use PowerPerChannel
                    v = sqrt(abs(this.p(index).PowerPerChannel(n)) * Rmean);
                    strMsg = sprintf("VDC%d = %f V (using PowerPerChannel = %f W, Rmean = %f Ohm).", n, v, this.p(index).PowerPerChannel(n), Rmean);
                    VDCstatus = VDCStatusEnum.ON_OK_P_CONTROLED;
                    if v > this.p(index).MaxVoltage(n)
                        v = min(v, this.p(index).MaxVoltage(n));
                        strMsg = sprintf("%s VDC%d reduced to MaxVoltage = %f V.", strMsg, n, v);
                        VDCstatus = VDCStatusEnum.ON_PCONTROLED_V_LIMIT;
                    end
                    if (v / Rmean) > this.p(index).MaxCurrent(n)
                        v = Rmean * this.p(index).MaxCurrent(n);
                        strMsg = sprintf("%s VDC%d reduced to %f V (MaxCurrent = %f was exceeded!).", strMsg, n, v, this.p(index).MaxCurrent(n));
                        VDCstatus = VDCStatusEnum.ON_PCONTROLED_I_LIMIT;
                    end
                    if this.p(index).ComputeVDuT(n) == 1
                        v = v * (0.82 + Rmean) / Rmean;
                        strMsg = sprintf("%s VDC%d adjusted to %f V to compensate shunt!", strMsg, n, v);
                    end
                    if (v > 0.0) && (v < 0.3)
                        strMsg = sprintf("%s VDC%d increased to 0.3 V which is the minimum value!", strMsg, n);
                        v = 0.3;
                    end
                else
                    VDCstatus = VDCStatusEnum.OFF_SHOULD_BE_ON;
                    strMsg = sprintf("VDC%d = 0 V (VDC cannot be computed using PowerPerChannel because measured Rmean = 0 Ohm).", n);
                    v = 0;
                end
                % should not happen, but just to make sure and find out what happened
                if(~((this.p(index).PowerPerChannel(n) > 0.0) && (this.p(index).MaxVoltage(n) > 0.0))) && (v == 0)
                    VDCstatus = VDCStatusEnum.OFF_SHOULD_BE_ON;
                    strMsg = sprintf("VDC%d = 0 V for unknown reasons! (%s)", n, strMsg);
                else
                    %build complete message
                    strMsg = sprintf("VDC%d = %f V. (%s)", n, v, strMsg);
                end
            end
        end
        function mMode = getCurrMeasurementMode(this)
            if this.currProfileStep == 0
                mMode = 0;
            else
                mMode = this.p(this.currProfileStep).Measure;
            end
        end
        function durMinutes = getCurrDurationMinutes(this)
            durMinutes = uint16(sum(minutes(this.p(this.currProfileStep).Duration)));
        end
        function durMinutes = getRemainingDurationStepMinutes(this)
            durMinutes = uint16(sum(minutes(this.remainingDurationStep(this.currProfileStep))));
        end
        function ret = isTimeForMeasurement(this)
            ret = false;
            if (this.profileStatus == ProfileStatusEnum.RUNNING) && (this.MeasurementRate > 0)
                now = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss');
                if this.lastMeasurementTime + this.MeasurementRate <= now
                    ret = true;
                end
            end
            if (this.profileStatus == ProfileStatusEnum.RUNNING) && this.lastChance4Measurement
                if (this.p(this.currProfileStep).Measure > 0) && (this.p(this.currProfileStep).MeasurementHappened < 1)
                    ret = true;
                    this.lastChance4Measurement = false;
                end
            end
        end
        function setMeasurementHappendInCurrentProfileStep(this)
            if this.currProfileStep > 0
                this.p(this.currProfileStep).MeasurementHappened = 1;
            end
        end
        function setLastChance4Measurement(this)
            this.lastChance4Measurement = true;
        end
    end
end

