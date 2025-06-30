% Updated Magstim class for use with serialport (modern MATLAB, M1/M2 Mac compatible)
classdef magstim < handle
    properties
        portID
        port = []
        connected = 0
        communicationTimer = []
        armedStatus = 0
    end

    methods
        function self = magstim(PortID)
            narginchk(1, 1);
            if ~ischar(PortID) && ~(exist('string','class') && isstring(PortID))
                error('The serial port ID must be a character or string array.');
            end
            self.portID = char(PortID);
        end

        function [errorOrSuccess, deviceResponse] = connect(self)
            narginchk(1, 1);
            if isempty(self.port)
                self.port = serialport(self.portID, 9600);
                %configureTerminator(self.port, "");
                self.port.DataBits = 8;
                self.port.Parity = "none";
                self.port.StopBits = 1;
                self.port.Timeout = 0.3;
            end

            try
                write(self.port, uint8([]), "uint8");
                errorOrSuccess = 0;
                deviceResponse = 'Already connected to Magstim.';
                return
            catch
            end

            try
                [errorOrSuccess, deviceResponse] = self.remoteControl(true, true);
                if errorOrSuccess > 0
                    self.disconnect();
                    error('Could not connect to the Magstim.');
                else
                    self.connected = 1;
                end
            catch ME
                self.disconnect();
                rethrow(ME);
            end
        end

        function [errorOrSuccess, deviceResponse] = disconnect(self)
            narginchk(1, 1);
            if ~isempty(self.port)
                if self.connected
                    [~, deviceResponse] = self.remoteControl(false, true);
                end
                delete(self.port);
                self.port = [];
            end
            self.connected = 0;
            errorOrSuccess = 0;
        end

        function [errorOrSuccess, deviceResponse] = processCommand(self, commandString, getResponse, bytesExpected)
            if (self.connected == 0) && ~ismember(commandString(1),['Q','R','J','F','\']) && ~strcmp(commandString, 'EA')
                error('You need to connect to the Magstim before sending commands.');
            end
            if ~isempty(self.communicationTimer)
                stop(self.communicationTimer)
            end
            flush(self.port);
            write(self.port, uint8([commandString magstim.calcCRC(commandString)]), "uint8");

            commandAcknowledge = char(read(self.port, 1, "uint8"));
            if isempty(commandAcknowledge)
                errorOrSuccess = 1;
                deviceResponse = 'No response detected from device.';
            elseif strcmp(commandAcknowledge,'?')
                errorOrSuccess = 2;
                deviceResponse = 'Invalid command.';
            elseif strcmp(commandAcknowledge,'N')
                readData = '';
                while true
                    characterIn = char(read(self.port, 1, "uint8"));
                    if characterIn == 0
                        readData = [readData characterIn char(read(self.port, 1, "uint8"))];
                        break
                    else
                        readData = [readData characterIn];
                    end
                end
                errorOrSuccess = 0;
                deviceResponse = self.parseResponse(commandAcknowledge, readData);
            else
                readData = char(read(self.port, bytesExpected - 1, "uint8"));
                if strcmp(readData(1),'?')
                    errorOrSuccess = 3;
                    deviceResponse = 'Supplied data value not acceptable.';
                elseif strcmp(readData(1),'S')
                    errorOrSuccess = 4;
                    deviceResponse = 'Command conflicts with current device settings.';
                elseif length(readData) < (bytesExpected - 1)
                    errorOrSuccess = 5;
                    deviceResponse = 'Incomplete response from device.';
                elseif readData(end) ~= magstim.calcCRC([commandAcknowledge, readData(1:end-1)])
                    errorOrSuccess = 6;
                    deviceResponse = 'CRC does not match message contents.';
                else
                    errorOrSuccess = 0;
                    deviceResponse = self.parseResponse(commandAcknowledge, readData);
                    self.armedStatus = deviceResponse.InstrumentStatus.Armed || deviceResponse.InstrumentStatus.Ready;
                    if ~getResponse
                        deviceResponse = [];
                    end
                end
            end
            if self.connected && ~isempty(self.communicationTimer) && ~strcmp(commandString(1), 'R')
                start(self.communicationTimer);
            end
        end

        function [errorOrSuccess, deviceResponse] = setAmplitudeA(self, power, varargin)
            narginchk(2, 3);
            getResponse = magstim.checkForResponseRequest(varargin);
            magstim.checkIntegerInput('Power', power, 0, 100);
            [errorOrSuccess, deviceResponse] = self.processCommand(['@' sprintf('%03s',num2str(power))], getResponse, 3);
        end

        function [errorOrSuccess, deviceResponse] = arm(self, varargin)
            if self.armedStatus
                warning('Device is already armed.');
                errorOrSuccess = 0;
                deviceResponse = 'Already armed';
                return;
            end
            narginchk(1, 2);
            getResponse = magstim.checkForResponseRequest(varargin);
            [errorOrSuccess, deviceResponse] =  self.processCommand('EB', getResponse, 3);
            if ~errorOrSuccess
                self.armedStatus = 1;
            end
        end

        function [errorOrSuccess, deviceResponse] = disarm(self, varargin)
            narginchk(1, 2);
            getResponse = magstim.checkForResponseRequest(varargin);
            [errorOrSuccess, deviceResponse] =  self.processCommand('EA' ,getResponse, 3);
            if ~errorOrSuccess
                self.armedStatus = 0;
            end
        end

        function [errorOrSuccess, deviceResponse] = fire(self, varargin)
            narginchk(1, 2);
            getResponse = magstim.checkForResponseRequest(varargin);
            [errorOrSuccess, deviceResponse] =  self.processCommand('EH', getResponse, 3);
        end

        function [errorOrSuccess, deviceResponse] = remoteControl(self, enable, varargin)
            narginchk(2, 3);
            getResponse = magstim.checkForResponseRequest(varargin);
            if ~ismember(enable, [0 1])
                error('enable parameter must be Boolean.');
            end
            if enable
                commandString = 'Q@';
            else
                commandString = 'R@';
                self.disarm();
            end
            [errorOrSuccess, deviceResponse] =  self.processCommand(commandString, getResponse, 3);
            if ~errorOrSuccess
                self.connected = enable;
                if enable
                    self.enableCommunicationTimer();
                else
                    self.disableCommunicationTimer();
                end
            end
        end

        function [errorOrSuccess, deviceResponse] = getParameters(self)
            narginchk(1, 1);
            [errorOrSuccess, deviceResponse] =  self.processCommand('J@', true, 12);
        end

        function [errorOrSuccess, DeviceResponse] = getTemperature(self)
            narginchk(1, 1);
            [errorOrSuccess, DeviceResponse] =  self.processCommand('F@', true, 9);
        end

        function poke(self, loud)
            narginchk(1, 2);
            if nargin > 1 && ismember(loud, [0 1]) && loud
                self.remoteControl(1, 0);
            end
            stop(self.communicationTimer);
            start(self.communicationTimer);
        end

        function pause(self, delay)
            narginchk(2, 2);
            magstim.checkIntegerInput('Delay', delay, 0, Inf);
            nextHundredth = 0;
            tic;
            elapsed = 0.0;
            while elapsed <= delay
                elapsed = toc;
                if ceil(elapsed / 0.1) > nextHundredth
                    self.remoteControl(1, 0);
                    nextHundredth = nextHundredth + 1;
                end
            end
        end

        function maintainCommunication(self)
            write(self.port, uint8('Q@n'), "uint8");
            read(self.port, 3, "uint8");
        end

        function enableCommunicationTimer(self)
            if isempty(self.communicationTimer)
                self.communicationTimer = timer;
                self.communicationTimer.ExecutionMode = 'fixedRate';
                self.communicationTimer.TimerFcn = @(~,~)self.maintainCommunication;
                self.communicationTimer.StartDelay = 0.5;
                self.communicationTimer.Period = 0.5;
            end
            if strcmp(self.communicationTimer.Running, 'off')
                start(self.communicationTimer);
            end
        end

        function disableCommunicationTimer(self)
            if ~isempty(self.communicationTimer)
                if strcmp(get(self.communicationTimer,'Running'),'on')
                    stop(self.communicationTimer);
                end
                delete(self.communicationTimer);
                self.communicationTimer = [];
            end
        end

        function info = parseResponse(~, command, readData)
            statusCode = bitget(double(readData(1)),1:8);
            info = struct('InstrumentStatus',struct('Standby', statusCode(1), ...
                'Armed', statusCode(2), ...
                'Ready', statusCode(3), ...
                'CoilPresent', statusCode(4), ...
                'ReplaceCoil', statusCode(5), ...
                'ErrorPresent', statusCode(6), ...
                'ErrorType', statusCode(7), ...
                'RemoteControlStatus', statusCode(8)));

            if command == 'J'
                info.PowerA = str2double(char(readData(2:4)));
            elseif command == 'F'
                info.CoilTemp1 = str2double(char(readData(2:4))) / 10;
                info.CoilTemp2 = str2double(char(readData(5:7))) / 10;
            end
        end
    end

    methods (Static)
        function checkSum = calcCRC(commandString)
            checkSum = char(bitcmp(bitand(sum(double(commandString)),255),'uint8'));
        end

        function getResponse = checkForResponseRequest(getResponseParameter)
            if isempty(getResponseParameter)
                getResponse = false;
            else
                getResponse = getResponseParameter{1};
                if ~ismember(getResponse, [0 1])
                    error('getResponse parameter must be Boolean.');
                end
            end
        end

        function checkNumericInput(inputString, inputParameter, minValue, maxValue)
            if ~isnumeric(inputParameter) || length(inputParameter) > 1
                error('Invalid %s. Must be a single numeric value.', inputString)
            end
            if (inputParameter < minValue || inputParameter > maxValue)
                if isinf(maxValue)
                    rangeString = sprintf(' greater than %s.', num2str(minValue));
                else
                    rangeString = sprintf(' between %s and %s.', num2str(minValue), num2str(maxValue));
                end
                error('%s must have a value %s', inputString, rangeString);
            end
            if mod(inputParameter, 0.1)
                error('%s can have at most one decimal value.',inputString);
            end
        end

        function checkIntegerInput(inputString, inputParameter, minValue, maxValue)
            magstim.checkNumericInput(inputString, inputParameter, minValue, maxValue);
            if mod(inputParameter, 1)
                error('Invalid %s value. Must be a single integer.', inputString);
            end
        end
    end
end
