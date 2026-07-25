classdef AnalogMux  < handle
    %AnalogMux: simplifies safe handling of the analog Multiplexer
    %Nothing is done in constructor, but in destructor, all analog channels are disabled
    %this makes sure that even in case of an exception, the
    %channel is switched off

    properties
        mainBoard MainBoard;
    end

    methods
        function this = AnalogMux(mainBoard)
            this.mainBoard = mainBoard;
        end

        function delete(this)
            %switch all channels Off in destructor
            try
                this.mainBoard.setMUX(-1);
            catch
            end
        end
    end
end