function MBCethUnitTestSTM1(host)
    fprintf('Started at: %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    %pause('on')

    %Nucleo F207 ZG
    %1 min: No deviation!
    %10 min: -3 s
    %60 min: -23, - 21, -20
    %120 min: -26, -73, -28
    %240 min: -70, -78, -75, -79,-74
    
    %Nucleo F103RB
    %1 min: No deviation!
    %10 min: -3 s
    %60 min: -19 s

    %MBC Ethernet STM32 Board
    %1 min -1 s
    %2 min -1 s
    %10 min 
    %60 min -27, -28 s

    %MBC Ethernet ESP32 AZ Delivery
    %1 min 0 s
    %2 min 
    %10 min - 2 s 
    %60 min -16 s

    %MBC Ethernet ESP32 Waveshare after Fixing
    %1 min 0 s
    %2 min 
    %10 min 
    %60 min + 1 s

    t = uint16(60);

    mbc = MBC_TB(host);
    index = 0;
    try
        mbc.connectToTCPServer(index, host, 10);
        pause(0.5);
        %mbc.reset();
    catch exc1
        MBCStatusString = sprintf("Could not connect to MBC on %s: %s.\n\n", mbc.port, extractBefore(exc1.message, "For more information"));
        fprintf("%s\n", MBCStatusString);
        try
            if ~isempty(mbc)
                delete(mbc);
            end
        catch exc2
            fprintf("Something went wrong (%s).\n", exc2.message);
        end
        return;
    end
    fprintf('MBC connected to %s \n', host);
    
    fprintf('Resetting MBC\n');
    mbc.reset();

    str = mbc.writeMessage('V', index);
    fprintf('MBC Version: %s \n', str);

    mbc.writeMessage('OW00', index);
    str = mbc.writeMessage('OR0', index);
    fprintf('TransportMode: %s \n', str);

    str = mbc.writeMessage('OR1', index);
    fprintf('Ethernet MAC: %s \n', str);

    %mbc.writeMessage('OW2192.168.2.33', index);
    str = mbc.writeMessage('OR2', index);
    fprintf('Ethernet IP: %s \n', str);
    
    str = mbc.writeMessage('OR3', index);
    fprintf('Ethernet Subnet Mask: %s \n', str);
    str = mbc.writeMessage('OR4', index);
    fprintf('Ethernet Gateway: %s \n', str);
    str = mbc.writeMessage('OR5', index);
    fprintf('WiFi AP Prefix: %s \n', str);
    str = mbc.writeMessage('OR6', index);
    fprintf('WiFi SSID: %s \n', str);
    str = mbc.writeMessage('OR7', index);
    fprintf('WiFi PW: %s \n', str);
    str = mbc.writeMessage('OR8', index);
    fprintf('AP PW: %s \n', str);

    fprintf('Get Error counter\n');
    ctr = mbc.getErrorCounter(index);
    fprintf('Eth | I2C: %s \n', ctr);

    %ScanI2CAddr(mbc);
    %scanI2CAddrWithMultiplexer(mbc, index);

    %Test get/set UUID
    uuidStr = 'ff0e0d0c-0b0a-0908-0706-050403020100';
    getUUID(mbc, index);
    setUUIDString(mbc, index, uuidStr);
    getUUID(mbc, index);
    
    T = readTemperatures(mbc, index, true);

    %Initialize
    iLED = 1;
    setTimer(mbc, index, 0);
    switchVDC(mbc, index, 1, 0);
    progress = 0;
    tic;
    while mbc.tcpClient(index+1).status.getStatus() == TCPClientStatusEnum.CONNECTED
        if toc > 1
            if progress>0
                fprintf('.');
            else
                fprintf('\b');
            end
            if progress == 10
                progress = -10;
            end
            progress = progress + 1;
            tic;
        end

        try
            if getVDCswitchStatus(mbc, index, 1) == 0
                fprintf('\nTimer elapsed and restarted at: %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
                
                ctr = mbc.getErrorCounter(index);
                fprintf('Eth | I2C %s: \n', ctr);
                
                switchVDC(mbc, index, 1, 2);
                setTimer(mbc, index, t);
                progress = 1;
            end
            %readTemperatures(mbc, index, progress == -9);
            readTemperatures(mbc, index, 0);
            setRGBLED(mbc, index, iLED, 255, 0, 0);
            if iLED < 123
                iLED = iLED + 1;
            else
                iLED = 1;
            end
        catch exc1
            if mbc.tryReconnect() == 0
                fprintf("Reconnect failed.\n");
                break;
            else
                fprintf("Reconnected.\n");
            end
        end
    end
    fprintf('Finished at: %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function ret = ScanI2CAddr(mbc)
    %Scan I2C Adresses
    fprintf("Scan I2C Adresses\n");
    [addr,hexaddr]=mbc.scanI2CAddr();
    for i=1:1:size(addr, 2)
        fprintf("%d\t%s\n", addr(i), hexaddr(i));
    end
    fprintf("\n");
    ret = size(addr, 2);
end


function ret = setTimer(mbc, index, t)
    ret = mbc.writeBytesI2C(0x08, index, [128 + 4 uint8(mod(uint16(t), 256)) uint8(bitshift(uint16(t), -8, 'uint16'))]);
end

function ret = switchVDC( mbc, index, VDC, v)
    %switch ATtiny: 0-off, 1-on, 2-blink
    ret = mbc.writeBytesI2C(0x08, index, [(127+VDC) uint8(v)]);
end

function status = getVDCswitchStatus(mbc, index, VDC)
    status = mbc.queryBytesI2C(0x08, index, (127+VDC), 1, 1);
end

function UUID = getUUID(mbc, index)
    fprintf('UUID = ');
    UUID = zeros(1, 16, 'uint8');
    for i = 0:1:15
        data = mbc.queryBytesI2C(0x08, index, (148+i), 1, 1);
    
        UUID(i+1) = data;
        fprintf('%d ', UUID(i+1));
        %fprintf(strMsg, char(data))
    end
    fprintf('\n');
end

function ret = setUUID(mbc, index, uuid)
    ret = 0;
    try
        for i=1:1:16
            ret = mbc.writeBytesI2C(0x08, index, [148+i-1 uuid(i)]);
        end
        ret = 1;
    catch e
        fprintf("Something went wrong writing UUID. Check Mainboard!(%s).\n", e.message);
    end
end

function ret = setUUIDString(mbc, index, str)
            ret = 0;
            uuid = zeros(1,16, 'uint8');
            str = regexprep(str,'[-]','');
            if strlength(str) == 32
                for i=1:1:16
                    uuid(i) = hex2dec(str((2*i - 1):(2*i)));
                end
                ret = setUUID(mbc, index, uuid);
            else
                ret = 0;
            end
        end

function scanI2CAddrWithMultiplexer(mbc, index)
    MPaddr = 0xE0; %Address of I2C Multiplexer (set to 0 if there is no)
    cOn = 0x04;         %Command to switch channel on
    cOff = 0x00;        %Command to switch channel off
    %Switch I2CMultiplexer on
    I2Cmulti = I2CMultiplexerPCA9542A(mbc, index, MPaddr, cOn, cOff);
    ScanI2CAddr(mbc);
end

function T = readTemperatures(mbc, index, print)
    T=[0.0,0.0,0.0];
    boardConnected = true;
    if boardConnected
        MPaddr = 0xE0; %Address of I2C Multiplexer (set to 0 if there is no)
        cOn = 0x04;         %Command to switch channel on
        cOff = 0x00;        %Command to switch channel off
        %Switch I2CMultiplexer on
        %I2Cmulti = I2CMultiplexerPCA9542A(mbc, index, MPaddr, cOn, cOff);
        tempSensor(1) = TempSensor_TMP1075(mbc, 0x94, index, MPaddr, cOn, cOff);
        tempSensor(2) = TempSensor_TMP1075(mbc, 0x98, index, MPaddr, cOn, cOff);
        tempSensor(3) = TempSensor_TMP1075(mbc, 0x9C, index, MPaddr, cOn, cOff);
    
        for i=1:1:3
            T(i) = tempSensor(i).getTemperatureCelsius();
            if print
                fprintf("%f °C\n", T(i));
            end
        end
    end
end

function setRGBLED(mbc, index, iLED, R, G, B)
    brightnessPosLEDs = 100;
    switchOffLEDs = 1;
    setLEDs = 1;
    mbc.writeBytesI2C(0x08, index, [uint8(iLED-1) uint8(R * brightnessPosLEDs / 100) uint8(G * brightnessPosLEDs / 100) uint8(B * brightnessPosLEDs / 100) uint8(switchOffLEDs) uint8(setLEDs)]);
end