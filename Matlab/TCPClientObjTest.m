function TCPClientObjTest(host, port)
    fprintf('Started at: %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    %pause('on')

    client = TCPClient();
    client.connectToServer(host, port, 10);

    if client.status.getStatus() == TCPClientStatusEnum.CONNECTED
        fprintf('\nTCPClient is connected\n');
    else
        fprintf('\nTCPClient is NOT connected\n');
        return
    end
    %pause;

    bPing = true;
    bReset = false;
    bVersion = true;
    bDCDCLEDblink = false;
    bDCDCLED = false;
    bRGBLED = false;
    bMainBoardLED = false;
    bQuerySWVersion = false;
    bQueryEEPROM = false;

    bVDC1on = false;
    bVDC2on = false;

    bVDC1_PWM = false;
    bVDC2_PWM = false;

    bSetTimer = false;
    bCheckUUID = false;

    i2cFrequency = '12';
    i2cFrequency = '';

    bTestTimer = false;

    bCheckI2CMultiplexer = false;
    
    strMsg = sprintf('\n\nInitialization\n');
    if bVersion
        strWrite = sprintf('V');
        strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
        if ~client.send(strWrite)
            return
        end
        [data, ret] = client.receiveLine();
        if ~ret
            return
        end
        fprintf('MBC Version: %s\n', char(data));
        strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
        
        % if strlength(char(data)) > 0
        %     fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
        % end
        strMsg = '';
    end

    if bPing
        if client.pingServer()
            fprintf('Ping successful!\n');
        else
            fprintf('Ping NOT successful!\n');
        end
        strMsg = '';
    end

    if strlength(char(i2cFrequency)) > 0
        strWrite = sprintf('IS_%s', i2cFrequency);
        strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
        if ~client.send(strWrite)
            return
        end
        [data, ret] = client.receiveLine();
        if ~ret
            return
        end
        strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
        fprintf(strMsg, char(data));
        
        if strlength(char(data)) > 0
            fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
        end
        strMsg = '';
    end
    if bCheckUUID
        for i = 0:1:15
            strWrite = sprintf('IW_08002%s%s', dec2hex(148 + i,2), dec2hex(i+3,2));
            strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
            if ~client.send(strWrite)
                return
            end
            [data, ret] = client.receiveLine();
            if ~ret
                return
            end
            strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
            %fprintf(strMsg, char(data));
            
            if strlength(char(data)) > 0
                fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
            end
            strMsg = '';
        end
        fprintf('UUID = ');
        UUID = zeros(1, 16, 'uint8');
        for i = 0:1:15
            strWrite = sprintf('IQ_08001001%s', dec2hex(148 + i,2));
            strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
            if ~client.send(strWrite)
                return
            end
            [data, ret] = client.receiveLine();
            if ~ret
                return
            end
            strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
            if strlength(char(data)) > 0
                UUID(i+1) = hex2dec(char(data));
                fprintf('%d ', UUID(i+1));
            end
            %fprintf(strMsg, char(data));
            
            if strlength(char(data)) ~= 2
                fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
            end
            strMsg = '';
        end
        fprintf('\n');
    end
    if bVDC1_PWM
        strWrite = 'IW_08003860A32';  %VDC1: 1 Hz, 50 % Duty Cycle on
        strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
        if ~client.send(strWrite)
            return
        end
        [data, ret] = client.receiveLine();
        if ~ret
            return
        end
        strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
        %fprintf(strMsg, char(data));
        
        if strlength(char(data)) > 0
            fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
        end
        strMsg = '';

        strWrite = 'IW_080028002';  %switch VDC1 to PWM
        strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
        if ~client.send(strWrite)
            return
        end
        [data, ret] = client.receiveLine();
        if ~ret
            return
        end
        strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
        %fprintf(strMsg, char(data));
        
        if strlength(char(data)) > 0
            fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
        end
        strMsg = '';

    end
    if bVDC2_PWM
        strWrite = 'IW_08003870A32';  %VDC1: 1 Hz, 50 % Duty Cycle on
        strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
        if ~client.send(strWrite)
            return
        end
        [data, ret] = client.receiveLine();
        if ~ret
            return
        end
        strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
        %fprintf(strMsg, char(data));
        
        if strlength(char(data)) > 0
            fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
        end
        strMsg = '';

        strWrite = 'IW_080028102';  %switch VDC1 to PWM
        strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
        if ~client.send(strWrite)
            return
        end
        [data, ret] = client.receiveLine();
        if ~ret
            return
        end
        strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
        %fprintf(strMsg, char(data));
        
        if strlength(char(data)) > 0
            fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
        end
        strMsg = '';

    end
    if bSetTimer
        strWrite = 'IW_08003840200';  %set timer to 2 min
        strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
        if ~client.send(strWrite)
            return
        end
        [data, ret] = client.receiveLine();
        if ~ret
            return
        end
        strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
        %fprintf(strMsg, char(data));
        
        if strlength(char(data)) > 0
            fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
        end
        strMsg = '';
    end
    if bVDC1on
        strWrite = 'IW_080028001';  %switch VDC1 on
        strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
        if ~client.send(strWrite)
            return
        end
        [data, ret] = client.receiveLine();
        if ~ret
            return
        end
        strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
        %fprintf(strMsg, char(data));
        
        if strlength(char(data)) > 0
            fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
        end
        strMsg = '';
    end
    if bVDC2on
        strWrite = 'IW_080028101';  %switch VDC2 on
        strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
        if ~client.send(strWrite)
            return
        end
        [data, ret] = client.receiveLine();
        if ~ret
            return
        end
        strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
        %fprintf(strMsg, char(data));
        
        % if strlength(char(data)) > 0
        %     fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
        % end
        strMsg = '';
    end

    i = 1;
    n=0;
    while client.status.getStatus() == TCPClientStatusEnum.CONNECTED
    %if client.status.getStatus() == TCPClientStatusEnum.CONNECTED
        strMsg = sprintf('\n\nTry: %d\n', i);
        if bVersion
            strWrite = sprintf('V');
            strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
            if ~client.send(strWrite)
                return
            end
            [data, ret] = client.receiveLine();
            if ~ret
                fprintf('Problem at: %s\n\n Try: %d\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), i);
                return
            end
            fprintf('Try: %d: Received: %s\n', i, char(data));
            strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
            
            % if strlength(char(data)) > 0
            %     fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
            % end
            strMsg = '';
        end

        if bPing
            if client.pingServer()
                fprintf('Ping successful!\n');
            else
                fprintf('Ping NOT successful!\n');
            end
            strMsg = '';
        end

        if bCheckI2CMultiplexer
            offset = 0;
            I2Caddr = 0x70;
            msg = ['IR_',dec2hex(I2Caddr,2),'001',13];

            try
                ret = client.send(msg);
                if ~ret
                    return
                end
                %resp = this.writeMessage(msg, offset);
                [data, ret] = client.receiveLine();
                if ~ret
                    return
                end
                if length(char(data))~=3
                    fprintf('CheckI2CMultiplexer successful: %s\n', data);
                else
                    fprintf('CheckI2CMultiplexer failed: %s\n', data);
                end
            catch e
                if offset == 0
                    strAddr = sprintf("0x%X", I2Caddr);
                else
                    strAddr = sprintf("0x%X, offset = %d", I2Caddr, offset);
                end
                fprintf("%d. I2C communication problem in checkI2CAddr: %s\naddr = %s, msg = %s\n", i, e.message, strAddr, msg);  
            end
        end

        if bTestTimer
            strWrite = 'IQ_0800100180';  %Check VDC1
            strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
            if ~client.send(strWrite)
                return
            end
            [data, ret] = client.receiveLine();
            if ~ret
                return
            end
            strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
            
            if strlength(char(data)) ~= 2
                fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
            end
            %fprintf("VDC1 = %s\n", char(data));
            strMsg = '';

            if(strcmp(char(data), '00'))
                fprintf('Timer elapsed and restarted at: %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
                %Restart Timer
                %strWrite = 'IW_08003847800';  %set timer to 120 min
                strWrite = 'IW_08003840A00';  %set timer to 120 min
                strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
                if ~client.send(strWrite)
                    return
                end
                [data, ret] = client.receiveLine();
                if ~ret
                    return
                end
                strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
                %fprintf(strMsg, char(data));
                
                if strlength(char(data)) > 0
                    fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
                end
                strMsg = '';

                strWrite = 'IW_080028002';  %switch VDC1 to blink
                strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
                if ~client.send(strWrite)
                    return
                end
                [data, ret] = client.receiveLine();
                if ~ret
                    return
                end
                strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
                %fprintf(strMsg, char(data));
                
                if strlength(char(data)) > 0
                    fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
                end
                strMsg = '';
            end

        end

        if bReset
            strWrite = sprintf('IT');
            strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
            if ~client.send(strWrite)
                return
            end
            [data, ret] = client.receiveLine();
            if ~ret
                return
            end
            strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
            
            if strlength(char(data)) > 0
                fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
            end
            strMsg = '';
        end
        if bQueryEEPROM
            strWrite = 'IQ_A000100100';  %Read first Byte from EEPROM
            strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
            if ~client.send(strWrite)
                return
            end
            [data, ret] = client.receiveLine();
            if ~ret
                return
            end
            strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
            %fprintf(strMsg);
            if strlength(char(data)) ~= 2
                fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
            end
            strMsg = '';
        end
        if bQuerySWVersion
            strWrite = 'IQ_08001003FF';  %Read Software version 
            strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
            if ~client.send(strWrite)
                return
            end
            [data, ret] = client.receiveLine();
            if ~ret
                return
            end
            strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
            %fprintf(strMsg);
            if strlength(char(data)) ~= 6
                fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
            end
            strMsg = '';
        end
        if bDCDCLED
            strWrite = 'IW_080028300';  %switch DC/DC LED off
            strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
            if ~client.send(strWrite)
                return
            end
            [data, ret] = client.receiveLine();
            if ~ret
                return
            end
            strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
            %fprintf(strMsg, char(data));
            
            if strlength(char(data)) > 0
                fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
            end
            strMsg = '';
        end
        if bDCDCLEDblink
            strWrite = 'IW_080028302';  %switch DC/DC LED to blink
            strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
            if ~client.send(strWrite)
                return
            end
            [data, ret] = client.receiveLine();
            if ~ret
                return
            end
            strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
            %fprintf(strMsg, char(data));
            
            if strlength(char(data)) > 0
                fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
            end
            strMsg = '';
        end
        if bMainBoardLED
            strWrite = 'IW_20002FFFF';  %switch Main Board LED off
            strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
            if ~client.send(strWrite)
                return
            end
            [data, ret] = client.receiveLine();
            if ~ret
                return
            end
            strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
            %fprintf(strMsg, char(data));
            

            if strlength(char(data)) > 0
                fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
            end
            strMsg = '';
        end

        if bRGBLED
            if n==0
                strWrite = sprintf('IW_08006%s0008000101', dec2hex(n,2));
            else
                strWrite = sprintf('IW_08006%s0800000001', dec2hex(n,2));
            end
            %strWrite = 'IW_08006058000000101';
            %strWrite = 'IW_08006058000000101';  %switch RGB LED 5 to red
            strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
            if ~client.send(strWrite)
                return
            end
            [data, ret] = client.receiveLine();
            if ~ret
                return
            end
            strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
            %fprintf(strMsg, char(data));
            
            if strlength(char(data)) > 0
                fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
            end
            strMsg = '';
        end
% 
%         pause(0.1);
%         strWrite = 'IR_08001';%s
%         strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
%         if ~client.send(strWrite)
%             return
%         end
%         [data, ret] = client.receiveLine();
%         if ~ret
%             return
%         end
%         strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
%         pause(0.1);bDCDCLED
%         strWrite = 'IQ_0800100185'; %ATiny status
%         strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
%         if ~client.send(strWrite)
%             return
%         end
%         [data, ret] = client.receiveLine();
%         if ~ret
%             return
%         end
%         strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
%         pause(0.1);
        if bDCDCLED
            strWrite = 'IW_040028301';  %switch DC/DC LED on
            strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
            if ~client.send(strWrite)
                return
            end
            [data, ret] = client.receiveLine();
            if ~ret
                return
            end
            strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
            %fprintf(strMsg, char(data));
            
            if strlength(char(data)) > 0
                fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
            end
            strMsg = '';
        end
        if bMainBoardLED
            strWrite = 'IW_80002FF7F';  %switch Main Board LED on
            strMsg = sprintf('%s\nSend: %s\n', strMsg, strWrite);
            if ~client.send(strWrite)
                return
            end
            [data, ret] = client.receiveLine();
            if ~ret
                return
            end
            strMsg = sprintf('%s Received: %s\n', strMsg, char(data));
            %fprintf(strMsg, char(data));
            
            if strlength(char(data)) > 0
                fprintf('Problem at: %s\n\n%s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), strMsg);
            end
            strMsg = '';
        end
%         pause(0.1);
%         strMsg = sprintf('%s Received %s\n', strMsg, char(data));
        %fprintf(strMsg);
        i = i + 1;
        if n<122
            n=n+1;
        else
            n=0;
        end
    end
    fprintf('\n\n%s\n', strMsg);
    fprintf('Closed at: %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end