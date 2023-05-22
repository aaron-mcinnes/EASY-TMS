function [ConnectionSuccess, magstimObject] = TMSStimulatorConnection(ConnectionPort, StimType, UnlockCode)

try
    if StimType == 1 % Magstim
        magstimObject = magstim(ConnectionPort);
        disp('Connecting magstim...')
    elseif StimType == 2 % Bistim
        magstimObject = bistim(char(ConnectionPort));
        disp('Connecting bistim...')
    elseif StimType == 3 % Rapid
        magstimObject = rapid(char(ConnectionPort), 'superplus', UnlockCode);
        disp('Connecting rapid2...')
    %elseif StimType == 4 % MagVenture
    end
    
    magstimObject.connect();
    pause(0.5)
    
    ConnectionSuccess = 1;
    ConnectionSuccessText = 'Connected';
    disp(ConnectionSuccessText)

catch
    magstimObject = 0;

    ConnectionSuccess = 0;
    ConnectionSuccessText = 'Could Not Connect';
    disp(ConnectionSuccessText)

end