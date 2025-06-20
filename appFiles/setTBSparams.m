function setTBSparams(freq, nPulse) 
    magstimObject = evalin('base', 'magstimObject');
    %get lpt port ready to trigger 
    ioObj = evalin('base', 'ioObj');
    address = evalin('base', 'address');

    trainParams.frequency = freq;
    trainParams.nPulses = nPulse;
    trainParams.duration = [];

    magstimObject.setTrain(trainParams);
    io64(ioObj,address,0); % set low
    assignin('base', 'magstimObject', magstimObject)
end