//Functions galore- see main for where they are called

//When focus has changed, update context to reflect our new position
~updateMetadata = {
	~nextBank = ~presetMeta[~nextPreset][1];
	~nextBankIndex = (~nextPreset / 511).floor + (~nextPreset % 511);
	~nextSubIndex = ~nextPreset % 31;
	~modDepthDisplay = (~vr[135] / 99 * 100).asInteger;
};

//Reload the main UI
~refreshScreen = {
		~nextBank = ~presetMeta[~nextPreset][1];
		m.sendMsg("/oled/line/1",(~selected ++ ~presetMeta[~nextPreset][3]).padRight(15) ++ ("#" ++ ~nextPreset).asString.padLeft(6));
		if(~auxPressed == false){
			m.sendMsg("/oled/line/2", "bank " ++ ~nextBank.padRight(9));
			m.sendMsg("/oled/line/3", "velocity " ++ ~organelleKeyVelocity);
			m.sendMsg("/oled/line/4", "lfo depth " ++ ~modDepthDisplay ++ "%");
			m.sendMsg("/oled/line/5", "octave " ++ ~octaveTable[~currentOctave]);
		}{
			m.sendMsg("/oled/line/2", "bend " ++ (~bend * 100).asStringPrec(3) ++ "%");
			m.sendMsg("/oled/line/3", "bend range " ++ ~bendRange);
			m.sendMsg("/oled/line/4", "lfo speed " ++ ~lfoSpeed.asStringPrec(3) ++ " Hz");
			m.sendMsg("/oled/line/5", "polyphony " ++ ~polyphony);
		};
};

//Unpack preset information
f = { arg x, y ,z; //y value, z cc no
	if(x == 3,
		{ ~vr[y] = z },
		{ ~vr[y + 128] = z }
	)
};

//Given a preset index, load that preset
~setPreset = {
	arg g;
	var p;
	postln("set preset " ++ g);
	~modWheel = nil;
	p = ~presets[g][0];
	145.do({arg item;
		var k = (p.at((item*2)) ++ p.at((item*2) + 1)).asInteger;
		f.value(~cirklonCCparse[item][0],~cirklonCCparse[item][1],k);
	});
	~currentPreset = g;
	~lfo_speed = ~dx7_voice_lfo_frequency[~vr[132]];
	~updateMetadata.();
	if(~nextPreset == ~currentPreset){
		~selected = "* ";
	}{
		~selected = "";
	};
	~refreshScreen.();
};

//Load a random patch!
~randomPatch = {
	var new;
	new = rrand(0,16383);
	~nextPreset = new;
	~setPreset.(~nextPreset);
	if(~nextPreset == ~currentPreset){
		~selected = "* ";
	}{
		~selected = "";
	};
	~refreshScreen.();
};


//Generic function for showing a text-based menu on Organelle screen
~textMenu = {
    arg title, linesArray ...extras;
	var firstEmpty;

	firstEmpty = linesArray.size-~pageStart-1;

	m.sendMsg("/oled/line/1", title);

    linesArray[~pageStart..(~pageStart+3)].do{
		arg item, i;
		var thisPreset, thisPresetMeta;
		thisPreset = linesArray[~pageStart+i];
		thisPresetMeta = ("#" ++ thisPreset) ++ " " ++ ~presetMeta[thisPreset][3];
		if(i == ~selectedLine){
			m.sendMsg("/oled/line/"++(i+2), "> " ++ thisPresetMeta)
		}{
			m.sendMsg("/oled/line/"++(i+2), "  " ++ thisPresetMeta)
		};
	};

	extras.do{
		arg item, i;
		var line = linesArray.size-~pageStart+2+i;
		if((firstEmpty<3)&&(line<6)){
			if((firstEmpty+i+1) == ~selectedLine){
				m.sendMsg("/oled/line/"++line, "> " ++ item)
			}{
				m.sendMsg("/oled/line/"++line, "  " ++ item)
			};
		}
	};
	~linesDisplayed = (linesArray[~pageStart..(~pageStart+3)] ++ extras)[0..3];
};

//Update an existing menu created with textMenu 
~incrementMenu = {
    arg title, linesArray, delta ...extras;
    var upLim, lowLim=0, firstEmpty;

	firstEmpty = linesArray.size-~pageStart-1;

	upLim = min(3, (linesArray.size + extras.size - 1));

        if(delta>0){
            if(~selectedLine<upLim){
                ~selectedLine = ~selectedLine + 1; 
            }{
				if((~pageStart + ~selectedLine)<(linesArray.size + extras.size - 1)){
                	~pageStart = (~pageStart + 1)
				}
            }
        }{
            if(~selectedLine>lowLim){
                ~selectedLine = ~selectedLine - 1;
            }{
				if(~pageStart>0){
                	~pageStart = (~pageStart - 1)
				}
            }
        };

		extras.do{
			arg item, i;
			var line;
			line = linesArray.size-~pageStart+2+i;
			if((firstEmpty<3) && (line < 6)){
				if((firstEmpty+i+1) == ~selectedLine){
					m.sendMsg("/oled/line/"++line, "> " ++ item)
				}{
					m.sendMsg("/oled/line/"++line, "  " ++ item)
				};
			}
		};	

		// postln("page start " ++ ~pageStart);
		// postln("selected line " ++ ~selectedLine);
		
		~linesDisplayed = (linesArray[~pageStart..(~pageStart+3)] ++ extras)[0..3];
		
        ~textMenu.(title, linesArray, *extras);
};

