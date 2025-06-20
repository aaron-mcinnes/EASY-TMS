%Aaron McInnes Sept 2023 - mcinn125@umn.edu
%%
%This function establishes communication with the rapid2 device at NNL
%   Calling this function prepares the device for single pulse in repetitive mode to keep output
%   consistent when changing parameters.
%   It also establishes communication from the LPT to the magstim device for
%   rapid triggering. triggerTBS depends on this. 
%After establishing the connection, make sure you set the amplitude via
%   magstimObject.setAmplitudeA(amplitude_as_integer) and arm the device with
%   magstimObject.arm()
%You can then trigger the device with magstimObject.fire() or by setting a
%   connected Parallel Port high on the correct pin. Aaron used pin 6, i.e.,
%   io64(ioObj,address,6);
%%
function magstimObject = RapidConnect(portID, UnlockCode, ioObjaddress)
    ioObj = io64;
    status = io64(ioObj);
    address = hex2dec(ioObjaddress); %LPT3 on NNL PC (new recorder). For other PCs, check device manager
    io64(ioObj,address,0); % send a signal
        %if already connected, disconect
    if evalin('base', 'exist(''magstimObject'', ''var'')') 
            disp('Magstim was already connected. Re-establishing connection now.')
            magstimObject = evalin('base', 'magstimObject');
            magstimObject.disconnect();
    end

   try 
        %try connecting to magstim via serial
            magstimObject = rapid(char(portID), 'superplus', UnlockCode);
            disp('Connecting rapid2...')
            magstimObject.connect();
            pause(2)
    
            %set amplitude to 0, arm, disarm so that initial connection pulse is suppressed
            magstimObject.setAmplitudeA(0);
            pause(.5);
            magstimObject.arm();
            pause(.5);
            magstimObject.disarm();
            pause(.5);

            assignin('base', 'ioObj', ioObj)
            assignin('base', 'address', address)
            assignin('base', 'magstimObject', magstimObject)

            setTBSparams(1, 1); %single pulse on RTMS mode (do this rather than explicitly changing to SP mode, on the assumption RTMS mode changes output)

    catch 
        errordlg('Could not connect to Magstim. Check serial connection', 'Error');
        return
   end

end