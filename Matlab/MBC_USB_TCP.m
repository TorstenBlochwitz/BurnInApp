classdef MBC_USB_TCP < handle
    % MBC which supports serial and TCP/IP based communication
    % Torsten Blochwitz Electronics & Software for InfraSolid
    
    %IP Address for Linux: 169.254.2.32
    
    properties
        mode = MBCModeEnum.UNKNOWN;
        strMode = 'I2C';
        addrOffset=0;
        s;  % serialport
        port;
        Baudrate = 19200;
        status = 'closed'
        closeFlag=1;

        tcpClient = TCPClient;
        nTcpClients = 8;
        tcpClientConnectErrorReported;
        ipAddr = '';
        tcpPort = 50000;

        Timeout = 1;
        nRepeat = 20;
        version = '';
        statusFile StatusFile;
        debug = true;

        DUTi2cEnable = true;
        %This table defines how I2C Adresses and their offsets are handled:
        % col1: I2Caddress
        % col2: Communication Mode for this I2C Address via I2C
        % col3: Communication Mode for this I2C Address via TCP
        % Allows letting larger software components unchanged if hardware has changed. For
        % example if I2C participants are no longer used. (Works only for
        % sending messages, since we don't know what the receiver would
        % have answered.)
        %        0: do not add the offset value to I2Caddress / 2 and communicate
        %        1: add the offset value to I2Caddress / 2 and communicate. Allows to use the offset value to select a certain TCPClient to be used. But offset is not used in the I2C Address
        I2CAddresses = {0 I2CAddrProp.DO_NOTHING I2CAddrProp.DO_NOTHING};
    end
    
    methods
        function this = MBC_USB_TCP(varargin)
            %find out if I2C or Ethernet shall be used
            this.mode = MBCModeEnum.I2C;
            if nargin == 1
                strAddr = varargin{1}{1};
                if (ischar(strAddr) || isstring(strAddr)) && ((strAddr == "") || checkIPAddress(strAddr) || ~contains(strAddr, 'COM', 'IgnoreCase', true))
                    this.mode = MBCModeEnum.TCP;
                end
            end
            if this.debug
                if ispc
                    folder = 'C:/Temp/CommunicationStatus';
                else
                    folder = '~/BurnInApp/Status/Communication/';
                end
                if ~isfolder(folder)
                    mkdir(folder);
                end
                if this.mode == MBCModeEnum.TCP
                    this.statusFile = StatusFile(folder, 'Ethernet Communication');
                else
                    this.statusFile = StatusFile(folder, 'I2C Communication');
                end
            end
            if this.mode == MBCModeEnum.I2C
                if (nargin == 0) || isempty(strAddr) || contains(strAddr, 'COM', 'IgnoreCase', true)
                    if ispc
                        Ports=findserial();
                        if isempty(Ports)
                            sclose();
                            % errordlg('No Port is detected, please be sure that MBC is connected to your computer.','Error');
                            % error('No Port is detected, please be sure that MBC is connected to your computer.')
                        else
                            handles.Ports=Ports;
                            if isscalar(Ports)
                                this.port = Ports{1};
                                this.serOpen();
                                this.serClose();
                                this.mode = MBCModeEnum.I2C;
                            else
                                
                                answer = listdlg('PromptString','Select a COM port',...
                                    'SelectionMode','single',...
                                    'ListString',handles.Ports);
                                if ~isempty(answer)
                                    
                                    this.port = Ports{answer};
                                    this.serOpen();
                                    this.serClose();
                                else
                                    warning('No serial object is created, there no function can be called later.');
                                    msgbox('No serial object is created, therefore no function can be called later.')
                                end
                            end
                        end
                    else
                        this.port = '/dev/ttyUSB-MBC';
                        this.serOpen();
                        this.serClose();                                    
                        this.mode = MBCModeEnum.I2C;
                    end
                else
                    if isobject(varargin{1})
                        this.s = varargin{1};
                        this.mode = MBCModeEnum.I2C;
                    else
                        this.mode = MBCModeEnum.UNKNOWN;
                        error('Arg1 is neither a serial port, nor an IP Address or a COM port name!');
                    end
                end
            else
                this.ipAddr = strAddr;
                %this.port = strAddr;
                for n = 1:1:this.nTcpClients
                    this.tcpClient(n) = TCPClient();
                    this.tcpClient(n).nRepeat = 1;
                    this.tcpClientConnectErrorReported(n) = false;
                end
                this.mode = MBCModeEnum.TCP;
                this.strMode = 'TCP';
            end
        end
        function strPort = GetConnectedPort(this)
            if this.mode == MBCModeEnum.I2C
                strPort = this.port;
            else
                n = this.GetNumberOfConnectedTCPClients();
                strPort = sprintf("%d Ethernet MBCs", n);
            end
        end
        function n = GetNumberOfConnectedTCPClients(this)
            n = 0;
            for k = 1:1:size(this.tcpClient, 2)
                if ~isempty(isvalid(this.tcpClient(k)))
                    if this.tcpClient(k).status.getStatus() == TCPClientStatusEnum.CONNECTED
                        n = n+1;
                    end
                end
            end
        end
        %%
        function delete(this)
            % close all open interfaces
            delete(this.s);
            for n = 1:1:size(this.tcpClient, 1)
                delete(this.tcpClient(n));
            end
        end
        %%
        function portopen(this)            
            if strcmp (this.status, 'closed')
                this.serOpen();
            end
        end
        %%
        function ret = connectToTCPServer(this, index, ipAddr, connectTimeOut)
            ret = false;
            if this.mode == MBCModeEnum.TCP
                this.tcpClient(index+1).connectToServer(ipAddr, this.tcpPort, connectTimeOut);
                if this.tcpClient(index+1).status.getStatus() ~= TCPClientStatusEnum.CONNECTED
                    if ~this.tcpClientConnectErrorReported(index+1)
                        this.statusFile.addMsg(msgLevel.ERROR, sprintf("Connect to %s failed : %s\n", this.tcpClient(index+1).host, this.tcpClient(index+1).strError));
                        this.tcpClientConnectErrorReported(index+1) = true;
                    end
                    error(this.tcpClient(index+1).strError);
                else
                    this.statusFile.addMsg(msgLevel.INFO, sprintf("Connected %s\n", this.tcpClient(index+1).host));
                    this.tcpClientConnectErrorReported(index+1) = false;
                    ret = true;
                end
            end
        end
        function ret = ping(this, index)
            ret = false;
            try
                if this.mode == MBCModeEnum.I2C
                    %TODO: Test
                    ver = this.writeSerial('V');
                else
                    ret = this.tcpClient(index+1).pingServer();
                end
            catch
                ret = false;
            end
        end
        %Sends the string in message to the respective interface
        function resp = writeMessage(this, message, offset)
            resp = '001';
            % Reset the warnings
            lastwarn('');
            if this.mode == MBCModeEnum.I2C
                % Open the Port if necessary
                this.portopen();
                
                restore = this.closeFlag;
                this.closeFlag = 0;
                
                % Write the message to the serialport
                writeline(this.s,message);
                
                % Conversion to char for compatibility reasons
                resp = char(readline(this.s)); 
                
                this.closeFlag = restore;
                
                % serClose handles the closeflag
                this.serClose();
            else
                if this.tcpClient(offset+1).status.getStatus() == TCPClientStatusEnum.CONNECTED
                    this.tcpClient(offset+1).send(message);
                    [resp, ] = this.tcpClient(offset+1).receiveLine();
                    resp = char(resp);
                end
            end
            
            % Remove non-printable char
            resp = resp(resp>32&resp<127); 

            %Throw warnings as Errors 
            error(lastwarn);
        end
        %% use I2CAddresses
        function [addr, communicate] = adaptAddr(this, I2CAddr, offset)
            addr = I2CAddr/2;
            communicate = true;
            if this.mode == MBCModeEnum.I2C
                col = 2;
            else
                col = 3;
            end
            idx = find(cellfun(@(x) x==I2CAddr, this.I2CAddresses(:, 1)));
            if ~isempty(idx)
                if this.I2CAddresses{idx, col} == I2CAddrProp.USE_OFFSET
                    addr = I2CAddr / 2 + offset;
                elseif this.I2CAddresses{idx, col} == I2CAddrProp.DO_NOTHING
                    communicate = false;
                end
            end
            %fprintf('Addr = %d\n', addr);
        end
        %% send bytes to the I2C device addr + offset
        %% addr is the 8 bit representation of the I2C address
        %% first element of bytes is sent first
        function ret = writeBytesI2C(this, addr, offset, bytes)
            ret = 0;
            [I2Caddr, doWrite] = this.adaptAddr(addr, offset);
            if ~doWrite
                return
            end

            this.switchI2C(0);
            
            str="";
            for index = 1:length(bytes)
               str = str + dec2hex(bytes(index),2); 
            end
            str=convertStringsToChars(str);
            
            %fprintf('%s\n', [ 'IW_'  dec2hex(addr/2+offset,2) dec2hex(length(bytes),3) str 13]);
            msg = [ 'IW_'  dec2hex(I2Caddr,2) dec2hex(length(bytes),3) str];
            for i=1:1:this.nRepeat
                try
                    resp = this.writeMessage(msg, offset);
            
                    if ~isempty(resp)
                        this.CBerror(resp);
                    else
                        break;
                    end
                catch e
                    if this.debug
                        if offset == 0
                            strAddr = sprintf("0x%X", addr);
                        else
                            strAddr = sprintf("0x%X, offset = %d", addr, offset);
                        end
                        this.statusFile.addMsg(msgLevel.WARNING, sprintf("%d. %s communication problem in writeBytesI2C: %s\naddr = %s, msg = %s\n", i, this.strMode, e.message, strAddr, msg));
                    end
                    if this.mode == MBCModeEnum.I2C
                        if i>this.nRepeat/2
                            if this.debug
                                this.statusFile.addMsg(msgLevel.WARNING, sprintf("\n--> Reseting I2C Bus.\n"));
                            end
                            this.resetI2C();
                        end
                    end
                    if i==this.nRepeat
                        rethrow(e);
                    end
                end
            end
            ret = 1;
        end

        %% send bytes to the I2C device addr + offset
        %% addr is the 8 bit representation of the I2C address
        %% first element of bytes is sent first
        function ret = writeBytesI2CCheck(this, addr, offset, bytes, mask)
            ret = 0;
            [I2Caddr, doWrite] = this.adaptAddr(addr, offset);
            if ~doWrite
                return
            end

            this.switchI2C(0);
            
            str="";
            for index = 1:length(bytes)
               str = str + dec2hex(bytes(index),2); 
            end
            str=convertStringsToChars(str);
            
            %fprintf('%s\n', [ 'IW_'  dec2hex(addr/2+offset,2) dec2hex(length(bytes),3) str 13]);
            msg = [ 'IW_'  dec2hex(I2Caddr,2) dec2hex(length(bytes),3) str];
            for i=1:1:this.nRepeat
                try
                    resp = this.writeMessage(msg, offset);
            
                    if ~isempty(resp)
                        this.CBerror(resp);
                    end

                    % check read stability
                    read1 = this.readBytesI2C(addr, offset, length(bytes));
                    read2 = this.readBytesI2C(addr, offset, length(bytes));
                    if ~isequal(read1, read2)
                        fprintf('Problem1 in checking returned bytes\n');
                        this.CBerror('029');
                    end
                    %check returned value
                    if isequalmask(read2, bytes, mask)
                    %if isequal(read2, bytes)
                       break
                    else
                        fprintf('Problem2 in checking returned bytes\n');
                        this.CBerror('029');
                    end
                catch e
                    if this.debug
                        if offset == 0
                            strAddr = sprintf("0x%X", addr);
                        else
                            strAddr = sprintf("0x%X, offset = %d", addr, offset);
                        end
                        this.statusFile.addMsg(msgLevel.WARNING, sprintf("%d. %s communication problem in writeBytesI2C: %s\naddr = %s, msg = %s\n", i, this.strMode, e.message, strAddr, msg));
                    end
                    if this.mode == MBCModeEnum.I2C
                        if i>this.nRepeat/2
                            if this.debug
                                this.statusFile.addMsg(msgLevel.WARNING, sprintf("\n--> Reseting I2C Bus.\n"));
                            end
                            this.resetI2C();
                        end
                    end
                    if i==this.nRepeat
                        rethrow(e);
                    end
                end
            end
            ret = 1;
        end

        %% send the nCmd bytes cmd to the I2C device addr + offset, returns nRead bytes
        %% addr is the 8 bit representation of the I2C address
        function bytes = queryBytesI2C(this, addr, offset, cmd, nCmd, nRead)
            [I2Caddr, ] = this.adaptAddr(addr, offset);
            
            bytes=zeros(1, nRead, 'uint8');
            
            this.switchI2C(0);

            str=dec2hex(cmd, nCmd*2);
            
            %fprintf([ 'IQ_'  dec2hex(addr/2+offset,2) dec2hex(nCmd,3) dec2hex(nRead,3) str 13])
            msg = [ 'IQ_'  dec2hex(I2Caddr,2) dec2hex(nCmd,3) dec2hex(nRead,3) str];
            for i=1:1:this.nRepeat
                try
                    resp = this.writeMessage(msg, offset);
                    
                    if nRead*2 ~= length(resp)
                        this.CBerror(resp);
                    else
                        break;
                    end
                catch e
                    if this.debug
                        if offset == 0
                            strAddr = sprintf("0x%X", addr);
                        else
                            strAddr = sprintf("0x%X, offset = %d", addr, offset);
                        end
                        
                        this.statusFile.addMsg(msgLevel.WARNING, sprintf("%d. %s communication problem in queryBytesI2C: %s\naddr = %s, msg = %s\n", i, this.strMode, e.message, strAddr, msg));
                    end
                    if this.mode == MBCModeEnum.I2C
                        if i>this.nRepeat/2
                            if this.debug
                                this.statusFile.addMsg(msgLevel.WARNING, sprintf("\n--> Trying ResetI2C Bus.\n"));
                            end
                            this.resetI2C();
                        end
                    end
                    if i==this.nRepeat
                        rethrow(e);
                    end
                end
            end
            for index = 1:nRead
                bytes(index) = hex2dec(resp((2*index - 1):(2*index)));
            end
        end

        %%
        %% read nRead bytes from the I2C device addr + offset, returns nRead bytes
        %% addr is the 8 bit representation of the I2C address
        function bytes = readBytesI2C(this, addr, offset, nRead)
            [I2Caddr, ] = this.adaptAddr(addr, offset);
            bytes=zeros(1, nRead, 'uint8');
            
            this.switchI2C(0);

            %fprintf(this.s, [ 'IR_'  dec2hex(addr/2+offset,2) dec2hex(nRead,3) 13]);
            msg = [ 'IR_'  dec2hex(I2Caddr,2) dec2hex(nRead,3)];
            for i=1:1:this.nRepeat
                try
                    resp = this.writeMessage(msg, offset);

                    if nRead*2 ~= length(resp)
                        this.CBerror(resp);
                    else
                        break;
                    end
                catch e
                    if this.debug
                        if offset == 0
                            strAddr = sprintf("0x%X", addr);
                        else
                            strAddr = sprintf("0x%X, offset = %d", addr, offset);
                        end
                        this.statusFile.addMsg(msgLevel.WARNING, sprintf("%d. %s communication problem in readBytesI2C: %s\naddr = %s, msg = %s\n", i, this.strMode, e.message, strAddr, msg));
                    end
                    if this.mode == MBCModeEnum.I2C
                        if i>this.nRepeat/2
                            if this.debug
                                this.statusFile.addMsg(msgLevel.WARNING, sprintf("\n--> Reseting I2C Bus.\n"));
                            end
                            this.resetI2C();
                        end
                    end
                    if i==this.nRepeat
                        rethrow(e);
                    end
                end
            end
            for index = 1:nRead
                bytes(index) = hex2dec(resp((2*index - 1):(2*index)));
            end
        end

        %% send the nCmd bytes cmd to the I2C device addr + offset, returns nRead bytes
        %% addr is the 8 bit representation of the I2C address
        function string = queryString(this, offset, msg)
            this.switchI2C(0);
            resp = "Error";
            for i=1:1:this.nRepeat
                try
                    resp = this.writeMessage(msg, offset);
                    break;
                catch e
                    if this.debug              
                        this.statusFile.addMsg(msgLevel.WARNING, sprintf("%d. %s communication problem in queryString: %s\nmsg = %s\n", i, this.strMode, e.message, msg));
                    end
                    if this.mode == MBCModeEnum.I2C
                        if i>this.nRepeat/2
                            if this.debug
                                this.statusFile.addMsg(msgLevel.WARNING, sprintf("\n--> Trying ResetI2C Bus.\n"));
                            end
                            this.resetI2C();
                        end
                    end
                    if i==this.nRepeat
                        rethrow(e);
                    end
                end
            end
            string = resp;
        end

        %TODO: Add offset as argument to make sure the correct TCP Server
        %is used!
        function ret = tryReconnect(this, index)
            if nargin < 2
                index = 1;
            end
            if this.mode == MBCModeEnum.I2C
                for i = 1:1:this.nRepeat
                    fprintf("Trying to reconnect: %d of %d\n", i, this.nRepeat);
                    if ~isempty(this.s) && isvalid(this.s)
                        %close if open
                        delete(this.s);
                        this.status = 'closed';
                    end
                    %try to connect at the same port
                    try
                        this.serOpen();
                        this.reset();
                        ret = 1;
                        return
                    catch e
                        ret = 0;
                        fprintf("Reconnect failed: %s Waiting...\n", e.message);
                        if i<10
                            pause(1.3^i);
                        end
                    end
                end
                for i = 1:1:this.nRepeat
                    %on Windows, try other COM-ports
                    if ispc
                        Ports = findserial();
                        for k = 1:length(Ports)
                            try
                                fprintf("Trying connect to %s: %d of %d\n", Ports{k}, i, this.nRepeat);
                                lastwarn('');
                                sTmp = serialport(Ports{k},19200,'Timeout',1,'ByteOrder',"big-endian");
                                configureTerminator(sTmp,"CR");
                                %Ask for version
                                writeline(sTmp, 'V');
                                resp = char(readline(sTmp));
                                error(lastwarn());
                                resp = resp(resp>32&resp<127);
                                fprintf('MBC Version: %s\n', resp);
                                this.port = Ports{k};
                                delete(sTmp);
                                this.serOpen();
                                this.reset();
                                ret = 1;
                                return
                            catch e
                                ret = 0;
                                if ~isempty(sTmp) && isvalid(sTmp)
                                    delete(sTmp);
                                end
                                fprintf("Connect to %s failed: %s Waiting...\n", Ports{k}, e.message);
                                if i<10
                                    pause(1.3^i);
                                end
                            end
                        end
                    end
                end
            else
                for i = 1:1:this.nRepeat
                    fprintf("\n...Trying to reconnect: %d of %d\n", i, this.nRepeat);
                    %TODO: Find the correct tcpClient!
                    if this.tcpClient(index).tryReconnectToServer(10) == true
                        this.statusFile.addMsg(msgLevel.INFO, sprintf("Reconnected to %s\n", this.tcpClient(index).host));
                        ret = 1;
                        return
                    else
                        ret = 0;
                        fprintf("Reconnect failed: Waiting %.2f s...\n", 1.35^i);
                        this.statusFile.addMsg(msgLevel.WARNING, sprintf("Reconnect to %s failed : %s\n", this.tcpClient(index).host, this.tcpClient(1).strError));
                        pause(1.35^i);
                    end
                end
            end
        end
        function ver = getVersion(this)
            if this.mode == MBCModeEnum.I2C
                ver = this.writeSerial('V');
            else
                %TODO: Find the first connected TCP MBC or print "No MBC connected"
                ver = this.queryString(0, "V");
            end
        end
        function ctr = getErrorCounter(this, offset)
            if this.mode == MBCModeEnum.I2C
                ctr = '0|0';
            else
                ctr = this.writeMessage('C', offset);
            end
        end
        %%
        %% Reset I2C bus by sending 9 high pulses on SCL (PD0)
        function resetI2C(this)

            %TODO: Implement for TCP/IP
            if this.mode == MBCModeEnum.I2C
                this.switchI2C(0);
    
                msg0 = 'PS_D00';
                msg1 = 'PS_D01';
                try
                    this.writeSerial(msg0);
                    for i=1:1:8
                        this.writeSerial(msg1);
                        this.writeSerial(msg0);
                    end
                    this.writeSerial(msg1);
                catch e
                    if this.debug
                        this.statusFile.addMsg(msgLevel.WARNING, sprintf("%d. I2C communication problem in resetI2C: %s\nmsg = %s\n", i, e.message, msg0));
                    end
                end
            end
        end

        %%
        function reset(this)
            %TODO: Implement for TCP
            if this.mode == MBCModeEnum.I2C
                restore = this.closeFlag;
                this.closeFlag = 0;
                
                this.switchI2C(0);
                
                %this.portopen()
    %             % DTR pin is connected to reset pin of uC (jumper needed)
    %             this.s.DataTerminalReady = 'on';
    %             pause(0.2);
    %             this.s.DataTerminalReady = 'off';
    %             pause(1.8); % 1.4s is minimum
                this.writeSerial('R');
                pause(1.8);
                
                flush(this.s);
    
    %             fprintf(this.s, ['R' 13]); % sw reset
    %             pause(1.8)
    %             flushinput(this.s) % after reset, just flush input
    
                msg = 't11001';
                this.writeSerial(msg);
                msg = 't_020';
                this.writeSerial(msg);
                msg = 'RS_13';
                this.writeSerial(msg);
                msg = 'IS_13';
                this.writeSerial(msg);
                msg = 'PS_C20';
                this.writeSerial(msg);
                msg = 'PS_E20';
                this.writeSerial(msg);
                
                
    %             fprintf(this.s, ['t11001' 13]); %critical parameter wait time of MCB to TSIC
    %             fgetl(this.s);
    %             fprintf(this.s, ['t_020' 13]);
    %             fgetl(this.s);
    %             fprintf(this.s, ['RS_13' 13]);
    %             fgetl(this.s);
    %             fprintf(this.s, ['IS_13' 13]);
    %             fgetl(this.s);
    %             % config DAC for 5V
    %             %fprintf(this.s, ['IW_4C0020FFF' 13])
    %             %fgetl(this.s);
    %             % set digital mode
    %             fprintf(this.s, ['PS_C20' 13]);
    %             fgetl(this.s);
    %             % set i2c to internal
    %             fprintf(this.s, ['PS_E20' 13]);
    %             fgetl(this.s);
    %             fclose(this.s);
    %             error(lastwarn); % throw error in case of warning
                
                this.closeFlag = restore;
                this.serClose();
            end
        end
        %%
        function setVdd(this, Vdd)
            restore = this.closeFlag;
            this.closeFlag = 0;
            
            this.switchI2C(0);
            msg = ['IW_4C0020' sprintf('%0.3X',round(Vdd/5*4095))];
            this.writeSerial(msg);
            
            this.closeFlag = restore;
            this.serClose();
        end
        %%
        function Vdd = getVdd(this)
            
            restore = this.closeFlag;
            this.closeFlag = 0;
            
            conf = '1011000100000011';
            this.switchI2C(0);
            
            msg = ['IW_4900301' dec2hex(bin2dec(conf))];
            this.writeSerial(msg);
            
            pause(0.5)
            
            msg = 'IW_4900100';
            this.writeSerial(msg);
            
            msg = 'IR_49002';
            resp = this.writeSerial(msg);
            Vdd = hex2dec(resp)/2^15*6.144;
            
        
            this.closeFlag = restore;
            this.serClose();
        end
        %%
        %% Scan the address between hex address
        % returs address as 8bit version
        function [addr,hexaddr]=scanI2CAddr(this)
            
            restore = this.closeFlag;
            this.closeFlag = 0;
            
            this.switchI2C(1);
           
            addr=[];
            addr(1) = -1;
            hexaddr(1) = "Nothing found";
            index = 1;
            for i=1:127
                fprintf("%d\n", i);
                %msg = ['ir_',dec2hex(i),'001'];
                %resp = this.writeSerial(msg);
                msg = ['IR_',dec2hex(i,2),'001'];
                resp = this.writeMessage(msg, 0);
                if length(resp)==3
                    continue;
                else
                    hexaddr(index)=string(dec2hex(2*i,2));
                    addr(index)=2*i;
                    index=index+1;
                end
            end
            
            this.closeFlag = restore;
            this.serClose();
        end
        
        
        %%
        function Mid = readEEPMid(this,Address)
            Mid = this.ReadEEPromMemory(Address,36,4);
            Mid = Mid(Mid>32&Mid<127);
            Mid = hex2dec(Mid);
        end
        
        %%
        function Pos = readEEPPos(this,Address)
            Pos = this.ReadEEPromMemory(Address,40,2);
            Pos = Pos(Pos>32&Pos<127);
            Pos = hex2dec(Pos);
        end
        
        %%
        function resp = writeEEPMid(this,Address,mid)
            resp = this.WriteEEPromMemory(Address,36,4,mid);
        end
        
        %%
        function resp = writeEEPPos(this,Address,pos)
            resp = this.WriteEEPromMemory(Address,40,2,pos);
        end
        
        %%
        function resp = clearEEPMid(this,Address)
            resp = this.WriteEEPromMemory(Address,36,4,2^32-1);
        end
        
        %%
        function resp = clearEEPPos(this,Address)
            resp = this.WriteEEPromMemory(Address,40,2,2^16-1);
        end
        %%
        function UUID = get_DUT_UUID(this,Address)
            
            restore = this.closeFlag;
            this.closeFlag = 0;
            
            this.switchI2C(1);
            pause(0.005)
      %      this.setVdd(3.3);
            %this.portopen()
           
            UUID = {};
            
            msg = [ 'IW_'  dec2hex(Address/2,2) '001' '00'];
            resp = this.writeSerial(msg);
            
