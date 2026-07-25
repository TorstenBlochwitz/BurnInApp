classdef BurnInStatus < handle
    properties (Access = private)
        status = BurnInStatusEnum.NO_HARDWARE_CONNECTED;
        strStatus =[...
            "ERROR"...
            "No Hardware connected"...
            "DCDC Converter connected"...
            "MainBoard Connected"...
            "Executing Profile"...
            "Switching Off"...
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
