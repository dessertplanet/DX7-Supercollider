~totalPresets = 16384;
~delta = 32;

~automate = {
    var x;

    ~setPreset.(1376);

    loop {
        if(~currentPreset<(~totalPresets-1)){
            wait(1.0);
            ~nextPreset = ~currentPreset + ~delta; 
            ~setPreset.(~nextPreset)
        }{
            0.yield;
        }
    };
};

"TEST FILE LOADED".postln;