%             lastwarn('')
%             fprintf(this.s, [ 'IW_'  dec2hex(Address/2,2) '001' '00' 13]);
%             resp = fgetl(this.s);
%             error(lastwarn())
%             resp = resp(resp>32&resp<127); % remove non-printabel char
            if length(resp)==3 % no ack -> no device present
                error("No UUID on Address %d",Address);
            end
            msg = [ 'IR_'  dec2hex(Address/2) '032'];
            resp = this.writeSerial(msg);
%             
%             fprintf(this.s, [ 'IR_'  dec2hex(Address/2) '032' 13]);
%             resp = fgetl(this.s);
%             error(lastwarn())
%             resp = resp(resp>32&resp<127); % remove non-printabel char
            UUID{1,1} =  resp;
          
            this.closeFlag = restore;
            this.serClose();
        end
        
        %%
    end
    methods
        %---------------------------------------------------------------------
        function switchI2C(this,port)
            % switch between internal and DUT port
            % 0: internal (control bus)
            % 1: DUT
            if this.mode == MBCModeEnum.I2C
                if ~this.DUTi2cEnable
                    port = 0;
                end
                
                % set i2c to internal
                if port
                    msg = 'PS_E21';
                else
                    msg = 'PS_E20';
                end
                
                this.writeSerial(msg);
            end
        end
        
        %%
        function resp = readSerial(this)            
            
            % Reset the warnings
            lastwarn('')
           
            % Open the Port if necessary
            this.portopen();
            
            % Conversion to char for compatibility reasons
            resp = char(readline(this.s));
            
            % Remove non-printable char
            resp = resp(resp>32&resp<127); 
            
            % serClose handles the closeflag
            this.serClose();
            
            %Throw warnings as Errors
            error(lastwarn())
        end
        
        %% 
        function resp = writeSerial(this,message)
            resp = '001';
            % Reset the warnings
            lastwarn('');
            if this.mode == MBCModeEnum.I2C
                % Open the Port if necessary
                this.portopen();
                
                restore = this.closeFlag;
                this.closeFlag = 0;
                
                % Write the message to the serialport
                writeline(this.s,message);
                
                % Conversion to char for compatibility reasons
                resp = char(readline(this.s)); 
                
                this.closeFlag = restore;
                
                % serClose handles the closeflag
                this.serClose();
            else
                if this.tcpClient(1).status.getStatus() == TCPClientStatusEnum.CONNECTED
                    this.tcpClient(1).send(message);
                    [resp, ] = this.tcpClient(1).receiveLine();
                    resp = char(resp);
                end
            end
            
            % Remove non-printable char
            resp = resp(resp>32&resp<127); 

            %Throw warnings as Errors 
            error(lastwarn);
        end

        %% 
        function resp = ReadEEPromMemory(this,addr,indx,lngth)
            %READEEPROMMEMORY Reads the EEPROM Memory at the specified
            %8-bit addres, there at said index and it reads lngth bytes
            
            restore = this.closeFlag;
            this.closeFlag = 0;
            
            this.switchI2C(1);

            if lngth < 0 || lngth >= 256
                error ("illegal length in ReadEEPROMMemory Encountered")
            end
            
            if indx < 0 || indx >= 256
                %TODO define valid upper Limit
                error("Illegal memoryIndex in ReadEEPROMMemory Encountered")
            end
            
            if (indx+lngth) >= 256
                %TODO define valid upper Limit
                error("Illegal memoryPosition (index + length) in ReadEEPROMMemory Encountered")
            end
            
            lngth = pad(num2str(lngth),3,'left','0');
            indx = dec2hex(indx,2);
            
            % query = [ 'IW_'  dec2hex(addr/2,2) '001' indx 13];
            msg = [ 'IW_'  dec2hex(addr/2,2) '001' indx];
            
            resp = this.writeSerial(msg);
            
            if length(resp)==3 % no ack -> no device present
                error("Nack Received while setting the EEPROM's index")
            end
            
            msg = [ 'IR_'  dec2hex(addr/2) lngth];
            
            resp = this.writeSerial(msg);
            
            this.closeFlag = restore;
            this.serClose();
            
        end % ReadEEPROM
        
         %%
        function resp = WriteEEPromMemory(this,addr,indx,lngthBytes,content)
            %WRITEEEPROMMEMORY Writes the content into the EEPROM Memory at 
            % the specified 8-bit addres, there at said index 

            restore = this.closeFlag;
            this.closeFlag = 0;
            
            this.switchI2C(1);           

            if lngthBytes < 0 || lngthBytes > 16
                error ("illegal length in WriteEEPROMMemory Encountered")
            end
                        
            if floor(indx/16) ~= floor((indx+lngthBytes)/16)
                error ("More than one page write in WriteEEPROMMemory Unhandled")
            end
            
            % +1 as the length and the content are transmittet in one
            lngthStr = sprintf('%03d',lngthBytes+1);
            if indx < 0 || indx > 64 % TODO 42
                %Max index in accordance with
                %https://metwiki.istag.endress.com/index.php/metrologyBUS
                error("Illegal memoryIndex in WriteEEPROMMemory Encountered")
            end
            indx = dec2hex(indx,2);
            
            if isa( content,'double')
                content = dec2hex(content,(lngthBytes*2));
                content = strcat(indx,content);
            else
                error("Unhandled datatype for WriteEEPROMMemory's content")
            end
            
            % Set the Pointer to the correct Memoryposition
            msg = [ 'IW_'  dec2hex(addr/2,2) lngthStr content 13];
            resp = this.writeSerial(msg);
            
            if length(resp)==3 % no ack -> no device present
                error("Nack Received while writing to the EEPROM")%Todo handle invalid values
            end
            
            this.closeFlag = restore;
            this.serClose();
        end % WriteEEPROM
        
        
        %%
        function this = serClose(this)
            if this.closeFlag
                delete(this.s);
                this.status = 'closed';
            end
        end
        
        
        
        %%
        function this = serOpen(this)
            this.s = serialport(this.port,this.Baudrate,...
                'Timeout',this.Timeout,...
                'ByteOrder',"big-endian");
            %setDTR(this.s,false);
            configureTerminator(this.s,"CR");
            
            this.status = 'open';
        end
        
        
        
        %% 
        function CBerror(this, code)
            
            codetable = {
                '001' 'no answer from Ethernet or USB';...
                '002' 'interface not supported by this version';
                '010' 'buffer overflow: transferred string to long';
                '011' 'selected mode is not allowed';
                '012' 'invalid input: number of bytes {0 .. 128}d';
                '013' 'invalid input: trigger-time {1 .. 999}d';
                '014' 'action not available; another interface is opened';
                '015' 'power supply ASIC = OFF! Wait for switching on';
                '016' 'wrong selection action on selected interface';
                '017' 'wrong selection speed of interface';
                '018' 'OWI - wrong selection of open port parameter';
                '019' 'invalid input: twait {0 .. 65535} d ';
                '020' 'port command - wrong selection of read or write option (2nd character)';
                '021' 'port command - invalid input for pin or port (3rd character)';
                '022' 'port command - invalid input: port selection {A ... D';
                '023' 'port command - invalid input: port state {00 .. FF}h';
                '024' 'port command - invalid input: pin selection {0 .. 7}d';
                '025' 'port command - invalid input: pin state {0/1/2]d';
                '026' '';
                '027' '';
                '028' '';
                '029' 'I²C - write and check: The written value could not be correctly retrieved';
                '030' 'I²C - Timeout! Master (CB) was not able to drive bus line';
                '031' 'I²C - start condition not sent';
                '032' 'I²C - read: no address-ack from slave --> try other I²C device address';
                '033' 'I²C - read: data not received: No ack from master';
                '034' 'I²C - read: last byte not correct. Wrong ack from master';
                '035' 'I²C - read: communication error during data byte transmission';
                '036' 'I²C - SDA or SCL shorted to GND - no high level on I²C bus --> check KS5V ';
                '037' 'I²C - write: no ack from slave after transmitting byte';
                '038' 'I²C - write: no address-ack from slave --> try other I²C device address';
                '039' 'I²C - Length of string from PC doesn''t fit to specified lenght. (Check e.g. ''ByteCount'' parameter in I2C spreadsheet)';
                '040' 'LIN - header incorrect';
                '041' 'OWI/Zacwire - Timeout! ASIC does not answer';
                '042' 'LIN - CRC incorrect:  received <=> calculated';
                '043' 'ZACwire - read: data channel not high';
                '044' 'LIN - wrong selection of action (2nd character)';
                '045' 'LIN - wrong selection of action (3rd character)';
                '046' 'LIN - Interface needs to be open before it can be used (--> use "LO" command)';
                '047' '';
                '048' '';
                '049' '';
                '050' 'SPI - header incorrect';
                '051' 'SPI - Timeout! Master (CB) was not able to drive busline';
                '052' 'SPI - Timeout during data trasnmission (either read or write)';
                '053' '';
                '054' '';
                '055' '';
                '056' '';
                '057' '';
                '058' '';
                '059' '';
                '060' '';
                '061' 'MCB - no seperator (:)';
                '062' 'MCB - no answer from MCB (serial ACK/NACK)';
                '063' 'MCB - no high signal on PinD2 (MCB V2.0) or PinD3 (MCB V2.1) before answer of MCB';
                '064' 'MCB - interface not supported by this firmware version';
                '065' 'MCB - "short ACK" mode of MCB is activated and thus only I2Cor ZACwire commands are allowed after MCB command';
                '066' 'MCB - No ACK from MCB in "short ACK" mode of MCB (no high signal on readback channel between MCB and CB)';
                '067' 'MCB - No ACK from MCB in "short ACK" mode of MCB (no low signal on readback channel between MCB and CB)';
                '068' 'MCB - firmware version V1.03 and V2.00a/V2.01 connected --> adjustment of timing ';
                '069' 'MCB - firmware version V1.03 and V2.00a/V2.01 connected - timing adjustment wasn''t successful';
                '070' '';
                '071' '';
                '072' '';
                '073' '';
                '074' '';
                '075' '';
                '076' '';
                '077' '';
                '078' '';
                '079' '';
                '080' 'ZACwire - invalid input: speed of interface [10...13]d or wrong length of input string';
                '081' 'ZACwire . wrong action on interface (select either "read", "write" or "speed" interface)';
                '082' 'ZACwire - wrong selection for trigger or non trigger ("T" or "_" for 3rd character) write command';
                '083' 'ZACwire - wrong number of parameters for write command --> check "ByteCount" and "BytesToBeWritten" in "ZACwire"';
                '084' 'ZACwire - timeout: no high signal found on the ZACwire interface --> check for shorted pin';
                '085' 'ZACwire - timeout: IC didn''t send 1st high-low transistion to send start-bit';
                '086' 'ZACwire - timeout: low-high edge of start-bit didn''t received --> check communication speed or shorted pin';
                '087' 'ZACwire - timeout: high-low edge at end of start-bit failed';
                '088' 'ZACwire - timeout: high-low edge at beginning of databit failed';
                '089' 'ZACwire - timeout: low-high edge at end of databit failed';
                '090' 'ZACwire - timeout: low-high edge at end of parity bit failed';
                '091' 'ZACwire - wrong number of parameters for read command --> check "ReadByteCount" in "ZACwire" tab';
                '092' 'ZACwire - wrong lenght of read command';
                '093' '';
                '094' '';
                '095' '';
                '096' '';
                '097' '';
                '098' '';
                '099' 'LIN - wrong selection for "LOM" command - either use LOM0, LOM1, or LOM2';
                '100' 'LIN - wrong version selected';
                '101' 'LIN - wrong communication speed selected';
                '102' 'LIN - wrong CRC option selected';
                '103' 'LIN - wrong option for LIN open interface selected';
                '104' 'LIN - wrong length of LIN open interface command';
                '105' 'LIN - write/read: no low signal at trigger command';
                '106' 'LIN - write/read: no high signal on bus before Break Field should be sent';
                '107' 'LIN - write/read: no low signal during Break Field';
                '108' 'LIN - write/read: no high level for stop condition after Break Field';
                '109' 'LIN - write/read: no low level for start condition of SYNC Field';
                '110' 'LIN - write/read: no high level for stop condition after SYNC Field';
                '111' 'LIN - write/read: no low level for start condition of PID';
                '112' 'LIN - write/read: no high level for stop condition after PID';
                '113' 'LIN - write: no low level for start condition before Data Field';
                '114' 'LIN - write: no high level for stop condition after Data Field';
                '115' 'LIN - write: no low level closeFlag: 1 for start condition before CRC Data Field';
                '116' 'LIN - write: no high level for stop condition after CRC Data Field';
                '117' 'LIN - read: no high level for last stop condition (CRC Data Field) of transmission detected';
                '118' 'LIN - read: no high level for stop condition of PID detected --> Test of PINB.0 at SSC CB';
                '119' 'LIN - read: no low level for start condition of 1st Data Field from slave detected';
                '120' 'LIN - read: no high level for stop condition of 1st Data Field from slave detected';
                '121' 'LIN - read: no low level for start condition of 2nd Data Field from slave detected';
                '122' 'LIN - read: no high level for stop condition of 2nd Data Field from slave detected';
                '123' 'LIN - read: no low level for start condition of 3rd Data Field from slave detected';
                '124' 'LIN - read: no high level for stop condition of 3rd Data Field from slave detected';
                '125' 'LIN - read: no low level for start condition of 4th Data Field from slave detected';
                '126' 'LIN - read: no high level for stop condition of 4th Data Field from slave detected';
                '127' 'LIN - read: no low level for start condition of 5th Data Field from slave detected';
                '128' 'LIN - read: no high level for stop condition of 5th Data Field from slave detected';
                '129' 'LIN - read: no low level for start condition of 6th Data Field from slave detected';
                '130' 'LIN - read: no high level for stop condition of 6th Data Field from slave detected';
                '131' 'LIN - read: no low level for start condition of 7th Data Field from slave detected';
                '132' 'LIN - read: no high level for stop condition of 7th Data Field from slave detected';
                '133' 'LIN - read: no low level for start condition of 8th Data Field from slave detected';
                '134' 'LIN - read: no high level for stop condition of 8th Data Field from slave detected';
                '135' 'LIN - read: no low level for start condition of CRC Data Field from slave detected';
                '136' '';
                '137' '';
                '138' '';
                '139' '';
                '140' 'analog read - wrong value channel: channel selection {0 .. 4';
                '141' '';
                '142' '';
                '143' '';
                '144' '';
                '145' '';
                '146' '';
                '147' '';
                '148' '';
                '149' '';
                '150' 'OWI - wrong length of OWI read command';
                '151' 'OWI - wrong selection for OWI read bytes';
                '152' '';
                '153' '';
                '154' '';
                '155' '';
                '156' '';
                '157' '';
                '158' '';
                '159' '';
                '160' 'I²C - query: no repeated start condition on the bus';
                '161' 'I²C - query: no address ACK from slave';
                '162' 'I²C - query: no data ACK from slave';
                '163' 'I²C - query: master could not put NACK on the bus';
                '164' '';
                '165' '';
                '166' '';
                '167' '';
                '168' '';
                '169' '';
                '170' '';
                '171' '';
                '172' '';
                '173' '';
                '174' '';
                '175' '';
                '176' '';
                '177' '';
                '178' '';
                '179' '';
                '180' '';
                '181' '';
                '182' '';
                '183' '';
                '184' '';
                '185' '';
                '186' '';
                '187' '';
                '188' '';
                '189' '';
                '190' '';
                '191' '';
                '192' '';
                '193' '';
                '194' '';
                '195' '';
                '196' '';
                '197' '';
                '198' '';
                '199' '';
                '200' 'SENT - open: wrong command length';
                '201' 'SENT - open: wrong selection of 3rd character ';
                '202' 'SENT - open: wrong selection of used SENT interface pin';
                '203' 'SENT - open: wrong selection of TICK time - TICK Time will now be measured automatically';
                '204' 'SENT - open: wrong selection for check of TICK time - TICK Time will now be measured automatically & Limit is set to 0';
                '205' 'SENT - open: wrong sele closeFlag: 1ction of number of nibbles in the data stream - lower limitation';
                '206' 'SENT - open: wrong selection of number of nibbles in the data stream - upper limitation';
                '207' 'SENT - open: wrong selection for CRC check enabled';
                '208' 'SENT - open: wrong selection for CRC version';
                '209' 'SENT - open: wrong selection for additional string "0000" at the end of the SENT open command';
                '210' 'SENT - open: wrong selection of SENT data formating';
                '211' '';
                '212' '';
                '213' '';
                '214' '';
                '215' '';
                '216' '';
                '217' '';
                '218' '';
                '219' 'SENT - measure TICK time: wrong command length';
                '220' 'SENT - measure TICK time: no high signal on the SENT interface ';
                '221' 'SENT - measure TICK time: no high-low transmission found';
                '222' 'SENT - measure TICK time: no low-high transmission found';
                '223' 'SENT - measure TICK time: measured low impuls was too long - check TICK time - overflow is caused at 200 µs TICK';
                '224' 'SENT - measure TICK time: no high signal after initialisation measurement';
                '225' 'SENT - measure TICK time: no high-low transmission during SYNC search';
                '226' 'SENT - measure TICK time: more than 255 nibbles tested and no SYNC found';
                '227' '';
                '228' '';
                '229' '';
                '230' 'SENT - read: invalid input: number of bytes {1 .. 16}d';
                '231' 'SENT - read: Length of string doesn''t fit to specified lenght. (Check e.g. ''ByteCount'' parameter in SENT spreadsheet)';
                '232' 'SENT - read: no TICK time speciefied for comparison with TICK time limits --> check and send SENT open command';
                '233' 'SENT - read: measured TICK time doesn''t fir to specified TICK time --> check range check and specified TICK time';
                '234' 'SENT - read: no initial high-low transmission found';
                '235' 'SENT - read: no high-low transmission found for the 2nd acquired data nibble';
                '236' 'SENT - read: no high-low transmission found for the 3rd acquired data nibble';
                '237' 'SENT - read: more than 255 nibbles tested and no SYNC found';
                '238' 'SENT - read: more than 255 nibbles tested and no SYNC found';
                '239' '';
                '240' '';
                '241' 'SENT - SDM: Length of string doesn''t fit to specified lenght. ';
                '242' 'SENT - SDM: no TICK time speciefied for comparison with TICK time limits --> check and send SENT open command';
                '243' 'SENT - SDM: measured TICK time doesn''t fir to specified TICK time --> check range check and specified TICK time';
                '244' 'SENT - SDM: no start bit (bit #3) found in the status nibble';
                '245' 'SENT - SDM: no initial high-low transmission found';
                '246' 'SENT - SDM: no high-low transmission found for the 2nd acquired data nibble';
                '247' 'SENT - SDM: no high-low transmission found for the 3rd acquired data nibble';
                '248' 'SENT - SDM: more than 255 nibbles tested and no SYNC found';
                '249' 'SENT - SDM: more than 255 nibbles tested and no SYNC found';
                '250' 'SENT - SDM: invalid input: number of bytes {1 .. 16}d';
                '251' '';
                '252' '';
                '253' '';
                '254' '';
                '255' '';
                '256' '';
                '257' '';
                '258' '';
                '259' '';
                '260' '';
                '261' '';
                '262' '';
                '263' 'SENT - read: wrong feedback for 4 inverted bits ';
                '264' '';
                '265' '';
                '266' '';
                '267' '';
                '268' '';
                '269' '';
                '270' '';
                '271' '';
                '272' '';
                '273' '';
                '274' '';
                '275' '';
                '276' '';
                '277' '';
                '278' '';
                '279' '' };
            error([code ': ' codetable{strcmp(code, codetable(:,1)),2}]);
            
        end
    end
end