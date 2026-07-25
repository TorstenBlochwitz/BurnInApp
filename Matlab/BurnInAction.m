classdef BurnInAction < handle

    properties
        currentAction BurnInActionEnum;
        nextAction BurnInActionEnum;
        strAction =["Doing nothing" "Connecting Hardware" "Connecting Hardware" "Self-testing" "Executing Profile" "Doing Measurement"];
    end
    
    methods
        function this = BurnInAction()
            this.currentAction = BurnInActionEnum.DO_NOTHING;
            this.nextAction = BurnInActionEnum.DO_NOTHING;
        end

        function ret = getActionString(this)
            ret = this.strAction(this.nextAction + 1);            
        end
    end
end

