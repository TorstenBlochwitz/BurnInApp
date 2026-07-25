%Some Tests of BurnIn PRDB
classdef TestBurnInPRDB < handle
    properties
        db
    end
    methods
        function this = TestBurnInPRDB()
            % database
            this.db = BurnInPRDB('infrasolid');
        end
        function ID = addMeasurement1(this, FAUF, profileID, stepID)
            % generate some test data
            R = [22.1, 22.2, 22.3];
            VDC = [2.3, 2.4, 2.5];
            VR = [0.12, 0.13, 0.14];
        
            % add measured data to database
            measurementID  = this.db.addMeasurement(FAUF, profileID, stepID, '{"Boards":{"DCDC":"1234-56_78-910","Main":"4567-89-89-123"},"DMM":"None"}', 47110815, 34.1, VDC, VR, R);
            
            fprintf("measurement_ID = %d\n", measurementID);
        
            %Retrieve some data
            VDC = this.db.getMeasurementValue(measurementID, 'VDC')
            R = this.db.getMeasurementValue(measurementID, 'R')
        end
        function ID = generateSomeProfileSteps1(this)
            ID = zeros(1,3);
            ID(1) = this.db.addProfileStep('Initial Check', 0, 0.2, 0.175, 2.0, 0,  0, 0);
            ID(2) = this.db.addProfileStep('Burn In 1',    10, 0.4, 0.66, 3.2, 2, 20, 1);
            ID(3) = this.db.addProfileStep('Burn In 2',    30, 0.5, 0.66, 3.2, 1, 50, 1);
        end
        function ID = addProfile(this, name, Type, n, R, dev, mRate, steps)
            ID = this.db.addProfile(name, Type, n, R, dev, mRate, steps);
        end
    end
end