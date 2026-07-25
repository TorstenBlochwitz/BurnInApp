classdef BurnInStatusEnum < int8
    enumeration
        ERROR(-1)
        NO_HARDWARE_CONNECTED(0)
        DCDC_CONNECTED(1)
        MAINBOARD_CONNECTED(2)
        EXECUTING_PROFILE(3)
        SWITCHING_OFF(5)
    end
end

