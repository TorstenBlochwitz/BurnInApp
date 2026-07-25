function MBCethUnitTest(host)
    fprintf('Started at: %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    %pause('on')

    t = uint16(1);

    mbc = MBC_TB(host);
    index = 0;
    try
        mbc.connectToTCPServer(index, host, 10);
        mbc.reset();
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
    fprintf('MBC connected to %s: \n', host);
    
    fprintf('Resetting MBC\n');
    mbc.reset();

    getUUID(mbc, index);

    %If I call this now, setTimer fails!!
    ScanI2CAddr(mbc);

    if mbc.checkI2CAddr(0xE0, 0)
        fprintf("I2C Multiplexer found\n");
    else
        fprintf("I2C Multiplexer not found\n");
    end

    %Initialize
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
        %If I call this here, no problem occurs
        ScanI2CAddr(mbc);
        try
            if getVDCswitchStatus(mbc, index, 1) == 0
                fprintf('\nTimer elapsed and restarted at: %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
                
                %If I call this here, an exception is thrown
                ScanI2CAddr(mbc);
                
                switchVDC(mbc, index, 1, 2);
                setTimer(mbc, index, t);
                progress = 1;
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