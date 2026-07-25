classdef VDCstatus < handle
    properties (Access = private)
        status = VDCStatusEnum.UNKNOWN;
        VDCmeasureStatus = 0;% -1: too small, 0: OK, 1 too big
        %from BurnInController
        cWhite = [1.0 1.0 1.0];
        cGreen = [0.0 1.0 0.0];     % OK     
        cOrange = [1.0 0.8 0.0];    % User interaction required
        cRed = [1.0 0.4 0.4];       % Error
        cFullRed = [1.0 0.0 0.0];   % Error (RGB LED)
    end
    
    methods
        function setStatus(this, v)
            this.status = v;
        end
        function ret = getStatus(this)
            ret = this.status;
        end
        function setVDCmeasureStatus(this, status)
            this.VDCmeasureStatus = status;
        end
        function [ret, color] = getStatusStringColor(this, VDCmeasured)
            strV = sprintf("%.2f", VDCmeasured);
            switch this.status
                case VDCStatusEnum.OFF_SHOULD_BE_ON
                    ret = "Error";
                    color = this.cFullRed;
                case VDCStatusEnum.OFF_OK
                    ret = "Off";
                    color = this.cGreen;
                case VDCStatusEnum.ON_OK_V_CONTROLED
                    ret = sprintf("%s", strV);
                    color = this.cGreen;
                case VDCStatusEnum.ON_OK_P_CONTROLED
                    ret = sprintf("%s (P)", strV);
                    color = this.cGreen;
                case VDCStatusEnum.ON_PCONTROLED_V_LIMIT
                    ret = sprintf("%s (P ↓V)", strV);
                    color = this.cOrange;
                case VDCStatusEnum.ON_PCONTROLED_I_LIMIT
                    ret = sprintf("%s (P ↓I)", strV);
                    color = this.cOrange;
                otherwise
                    ret = "";
                    color = this.cWhite;
            end
            if this.VDCmeasureStatus < 0
                ret = sprintf("%s (↓)", strV);
                color = this.cFullRed;
            elseif this.VDCmeasureStatus > 0
                ret = sprintf("%s (↑)", strV);
                color = this.cFullRed;
            end
        end
    end
end
