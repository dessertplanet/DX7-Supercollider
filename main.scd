//Load file with painstakingly measured envelopes and conversions from Ege Gonul
"/tmp/patch/magic.scd".load;

//Load file with additional functions
"/tmp/patch/lib.scd".load;

//Load file with SynthDefs for making sounds
"/tmp/patch/sound.scd".load;

~graphics.(\Clear);

m.sendMsg("/oled/line/1", "DX7-Supercollider:");
m.sendMsg("/oled/line/2","loading 16384 presets");

~presetMeta = CSVFileReader.read("/tmp/patch/DX7-presets2.csv",true);

~presets = FileReader.read("/tmp/patch/DX7.afx");

~presetPath = "/tmp/patch/dx7_state";

~rawKnobs = Array.newClear(6);
~organelleKeyVelocity = 100;
~sustain = false;
~sustainedNotes = Set.new(128);
~keysDown = Set.new(128);
~initialPreset= 1;
~currentPreset = ~initialPreset;
~nextPreset = ~initialPreset;
~nextBank = ~presetMeta[~initialPreset][1];
~nextBankIndex = (~initialPreset / 512).floor + (~initialPreset % 512);
~nextSubIndex = ~initialPreset % 32;
~auxPressed = false;
~longEncPressState = false;
~octaveTable = [-2,-1,0,1,2];
~currentOctave = 2;
~organelleTranspose = 0;
~activeMessage = false;
~currentScreen = \main;
~modDepthDisplay = 0;
~lfoSpeed = ~dx7_voice_lfo_frequency[~vr[132]];
~selected = "* ";
~saveMenuTitle = "LOAD/SAVE";
~newSaveSym = 'SAVE CURRENT';
~cancelSym = 'CANCEL';
~toDelete = nil;
~bend = 0.0;
~bendRange = 12; // range for pitch bend. +/- in semitones.
~modWheel = nil;

~selectedLine = 0;
~pageStart = 0;
~linesDisplayed= [];

//set things up

fork {
	wait(0.1);
	~setPreset.(~initialPreset);
	~drawKeyboard.();
	postln("Initial preset loaded");

	m.sendMsg("/enablepatchsub", 1);
	~loadFromFile.();
	if(~savedPresets[~savedPresets.size-1]!=nil){
		~nextPreset = ~savedPresets[~savedPresets.size-1];
		~setPreset.(~savedPresets[~savedPresets.size-1])
	};
	~graphics.(\Clear);
	~refreshScreen.();	
};


//define functions- these are mostly called by OSCdefs and MIDIdefs in interface.scd

~noteParser = { arg note, vel;
	1.do { arg yxx;
		if(vel > 0,
			{
				//150.do({ arg c; ("cc#" ++ c.asString ++ " = " ++ ~vr[c]).postln}); //general cc printer, rates are not inverted.
				if(~noteArrayDX7[note] !== nil,~noteArrayDX7[note].free);

				if(~vr[137] == 1, {//lfo sync controller
					if(~betass == 1,   {
						~headno.free;
					});
					~betass = 1;
					~headno = Synth.before(~groupDX7, \InfEfx, ~defjamHead0.());
				},
				{
					if(~betass == 0,   {
						~betass = 1;
						~headno = Synth.before(~groupDX7, \InfEfx, ~defjamHead0.())
					},
					{
						~headno.set(~defjamHead0.())
					});
				});
				~noteArrayDX7[note] = Synth(\DX7 ,~defme.value(note, vel),~groupDX7);
				//~noteArrayDX7[note] = Synth(\DX7 ,~defme.value(note, vel), ~groupDX7); //orjburayi addtotail diye degistirdin

			},
			{
				~noteArrayDX7[note].set(\gate,0);
				~noteArrayDX7[note] = nil;

		})
	}
};


//Unpack preset information
f = { arg x, y ,z; //y value, z cc no
	if(x == 3,
		{ ~vr[y] = z },
		{ ~vr[y + 128] = z }
	)
};

