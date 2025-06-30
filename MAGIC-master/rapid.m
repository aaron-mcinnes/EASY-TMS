% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.

% Updated rapid class for use with serialport (modern MATLAB, M1/M2 Mac compatible)
classdef rapid < magstim & handle
    properties (SetAccess = private)
        enhancedPowerModeStatus = 0;
        rapidType = [];
        unlockCode = [];
        version = [];
        controlCommand = '';
        controlBytes = [];
    end

    properties (Constant)
        energyPowerTable = [  0.0,   0.0,   0.1,   0.2,   0.4,   0.6,   0.9,   1.2,   1.6,   2.0,...
                              2.5,   3.0,   3.6,   4.3,   4.9,   5.7,   6.4,   7.3,   8.2,   9.1,...
                             10.1,  11.1,  12.2,  13.3,  14.5,  15.7,  17.0,  18.4,  19.7,  21.2,...
                             22.7,  24.2,  25.8,  27.4,  29.1,  30.8,  32.6,  34.5,  36.4,  38.3,...
                             40.3,  42.3,  44.4,  46.6,  48.8,  51.0,  53.3,  55.6,  58.0,  60.5,...
                             63.0,  65.5,  68.1,  70.7,  73.4,  76.2,  79.0,  81.8,  84.7,  87.7,...
                             90.7,  93.7,  96.8, 100.0, 103.2, 106.4, 109.7, 113.0, 116.4, 119.9,...
                            123.4, 126.9, 130.5, 134.2, 137.9, 141.7, 145.5, 149.3, 153.2, 157.2,...
                            161.2, 165.2, 169.3, 173.5, 177.7, 181.9, 186.3, 190.6, 195.0, 199.5,...
                            204.0, 208.5, 213.1, 217.8, 222.5, 227.3, 232.1, 236.9, 241.9, 246.8, 252]; 
    end

    methods
        function self = rapid(PortID, rapidType, varargin)
            narginchk(1, 3);
            if nargin < 2
                rapidType = 'rapid';
            elseif ~ismember(lower(rapidType), {'rapid','super','superplus'})
                error('rapidType must be ''rapid'', ''super'', or ''superplus''.');
            end
            self = self@magstim(PortID);
            self.rapidType = lower(rapidType);
            if nargin > 2
                self.unlockCode = varargin{1};
            end
        end

        function [errorOrSuccess, deviceResponse] = remoteControl(self, enable, varargin)
            narginchk(2, 3);
            getResponse = magstim.checkForResponseRequest(varargin);
            if ~ismember(enable, [0 1])
                error('enable parameter must be Boolean.');
            end
            if enable
                if ~isempty(self.unlockCode)
                    commandString = ['Q' self.unlockCode];
                else
                    commandString = 'Q@';
                end
            else
                commandString = 'R@';
                self.disarm();
            end
            alreadyConnected = self.connected;
            [errorOrSuccess, deviceResponse] = self.processCommand(commandString, getResponse, 3);
            if ~errorOrSuccess
                self.connected = enable;
                if enable
                    if ~alreadyConnected
                        [errorCode, magstimVersion] = self.getDeviceVersion();
                        if errorCode
                            errorOrSuccess = errorCode;
                            deviceResponse = magstimVersion;
                            return;
                        else
                            self.version = magstimVersion;
                        end
                    end
                    if self.version{1} >= 9
                        self.controlBytes = 6;
                        self.controlCommand = 'x@G';
                    else
                        self.controlBytes = 3;
                        self.controlCommand = 'Q@n';
                    end
                    self.enableCommunicationTimer();
                else
                    self.disableCommunicationTimer();
                end
            end
        end

        function maintainCommunication(self)
            write(self.port, uint8(self.controlCommand), "uint8");
            read(self.port, self.controlBytes, "uint8");
        end

        function [errorOrSuccess, deviceResponse] = parseResponse(self, command, readData)
            if command == 'N'
                info = cellfun(@(x) str2double(x), regexp(readData,'\d*','Match'),'UniformOutput',false);
                errorOrSuccess = 0;
                deviceResponse = info;
                return;
            end
            statusCode = bitget(double(readData(1)),1:8);
            info = struct('InstrumentStatus', struct(...
                'Standby', statusCode(1), 'Armed', statusCode(2), 'Ready', statusCode(3), ...
                'CoilPresent', statusCode(4), 'ReplaceCoil', statusCode(5), ...
                'ErrorPresent', statusCode(6), 'ErrorType', statusCode(7), ...
                'RemoteControlStatus', statusCode(8)));

            if ismember(command, ['\\', '[', 'D', 'B', '^', '_', 'x', 'n'])
                statusCode = bitget(double(readData(2)),1:8);
                info.RapidStatus = struct(...
                    'EnhancedPowerMode', statusCode(1), 'Train', statusCode(2), ...
                    'Wait', statusCode(3), 'SinglePulseMode', statusCode(4), ...
                    'HVPSUConnected', statusCode(5), 'CoilReady', statusCode(6), ...
                    'ThetaPSUDetected', statusCode(7), 'ModifiedCoilAlgorithm', statusCode(8));
            end

            if command == '\\'
                info.PowerA = str2double(char(readData(3:5)));
                info.Frequency = str2double(char(readData(6:9))) / 10;
                if self.version{1} >= 9
                    info.NPulses = str2double(char(readData(10:14)));
                    info.Duration = str2double(char(readData(15:18))) / 10;
                    info.WaitTime = str2double(char(readData(19:22))) / 10;
                elseif self.version{1} >= 7
                    info.NPulses = str2double(char(readData(10:13)));
                    info.Duration = str2double(char(readData(14:16))) / 10;
                    info.WaitTime = str2double(char(readData(17:20))) / 10;
                else
                    info.NPulses = str2double(char(readData(10:13)));
                    info.Duration = str2double(char(readData(14:16))) / 10;
                    info.WaitTime = str2double(char(readData(17:19))) / 10;
                end
            elseif command == 'F'
                info.CoilTemp1 = str2double(char(readData(2:4))) / 10;
                info.CoilTemp2 = str2double(char(readData(5:7))) / 10;
            elseif command == 'I'
                info.ErrorCode = char(readData(2:4));
            elseif command == 'x' || (command == 'n' && self.version{1} >= 10)
                statusCode = bitget(double(readData(4)),1:8);
                info.SystemStatus = struct(...
                    'Plus1ModuleDetected', statusCode(1),...
                    'SpecialTriggerModeActive', statusCode(2),...
                    'ChargeDelaySet', statusCode(3));
            elseif command == 'o'
                if self.version{1} >= 10
                    info.ChargeDelay = str2double(char(readData(2:6)));
                else
                    info.ChargeDelay = str2double(char(readData(2:5)));
                end
            end

            errorOrSuccess = 0;
            deviceResponse = info;
        end
    end

    methods (Static)
        function [errorOrSuccess, deviceResponse] = calcMinWaitTime(power, frequency, nPulses)
            ePulse = rapid.energyPowerTable(power + 1);
            deviceResponse = (nPulses * ((frequency * ePulse) - 1050)) / (1050 * frequency);
            if deviceResponse < 0.5
                warning('Your input parameters result in a minimum wait time less than 500ms.');
                deviceResponse = 0.5;
            end
            errorOrSuccess = 0;
        end
    end
end
