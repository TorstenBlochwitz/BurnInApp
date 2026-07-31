classdef BurnInDev < handle
    %BurnInDev: interface to a BurnIn Device consisting of
    %DCDCConverterBoard (with or without an LED Board) and a MainBoard
    %I2C Adresses:
        % 0x08: µC ATtiny84A: U3 
        % 0x38: DC/DC Converter for VDC1 SiC450: U1
        % 0x3A: DC/DC Converter for VDC2 SiC450: U2
        % 0x40: 16 bit I2C to GPIO PCF8575DWR: IC2
        % 0x90: ADC ADS1115: IC2
        % 0x92: ? exists also with deactivated I2C Multiplexer
        % 0x94: Temperature Sensor TMP1075DGKR: IC13
        % 0x98: Temperature Sensor TMP1075DGKR: IC10
        % 0x9C: Temperature Sensor TMP1075DGKR: IC11
        % 0xA0: EEPROM M24C02 (Memory access): IC3
        % 0xB0: EEPROM M24C02 (Identification page access): IC3
        % 0xE0: I2C Multiplexer PCA9542APW: IC9

    properties
        mbc = MBC_TB.empty;        %MBC
        offset;     %I2C Addr of the DCDC Converter Board
        MPaddr = 0xE0;      %Address of I2C Multiplexer (set to 0 if there is no)
        %MPaddr = 0x00;
        cOn = 0x04;         %Command to switch channel on
        cOff = 0x00;        %Command to switch channel off
        DCDCConv;   %DCDCConverter Board
        mainBoard;  %MainBoard
        noDCDCConverterErrorReported = 0;   % number of reported no DC/DC Converter Board error messages
        lastErrorMessage = "";
    end

    methods
        function this = BurnInDev()
            this.DCDCConv = DCDCConverterBoard(this.MPaddr, this.cOn, this.cOff);
            this.mainBoard = MainBoard(this.MPaddr, this.cOn, this.cOff);
        end
        function ret = ConnectBoards(this, mbc, offset)
            ret = 0;
            this.mbc = mbc;
            this.offset = offset;
            
            %fprintf("Connect Main Board %d\n", offset);

            ret = connectDCDCConverterBoard(this, mbc, offset);
            if ret==1
                ret = this.connectMainBoard();
            end
        end
        function ret = connectDCDCConverterBoard(this, mbc, offset)
            ret = 0;
            this.mbc = mbc;
            this.offset = offset;

            %fprintf("Check if DCDCConverter: %d exists\n", this.offset);
            %Is the I2C Multiplexer there?
            %TODO: Needs to be changed for final TCP/IP Version since there is no
            %I2C Multiplexer anymore
            if mbc.checkI2CAddr(this.MPaddr, offset)
                this.noDCDCConverterErrorReported = 0;
                %fprintf("Connecting DCDCConverter: %d\n", this.offset);
                ret = this.DCDCConv.Connect(mbc, offset);
                if ret>0
                    this.DCDCConv.setSiC450_Defaults(1);
                    this.DCDCConv.status = 1;
                    if ret == 2
                        this.DCDCConv.setSiC450_Defaults(2);
                    end
                    %set ATtinyStatus to a value > 1 to signal it was connected
                    this.DCDCConv.setATtinyStatus(2);
                    %fprintf("Connecting DCDCConverter: %d successful!\n", this.offset);
                end
            else
                if ret > 0
                    this.DCDCConv.status = 1;%one SiC450 is there
                else
                    this.DCDCConv.status = 0;
                end
                this.DCDCConv.lastErrorMsg = sprintf("No DC/DC Converter with I2C offset %d connected to MBC!", offset);
                this.noDCDCConverterErrorReported = min(this.noDCDCConverterErrorReported + 1, 10);
            end
        end
        function ret = connectMainBoard(this)
            ret = 0;
            %fprintf("Connecting Mainboard: %d\n", this.offset);
            if this.DCDCConv.nChannels > 1
                mainBoardKind = MainBoardKind.FullBoardWithATtiny;
            else
                mainBoardKind = MainBoardKind.HalfBoardWithATtiny;
            end
            ret = this.mainBoard.Connect(this.mbc, this.offset, mainBoardKind);
        end
        function ret = switchOffI2CMultiplexer(this)
            ret = 0;
            if this.MPaddr ~= 0
                try
                    this.mbc.writeBytesI2C(this.MPaddr, this.offset, this.cOff);
                    ret = 1;
                catch
                end
            end
        end
        function ret = UpdateRefToMBC(this, mbc)
            ret = 0;
            this.mbc = mbc;
            this.DCDCConv.UpdateRefToMBC(mbc);
            this.mainBoard.UpdateRefToMBC(mbc);
            ret = 1;
        end
        %TODO!
        function [status, VDC] = measureVDC(this, i, dmm)
            %Make sure the analog multiplexer is really switched off at the
            %end, even if an exception is thrown
            analogMux = AnalogMux(this.mainBoard);
            status = false;
            VDC = 0.0;
            iOther = 1;
            if i == 1
                iOther = 2;
            end
            useADC = false;
            %is DMM connected?
            if isempty(dmm) || ~isvalid(dmm)
                useADC = true; %use ADC
            else
                try
                    %does the DMM really work?
                    VDC = dmm.meas_VDC();
                catch
                    useADC = true; %use ADC    
                end
            end
            %Remember if VDCs are switched on
            statusVDC(1) = this.DCDCConv.getVDCswitchStatus(1);
            statusVDC(2) = this.DCDCConv.getVDCswitchStatus(2);
            %is VDC switched on?
            if (statusVDC(i) > 0)
                % manipulate timer to ensure it does not switch off everything
                tSwitchOff = this.DCDCConv.getTimer();
                this.DCDCConv.setTimer(0);
                %switch off other VDC if switched on to not influence the measurement
                this.DCDCConv.switchVDC(iOther, 0);
                %switch on
                this.DCDCConv.switchVDC(i, 1);
                %do measurement
                this.mainBoard.setMUX(this.GetVDCChannel(i));
                %wait a short time to let everything settle down -> does not help!
                %pause(0.1);
                if useADC
                    VDC = this.mainBoard.adc.getVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                else
                    VDC = dmm.meas_VDC();        
                end
                if VDC < 1.0
                    %Breakpoint!
                    fprintf("VDC is small: %f\n", VDC);
                end
                this.mainBoard.setMUX(-1);
                %switch timer back
                this.DCDCConv.setTimer(tSwitchOff);
                %switch VDC back
                this.DCDCConv.switchVDC(1, statusVDC(1));
                this.DCDCConv.switchVDC(2, statusVDC(2));
                status = true;
            end
        end
        function [status, VDC] = measureVDCmean(this, i, n, dmm)
            %Make sure the analog multiplexer is really switched off at the
            %end, even if an exception is thrown
            analogMux = AnalogMux(this.mainBoard);
            if n < 1
                n = 1;
            end
            useADC = false;
            %is DMM connected?
            if isempty(dmm) || ~isvalid(dmm)
                useADC = true; %use ADC
            else
                try
                    %does the DMM really work?
                    VDC = dmm.meas_VDC();
                catch
                    useADC = true; %use ADC    
                end
            end
            status = false;
            VDC = 0.0;
            iOther = 1;
            if i == 1
                iOther = 2;
            end
            %Remember if VDCs are switched on
            statusVDC(1) = this.DCDCConv.getVDCswitchStatus(1);
            statusVDC(2) = this.DCDCConv.getVDCswitchStatus(2);

            %is VDC switched on?
            if (statusVDC(i) > 0)
                tSwitchOff = this.DCDCConv.getTimer();
                this.DCDCConv.setTimer(0);
                %switch off other VDC if switched on to not influence the measurement
                this.DCDCConv.switchVDC(iOther, 0);
                %switch on
                this.DCDCConv.switchVDC(i, 1);
                %do measurement
                %wait a short time to let everything settle down -> does not help!
                %pause(0.1);
                Vmeas = zeros(1, n, 'double');
                for j = 1:1:n
                    this.mainBoard.setMUX(this.GetVDCChannel(i));
                    if useADC
                        Vmeas(j) = this.mainBoard.adc.getVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                    else
                        Vmeas(j) = dmm.meas_VDC();        
                    end
                    %fprintf("VDC%d(%d) = %f V\n", i, j, Vmeas(j));
                end
                this.mainBoard.setMUX(-1);
                %switch VDC back
                this.DCDCConv.setTimer(tSwitchOff);
                this.DCDCConv.switchVDC(1, statusVDC(1));
                this.DCDCConv.switchVDC(2, statusVDC(2));
                
                VDC = trimmedMean(Vmeas);
                status = true;
            end
        end
        function [R, VDC, VR] = meas_R(this, channel, n, dmm)
            %Make sure the analog multiplexer is really switched off at the
            %end, even if an exception is thrown
            analogMux = AnalogMux(this.mainBoard);
            VDC = 0;
            VR = 0;
            R = inf;
            measurementOK = 1;
            if n < 1
                n = 1;
            end
            try
                useADC = false;
                %is DMM connected?
                if isempty(dmm) || ~isvalid(dmm)
                    useADC = true; %use ADC
                else
                    try
                        %does the DMM really work?
                        VDC = dmm.meas_VDC();
                    catch
                        useADC = true; %use ADC    
                    end
                end
                Vmeas = zeros(1, n, 'double');
                for j = 1:1:n
                    %measure VDC
                    if channel < 60
                        %VDC1
                        this.mainBoard.setMUX(this.GetVDCChannel(1));
                    else
                        %VDC2
                        this.mainBoard.setMUX(this.GetVDCChannel(2));
                    end
                    if useADC
                        %Vmeas(j) = this.mainBoard.adc.getVoltage(ADS1115.CONFIG_MUX_SINGLE_0, ADS1115.GAIN_TWOTHIRDS_6_144);
                        Vmeas(j) = this.mainBoard.adc.getVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                    else
                        Vmeas(j) = dmm.meas_VDC();        
                    end
                    if Vmeas(j) < 1.0
                        %Breakpoint!
                        fprintf("VDC is small: %f\n", Vmeas(j));
                    end
                end
                VDC = trimmedMean(Vmeas);
                if measurementOK
                    Vmeas = zeros(1, n, 'double');
                    for j = 1:1:n
                        this.mainBoard.setMUX(channel);
                        if useADC
                            %Vmeas(j)  = this.mainBoard.adc.getVoltage(ADS1115.CONFIG_MUX_SINGLE_0, ADS1115.GAIN_TWOTHIRDS_6_144);
                            Vmeas(j) = this.mainBoard.adc.getVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                        else
                            Vmeas(j) = dmm.meas_VDC();
                        end
                    end
                    VR = trimmedMean(Vmeas);
                    if VR < 0.01
                        R = inf;
                    else
                        R = 0.82 * (VDC/VR - 1.0);
                    end
                    if R < 0.0
                        R = inf;
                    end
                end
            catch
                VDC = 0;
                VR = 0;
                R = inf;
            end
            this.mainBoard.setMUX(-1);
        end
        function [ret, bShort] = checkShortCircuit(this, vMax, Rexpected)
            %fprintf("Check Short Circuit started\n");
            %Make sure the analog multiplexer is really switched off at the
            %end, even if an exception is thrown
            analogMux = AnalogMux(this.mainBoard);

            numberOfEmitters = this.GetMaxNofEmitters();

            ret = 0;
            mainBoardStatusLED = 0;
            bShort = zeros(1, numberOfEmitters, 'logical');
            vMax = min(vMax, this.mainBoard.getVMaxShortCircuit());
            %Blink
            this.DCDCConv.switchStatusLED_DCDC(2);
            %setVoltage
            this.DCDCConv.setSiC450_Voltage(1, vMax(1));
            this.DCDCConv.setSiC450_Voltage(2, vMax(2));
            %switch VDC2 off to make sure it does not influence the
            %measurement of the upper half
            this.DCDCConv.switchVDC(2, 0);
            %switch VDC1 on 
            this.DCDCConv.switchVDC(1, 1);
            %measure VDC1
            this.mainBoard.setMUX(this.GetVDCChannel(1));
            VDC = this.mainBoard.adc.getVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
            Vmax = this.mainBoard.RShunt * (VDC / (this.mainBoard.RShunt + 0.5 * Rexpected(1)));
            for i = 1:1:numberOfEmitters
                %fprintf("i = %d\n", i);
                %switch RGB LED to red
                this.mainBoard.switchRGBLED(i, 255, 0, 0, true, true);
                %toggle Main Board status LED
                if mainBoardStatusLED == 0
                    mainBoardStatusLED = 1;
                else
                    mainBoardStatusLED = 0;
                end
                this.mainBoard.switchStatusLED(mainBoardStatusLED);
                if(i == 61)
                    %lower half
                    this.DCDCConv.switchVDC(1, 0);
                    %switch VDC2 on 
                    this.DCDCConv.switchVDC(2, 1);
                    this.mainBoard.setMUX(this.GetVDCChannel(2));
                    VDC = this.mainBoard.adc.getVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                    %Resistances with less than 0.5*Rexpectd are counted as short circuits
                    %max voltage caused by R = 0.5*Rexpected
                    Vmax = this.mainBoard.RShunt * (VDC / (this.mainBoard.RShunt + 0.5 * Rexpected(2)));
                end
                this.mainBoard.setMUX(i-1);
                VR(1) = this.mainBoard.adc.getVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                VR(2) = this.mainBoard.adc.getVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                %Measure maximum 5 times or as long as 2 measurements do not differ more than 20 %
                for k = 1:1:5
                    diff = abs(VR(1) - VR(2));
                    %fprintf("i = %d k = %d: VDC = %d VR1 = %d VR2 = %d Vmax = %d\n", i, k, VDC, VR(1), VR(2), Vmax);
                    if diff < abs(0.2 * max(VR(1), VR(2)))
                        break;
                    end
                    VR(1) = VR(2);
                    VR(2) = this.mainBoard.adc.getVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
                end
                if VR(1) > Vmax && VR(1) < VDC
                    bShort(i) = true;
                    ret = ret + 1;
                end
            end
            this.mainBoard.setMUX(-1);
            %switch off RGB LEDs 
            this.mainBoard.switchRGBLED(0, 0, 0, 0, true, true);
            %switch Off Main Board status LED
            this.mainBoard.switchStatusLED(0);
            %switch off DCD status LED
            this.DCDCConv.switchStatusLED_DCDC(0);
        end
        function [VDC, VR, R, Rm] = completeMeasurement(this, nSkip, nMean, numberOfEmitters, dmm, measApp)
            %works with n= 0, 1, 2, 3, 4 (5, 6, 8, 10, 12)
            mainBoardStatusLED = 0;
            %fprintf("Measurement started\n");
            if nSkip(1) == 0
                nSkip(1) = 1;
            end
            if nSkip(2) == 0
                nSkip(2) = 1;
            end
            %limit numberOfEmitters to maximum possible
            if this.mainBoard.mainBoardKind > MainBoardKind.FullBoardWithATtiny
                n = min(60/nSkip(1), numberOfEmitters);
            else
                n = min(uint8(60/nSkip(1) + 60/nSkip(2)), numberOfEmitters);
            end
            VDC = zeros(1, n, 'double');
            VR =  zeros(1, n, 'double');
            R = zeros(1, n, 'double') + inf;
            Rm = zeros(12, 10, 'double') + inf;
            debug = this.mainBoard.debug;
            this.mainBoard.debug = 0;
            interactive = ~isempty(measApp) && isvalid(measApp);
            if interactive
                progress = uiprogressdlg(measApp.BurnInBoardMaintenanceUIFigure, 'Title', 'Measurement is running...', 'Value', 0, "Cancelable","on","CancelText",'Cancel');
            end
            %Remember if VDC1 and 2 are switched on
            statusVDC1 = this.DCDCConv.getVDCswitchStatus(1);
            statusVDC2 = this.DCDCConv.getVDCswitchStatus(2);
            %extend switchOffTimer of ATtiny if we are close to switchOff time
            tSwitchOff = this.DCDCConv.getTimer();
            this.DCDCConv.setTimer(0);
            %switch VDC2 off to make sure it does not influence the
            %measurement of the upper half
            this.DCDCConv.switchVDC(2, 0);
            %switch VDC1 on 
            this.DCDCConv.switchVDC(1, 1);
            if nSkip(1) > 1
                iStart = 2;
            else
                iStart = 1;
            end
            k=1;    %position in vectors
            col = 1;  %column in R-vector
            row = iStart;  %row in R-vector
            i = iStart;
            lowerHalf = false;
            nCurSkip = nSkip(1);
            for m = 1:1:n
                %fprintf('k = %d\n', k);
                %fprintf('i = %d\n', i);
                %switch RGB LED to orange 
                this.mainBoard.switchRGBLED(i, 255, 204, 0, true, true);
                %toggle Main Board status LED
                if mainBoardStatusLED == 0
                    mainBoardStatusLED = 1;
                else
                    mainBoardStatusLED = 0;
                end
                this.mainBoard.switchStatusLED(mainBoardStatusLED);
                if interactive
                    if progress.CancelRequested
                        break
                    end
                end
                [R(k), VDC(k), VR(k)] = this.meas_R(i-1, nMean, dmm);
                Rm(row,col) = R(k);
                if interactive
                    measApp.Resistance.Data = Rm;
                    drawnow();
                    progress.Value = k/double(n);
                    progress.Message = sprintf('%d / %d', k, n);
                end
                row = row + nCurSkip;
                if i < 60
                    if row > 6
                        row = iStart;
                        col = col + 1;
                        if col > 10
                            col = col + 1;
                        end
                    end
                else
                    if lowerHalf == false
                        nCurSkip = nSkip(2);
                        if nCurSkip > 1
                            iStart = 2;
                        else
                            iStart = 1;
                        end
                        this.DCDCConv.switchVDC(1, 0);
                        this.DCDCConv.switchVDC(2, 1);
                        lowerHalf = true;
                        col = 1;
                        row = 6 + i - 60 + iStart;   %looks strange, but is correct, for example with nSkip = 3, we start at row 9
                    end
                    if row > 12
                        row = 6 + iStart;
                        col = col + 1;
                        if col > 10
                            col = col + 1;
                        end
                    end
                end
                k = k + 1;
                i = i + nCurSkip;
            end
            %set timer back
            this.DCDCConv.setTimer(tSwitchOff);
            %set VDC's back
            this.DCDCConv.switchVDC(1, statusVDC1);
            this.DCDCConv.switchVDC(2, statusVDC2);
            this.mainBoard.setMUX(-1);
            this.mainBoard.debug = debug;
            
            %switch off RGB LEDs 
            this.mainBoard.switchRGBLED(0, 0, 0, 0, true, true);
            %switch Off Main Board status LED
            this.mainBoard.switchStatusLED(0);
            %switch off DCD status LED
            this.DCDCConv.switchStatusLED_DCDC(0);
        end
        
        function [ret, strFilename] = saveMeasurement(this, folder, dDate, dTime, postfix, SNr, VDC, VR, R)
            T(1) = this.mainBoard.tempSensor(1).getTemperatureCelsius();
            T(2) = this.mainBoard.tempSensor(2).getTemperatureCelsius();
            T(3) = this.mainBoard.tempSensor(3).getTemperatureCelsius();
            k = 1;
            strT(1) = "";
            strTHead(1) = "";
            for i = 1:size(T, 2)
                if T(i) > -273
                    strT(k) = sprintf("%0.3f", T(i));
                    strTHead(k) = sprintf("T%d", k);
                    k = k + 1;
                end
            end
            ret = 1;
            %build filename
            if convertCharsToStrings(postfix) ~= ""
                strTime = strrep(sprintf("%s", dTime), ':', '_');
                strFilename = fullfile(folder, sprintf('%s-%s_%s.csv', dDate, strTime, postfix));
            else
                strFilename = folder;
            end
            %generate folder if not existing
            % extract folder
            [folder, ~, ~] = fileparts(strFilename);
            if ~exist(folder, 'dir')
                if ~mkdir(folder)
                    this.lastErrorMessage = sprintf("Folder: %s could not be created!", folder);
                end
            end
            %store header
            strHeader = ["Date", "Time", "Channel", "SNr" "VDC", "VR", "R", strTHead];
            %store data
            try
                writematrix(strHeader, strFilename,'Delimiter','tab');
                for i = 1:size(VDC,2)
                    if size(SNr, 2) < i
                        strSNr = sprintf("%s", SNr(1));
                    else
                        strSNr = sprintf("%s", SNr(i));
                    end
                    strRow = [sprintf("%s", dDate), sprintf("%s", dTime), sprintf("%d", i), sprintf("%s", strSNr), sprintf("%f", VDC(i)), sprintf("%f", VR(i)), sprintf("%f", R(i)), strT];
                    writematrix(strRow, strFilename, 'Delimiter','tab', 'WriteMode','append');
                end
            catch
                this.lastErrorMessage = sprintf("%s Cannot write measured data to %s. Please check access rights to the folder and free space on your disc!", this.lastErrorMessage, strFilename);
                ret = 0;
            end
        end
        function switchOff(this, complete)
            if nargin < 1
                complete = true;
            end
            this.mainBoard.switchOff(complete);
            this.DCDCConv.switchOff();
        end
        function ret = switchOn(this, VDC1, VDC2, f1, f2, dutyCycle1, dutyCycle2, duration)
            ret = 1;
            try
                this.mainBoard.switchOn();
                this.DCDCConv.switchOn(VDC1, VDC2, f1, f2, dutyCycle1, dutyCycle2, duration);
            catch e
                ret = 0;
            end
        end
        function ret = GetMainBoardKind(this)
            ret = this.mainBoard.mainBoardKind;
        end
        function ret = GetNofBanks(this)
            if this.mainBoard.mainBoardKind > MainBoardKind.FullBoardWithATtiny
                ret = 1;
            else
                ret = 2;
            end
        end
        function ret = GetMaxNofEmitters(this)
            if this.mainBoard.mainBoardKind > MainBoardKind.FullBoardWithATtiny
                ret = 60;
            else
                ret = 120;
            end
        end
        function ret = GetVDCChannel(this, index)
            if this.mainBoard.mainBoardKind > MainBoardKind.FullBoardWithATtiny
                if index == 1
                    ret = 60;
                else
                    ret = 0;
                end
            else
                if index == 1
                    ret = 120;
                else
                    ret = 124;
                end
            end
        end
    end
end
