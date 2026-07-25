classdef TCPClientStatus < handle
    properties (Access = private)
        status = TCPClientStatusEnum.DISCONNECTED;
        strStatus =[...
            "ERROR"...
            "Disconnected"...
            "Connected"...
            ];
    end
    
    methods
        function setStatus(this, v)
            this.status = v;
        end
        function ret = getStatus(this)
            ret = this.status;
        end
        function ret = getStatusString(this)
            ret = this.strStatus(this.status + 2);
        end
    end
end
