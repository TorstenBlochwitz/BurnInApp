classdef BurnInPRDB < prdb
    %Interface to PRDB

    methods
        function this = BurnInPRDB(db)
            this@prdb();
            this.db = db;
            this.userName = 'e40012110';
            this.password = 'd/HX73XzCHz14F0V';
            this.retryCount = 2;

        end

        function measurement_ID = addMeasurement(this, FAUF, profileID, stepID, anlagenID, materialID, T, VDC, VR, R)
            % SQL: INSERT INTO `SUB_measurement`(`FAUF`, `subID`, `AG`,`valid`, `anlagenID`, `materialId`, `user`) VALUES ('0815','1','Meier','1','{"Boards":{"DCDC":"1234-56_78-910","Main":"4567-89-89-123"},"DMM":"None"}','4711','Me')
            
            m(1,1).FAUF = FAUF;  % Fertigungsauftrag: Das ist bei InfraSolid eine ID, die einmal eingegeben werden muss, oder?
            m(1,1).AG = int2str(profileID); % Arbeitsgang: Referenz auf das BurnIn Profile: KMAT_settings: Eintrag mit ZVC = IVC_2000
            m(1,1).subId = int2str(stepID); % Referenz auf den aktuellen BurnIn Profile Step: KMAT_settings: Eintrag mit ZVC = IVC_2500
            m(1,1).valid = 0;    % 0 bedeutet kein Fehler
            m(1,1).anlagenId = anlagenID;        % JSON Beispiel:{"Boards":{"DCDC":"1234-56_78-910","Main":"4567-89-89-123"},"DMM":"None"}'
            m(1,1).materialId = materialID;      % Referenz auf zum Beispiel HIS550R-0WC, das müsste mal jemand befüllen
            user = getenv('username');
            if size(user, 2) > 5
                user = user(1:5);
            end
            m(1,1).user = user;    % Hier sind lediglich 5 Zeichen erlaubt! e40012110 passt da zum Beispiel nicht rein. Gibt es eine alternative Nutzerverwaltung?
            try
                measurement_ID = this.insert('SUB_measurement', m);
            catch e
                this.errorMsg = e.message;
                measurement_ID = 0;
                return
            end
            % Add measurement data
            data(1,1).related_measurement_id = measurement_ID;
            %Temperature (nur ein Wert pro Messung)
            data(1,1).x = 0; % Gilt für alle Positionen, deshalb 0!
            data(1,1).y = 0; % Gibt es beim BurnIn nicht
            data(1,1).para = 25; % Temp
            data(1,1).value = T;
            data(1,1).bincode = 0; % 0 bedeutet OK
            id = this.insert('SUB_data', data);
            for i = 1:size(VDC,2)
                data(1,1).x = i; % Index auf dem BurnIn Main Board
                data(1,1).para = 26; % R
                data(1,1).value = R(i);
                id = this.insert('SUB_data', data);
                data(1,1).para = 44; % VDC
                data(1,1).value = VDC(i);
                id = this.insert('SUB_data', data);
                data(1,1).para = 45; % VR
                data(1,1).value = VR(i);
                id = this.insert('SUB_data', data);
            end
% Allgemeine Fragen:
% - was ist noch einmal der Inhalt der PID genau? ein bestimmter ausgeführter Prozessschritt, wie zum Beispiel das BurnIn: Ja!
% - wie verweist ein Measurement auf einen BurnIn Prozess, also einen PIDEintrag? -> Über den AG? -> Klärt Adjan, Vorschlag Torsten: über den FAUF

% - wo speichern wir die Prozessbeschreibung (also die Parameter der einzelnen BurnIn Steps)? Im SAP? Steht PID.AG für Arbeitsgang und verweist darauf? 

% - wo speichern wir das "Protokoll" eines BurnIn Vorgangs, also das, was aktuell im Status File landet?

% - worauf verweist die materalId? Auf KMAT_settings.MaterialId? Sind das auch key - value pairs?

% Inkonsistenzen:
% - in PID is AG ein integer, in SUB_measurement ein var_char
% - es gibt alle Schreibweisen für Identifier: ID, Id, id, _ID, _id

        end
        function v = getMeasurementValue(this, measurement_ID, p)
            if isa(p, 'char')
                % Get 
                this.prepareStatement('SELECT id FROM `SUB_mapping` WHERE `label`="{S}"', p);
                data = this.query();
                if isempty(data)
                   v=this.nullValue;
                   return
                end
                para = data.id(1);
            else
                para = p;
            end
            this.prepareStatement('SELECT `value` FROM `SUB_data` WHERE `related_measurement_id` = "{Si}" AND para = "{Si}" ORDER BY `x`', measurement_ID, para);
            data = this.query();
            v=data.value;
        end
        function R = getResistance(this, measurement_ID)
            %SQL: SELECT `value` FROM `SUB_data` WHERE `related_measurement_id` = 4688 AND para = 26;
