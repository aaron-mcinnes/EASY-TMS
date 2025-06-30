% Updated bistim class inheriting from serialport-based magstim
classdef bistim < magstim & handle
    properties (SetAccess = public)
        highRes = 0; %Bistim High Resolution Time Setting Mode
    end

    methods
        function self = bistim(PortID)
            self = self@magstim(PortID);
        end

        function [errorOrSuccess, deviceResponse] = setAmplitudeB(self, power, varargin)
            narginchk(2, 3);
            getResponse = magstim.checkForResponseRequest(varargin);
            magstim.checkIntegerInput('Power', power, 0, 100);
            [errorOrSuccess, deviceResponse] = self.processCommand(['A' sprintf('%03s',num2str(power))], getResponse, 3);
        end

        function [errorOrSuccess, deviceResponse] = setPulseInterval(self, ipi, varargin)
            narginchk(2, 3);
            getResponse = magstim.checkForResponseRequest(varargin);
            if self.highRes
                magstim.checkNumericInput('IPI', ipi, 0, 99.9);
                ipi = round(ipi * 10);
            else
                magstim.checkIntegerInput('IPI', ipi, 0, 999);
            end
            [errorOrSuccess, deviceResponse] = self.processCommand(['C' sprintf('%03s', num2str(ipi))], getResponse, 3);
        end

        function [errorOrSuccess, deviceResponse] = highResolutionMode(self, enable, varargin)
            narginchk(2, 3);
            getResponse = magstim.checkForResponseRequest(varargin);
            if ~ismember(enable, [0 1])
                error('enable Must Be A Boolean');
            end
            if enable
                commandString = 'Y@';
            else
                commandString = 'Z@';
            end
            [errorOrSuccess, deviceResponse] = self.processCommand(commandString, getResponse, 3);
            if ~errorOrSuccess
                self.highRes = enable;
            end
        end

        function [errorOrSuccess, deviceResponse] = getParameters(self)
            narginchk(1,1);
            [errorOrSuccess, deviceResponse] =  self.processCommand('J@', true, 12);
            if self.highRes
                deviceResponse.IPI = deviceResponse.IPI / 10;
            end
        end
    end

    methods (Access = 'public')
        function info = parseResponse(~, command, readData)
            statusCode = bitget(double(readData(1)),1:8);
            info = struct('InstrumentStatus',struct('Standby', statusCode(1),...
                                                    'Armed', statusCode(2),...
                                                    'Ready', statusCode(3),...
                                                    'CoilPresent', statusCode(4),...
                                                    'ReplaceCoil', statusCode(5),...
                                                    'ErrorPresent', statusCode(6),...
                                                    'ErrorType', statusCode(7),...
                                                    'RemoteControlStatus', statusCode(8)));

            if command == 'J'
                info.PowerA = str2double(char(readData(2:4)));
                info.PowerB = str2double(char(readData(5:7)));
                info.IPI    = str2double(char(readData(8:10)));
            elseif command == 'F'
                info.CoilTemp1 = str2double(char(readData(2:4))) / 10;
                info.CoilTemp2 = str2double(char(readData(5:7))) / 10;
            end
        end
    end
end