//Reload the main UI
~refreshScreen = {
		~nextBank = ~presetMeta[~nextPreset][1];
		m.sendMsg("/oled/line/1",(~selected ++ ~presetMeta[~nextPreset][3]).padRight(15) ++ ("#" ++ ~nextPreset).asString.padLeft(6));
		m.sendMsg("/oled/line/2", "bank " ++ ~nextBank.padRight(9));
		if(~auxPressed == false){
			m.sendMsg("/oled/line/3", "velocity " ++ ~organelleKeyVelocity);
			m.sendMsg("/oled/line/4", "octave " ++ ~octaveTable[~currentOctave]);
			m.sendMsg("/oled/line/5", "lfo depth " ++ ~modDepthDisplay ++ "%")
		}{
			m.sendMsg("/oled/line/3", "bend " ++ (~bend * 100).asStringPrec(3) ++ "%");
			m.sendMsg("/oled/line/4", "bend range " ++ ~bendRange);
			m.sendMsg("/oled/line/5", "lfo speed " ++ ~lfoSpeed.asStringPrec(3) ++ " Hz")
		};
};

//When focus has changed, update context to reflect our new position
~updateMetadata = {
	~nextBank = ~presetMeta[~nextPreset][1];
	~nextBankIndex = (~nextPreset / 511).floor + (~nextPreset % 511);
	~nextSubIndex = ~nextPreset % 31;
	~modDepthDisplay = (~vr[135] / 99 * 100).asInteger;
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
~longEncPress = Routine {
	~longEncPressState = false;
	wait(2);
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

~bendExistingNotes = {
	~noteArrayDX7.do({
			arg item, i;

			if(item != nil){
				var new;
				new = (i + ~vr[131] - 24 + (~bend * ~bendRange)).midicps;
				item.set(\pitch, new);
			}
		})
};

~setModDepth = {
	arg val;

	~modWheel = (val / 127 * 99).asInteger;

	~headno.set(\pitchCons, ~dx7_voice_pms_to_semitones[~vr[138]] * (~modWheel / 99));
	~headno.set(\lfo_amd, ~dx7_voice_amd_to_ol_adjustment[~vr[136]] * (~modWheel / 99));

	~modDepthDisplay = (val / 127 * 100).asInteger;
	~refreshScreen.();
};

~setLfoSpeed = {
	arg val;

	~lfoSpeed = val;

	~headno.set(\lfo_speed, ~lfoSpeed);

	~refreshScreen.();
};

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

OSCdef( \knobs,
	{
		arg msg, time, addr, recvPort;

	
		if (~rawKnobs[0] != nil){
			if ((msg[1] - ~rawKnobs[0]).abs > 2){
				~nextSubIndex = (msg[1] / 1023 * 31).asInteger;
				~nextBankIndex = (msg[1] / 1023 * 511).asInteger;

				~nextPreset = ~nextBankIndex * 32 + ~nextSubIndex;
				~nextBank = ~presetMeta[~nextPreset][1];

				if(~nextPreset == ~currentPreset){
					~selected = "* ";
				}{
					~selected = "";
				}
			}
		};

		if(~auxPressed == false){

			if ((msg[2] != ~rawKnobs[1]) && (~rawKnobs[1] != nil), {
				~organelleKeyVelocity = (msg[2] / 1023 * 126 + 1).asInteger;
			});

			if ((msg[3] != ~rawKnobs[2]) && (~rawKnobs[2] != nil), {
				~currentOctave = (msg[3] / 1023 * 4).asInteger;
			});

			if ((msg[4] != ~rawKnobs[3]) && (~rawKnobs[3] != nil), {
				~setModDepth.(msg[4] / 1023 * 127);
			});
		}{
			if ((msg[2] != ~rawKnobs[1]) && (~rawKnobs[1] != nil), {
				~bend = msg[2] / 1023 * 2 - 1;
				~bendExistingNotes.();
			});

			if ((msg[3] != ~rawKnobs[2]) && (~rawKnobs[2] != nil), {
				~bendRange = (msg[3] / 1023 * 11 + 1).asInteger;
			});

			if ((msg[4] != ~rawKnobs[3]) && (~rawKnobs[3] != nil), {
				//LFO SPEED
				~setLfoSpeed.(msg[4].linexp(0.0,1023.0,0.05,50.0))
			});
		};


		5.do {
			arg i;
			~rawKnobs[i] = msg[i + 1];
		};


		~refreshScreen.();
	},
	"/knobs",
	recvPort:4000
);

OSCdef( \RoutePhysicalKeys,
	{

		arg msg, time, addr, recvPort;
		var src = \phys;


		if(msg[1] == 0){
			~self.sendMsg("/aux", msg[2]);
		}{

			if (msg[2] > 0){
					
				~self.sendMsg("/note", msg[1] + 59, ~organelleKeyVelocity,src );
				
			}{
				~self.sendMsg("/note", msg[1] + 59, 0,src);
			}
		};
	},
	"/key",
	recvPort:4000
);

OSCdef( \enc,
	{
		arg msg, time, addr, recvPort;
		var delta;

		if(~auxPressed){
			delta = 32;
		}{
			delta = 1;
		};

		switch(~currentScreen)
		{\main}{

			if(msg[1]>0) {
				if(~nextPreset<(16384-delta)){
					~nextPreset = ~nextPreset + delta;
				}{~nextPreset = 16383}
			}{
				if(~nextPreset>=delta){
					~nextPreset = ~nextPreset - delta;
				}{~nextPreset = 0}
			};

			~nextBank = ~presetMeta[~nextPreset][1];

			if(~nextPreset == ~currentPreset){
				~selected = "* ";
			}{
				~selected = "";
			};

			~refreshScreen.();
		}
		{\save}{
			//SAVE MENU ENCCCC
			~incrementMenu.(~saveMenuTitle, ~savedPresets, msg[1], ~newSaveSym, ~cancelSym)
		}
		{\confirm}{
			//confirm menu enc
			~incrementMenu.("DELETE SAVE?",[],msg[1],'NO','YES');
		}
	},
	"/encoder/turn",
	recvPort:4000
);

OSCdef( \encbut,
	{
		arg msg, time, addr, recvPort;
		//press encoder to pop patch menu

		if(msg[1]>0){
			//enc button down
			
			~longEncPress.reset.play;
			
		}{
			//enc button up
			~longEncPress.stop;
			if(~longEncPressState == false){
				switch(~currentScreen)
				{\main}{
					if(~auxPressed == false){
						~setPreset.(~nextPreset);
					}{
						~randomPatch.();
					}
				}
				{
					//SAVE MENU ENCBUT UP
					~currentScreen = \main;

					~menuSelect.(~linesDisplayed[~selectedLine]);
				};
				~longEncPressState = false;
			}
		}
	},
	"/encoder/button",
	recvPort:4000
);



OSCdef( \aux,
	{
		arg msg, time, addr, recvPort;

		if(msg[1]>0){
			~auxPressed = true;
			m.sendMsg("/led", 4);
		}{
			~bend = 0.0;
			~bendExistingNotes.();

			~auxPressed = false;

			m.sendMsg("/led", 0);
		};

		if(~currentScreen == \main){
			~refreshScreen.();
		}
	},
	"/aux",
	recvPort:57120
);

OSCdef( \fs,
	{
		arg msg, time, addr, recvPort;

		if(msg[1]>0){
			~self.sendMsg("/sustain", 0)
		}{
			~self.sendMsg("/sustain", 1)
		};
	},
	"/fs",
	recvPort:4000
);

MIDIdef.cc(\sustainCC,
	{
		arg ... msg;

		if (msg[0]>125){
			~self.sendMsg("/sustain", 1);
		};
		if(msg[0]<5){
			~self.sendMsg("/sustain", 0);
		}

	},
	64 //SUSTAIN PEDAL CC VALUE;
);

OSCdef( \sustain,
	{
		arg msg, time, addr, recvPort;

		if (msg[1]>0){
			~sustainedNotes = Set.newFrom(~keysDown);
			~sustain = true;

		}{
			~sustain = false;
			~sustainedNotes.do{
				arg item;
				if(~keysDown.includes(item)== false){
					~noteParser.(item, 0);
				}
			};
			~sustainedNotes = Set.new;
		};

	},
	"/sustain",
	recvPort:57120
);

OSCdef( \note,
	{
		arg msg, time, addr, recvPort;


		if(msg[2]>0){
			if(msg[3] == \phys){
				~organelleTranspose = ~octaveTable[~currentOctave];
			}{
				~organelleTranspose = 0;
			};

			~keysDown.add(msg[1]);
			if(~sustain){~sustainedNotes.add(msg[1])};
			~noteParser.(msg[1],msg[2]);
		}{
			~keysDown.remove(msg[1]);
			if (~sustainedNotes.includes(msg[1])==false){
				~noteParser.(msg[1],msg[2]);
			}
		};

	},
	"/note",
	recvPort:57120
);

MIDIdef.bend(\pitchbend,
	{
		arg raw;

		~bend = (raw - 8192).clip(-8191,8191) / 8191;
		if(~auxPressed){
			~refreshScreen.();
		};

		//bend is calculated to be high resolution pitch bend multiplier from -1.0 to 1.0, 0 at rest.


		~bendExistingNotes.();

	}
);



MIDIdef.cc(\modDepth,
	{
		arg val;

		~setModDepth.(val);
	},
	1 //MODWHEEL CC
);
