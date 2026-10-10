classdef BurnInController < handle
   
    properties
        appName = "BurnIn App";
        version = "3.2.2";
        statusFile StatusFile;
        settings BurnInSettings;
        mbc MBC_TB;
        dmm Keithley6500;
        burnInDev BurnInDev;
        burnInAction BurnInAction;
        burnInStatus BurnInStatus;
        burnInProfile BurnInProfile;
        VDC1status VDCstatus;
        VDC2status VDCstatus;

        currActionDevice = 1;

        debug = false;
        storeMemConsumption = false;

        maxVDCDeviation = 20; %in %

        MBCStatusString="";
        DMMStatusString='';
        DCDCStatusString='';
        MainBoardStatusString='';
        serialNumber = ["" "" "" "" "" "" "" ""];
        numberOfEmitters = [120 120 120 120 120 120 120 120];
        
        VDC1 = [0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0];   %current set Values of VDC
        VDC2 = [0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0];
        VDC1measured = [0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0]; %last measured VDC
        VDC2measured = [0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0]; %last measured VDC
        R1mean = [0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0]; %Mean Value of Resistance of Emitters at VDC1
        R2mean = [0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0]; %Mean Value of Resistance of Emitters at VDC2
        VDCSwitchedOn = [false, false,false,false,false,false,false,false];
        
        selfTestRequired = false;

        lastTimeOfSelfTestResultStorage;
        lastTimeOfMemoryAnalysis;
        
        SNrDisplayUpdateNeeded;

        cWhite = [1.0 1.0 1.0];
        cGreen = [0.0 1.0 0.0];     % OK     
        cOrange = [1.0 0.8 0.0];    % User interaction required
        cRed = [1.0 0.4 0.4];       % Error
        cBlue = [0.0 0.4 1.0];      % Ready
        cFullBlue = [0.0 0.0 1.0];  % Ready (RGB LED)
        cFullRed = [1.0 0.0 0.0];   % Error (RGB LED)
        cYellow = [1.0 1.0 0.0];    % User interaction required (RGB LED)
        cBlack = [0.0 0.0 0.0];     % Off   (RGB LED)
    end
    
    methods
        function this = BurnInController()
            pause('on');
            this.SNrDisplayUpdateNeeded = false;
            strSettingsFile = "BurnInSettings.mat";
            try
                if ispc
                    strSettingsFile = winqueryreg('HKEY_CURRENT_USER', 'BurnInApp', 'BurnInSettings');
                else
                    strSettingsFile = "~/.config/BurnInApp/BurnInSettings.mat";
                end
            catch
            end
            
            fprintf("Settings: %s\n", strSettingsFile);
            this.settings = BurnInSettings(strSettingsFile);

            for i=1:1:8
                this.burnInStatus(i) = BurnInStatus();
                this.burnInAction(i) = BurnInAction();
                this.burnInDev(i) = BurnInDev();
                this.burnInProfile(i) = BurnInProfile();
                this.VDC1status(i) = VDCstatus();
                this.VDC2status(i) = VDCstatus();
            end

            this.applyRGBLEDbrightness();

            now = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss');
            this.lastTimeOfSelfTestResultStorage = [now, now, now, now, now, now, now, now];
            this.lastTimeOfMemoryAnalysis = now;

            this.statusFile = StatusFile(this.settings.folderStatus, this.getAppTitle());
            if(this.debug)
                this.writeMemoryUsage(true);
            end
        end
        function str = getAppTitle(this)
            str = sprintf("%s Version: %s", this.appName, this.version);
        end
        function ret = connectMBC(this, MBCAddr)
            %TODO: Remember COM Port and connect to it
            ret = 1;
            try
                if ~isempty(this.mbc)
                    delete(this.mbc);
                end
                this.mbc = MBC_TB(MBCAddr);

                this.mbc.reset();
                %set frequency to 1 kHz for testing
                this.mbc.setI2Cfrequency(16);
                %Update reference to MBC everywhere! Connection to MBC could have been lost or might have been manually reconnected.
                % In this case, it was deleted and we have to update its references to all hardware devices, which are connected
                this.UpdateRefToMBC();
                this.MBCStatusString=sprintf("MBC connected to %s", this.mbc.GetConnectedPort());
                this.statusFile.addMsg(msgLevel.SETUP, this.MBCStatusString);
            catch exc1
                str = sprintf("%s", exc1.message);
                fprintf("Could not connect to MBC: %s\n", str);
                if strlength(str) > 32
                    str = extractBefore(exc1.message, "For more information");
                end
                this.MBCStatusString = sprintf("Could not connect to MBC: %s.", str);
                this.statusFile.addMsg(msgLevel.ERROR, this.MBCStatusString);
                try
                    if ~isempty(this.mbc)
                        delete(this.mbc);
                    end
                catch exc2
                    fprintf("Something went wrong (%s).\n", exc2.message);
                end
                ret = 0;
            end
        end
        function ret = connectDMM(this, str)
            ret = 1;
            try
                this.dmm = Keithley6500(str);
                this.dmm.init();
                this.dmm.set_VDC();
                this.DMMStatusString = 'DMM connected.';
                this.statusFile.addMsg(msgLevel.SETUP, sprintf("Keythley DMM6500 %s connected", str));
            catch exception1
                sprintf("Could not connect to Keithley DMM6500 (%s): %s", str, exception1.message);
                this.statusFile.addMsg(msgLevel.WARNING, sprintf("Could not connect to Keithley DMM6500 (%s): %s", str, exception1.message));
                this.DMMStatusString = sprintf("Could not connect to Keithley DMM6500 (%s).\n\n", exception1.message);
                try
                    if ~isempty(this.dmm)
                        delete(this.dmm);
                    end
                catch exception2
                    fprintf("Something went wrong (%s).\n", exception2.message);
                end
                ret = 0;
            end
        end

        function stat = connectBoards(this, index, connectTimeOut)
            stat = -1;
            try
                if this.settings.MBCmode == MBCModeEnum.TCP && this.settings.IPAddress(index) ~= ""
                    if this.mbc.connectToTCPServer(index-1, this.settings.IPAddress(index), connectTimeOut)
                        stat = 0;
                    end
                else
                    stat = 0;
                end
                if stat == -1
                    %no Hardware connected or IP Address empty
                    return;
                end
                stat = this.burnInDev(index).connectDCDCConverterBoard(this.mbc, index-1);
                if stat > 0
                    if stat == 1
                        this.statusFile.addMsg(msgLevel.SETUP, sprintf("Board %d: DCDC Converter (with one channel only) %s connected", index, this.burnInDev(index).DCDCConv.UUID));
                    else
                        this.statusFile.addMsg(msgLevel.SETUP, sprintf("Board %d: DCDC Converter %s connected", index, this.burnInDev(index).DCDCConv.UUID));
                    end
                    stat = this.burnInDev(index).connectMainBoard();
                    if stat == 1
                        stat = 2;
                        this.statusFile.addMsg(msgLevel.SETUP, sprintf("Board %d: Main Board %s connected", index, this.burnInDev(index).mainBoard.UUID));
                    else
                        stat = 1;
                    end
                end
            catch exc1
                stat = 0;
                %TODO: is this correct?
                if this.settings.MBCmode ~= MBCModeEnum.TCP
                    %Check if exception might have been thrown by a disconnected MBC
                    if (strlength(this.burnInDev(index).DCDCConv.lastErrorMsg) == 0) && (this.burnInDev(index).DCDCConv.versionErrorReported == 0)
                        throw(exc1);
                    end
                end
            end
            if stat == 0
                %TODO: Improve error message!
                %Avoid continuous reporting of version error
                if (strlength(this.burnInDev(index).DCDCConv.lastErrorMsg) > 0) && ((this.burnInDev(index).DCDCConv.versionErrorReported == 1) || (this.burnInDev(index).noDCDCConverterErrorReported == 1))
                    this.statusFile.addMsg(msgLevel.ERROR, sprintf("Board %d: Could not connect to DC/DC Converter: %s", index, this.burnInDev(index).DCDCConv.lastErrorMsg));
                end
            end
            this.MBCStatusString = sprintf("MBC connected to %s", this.mbc.GetConnectedPort());
        end
        function ret = UpdateRefToMBC(this)
            ret = 0;
            for i=1:1:8
                this.burnInDev(i).UpdateRefToMBC(this.mbc);
            end
            ret = 1;
        end
        function ret = isAProfileRunning(this)
            ret = false;
            for k=1:1:8
                if this.burnInStatus(k).getStatus() == BurnInStatusEnum.EXECUTING_PROFILE
                    ret = true;
                    return;
                end
            end
        end
        function ret = doAction(this)
            ret = 0;
            if this.debug
                this.writeMemoryUsage(false);
            end
            if isvalid(this.mbc)
                try
                    %this.switchOffI2CMultiplexers();
                    %if something weired happened before
                    %TODO: Check!!
                    this.disableAllMux();
                    action = this.burnInAction(this.currActionDevice);
                    action.currentAction = action.nextAction;
                    status = this.burnInStatus(this.currActionDevice);
                    switch action.nextAction
                        case BurnInActionEnum.DO_NOTHING
                            %pause(0.5);
                            action.nextAction = BurnInActionEnum.CONNECT_DCDC_CONVERTER;
                        case BurnInActionEnum.CONNECT_DCDC_CONVERTER
                            stat = this.connectBoards(this.currActionDevice, 2);
                            switch stat
                                case -1
                                    action.nextAction = BurnInActionEnum.DO_NOTHING;
                                    this.setStatus(this.currActionDevice, BurnInStatusEnum.NO_HARDWARE_CONNECTED);                                    
                                case 0
                                    action.nextAction = BurnInActionEnum.DO_NOTHING;
                                    this.setStatus(this.currActionDevice, BurnInStatusEnum.NO_HARDWARE_CONNECTED);
                                case 1
                                    action.nextAction = BurnInActionEnum.CONNECT_MAINBOARD; 
                                    this.setStatus(this.currActionDevice, BurnInStatusEnum.DCDC_CONNECTED);
                                case 2
                                    action.nextAction = BurnInActionEnum.SELF_TEST;
                                    this.setStatus(this.currActionDevice, BurnInStatusEnum.MAINBOARD_CONNECTED);
                            end
                        case BurnInActionEnum.CONNECT_MAINBOARD
                            stat = this.burnInDev(this.currActionDevice).connectMainBoard();
                            if stat == 1
                                action.nextAction = BurnInActionEnum.SELF_TEST;
                                this.setStatus(this.currActionDevice, BurnInStatusEnum.MAINBOARD_CONNECTED);
                            else
                                action.nextAction = BurnInActionEnum.CONNECT_MAINBOARD;
                                %this.setStatus(this.currActionDevice, BurnInStatusEnum.NO_HARDWARE_CONNECTED);
                            end
                        case BurnInActionEnum.SELF_TEST
                            %pause(2);
                            stat = this.doSelfTest();
                            if status.getStatus() == BurnInStatusEnum.NO_HARDWARE_CONNECTED
                                action.nextAction = BurnInActionEnum.CONNECT_DCDC_CONVERTER;
                            else
                                action.nextAction = BurnInActionEnum.CHECK_PROFILE;
                            end
                        case BurnInActionEnum.CHECK_PROFILE
                            if status.getStatus() == BurnInStatusEnum.NO_HARDWARE_CONNECTED
                                action.nextAction = BurnInActionEnum.CONNECT_DCDC_CONVERTER;
                            else
                                switch this.burnInProfile(this.currActionDevice).getStatus()
                                    case ProfileStatusEnum.RUN_REQUESTED
                                        this.startProfile(this.currActionDevice);
                                        this.handleProfileStepping();
                                    case ProfileStatusEnum.STOP_REQUESTED_MANUALLY
                                        this.stopProfile(this.currActionDevice, ProfileStatusEnum.STOPPED_MANUALLY);
                                    case ProfileStatusEnum.STOP_REQUESTED_ERROR
                                        this.stopProfile(this.currActionDevice, ProfileStatusEnum.STOPPED_ERROR);
                                    case ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR
                                        this.continueProfile(this.currActionDevice);
                                    case ProfileStatusEnum.CONTINUE_REQUESTED
                                        this.continueProfile(this.currActionDevice);
                                        this.handleProfileStepping();
                                    case ProfileStatusEnum.RESET_REQUESTED
                                        this.resetProfile(this.currActionDevice);
                                    case ProfileStatusEnum.RUNNING
                                        this.handleProfileStepping();
                                end
        
                                switch this.burnInProfile(this.currActionDevice).getStatus()
                                    case ProfileStatusEnum.EMPTY
                                        action.nextAction = BurnInActionEnum.SELF_TEST;
                                    case ProfileStatusEnum.READY_TO_RUN
                                        action.nextAction = BurnInActionEnum.SELF_TEST;
                                    case ProfileStatusEnum.RUNNING
                                        this.setStatus(this.currActionDevice, BurnInStatusEnum.EXECUTING_PROFILE);
                                        %Check if we switched to a new profile step, which requires an immediate Selftest
                                        if this.selfTestRequired == true
                                            action.nextAction = BurnInActionEnum.SELF_TEST;
                                        else
                                            action.nextAction = BurnInActionEnum.DO_MEASUREMENT;
                                        end
                                    case ProfileStatusEnum.FINISHED
                                        action.nextAction = BurnInActionEnum.CHECK_PROFILE;
                                    case ProfileStatusEnum.STOPPED_MANUALLY
                                        action.nextAction = BurnInActionEnum.SELF_TEST;
                                        %action.nextAction = BurnInActionEnum.CHECK_PROFILE;
                                    case ProfileStatusEnum.STOPPED_ERROR
                                        action.nextAction = BurnInActionEnum.SELF_TEST;
                                        %action.nextAction = BurnInActionEnum.CHECK_PROFILE;
                                end
                            end
                        case BurnInActionEnum.DO_MEASUREMENT
                            currProfile = this.burnInProfile(this.currActionDevice);
                            if currProfile.isTimeForMeasurement()
                                %store time now
                                tStartMeasurement = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss');
                                this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Measurement started", this.currActionDevice));
                                this.doMeasurement(this.currActionDevice, false);
                                this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Measurement finished", this.currActionDevice));
                                currProfile.setMeasurementHappendInCurrentProfileStep();
                                % Adjust voltages according to measured resistances
                                if currProfile.getCurrMeasurementMode() == 2
                                    [strMsg1, curVDC1status, this.VDC1(this.currActionDevice)] = currProfile.getCurrVoltage(1, this.R1mean(this.currActionDevice), this.numberOfEmitters((this.currActionDevice)));
                                    this.VDC1status(this.currActionDevice).setStatus(curVDC1status);
                                    if this.VDC1(this.currActionDevice) > 0.0
                                        this.burnInDev(this.currActionDevice).DCDCConv.setSiC450_Voltage(1, this.VDC1(this.currActionDevice));
                                    end
                                    %use VDC for VDCmeasured until the next SelfTest
                                    this.VDC1measured(this.currActionDevice) = this.VDC1(this.currActionDevice);
                                    [p1, ~, ~, ~] = this.burnInProfile(this.currActionDevice).getCurrProfileElectrics(1);
                                    
                                    if this.burnInDev(this.currActionDevice).GetNofBanks() == 2
                                        [strMsg2, curVDC2status, this.VDC2(this.currActionDevice)] = currProfile.getCurrVoltage(2, this.R2mean(this.currActionDevice), this.numberOfEmitters((this.currActionDevice)));
                                        this.VDC2status(this.currActionDevice).setStatus(curVDC2status);
                                        if this.VDC2(this.currActionDevice) > 0.0
                                            this.burnInDev(this.currActionDevice).DCDCConv.setSiC450_Voltage(2, this.VDC2(this.currActionDevice));
                                        end
                                        this.VDC2measured(this.currActionDevice) = this.VDC2(this.currActionDevice);
                                        [p2, ~, ~, ~] = this.burnInProfile(this.currActionDevice).getCurrProfileElectrics(2);
                                    
                                        this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Profile step %d '%s' adjusted. Remaining duration: %d min, P1 = %f W, P2 = %f W, VDC1 = %f V, VDC2 = %f V, R1mean = %f Ohm, R2mean = %f Ohm", ...
                                            this.currActionDevice, ...
                                            currProfile.currProfileStep, ...
                                            currProfile.getCurrProfileName(), ...
                                            currProfile.getRemainingDurationStepMinutes(), ...
                                            p1, ...
                                            p2, ...
                                            this.VDC1(this.currActionDevice), ...
                                            this.VDC2(this.currActionDevice), ...
                                            this.R1mean(this.currActionDevice), ...
                                            this.R2mean(this.currActionDevice)));
    
                                        this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Profile step %d %s: Computation of VDC: %s %s", ...
                                            this.currActionDevice, ...
                                            currProfile.currProfileStep, ...
                                            currProfile.getCurrProfileName(),...
                                            strMsg1,...
                                            strMsg2));
                                    else
                                        this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Profile step %d '%s' adjusted. Remaining duration: %d min, P1 = %f W, VDC1 = %f V, R1mean = %f Ohm", ...
                                            this.currActionDevice, ...
                                            currProfile.currProfileStep, ...
                                            currProfile.getCurrProfileName(), ...
                                            currProfile.getRemainingDurationStepMinutes(), ...
                                            p1, ...
                                            this.VDC1(this.currActionDevice), ...
                                            this.R1mean(this.currActionDevice)));    
                                        this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Profile step %d %s: Computation of VDC: %s", ...
                                            this.currActionDevice, ...
                                            currProfile.currProfileStep, ...
                                            currProfile.getCurrProfileName(),...
                                            strMsg1));
                                    end
                                end
                                %set lastMeasurementTime now, when everything is definitely done. There might have been an exception meanwhile
                                currProfile.lastMeasurementTime = tStartMeasurement;
                            end
                            action.nextAction = BurnInActionEnum.DO_NOTHING;
                            switch status.getStatus()
                                case BurnInStatusEnum.DCDC_CONNECTED
                                    action.nextAction = BurnInActionEnum.CONNECT_MAINBOARD;
                                case BurnInStatusEnum.MAINBOARD_CONNECTED
                                    action.nextAction = BurnInActionEnum.CHECK_PROFILE;
                                case BurnInStatusEnum.EXECUTING_PROFILE
                                    action.nextAction = BurnInActionEnum.SELF_TEST;
                                case BurnInStatusEnum.READY
                                    action.nextAction = BurnInActionEnum.CHECK_PROFILE;
                            end
                    end
                catch e
                    %TODO: which error occured?
                    %fprintf("Problem during communication with Hardware: %s\n", e.message);
                    if(~isempty(strfind(e.stack(1).name, 'CBerror')))
                        this.handleSelfTestError(this.currActionDevice, sprintf("Board %d: Problem during communication with Hardware: %s.", this.currActionDevice, e.message));
                    else
                        this.handleDisconnectedMBC(e.message);
                    end
                end
                %switch to next board only, if no immediate self test was required
                if this.selfTestRequired == false
                    if this.currActionDevice < 8
                        this.currActionDevice = this.currActionDevice + 1;
                    else
                        this.currActionDevice = 1;
                    end
                else
                    this.selfTestRequired = false;
                end
            end
        end
        function ret = handleProfileStepping(this)
            ret = 0;
            currProfile = this.burnInProfile(this.currActionDevice);
            if currProfile.profileStatus == ProfileStatusEnum.RUNNING
                %Start Profile
                if (currProfile.currProfileStep == 0)
                    currProfile.remainingDurationStep = duration(nan(currProfile.getNoSteps(),3));
                    for i=1:1:size(currProfile.p, 2)
                        currProfile.remainingDurationStep(i) = currProfile.p(i).Duration;
                    end
                    currProfile.startTime = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss');
                    currProfile.lastTimeCurrentStep = currProfile.startTime;
                    currProfile.stopTime = currProfile.startTime + currProfile.getDuration();
                    
                    if currProfile.getCurrName() == "Skip initial check"
                        %only for testing
                        this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: No initial checks! For test purpose only!", this.currActionDevice));
                        if currProfile.Resistance > 10.0
                            this.R1mean(this.currActionDevice) = currProfile.Resistance(1);
                            this.R2mean(this.currActionDevice) = currProfile.Resistance(2);
                        else
                            this.R1mean(this.currActionDevice) = 22.0;
                            this.R2mean(this.currActionDevice) = 22.0;
                        end
                        currProfile.currProfileStep = 1;
                    else
                        %Check for short circuit
                        this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Check Short Circuit started", this.currActionDevice));
                        [nShortCircuit, bShort] = this.checkShortCircuit(this.currActionDevice);
                        if(nShortCircuit > 0)
                            strPos = "";
                            for k=1:1:size(bShort, 2)
                                if bShort(k)
                                    strPos = sprintf("%s%d ", strPos, k);
                                end
                            end
                            this.statusFile.addMsg(msgLevel.ERROR, sprintf("Board %d: %d Short Circuits at positions: %s", this.currActionDevice, nShortCircuit, strPos));
                        else
                            this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Check Short Circuit finished, no short circuits", this.currActionDevice));
                            this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Measurement started", this.currActionDevice));
                            currProfile.lastMeasurementTime = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss');
                            this.doMeasurement(this.currActionDevice, true);
                            this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Measurement finished", this.currActionDevice));
                            currProfile.currProfileStep = 1;
                        end
                    end
                    %update stop time
                    currProfile.stopTime = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss') + currProfile.getDuration();

                    ret = 1;
                else
                    now = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss');
                    stepIsReady = false;
                    if currProfile.p(currProfile.currProfileStep).Duration == duration(0,0,0)
                        %Step is finished, as soon as it is finished
                        stepIsReady = true;
                    else
                        %time based
                        elapsedDuration = now - currProfile.lastTimeCurrentStep;
                        if elapsedDuration > currProfile.remainingDurationStep(currProfile.currProfileStep)
                            %ready
                            stepIsReady = true;
                        else
                            %Continue and keep remaining time up to date
                            currProfile.remainingDurationStep(currProfile.currProfileStep) = currProfile.remainingDurationStep(currProfile.currProfileStep) - elapsedDuration;
                            currProfile.lastTimeCurrentStep = now;
                            %fprintf('RemainingDuration: %s', currProfile.remainingDurationStep(currProfile.currProfileStep));
                        end
                    end
                    if stepIsReady
                        %is a measurement required, but did not happen in this step?
                        if (currProfile.p(currProfile.currProfileStep).Measure > 0) && (currProfile.p(currProfile.currProfileStep).MeasurementHappened < 1)
                            currProfile.setLastChance4Measurement();
                            stepIsReady = false;
                        end
                    end
                    if stepIsReady
                        this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Profile step %d '%s' finished", this.currActionDevice, currProfile.currProfileStep, currProfile.getCurrName()));
                        if currProfile.currProfileStep < size(currProfile.p, 2)
                            currProfile.remainingDurationStep(currProfile.currProfileStep) = duration(0,0,0);
                            currProfile.currProfileStep = currProfile.currProfileStep + 1;
                            currProfile.lastTimeCurrentStep = now;
                            %estimate new stopTime
                            currProfile.stopTime = now + currProfile.getDuration();
                            
                            [p1, ~, f1, dutyCycle1] = this.burnInProfile(this.currActionDevice).getCurrProfileElectrics(1);
                            %Compute VDC1 and VDC2 depending on R_mean, MaxCurrent, MaxVoltage
                            [strMsg1, curVDC1status, this.VDC1(this.currActionDevice)] = this.burnInProfile(this.currActionDevice).getCurrVoltage(1, this.R1mean(this.currActionDevice), this.numberOfEmitters((this.currActionDevice)));
                            this.VDC1status(this.currActionDevice).setStatus(curVDC1status);
                            %use VDC for Vmeasured until the next SelfTest
                            this.VDC1measured(this.currActionDevice) = this.VDC1(this.currActionDevice);
                            
                            if this.burnInDev(this.currActionDevice).GetNofBanks() == 2
                                [p2, ~, f2, dutyCycle2] = this.burnInProfile(this.currActionDevice).getCurrProfileElectrics(2);
                                [strMsg2, curVDC2status, this.VDC2(this.currActionDevice)] = this.burnInProfile(this.currActionDevice).getCurrVoltage(2, this.R2mean(this.currActionDevice), this.numberOfEmitters((this.currActionDevice)));
                                this.VDC2measured(this.currActionDevice) = this.VDC2(this.currActionDevice);
                            else
                                p2 = 0.0;
                                f2 = 0.0;
                                dutyCycle2 = 0.0;
                                strMsg2 = "";
                                curVDC2status =VDCStatusEnum.VDC_NOT_AVAILABLE;
                                this.VDC2(this.currActionDevice) = 0.0;
                            end
                            this.VDC2status(this.currActionDevice).setStatus(curVDC2status);

                            durationMinutes = this.burnInProfile(this.currActionDevice).getCurrDurationMinutes();
                            %Compute VDC1 and VDC2 depending on R_mean, MaxCurrent, MaxVoltage

                            %use VDC for Vmeasured until the next SelfTest

                            this.burnInDev(this.currActionDevice).switchOn(this.VDC1(this.currActionDevice), this.VDC2(this.currActionDevice), f1, f2, dutyCycle1, dutyCycle2, durationMinutes);
                            this.VDCSwitchedOn(this.currActionDevice) = true;
                            if this.burnInDev(this.currActionDevice).GetNofBanks() == 2
                                this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Profile step %d '%s' started. Duration: %d min, P1 = %f W, P2 = %f W, VDC1 = %f V, VDC2 = %f V, R1mean = %f Ohm, R2mean = %f Ohm", ...
                                    this.currActionDevice, ...
                                    currProfile.currProfileStep, ...
                                    currProfile.getCurrProfileName(), ...
                                    durationMinutes, ...
                                    p1, ...
                                    p2, ...
                                    this.VDC1(this.currActionDevice), ...
                                    this.VDC2(this.currActionDevice), ...
                                    this.R1mean(this.currActionDevice), ...
                                    this.R2mean(this.currActionDevice)));
                                this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Profile step %d %s: Computation of VDC: %s %s", ...
                                    this.currActionDevice, ...
                                    currProfile.currProfileStep, ...
                                    currProfile.getCurrProfileName(),...
                                    strMsg1,...
                                    strMsg2));
                            else
                                this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Profile step %d '%s' started. Duration: %d min, P1 = %f W, VDC1 = %f V, R1mean = %f Ohm", ...
                                    this.currActionDevice, ...
                                    currProfile.currProfileStep, ...
                                    currProfile.getCurrProfileName(), ...
                                    durationMinutes, ...
                                    p1, ...
                                    this.VDC1(this.currActionDevice), ...
                                    this.R1mean(this.currActionDevice)));
                                this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Profile step %d %s: Computation of VDC: %s %s", ...
                                    this.currActionDevice, ...
                                    currProfile.currProfileStep, ...
                                    currProfile.getCurrProfileName(),...
                                    strMsg1));
                            end
                            % we went to a new profile step -> we should do a selftest now
                            this.selfTestRequired = true;
                        else
                            this.setProfileStatus(this.currActionDevice, ProfileStatusEnum.FINISHED);
                            currProfile.stopTime = now;
                            this.burnInDev(this.currActionDevice).switchOff(false);
                            this.VDCSwitchedOn(this.currActionDevice) = false;
                            [~, SNrEnd] = getSNr(this.serialNumber(this.currActionDevice), this.numberOfEmitters(this.currActionDevice));
                            this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Profile '%s' finshed sucessfully. SNr: '%s' - '%s'", this.currActionDevice, regexprep(string(currProfile.getCompleteFileName()), '\\([abfnrtv\\])', '\\\\$1'), this.serialNumber(this.currActionDevice), SNrEnd));
                        end
                        ret = 1;
                    end
                end
            end
        end
        function ret = setNextAction(this, index, action)
            ret = 1;
            this.burnInAction(index).nextAction = action;
        end
        function ret = GetMaxNofEmitters(this, index)
            %fprintf("index: %f\n", index);
            max1 = this.burnInDev(index).GetMaxNofEmitters();
            %fprintf("max1 %f\n", max1);
            max2 = this.burnInProfile(index).GetMaxNofEmitters();
            %fprintf("max2 %f\n", max2);
            ret = min(max1, max2);
        end
        function setStatus(this, index, status)
            %TODO: UpdateVisibility in BurnInApp
            if status ~= this.burnInStatus(index).getStatus()
                this.burnInStatus(index).setStatus(status);
                this.setRGBLEDStatus(index);
            end
        end
        function setProfileStatus(this, index, status)
            this.burnInProfile(index).setStatus(status);
            this.setRGBLEDStatus(index);
        end
        function setRGBLEDStatus(this, index)
            if this.burnInStatus(index).getStatus() >= BurnInStatusEnum.MAINBOARD_CONNECTED
                c121 = this.cBlack;
                c122 = this.cBlack;
                c123 = this.cBlack;
                if this.burnInStatus(index).getStatus() ~= BurnInStatusEnum.EXECUTING_PROFILE
                    switch this.burnInStatus(index).getStatus()
                        case BurnInStatusEnum.ERROR
                            c123 = this.cFullRed;
                        case BurnInStatusEnum.NO_HARDWARE_CONNECTED
                            c122 = this.cOrange;
                        case BurnInStatusEnum.DCDC_CONNECTED
                            c122 = this.cOrange;
                        case BurnInStatusEnum.MAINBOARD_CONNECTED
                            c122 = this.cOrange;
                    end
                else
                    switch this.burnInProfile(index).getStatus()
                        case ProfileStatusEnum.EMPTY
                            c122 = this.cYellow;
                        case ProfileStatusEnum.READY_TO_RUN
                            c122 = this.cYellow;
                        case ProfileStatusEnum.RUNNING
                            c121 = this.cGreen;
                        case ProfileStatusEnum.STOPPED_MANUALLY
                            c122 = this.cYellow;
                        case ProfileStatusEnum.STOPPED_ERROR
                            c123 = this.cFullRed;
                        case ProfileStatusEnum.STOPPED_SHORTCIRCUIT
                            c123 = this.cFullRed;
                        case ProfileStatusEnum.FINISHED
                            %3 x blue or better green?
                            c121 = this.cFullBlue;
                            c122 = this.cFullBlue;
                            c123 = this.cFullBlue;
                        case ProfileStatusEnum.RUN_REQUESTED
                            c121 = this.cGreen;
                        case ProfileStatusEnum.STOP_REQUESTED_ERROR
                            c123 = this.cFullRed;
                        case ProfileStatusEnum.STOP_REQUESTED_MANUALLY
                            c122 = this.cYellow;
                        case ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR
                            c121 = this.cYellow;
                        case ProfileStatusEnum.CONTINUE_REQUESTED
                            c121 = this.cGreen;                            
                        case ProfileStatusEnum.RESET_REQUESTED
                            c122 = this.cYellow;
                    end
                end
                rgbLED121 = 255 * c121;
                rgbLED122 = 255 * c122;
                rgbLED123 = 255 * c123;            
    
                this.burnInDev(index).mainBoard.setStatusRGBLEDs(rgbLED121, rgbLED122, rgbLED123);
            end
        end

        function [ret, isError] = getStatusColor(this, index)
            ret = this.cWhite;
            isError = false;
            if this.burnInStatus(index).getStatus() ~= BurnInStatusEnum.EXECUTING_PROFILE
                switch this.burnInStatus(index).getStatus()
                    case BurnInStatusEnum.ERROR
                        ret = this.cRed;
                        isError = true;
                    case BurnInStatusEnum.NO_HARDWARE_CONNECTED
                        ret = this.cOrange;
                    case BurnInStatusEnum.DCDC_CONNECTED
                        ret = this.cOrange;
                    case BurnInStatusEnum.MAINBOARD_CONNECTED
                        ret = this.cOrange;
                end
            else
                switch this.burnInProfile(index).getStatus()
                    case ProfileStatusEnum.EMPTY
                        ret = this.cOrange;
                    case ProfileStatusEnum.READY_TO_RUN
                        ret = this.cOrange;
                    case ProfileStatusEnum.RUNNING
                        ret = this.cGreen;
                    case ProfileStatusEnum.STOPPED_MANUALLY
                        ret = this.cOrange;
                    case ProfileStatusEnum.STOPPED_ERROR
                        ret = this.cFullRed;
                        isError = true;
                    case ProfileStatusEnum.STOPPED_SHORTCIRCUIT
                        ret = this.cFullRed;
                        isError = true;
                    case ProfileStatusEnum.FINISHED
                        %3 x blue or better green?
                        ret = this.cBlue;
                    case ProfileStatusEnum.RUN_REQUESTED
                        ret = this.cGreen;
                    case ProfileStatusEnum.STOP_REQUESTED_ERROR
                        ret = this.cFullRed;
                        isError = true;
                    case ProfileStatusEnum.STOP_REQUESTED_MANUALLY
                        ret = this.cOrange;
                    case ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR
                        ret = this.cOrange;
                    case ProfileStatusEnum.CONTINUE_REQUESTED
                        ret = this.cGreen;
                    case ProfileStatusEnum.RESET_REQUESTED
                        ret = this.cOrange;
                end
            end        
        end
        function str = getStatusString(this, index)
            str = this.burnInStatus(index).getStatusString();

            if (this.burnInProfile(index).getStatus() >= ProfileStatusEnum.RUNNING)
                str = sprintf("%s", this.burnInProfile(index).getCurrName());
            end
        end
        function switchOffI2CMultiplexers(this)
            try
                for k=0:1:7
                    this.burnInDev(k+1).switchOffI2CMultiplexer();
                end
            catch
            end
        end
        function switchOff(this, complete)
            for k=0:1:7
                this.burnInDev(k+1).switchOff(complete);
                this.VDCSwitchedOn(k+1) = false;
            end    
        end
        function switchOffEverything(this)
            %use a try catch section here to avoid an error if stopProfile() was called
            %after a failed sefTesting and no hardware is connected
            try
                for k=0:1:7
                    this.setStatus(k+1, BurnInStatusEnum.SWITCHING_OFF);
                    this.burnInDev(k+1).switchOff(true);
                    this.VDCSwitchedOn(k+1) = false;
                end
            catch e
            end
        end
        function disableAllMux(this)
            try
                for index=1:1:8
                    if this.burnInStatus(index).getStatus() >= BurnInStatusEnum.MAINBOARD_CONNECTED
                        this.burnInDev(index).mainBoard.setMUX(-1);
                    end
                end
            catch e
            end
        end
        function [ret, bShort] = checkShortCircuit(this, index)
            this.burnInDev(index).mainBoard.switchRGBLED(0, 0, 0, 0, true, true);
            %get expected resistance and max. voltage from first profile step
            %TODO: fix voltage per channel: DONE
            v=[0,0];
            R=[0,0];
            for i=1:2
                [~, v(i), ~, ~] = this.burnInProfile(index).getCurrProfileElectrics(i);
                R(i) = this.burnInProfile(index).Resistance(i) - this.burnInProfile(index).Deviation(i);
                if R(i) < 2
                    R(i) = 2;
                end
            end
            [ret, bShort] = this.burnInDev(index).checkShortCircuit(v, R);
            if ret > 0
                this.burnInDev(index).mainBoard.switchRGBLEDs(bShort, 255, 0, 0);
                this.stopProfile(index, ProfileStatusEnum.STOPPED_SHORTCIRCUIT);
            end
            %TODO: handle Error case ret < 0
        end
        function ret = doMeasurement(this, index, setVoltage)
            ret = 0;
            %Blink
            this.burnInDev(index).DCDCConv.switchStatusLED_DCDC(2);
            %switch off RGB LEDs 
            %this.burnInDev(index).mainBoard.switchRGBLED(0, 0, 0, 0, true, true);
            if setVoltage
                %get max. voltage from first profile step
                [~, v1, ~, ~] = this.burnInProfile(index).getCurrProfileElectrics(1);
                if this.burnInDev(index).GetNofBanks() > 1
                    [~, v2, ~, ~] = this.burnInProfile(index).getCurrProfileElectrics(2);
                else
                    v2 = 0.0;
                end
                %switch on
                this.burnInDev(index).switchOn(v1, v2, 0, 0, 0, 0, 0);
            end
            %remember time
            dDate = datetime('now', 'Format', 'yyyy-MM-dd');
            dTime = datetime('now', 'Format', 'HH:mm:ss');
            %do measurement
            nSkip = [uint8(60) / uint8(this.burnInProfile(index).NumberOfChannels(1)), uint8(60) / uint8(this.burnInProfile(index).NumberOfChannels(2))];
            [VDC, VR, R, ~] = this.burnInDev(index).completeMeasurement(nSkip, this.settings.numberOfMeasurementsForMeanValues, this.numberOfEmitters(index), this.dmm, BurnInBoardMaintenanceMeasApp.empty);
            if setVoltage
                this.burnInDev(index).switchOff(false);
            end
            %store measured data in file
            strPostfix = sprintf("SNr_%s", this.serialNumber(index));
            for i=1:size(R,2)
                %increment serial number
                [~, SNr(i)] = getSNr(this.serialNumber(index), i);
            end
            [bOK, strFilename] = this.burnInDev(index).saveMeasurement(this.settings.folder, dDate, dTime, strPostfix, SNr, VDC, VR, R);
            if ~bOK
                this.statusFile.addMsg(msgLevel.WARNING, sprintf("Board %d: %s ", index, this.burnInDev(index).lastErrorMessage));
            else
                strFilename = regexprep(string(strFilename), '\\([abfnrtv\\])', '\\\\$1');
                %strFilename = replace(string(strFilename), "\", "\\");
                this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Measurement stored in: %s", index, strFilename));
            end

            %max. number of emitters
            if this.burnInDev(index).GetNofBanks() == 2
                maxEmitters = 120;
            else
                maxEmitters = 60;
            end
            %mark emitters resistances not within tolerance band
            outOfLimit = zeros(1, maxEmitters, 'logical');
            offLimit = false;
            nCurSkip = nSkip(1);
            if nCurSkip > 1
                k = 2;
            else
                k = 1;
            end
            lowerHalf = false;
            RMax(1) = this.burnInProfile(index).Resistance(1) + this.burnInProfile(index).Deviation(1);
            if this.burnInDev(index).GetNofBanks() > 1
                RMax(2) = this.burnInProfile(index).Resistance(2) + this.burnInProfile(index).Deviation(2);
            end
            RMaxC = RMax(1);
            for i = 1:1:size(R,2)
                if (k > 60) && (~lowerHalf)
                    RMaxC = RMax(2);
                    nCurSkip = nSkip(2);
                    lowerHalf = true;
                    if nCurSkip > 1
                        k = 62;
                    else
                        k = 61;
                    end
                end
                if R(i) > RMaxC
                    outOfLimit(k) = true;
                    offLimit = true;
                end
                k = k + nCurSkip;
            end
            %switch off RGB LEDs 
            this.burnInDev(index).mainBoard.switchRGBLED(0, 0, 0, 0, true, true);
            if offLimit
                this.burnInDev(index).mainBoard.switchRGBLEDs(outOfLimit, 0, 0, 255);
            end
            outOfLimit = zeros(1, maxEmitters, 'logical');
            offLimit = false;
            nCurSkip = nSkip(1);
            if nCurSkip > 1
                k = 2;
            else
                k = 1;
            end
            lowerHalf = false;
            RMin(1) = this.burnInProfile(index).Resistance(1) - this.burnInProfile(index).Deviation(1);
            if this.burnInDev(index).GetNofBanks() > 1
                RMin(2) = this.burnInProfile(index).Resistance(2) - this.burnInProfile(index).Deviation(2);
            end
            RMinC = RMin(1);
            for i = 1:size(R,2)
                if (k > 60) && (~lowerHalf)
                    RMinC = RMin(2);
                    nCurSkip = nSkip(2);
                    lowerHalf = true;
                    if nCurSkip > 1
                        k = 62;
                    else
                        k = 61;
                    end
                end
                if R(i) < RMinC
                    outOfLimit(k) = true;
                    offLimit = true;
                end
                k = k + nCurSkip;
            end
            if offLimit
                this.burnInDev(index).mainBoard.switchRGBLEDs(outOfLimit, 255, 0, 0);
            end
            %compute mean value of resistances
            sizeBank1 = min(this.numberOfEmitters(index), this.burnInProfile(index).NumberOfChannels(1));
            this.R1mean(index) = this.computeRMean(R(1:sizeBank1), RMin(1), RMax(1));
            if this.R1mean(index) < 1e-10
                this.statusFile.addMsg(msgLevel.WARNING, sprintf("Board %d: None of the emitters in bank 1 is within the allowed range of Rmin = %f Ohm and Rmax = %f Ohm. Please check emitters and the used profile (%s).",index, RMin(1), RMax(1), this.burnInProfile(index).getFileName()));
            end
            if this.burnInDev(index).GetNofBanks() > 1
                if (this.numberOfEmitters(index) > this.burnInProfile(index).NumberOfChannels(1))
                    this.R2mean(index) = this.computeRMean(R(sizeBank1 + 1:size(R,2)), RMin(2), RMax(2));
                    if this.R2mean(index) < 1e-10
                        this.statusFile.addMsg(msgLevel.WARNING, sprintf("Board %d: None of the emitters in bank 2 is within the allowed range of Rmin = %f Ohm and Rmax = %f Ohm. Please check emitters and the used profile (%s).",index, RMin(2), RMax(2), this.burnInProfile(index).getFileName()));
                    end
                else
                    %No emmitters on VDC2 (lower half)
                    this.R2mean(index) = 0;
                end
            else
                this.R2mean(index) = 0;
            end
            %fprintf("R1mean = %f Ohm, R2mean = %f Ohm\n", this.R1mean(index), this.R2mean(index));
            this.burnInDev(index).DCDCConv.switchStatusLED_DCDC(0);
        end
        function R = computeRMean(this, Rmeas, RMin, RMax)
            R = 0;
            ctr = 0;
            %fprintf("RMin = %f Ohm, RMax = %f Ohm\n", RMin, RMax);
            for i = 1:size(Rmeas,2)
                if (Rmeas(i) <= RMax) && (Rmeas(i) >= RMin)
                    %fprintf("OK: R%d = %f Ohm\n", i, Rmeas(i));
                    R = R + Rmeas(i);
                    ctr = ctr + 1;
                else
                    %fprintf("NOK: R%d = %f Ohm\n", i, Rmeas(i));
                end
            end
            if R ~= 0.0
                R = R / ctr;
            end
        end
        function ret = requestNewProfileStatus(this, index, status)
            ret = 0;
            this.burnInProfile(index).setStatus(status);
            % set nextAction to checkProfile to react as soon as possible
            this.setNextAction(index, BurnInActionEnum.CHECK_PROFILE);
        end
%         function ret = requestStopProfile(this, index, reason)
%             ret = 0;
%             this.burnInProfile(index).setStatus(reason);
%             % set nextAction to checkProfile to react as soon as possible
%             this.setNextAction(index, BurnInActionEnum.CHECK_PROFILE);
%         end
    end
    methods (Access = private)
        %the following functions must not be called outside from
        %handleActions(), because they acces hardware!
        function ret = startProfile(this, index)
            ret = 0;
            currProfile = this.burnInProfile(index);
            if  (currProfile.profileStatus == ProfileStatusEnum.READY_TO_RUN) ||...
                (currProfile.profileStatus == ProfileStatusEnum.RUN_REQUESTED)
                ret = 1;
                currProfile.currProfileStep = 0;
                this.setProfileStatus(index, ProfileStatusEnum.RUNNING);
                this.setNextAction(index, BurnInActionEnum.CHECK_PROFILE);
                this.setStatus(index, BurnInStatusEnum.EXECUTING_PROFILE);
                if this.numberOfEmitters(index) > (this.burnInProfile(index).NumberOfChannels(1) + this.burnInProfile(index).NumberOfChannels(2))
                    this.SNrDisplayUpdateNeeded = true;
                    this.numberOfEmitters(index) = this.burnInProfile(index).NumberOfChannels(1) + this.burnInProfile(index).NumberOfChannels(2);
                end
                [~, SNrEnd] = getSNr(this.serialNumber(index), this.numberOfEmitters(index));
                this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Profile '%s' started. SNr: '%s' - '%s'", index, regexprep(string(currProfile.getCompleteFileName()), '\\([abfnrtv\\])', '\\\\$1'), this.serialNumber(index), SNrEnd));
            end
        end
        function ret = stopProfile(this, index, reason)
            ret = 0;
            currProfile = this.burnInProfile(index);

            if  (currProfile.profileStatus == ProfileStatusEnum.RUNNING)||...
                (currProfile.profileStatus == ProfileStatusEnum.STOP_REQUESTED_ERROR) ||...
                (currProfile.profileStatus == ProfileStatusEnum.STOP_REQUESTED_MANUALLY) ||...
                (currProfile.profileStatus == ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR)
                ret = 1;
                this.setProfileStatus(index, reason);
                if reason == ProfileStatusEnum.STOPPED_MANUALLY
                    strReason = sprintf("manually");
                    level = msgLevel.INFO;
                else
                    strReason = sprintf("because of an error");
                    level = msgLevel.ERROR;
                end
                %we use a try catch section here to avoid an error if stopProfile() was called
                %after a failed selfTesting and no hardware is connected
                try
                    %keep RGB LEDs on to mark short circuits
                    this.VDCSwitchedOn(index) = false;
                    this.burnInDev(index).switchOff(false);
                catch e
                end
                this.statusFile.addMsg(level, sprintf("Board %d: Profile stopped %s", index, strReason));
                
                %TODO: Store switch off time from ATtiny?
            end
        end
        function ret = continueProfile(this, index)
            ret = 0;
            currProfile = this.burnInProfile(index);
            if  (currProfile.profileStatus == ProfileStatusEnum.STOPPED_MANUALLY) ||...
                (currProfile.profileStatus == ProfileStatusEnum.STOPPED_SHORTCIRCUIT) ||...
                (currProfile.profileStatus == ProfileStatusEnum.STOPPED_ERROR) ||...
                (currProfile.profileStatus == ProfileStatusEnum.CONTINUE_REQUESTED) ||...
                (currProfile.profileStatus == ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR)
                ret = 1;
                
                if (currProfile.profileStatus == ProfileStatusEnum.STOPPED_ERROR) || (currProfile.profileStatus == ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR)
                    %ConnectBoards (at least try it!)
                    if this.connectBoards(index, 10) ~= 2
                        this.stopProfile(index, ProfileStatusEnum.STOPPED_ERROR);
                        this.statusFile.addMsg(msgLevel.ERROR, sprintf("Board %d: Continuation failed. Cannot connect to hardware. Problem still exists.", index));
                        ret = 0;
                        return;
                    end
                end

                %Don't switch in case of Initial Checks
                if currProfile.currProfileStep > 0
                    %Skip missed time
                    currProfile.lastTimeCurrentStep = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss');
                    %remainingTime counts from now
                    
                    %Set VDCs, f, DutyCycle, switch on
                    [p1, ~, f1, dutyCycle1] = this.burnInProfile(index).getCurrProfileElectrics(1);
                    [p2, ~, f2, dutyCycle2] = this.burnInProfile(index).getCurrProfileElectrics(2);
                    durationMinutes = this.burnInProfile(index).getRemainingDurationStepMinutes();
                    %we use the formerly computed VDCs and don't update them using the last measured R1mean, R2mean
                    this.burnInDev(index).switchOn(this.VDC1(index), this.VDC2(index), f1, f2, dutyCycle1, dutyCycle2, durationMinutes);
                    this.VDCSwitchedOn(index) = true;
                    this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Profile step %d '%s' continued. Remaining duration: %d min, P1 = %f W, P2 = %f W, VDC1 = %f V, VDC2 = %f V, R1mean = %f Ohm, R2mean = %f Ohm", ...
                        index, ...
                        currProfile.currProfileStep, ...
                        currProfile.getCurrProfileName(), ...
                        durationMinutes, ...
                        p1, ...
                        p2, ...
                        this.VDC1(index), ...
                        this.VDC2(index), ...
                        this.R1mean(index), ...
                        this.R2mean(index)));
                else
                    this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Profile step %d '%s' continued.", ...
                        index, ...
                        currProfile.currProfileStep, ...
                        currProfile.getCurrProfileName()));
                end
                this.selfTestRequired = true;
                this.setProfileStatus(index, ProfileStatusEnum.RUNNING);
                currProfile.stopTime = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss') + currProfile.getDuration();
                this.setNextAction(index, BurnInActionEnum.CHECK_PROFILE);
                this.setStatus(index, BurnInStatusEnum.EXECUTING_PROFILE);
            end
        end
    end
    methods
        function ret = resetProfile(this, index)
            ret = 0;
            currProfile = this.burnInProfile(index);
            if      (currProfile.profileStatus == ProfileStatusEnum.STOPPED_MANUALLY) ||...
                    (currProfile.profileStatus == ProfileStatusEnum.STOPPED_SHORTCIRCUIT) ||...
                    (currProfile.profileStatus == ProfileStatusEnum.STOPPED_ERROR) ||...
                    (currProfile.profileStatus == ProfileStatusEnum.FINISHED) ||...
                    (currProfile.profileStatus == ProfileStatusEnum.RESET_REQUESTED)
                ret = 1;

                %Reset everything
                currProfile.resetProfileTiming();
                this.setProfileStatus(index, ProfileStatusEnum.READY_TO_RUN);

                this.VDC1(index) = 0.0;
                this.VDC2(index) = 0.0;
                this.R1mean(index) = 0.0;
                this.R2mean(index) = 0.0;
                this.VDCSwitchedOn(index) = false;
                this.serialNumber(index) = "";
                this.numberOfEmitters(index) = 120;
                this.SNrDisplayUpdateNeeded = true;
                this.setStatus(index, BurnInStatusEnum.MAINBOARD_CONNECTED);
                this.burnInDev(index).switchOff(true);
                this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Profile reset", index));
            end
        end

        function status = doSelfTest(this)
            status = false;
            
            try
                %Check existence of DCDC Converter Board by checking
                %response from I2C Multiplexer on DCDC Converter Board
                status = this.mbc.checkI2CAddr(this.burnInDev(this.currActionDevice).DCDCConv.MPaddr, this.burnInDev(this.currActionDevice).DCDCConv.offset);
                if ~status
                    this.handleSelfTestError(this.currActionDevice, sprintf("Board %d: DC/DC Converter Board is not responding! Check connection to MBC", this.currActionDevice));
                    return
                end
                %Check if SiC450 are responding
                %TODO: try getting temperatures, which will be needed later
                status = this.burnInDev(this.currActionDevice).DCDCConv.checkSiC450();
                if ~status
                    this.handleSelfTestError(this.currActionDevice, sprintf("Board %d: Problem with DC/DC Converter Board: Sic450 is not responding. Check DC power supply!", this.currActionDevice));
                    return
                end
                %Check existence of Main Board
                status = this.burnInDev(this.currActionDevice).mainBoard.checkMainBoard();
                if ~status
                    this.handleSelfTestError(this.currActionDevice, sprintf("Board %d: Problem with Main Board: Multiplexer is not responding: %s. Check connection between DC/DC Converter and Main Board! ", this.currActionDevice, this.burnInDev(this.currActionDevice).mainBoard.lastErrorMsg));
                    return
                end
                %Check ATtiny status
                ATtinyStatus = this.burnInDev(this.currActionDevice).DCDCConv.getATtinyStatus();
                if ATtinyStatus < 2
                    %ATtiny was booted or is no longer reachable
                    if this.burnInProfile(this.currActionDevice).getStatus() == ProfileStatusEnum.RUNNING
                        this.statusFile.addMsg(msgLevel.WARNING, sprintf("Board %d: Problem with Main Board: ATtiny was booted! Trying to continue...", this.currActionDevice));
                        %this.handleSelfTestError(this.currActionDevice, sprintf("Board %d: Problem with Main Board: ATtiny was booted! trying to continue...", this.currActionDevice));
                        this.requestNewProfileStatus(this.currActionDevice, ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR);
                        if ~this.continueProfile(this.currActionDevice)
                            return
                        end
                    else
                        status = false;
                        this.handleSelfTestError(this.currActionDevice, sprintf("Board %d: Problem with Main Board: ATtiny was booted since last connection.", this.currActionDevice));
                        return
                    end              
                end

                if (this.burnInProfile(this.currActionDevice).getStatus() == ProfileStatusEnum.RUNNING) && (this.VDCSwitchedOn(this.currActionDevice))
                    %Check if ATtiny is in correct mode
                    %Don't do this during Initial Check
                    if this.burnInProfile(this.currActionDevice).currProfileStep > 0
                        tSwitchOff = this.burnInDev(this.currActionDevice).DCDCConv.getTimer();
                        %Do we have enough time?
                        if tSwitchOff > 2
                            strStatus= {'Off', 'On', 'Blinking'};
                            VDCset(1) = this.VDC1(this.currActionDevice);
                            if this.burnInDev(this.currActionDevice).GetNofBanks() > 1
                                VDCset(2) = this.VDC2(this.currActionDevice);
                            else
                                VDCset(2) = 0.0;
                            end
                            for k=1:1:this.burnInDev(this.currActionDevice).GetNofBanks()
                                curStatus = this.burnInDev(this.currActionDevice).DCDCConv.getVDCswitchStatus(k);
                                %Get current frequency to find out if we should blink or not
                                [~, ~, f, ~] = this.burnInProfile(this.currActionDevice).getCurrProfileElectrics(k);
                                status = 0;
                                if VDCset(k) > 0
                                    status = 1;
                                    if f > 0
                                        status = 2;
                                    end
                                end
                                if curStatus ~= status
                                    %fix the problem
                                    this.burnInDev(this.currActionDevice).DCDCConv.switchVDC(k, status);
                                    %put a warning
                                    this.statusFile.addMsg(msgLevel.WARNING, sprintf("Board %d: Problem with Main Board: For unknown reasons, the VDC%d channel was not in mode %d (%s), but in mode %d (%s). This was automatically corrected. Please check the status file for problems and inform Andreas Neumann!",...
                                        this.currActionDevice, ...
                                        k,...
                                        status, ...
                                        strStatus{status+1}, ...
                                        curStatus, ...
                                        strStatus{curStatus+1}));
                                end
                            end
                        end
                    end

                    %Measure VDCs if profile is running
                    VDCset(1) = this.VDC1(this.currActionDevice);
                    if this.burnInDev(this.currActionDevice).GetNofBanks() > 1
                        VDCset(2) = this.VDC2(this.currActionDevice);
                    end
                    stopProfile = false;
                    measurementOK = [false, false];
                    %Reset VDCmeaseureStatus
                    this.VDC1status(this.currActionDevice).setVDCmeasureStatus(0);
                    if this.burnInDev(this.currActionDevice).GetNofBanks() > 1
                        this.VDC2status(this.currActionDevice).setVDCmeasureStatus(0);
                    end
                    %TODO: This should not happen, but happened, see #49. Find out why! 
                    if  this.VDC1status(this.currActionDevice).getStatus() == VDCStatusEnum.OFF_SHOULD_BE_ON
                        stopProfile = true;
                        this.statusFile.addMsg(msgLevel.ERROR, sprintf("Board %d: Problem with computed VDC1: It should be greater than zero, but is zero for unknown reaons! Please inform Andreas Neumann!", this.currActionDevice));
                    elseif this.VDC2status(this.currActionDevice).getStatus() == VDCStatusEnum.OFF_SHOULD_BE_ON
                        stopProfile = true;
                        this.statusFile.addMsg(msgLevel.ERROR, sprintf("Board %d: Problem with computed VDC2: It should be greater than zero, but is zero for unknown reaons! Please inform Andreas Neumann!", this.currActionDevice));
                    else
                        VDCperc = [0, 0];
                        VDCcur = [0, 0];
                        for k=1:1:this.burnInDev(this.currActionDevice).GetNofBanks()
                            if VDCset(k) > 0
                                [measurementOK(k), VDCcur(k)] = this.burnInDev(this.currActionDevice).measureVDC(k, this.dmm);
                                if measurementOK(k)
                                    VDCperc(k) = abs(100.0 - VDCcur(k) * 100.0 / VDCset(k));
                                    if VDCperc(k) > this.maxVDCDeviation
                                        this.statusFile.addMsg(msgLevel.WARNING, sprintf("Board %d: Problem with Main Board: VDC%d = %f V deviates by %f %% from set value %f V! Doing more precice measurement!", this.currActionDevice, k, VDCcur(k), VDCperc(k), VDCset(k)));
                                        %repeat measurement and measure mean value
                                        [measurementOK(k), VDCcur(k)] = this.burnInDev(this.currActionDevice).measureVDCmean(k, 10, this.dmm);
                                        if measurementOK(k)
                                            VDCperc(k) = abs(100.0 - VDCcur(k) * 100.0 / VDCset(k));
                                            if VDCperc(k) > this.maxVDCDeviation
                                                stopProfile = true;
                                                this.statusFile.addMsg(msgLevel.ERROR, sprintf("Board %d: Problem with Main Board: VDC%d = %f V deviates by %f %% from set value %f V!", this.currActionDevice, k, VDCcur(k), VDCperc(k), VDCset(k)));
                                                %log status of problematic channel
                                                strStatus = sprintf("Board %d: Status of DC/DC converter %d:", this.currActionDevice, k);
                                                strStatus = sprintf("%s STATUS_CML = 0x%X", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(k).getSTATUS_CML());
                                                strStatus = sprintf("%s STATUS_WORD = 0x%X", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(k).getSTATUS_WORD());
                                                strStatus = sprintf("%s STATUS_VOUT = 0x%X", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(k).getSTATUS_VOUT());
                                                strStatus = sprintf("%s STATUS_INPUT = 0x%X", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(k).getSTATUS_INPUT());
                                                strStatus = sprintf("%s VOUT = %.3f V", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(k).getREAD_VOUT());
                                                strStatus = sprintf("%s IOUT = %.3f A", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(k).getREAD_IOUT());
                                                strStatus = sprintf("%s VIN = %.3f V", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(k).getREAD_VIN());
                                                strStatus = sprintf("%s IIN = %.3f A", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(k).getREAD_IIN());
                                                this.statusFile.addMsg(msgLevel.INFO, strStatus);
                                                if this.burnInDev(this.currActionDevice).GetNofBanks() > 1
                                                    %log status of other channel
                                                    if k == 1
                                                        otherChannel = 2;
                                                    else
                                                        otherChannel = 1;
                                                    end
                                                    strStatus = sprintf("Board %d: Status of DC/DC converter %d:", this.currActionDevice, otherChannel);
                                                    strStatus = sprintf("%s STATUS_CML = 0x%X", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(otherChannel).getSTATUS_CML());
                                                    strStatus = sprintf("%s STATUS_WORD = 0x%X", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(otherChannel).getSTATUS_WORD());
                                                    strStatus = sprintf("%s STATUS_VOUT = 0x%X", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(otherChannel).getSTATUS_VOUT());
                                                    strStatus = sprintf("%s STATUS_INPUT = 0x%X", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(otherChannel).getSTATUS_INPUT());
                                                    strStatus = sprintf("%s VOUT = %.3f V", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(otherChannel).getREAD_VOUT());
                                                    strStatus = sprintf("%s IOUT = %.3f A", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(otherChannel).getREAD_IOUT());
                                                    strStatus = sprintf("%s VIN = %.3f V", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(otherChannel).getREAD_VIN());
                                                    strStatus = sprintf("%s IIN = %.3f A", strStatus, this.burnInDev(this.currActionDevice).DCDCConv.SiC450(otherChannel).getREAD_IIN());
                                                    this.statusFile.addMsg(msgLevel.INFO, strStatus);
                                                end
                                                %Set VDCStatus
                                                if VDCcur(k) > VDCset(k)
                                                    VDCmeaseureStatus = 1;
                                                else
                                                    VDCmeaseureStatus = -1;
                                                end
                                                if k == 1
                                                    this.VDC1status(this.currActionDevice).setVDCmeasureStatus(VDCmeaseureStatus);
                                                else
                                                    this.VDC2status(this.currActionDevice).setVDCmeasureStatus(VDCmeaseureStatus);
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if measurementOK(1)
                        this.VDC1measured(this.currActionDevice) = VDCcur(1);
                    end
                    if this.burnInDev(this.currActionDevice).GetNofBanks() > 1
                        if measurementOK(2)
                            this.VDC2measured(this.currActionDevice) = VDCcur(2);
                        end
                    end
                    if stopProfile
                        status = false;
                        this.stopProfile(this.currActionDevice, ProfileStatusEnum.STOPPED_ERROR);
                        return
                    else
                        status = true;
                        if(this.isTimeForSelfTestResultStoring(this.currActionDevice))
                            if measurementOK(1) || measurementOK(2)
                                VDCmsg = ["", ""];
                                for k=1:1:this.burnInDev(this.currActionDevice).GetNofBanks()
                                    if measurementOK(k)
                                        VDCmsg(k) = sprintf("VDC%dset = %f V VDC%d = %f V (%f %%)", k, VDCset(k), k, VDCcur(k), VDCperc(k));
                                    end
                                    T = this.burnInDev(this.currActionDevice).DCDCConv.SiC450(k).getREAD_TEMPERATURE();
                                    Tmsg(k) = sprintf(" T%d = %f °C", k, T);
                                end
                                if (strlength(VDCmsg(1)) > 0) && (strlength(VDCmsg(2)) > 0)
                                    strSep = "; ";
                                else
                                    strSep = "";
                                end
                                if this.burnInDev(this.currActionDevice).GetNofBanks() > 1
                                    this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Self-test: %s%s%s%s%s", this.currActionDevice, VDCmsg(1), Tmsg(1), strSep, VDCmsg(2), Tmsg(2)));
                                else
                                    this.statusFile.addMsg(msgLevel.INFO, sprintf("Board %d: Self-test: %s%s", this.currActionDevice, VDCmsg(1), Tmsg(1)));
                                end
                            end
                        end
                    end
                end
                %Check temperatures?

            catch e
                %Which error occured?
                if(~isempty(strfind(e.stack(1).name, 'CBerror')))
                    %problem with one of the boards
                    this.handleSelfTestError(this.currActionDevice, sprintf("Board %d: Problem during communication with Hardware: %s.", this.currActionDevice, e.message));
                else
                    %problem with MBC
                    this.handleDisconnectedMBC(e.message);
                end
            end
        end
        function handleDisconnectedMBC(this, errorMsg)
            fprintf("Problem with MBC: %s\n", errorMsg);
            this.statusFile.addMsg(msgLevel.WARNING, sprintf("MBC disconnected! Reason: %s Trying to reconnect...", errorMsg));
            % TODO: Add this.currActionDevice to tryReconnect
            if this.mbc.tryReconnect(this.currActionDevice) == 0
                delete(this.mbc);
                this.statusFile.addMsg(msgLevel.ERROR, sprintf("MBC disconnected and reconnect failed: %s", errorMsg));
                this.MBCStatusString = 'ERROR: MBC disconnected';
                % TODO: in case of TCP, check, which board really must be
                % stopped or stop this.currActionDevice only
                for k = 1:1:8
                    if this.burnInProfile(k).getStatus() == ProfileStatusEnum.RUNNING
                        try
                            this.stopProfile(k, ProfileStatusEnum.STOPPED_ERROR);
                        catch e
                            fprintf("Exception catched during StopProfile: %s\n", e.message);
                        end
                    else
                        this.setNextAction(k, BurnInActionEnum.DO_NOTHING);
                        this.setStatus(k, BurnInStatusEnum.NO_HARDWARE_CONNECTED);
                    end
                end
            else
                this.statusFile.addMsg(msgLevel.WARNING, sprintf("MBC reconnected to %s!", this.mbc.GetConnectedPort()));
                this.MBCStatusString = sprintf("MBC reconnected to %s", this.mbc.GetConnectedPort());
                %conncetion to MBC might have been lost when a multiplexer was switched on
                this.switchOffI2CMultiplexers();
                %conncetion to MBC might have been lost when an analog multiplexer was switched on
                this.disableAllMux();
                %we simply try to continue, if something really bad happened, the SelfTest will notice!
                % TODO: in case of TCP, check, which board really must be continued or continue this.currActionDevice only
                for k = 1:1:8
                    if this.burnInProfile(k).getStatus() == ProfileStatusEnum.RUNNING
                        this.requestNewProfileStatus(k, ProfileStatusEnum.CONTINUE_REQUESTED_AFTER_ERROR);
                    end
                end
            end
        end
        function handleSelfTestError(this, index, errorMsg)
            if this.burnInProfile(index).getStatus() >= ProfileStatusEnum.RUNNING
                if this.burnInProfile(index).getStatus() ~= ProfileStatusEnum.STOPPED_ERROR
                    this.statusFile.addMsg(msgLevel.ERROR, errorMsg);
                    this.stopProfile(index, ProfileStatusEnum.STOPPED_ERROR);
                end
            else
                if this.burnInStatus(index).getStatus() ~= BurnInStatusEnum.NO_HARDWARE_CONNECTED
                    this.statusFile.addMsg(msgLevel.ERROR, errorMsg);
                    this.setStatus(index, BurnInStatusEnum.NO_HARDWARE_CONNECTED);
                end
                this.setNextAction(index, BurnInActionEnum.DO_NOTHING);
            end
        end
        function ret = isTimeForSelfTestResultStoring(this, index)
            ret = false;
            if this.settings.storeSelfTestResult
                now = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss');
                if this.lastTimeOfSelfTestResultStorage(index) + minutes(this.settings.storeSelfTestResultPeriod) <= now
                    ret = true;
                    this.lastTimeOfSelfTestResultStorage(index) = now;
                end
            end
        end
        function applyRGBLEDbrightness(this)
            for i=1:1:8
                this.burnInDev(i).mainBoard.brightnessPosLEDs = this.settings.brightnessPosLEDs;
                this.burnInDev(i).mainBoard.brightnessStatusLEDs = this.settings.brightnessStatusLEDs;
            end
        end
        function writeMemoryUsage(this, force)
            if this.settings.storeSelfTestResult && this.storeMemConsumption
                now = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss');
                if (this.lastTimeOfMemoryAnalysis + minutes(2) <= now) || force
                    if ispc
                        mem = memory();
                        this.statusFile.addMsg(msgLevel.DEBUG, sprintf("Memory used: %12f MB", mem.MemUsedMATLAB / (1024*1024)));
                    else
                        p = feature('getpid');
                        [~, out] = system(sprintf('ps -o rss= -p %d', p));
                        this.statusFile.addMsg(msgLevel.DEBUG, sprintf("Memory used: %12f MB", str2double(out) /1024));

                    end
                    this.lastTimeOfMemoryAnalysis = now;
                end
            end
        end
    end
end