%           Just to remember how to join:
%             SELECT * 
%             FROM `SUB_data` 
%             JOIN `SUB_mapping` ON `SUB_data`.`para`=`SUB_mapping`.`id`
%             WHERE `related_measurement_id` = 4688 AND para = 26;
            this.prepareStatement('SELECT `value` FROM `SUB_data` WHERE `related_measurement_id` = "{Si}" AND para = 26 ORDER BY `x`', measurement_ID);
            data = this.query();
            R=data.value;
        end

        function ID = addProfileStep(this, name, d, P, Imax, Vmax, f, duty, m)
            pS(1,1).MaterialId = 47110815; % Es kann BurnIn Steps/Profiles geben, die für mehrere MaterialIds verwendet werden können
            pS(1,1).KMAT = 1800;           % Produktgruppe?: 1800 für IR Strahler
            pS(1,1).ZVC = 'IVC_2500';      % Wird für jedes Profile eine neue ZVC vergeben? Oder bedeutet eine bestimmte ZVC: Das ist ein Eintrag vom Typ XXX? Ich nehme letzteres an
            %pS(1,1).value = 0;            % Brauchen wir nicht, wir nutzen DokuWert und stecken dort einen JSON String rein
            pS(1,1).valueDescr = this.BuildJSON4BurnInProfileStep(name, d, P, Imax, Vmax, f, duty, m);
            try
                ID = this.insert('KMAT_settings', pS);
            catch e
                this.errorMsg = e.message;
                ID = 0;
                return
            end
        end
        function ID = addProfile(this, name, Type, n, R, dev, mRate, steps)
            p(1,1).MaterialId = 47110815; % Es kann BurnIn Steps/Profiles geben, die für mehrere MaterialIds verwendet werden können
            p(1,1).KMAT = 1800;           % Produktgruppe?: 1800 für IR Strahler
            p(1,1).ZVC = 'IVC_2000';      % Wird für jedes Profile eine neue ZVC vergeben? Oder bedeutet eine bestimmte ZVC: Das ist ein Eintrag vom Typ XXX? Ich nehme letzteres an
            %p(1,1).value = 0;            % Brauchen wir nicht, wir nutzen DokuWert und stecken dort einen JSON String rein
            p(1,1).valueDescr = this.BuildJSON4BurnInProfile(name, Type, n, R, dev, mRate, steps);
            try
                ID = this.insert('KMAT_settings', p);
            catch e
                this.errorMsg = e.message;
                ID = 0;
                return
            end
        end

        function strJ = BuildJSON4BurnInProfile(this, name, Type, n, R, dev, mRate)
            profile.name = name;    % Name
            profile.Type = Type;    % Type, example "TO39"
            profile.n = n;          % NumberOfChannels (maximum emitters per board)
            profile.R = R;          % Resistance in Ohm
            profile.dev = dev;      % Deviation in Ohm
            profile.mRate = mRate;  % MeasurementRate in min
            
            strJ=jsonencode(profile);
        end
        function strJ = BuildJSON4BurnInProfileStep(this, name, d, P, Imax, Vmax, f, duty, m)
            step.name = name;    % Name, example "BurnIn1"
            step.d = d;          % Duration in min
            step.P = P;          % PowerPerChannel in W
            step.Imax = Imax;    % MaxCurrent in A
            step.Vmax = Vmax;    % MaxVoltage in V
            step.f = f;          % Frequency in Hz
            step.duty = duty;    % DutyCycle in %
            step.m = m;          % Measure (do at least one measurement in this step)
            
            strJ=jsonencode(step);
        end
        function profile = getProfile(this, MaterialID)
            this.prepareStatement('SELECT * FROM `KMAT_settings` WHERE `MaterialId`="{Si}" AND `ZVC`= "IVC_2000"', MaterialID);
            profile = this.query();
            if isempty(profile)
               fprintf("No BurnIn Profile for MaterialId %d found!", MaterialID);
               return
            else
                fprintf('%s\n', profile.valueDescr{1,1});
                i=0;
                while true
                    IVC = sprintf("IVC_%d", 2500+i);
                    this.prepareStatement('SELECT * FROM `KMAT_settings` WHERE `MaterialId`="{Si}" AND `ZVC`= "{S}"', MaterialID, IVC);
                    profileStep = this.query();
                    if isempty(profileStep) || strlength(profileStep.valueDescr{1,1}) == 0
                        break
                    else
                        fprintf('Step %d: %s\n', i+1, profileStep.valueDescr{1,1});
                        i = i +1;
                    end
                end
            end
        end
    end
end