//Handle selection from a textMenu
~menuSelect = {
	arg item;

	switch(item)
	{'SAVE CURRENT'}{
		//SAVE THE CURRENT PRESET
		postln("saving preset " ++ ~currentPreset);
		~savedPresets = ~savedPresets.add(~currentPreset);
		~nextPreset = ~currentPreset;
		~currentScreen = \main;
		if(~nextPreset == ~currentPreset){
			~selected = "* ";
		}{
			~selected = "";
		};
		~refreshScreen.();
		~saveToFile.();
	}
	{'CANCEL'}{
		~currentScreen = \main;
		~refreshScreen.()
	}
	{'YES'}{
		//delete this preset
		postln("removing at " ++ (~toDelete));
		~savedPresets.removeAt(~toDelete);
		~currentScreen = \save;
		~graphics.(\Clear);
		~selectedLine = 0;
		~pageStart = 0;
		~textMenu.(~saveMenuTitle, ~savedPresets,~newSaveSym, ~cancelSym);
		~saveToFile.();
	}
	{'NO'}{
		~currentScreen = \save;
		~graphics.(\Clear);
		~selectedLine = 0;
		~pageStart = 0;
		~textMenu.(~saveMenuTitle, ~savedPresets,~newSaveSym, ~cancelSym);
	}
	{//DEFAULT CASE IS A PRESET ID
		~nextPreset = item;
		~setPreset.(item);
	};
	~selectedLine = 0;
	~pageStart = 0;
};

//Routine to govern behavior of organelle encoder long press
~longEncPress = {
	~longEncPressState = false;
	wait(1);
	~longEncPressState = true;
	switch(~currentScreen)
	{\main}{
		if(~auxPressed == false){		
			m.sendMsg("/gohome")
		}{
			//SHOWING THE SAVED MENU
			~graphics.(\Clear);
			~currentScreen = \save;
			~textMenu.(~saveMenuTitle, ~savedPresets,~newSaveSym, ~cancelSym);
		}
	}
	{\save}{
		//longencpress savemenu
		//Clear slot
		~toDelete = ~pageStart + ~selectedLine;
		if(~selectedLine<~savedPresets.size){
			~selectedLine=0;
			~pageStart=0;
			~graphics.(\Clear);
			~currentScreen = \confirm;
			~textMenu.("DELETE SAVE?",[],'NO','YES');
			m.sendMsg("/oled/line/4","to be deleted:");
			m.sendMsg("/oled/line/5", ("#" ++ ~savedPresets[~toDelete]) ++ " " ++ ~presetMeta[~savedPresets[~toDelete]][3])
		}{
			"can't delete symbols".postln;
		}
	}
};

//A few functions to help with MIDI input
~bendExistingNotes = {
	~noteArrayDX7.do({
			arg item, i;

			if(item != nil){
				var new;
				new = (i + ~vr[131] - 24 + (~bend * ~bendRange) + (~transpose*12)).midicps;
				item.set(\pitch, new);
			}
		})
};

//set lfo depth
~setModDepth = {
	arg val;

	~modWheel = (val / 127 * 99).asInteger;

	~headno.set(\pitchCons, ~dx7_voice_pms_to_semitones[~vr[138]] * (~modWheel / 99));
	~headno.set(\lfo_amd, ~dx7_voice_amd_to_ol_adjustment[~vr[136]] * (~modWheel / 99));

	~modDepthDisplay = (val / 127 * 100).asInteger;
	~refreshScreen.();
};

//set lfo frequency
~setLfoSpeed = {
	arg val;

	~lfoSpeed = val;

	~headno.set(\lfo_speed, ~lfoSpeed);

	~refreshScreen.();
};

//Save file management. When a preset is saved, the whole list is re-written to file dx7_state
//Load only happens when the patch fires up. Save happens whenever something is saved or deleted
~saveToFile = {
	var presetFile, state = "";

	presetFile = File.open(~presetPath,"w");

		~savedPresets.do({
			arg item;
			state = state ++ item ++ "\n"
		});

		postln("writing save file: " ++ ~savedPresets);
		presetFile.write(state);
		presetFile.close;
};

~loadFromFile = {
	if(File.exists(~presetPath)){
		postln("found preset file, loading saved presets");
		~savedPresets = FileReader.read(~presetPath);
		if(~savedPresets==nil){
			~savedPresets = [];
		}{
			~savedPresets.do{
				arg item, i;
					~savedPresets[i] = item[0].asInteger;
			}
		}
	}{
		postln("no preset file found");
		~savedPresets = [];
	};

	~savedPresets.postln;
};

~resetVoices = {
	~voiceIndex = 0;
	~noteOrder.do{
		arg item, i;
		if(item !== nil){
			~silence.(item).r.play;
		}
	};
	~noteArrayDX7 = Array.newClear(128);
	~noteOrder = Array.new(24);
};

~silence = {
	arg synth;
	var func;
	func = {
		synth.set(\totVol,-40);
		wait(0.1);
		synth.free;
	};
	func;
}
