function triggerTBS(trigPin, carrierFreq, nBursts)
    ioObj = evalin('base', 'ioObj');
    address = evalin('base', 'address');
    magstimObject = evalin('base', 'magstimObject');
    
    IBI = round(1/carrierFreq, 3);
    if IBI < .333
        error('rTMS can not be triggered at intervals less that 3 Hz (333 ms)')
        aa %generate an error
    end

    magstimObject.poke(0);
    for burst = 1:nBursts
        time = hat;
        io64(ioObj,address,trigPin); % send a signal
        while hat < time + .001
        end
        magstimObject.poke(1);
        io64(ioObj,address,0); % send a signal
        while hat < time + IBI %due to device constraints, I cannot set the inter-burst interval lower tha 333 ms (3 Hz)
        end
    end
end

