classdef TCPClient <  handle
    properties
        host = '';
        port = 0;
        status TCPClientStatus;
        strError = '';
        s;
        nRepeat = 10;
    end

    methods
        function this = TCPClient()
            this.status = TCPClientStatus();
            this.status.setStatus(TCPClientStatusEnum.DISCONNECTED);
            %this.s = libpointer(tcpclient);
        end
        function delete(this)
            this.disconnect();
        end
        function ret = connectToServer(this, host, port, connectTimeOut)
            %fprintf('TCPClient.connectToServer at: %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

            %TODO: Do nothing, if server is already connected, a problem might ocurre if we disconnect and try to reconnect immediately!
            % check if host and port are still the same
            % check isvalid(t)
            % implement a ping - pong
            % check if host and port are still the same
            if this.status.getStatus() == TCPClientStatusEnum.CONNECTED
                if ~strcmp(this.host, host) || this.port ~= port
                    this.disconnect();
                end
            end
            this.host = char(host); %host must be char array not a string when it used in as argument for system()
            this.port = port;
            ret = this.tryReconnectToServer(connectTimeOut);
        end
        function ret = tryReconnectToServer(this, connectTimeOut)
            %fprintf('TCPClient.reConnectToServer at: %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
            this.strError = '';
            try
                %fprintf('(Re)Connecting to %s...\n', this.host);
                try
                    addr = java.net.InetAddress.getByName(this.host);
                catch ME
                    this.strError = sprintf('Error while (re)connecting to %s:\nName cannot be resolved.', this.host);
                    this.status.setStatus(TCPClientStatusEnum.ERROR);
                    this.disconnect();
                    ret = false;
                    return
                end
                state = addr.isReachable(connectTimeOut*1000);

                if ~state
                    this.strError = sprintf('Error while (re)connecting to %s:\nIP address not found! Ping failed.', this.host);
                    this.status.setStatus(TCPClientStatusEnum.ERROR);
                    this.disconnect();
                    ret = false;
                    return
                end
                if ~isempty(this.s) && isa(this.s, "tcpclient")
                    if this.pingServer()
                        ret = true;
                        return
                    else
                        this.disconnect();
                    end
                end
                %reconnect
                this.s = tcpclient(this.host, this.port, "ConnectTimeout",connectTimeOut, "Timeout", 5, "EnableTransferDelay", false);
                this.status.setStatus(TCPClientStatusEnum.CONNECTED);
                configureTerminator(this.s, "LF");
                ret = true;
            catch ME
                %fprintf('Error while (re)connecting to %s:\n %s\n', this.host, ME.message);
                this.strError = sprintf('Error while (re)connecting to %s:\n %s For more information\n', this.host, ME.message);
                this.status.setStatus(TCPClientStatusEnum.ERROR);
                %this.s = libpointer(tcpclient);
                this.disconnect();
                ret = false;
            end
        end

        function disconnect(this)
            if ~isempty(this.s) && isa(this.s, "tcpclient")
                try
                    delete(this.s);
                catch ME
                    fprintf("Could not delete TCP client: %s", ME.message);
                end
            end
            this.s = [];
        end

        function ret = pingServer(this)
            ret = false;
            % we do everything manually here to avoid retry if something goes wrong
            if this.status.getStatus() == TCPClientStatusEnum.CONNECTED
                try
                    writeline(this.s, 'P');
                    pong = readline(this.s);
                    ret = pong == "Pong";
                    return
                catch
                    ret = false;
                end
            end
        end
        function ret = send(this, msg)
            ret = false;
            %pause('on')
            if this.status.getStatus() ~= TCPClientStatusEnum.CONNECTED
                return
            end
            strMsg = '';
            for i = 1:1:this.nRepeat
                try
                    strMsg = sprintf('%d. Trying to send: %s\n', i, msg);
                    writeline(this.s, msg);
                    ret = true;
                    return
                catch ME
                    fprintf(strMsg);
                    fprintf('\nAt: %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
                    fprintf('The error: %s has occurred during write  after: %d\n\n', ME.message, i);
    
                    this.status.setStatus(TCPClientStatusEnum.ERROR);
                    if i>this.nRepeat
                        ret = false;
                        return;
                    end
                    ret = this.tryReconnectToServer(10);
                    if ~ret && (i>this.nRepeat)
                        return
                    end
                end
            end
        end
        function [msg, ret] = receive(this, size)
            ret = false;
            msg = '001';
            %pause('on')
            if this.status.getStatus() ~= TCPClientStatusEnum.CONNECTED
                return
            end
            strMsg = '';
            for i = 1:1:this.nRepeat
                try
                    strMsg = sprintf('Try to read %d bytes\n', size);
                    msg = read(this.s, size);
                    ret = true;
                    return
                catch ME
                    fprintf(strMsg);
                    fprintf('\nAt: %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
                    fprintf('The error: %s has occurred during read after: %d\n\n', ME.message, i);
    
                    this.status.setStatus(TCPClientStatusEnum.ERROR);
                    if i>this.nRepeat
                        ret = false;
                        return
                    end
                    ret = this.tryReconnectToServer(10);
                    if ~ret && (i>this.nRepeat)
                        return
                    end
                end
            end
        end
        function [msg, ret] = receiveLine(this)
            ret = false;
            msg = '';
            %pause('on')
            if this.status.getStatus() ~= TCPClientStatusEnum.CONNECTED
                return
            end
            strMsg = '001';
            for i = 1:1:this.nRepeat
                try
                    strMsg = sprintf('Try to read String\n');
                    msg = readline(this.s);
                    ret = true;
                    return
                catch ME
                    fprintf(strMsg);
                    fprintf('\nAt: %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
                    fprintf('The error: %s has occurred during read after: %d\n\n', ME.message, i);
    
                    this.status.setStatus(TCPClientStatusEnum.ERROR);
                    strMsg = '001';
                    if i>this.nRepeat
                        ret = false;
                        return
                    end
                    ret = this.tryReconnectToServer(10);
                    if ~ret && (i>this.nRepeat)
                        return
                    end
                end
            end
        end
    end
end