//DX7-Supercollider as a patch for the Organelle M
//This patch implements every? DX7 preset known to humanity with an easy interface on Organelle
//Save your favorites, jump to random presets, sequence/control via MIDI

//Load file with painstakingly measured envelopes and conversions from Aziz Ege Gonul
"/tmp/patch/magic.scd".load;

//Load file with additional magic spells from Aziz that set up the Synth parameters
"/tmp/patch/lib.scd".load;

//Load file with SynthDefs for making sounds (These also from Ege)
"/tmp/patch/sound.scd".load;

//Show a reasonabl loading screen while we crunch on big files.
~graphics.(\Clear);

m.sendMsg("/oled/line/1", "DX7-Supercollider:");
m.sendMsg("/oled/line/2","loading 16384 presets");

//INITIAL SETUP

~presetMeta = CSVFileReader.read("/tmp/patch/DX7-presets2.csv",true);

~presets = FileReader.read("/tmp/patch/DX7.afx");


//Declare global variables

////POLYPHONY VARIABLE/////

~maxVoices=16; //1-16

///////////////////////////

~presetPath = "/tmp/patch/dx7_state"; //path to file used to save presets that the user likes
~rawKnobs = Array.newClear(6); //array for raw knob values
~organelleKeyVelocity = 100; //variable to set the velocity used when user plays a note on the organelle accordion keys
~sustain = false; //state of the sustain pedal for synth consumption. Either via MIDI or the PEDAL input on Organelle
~sustainedNotes = Set.new(128); //Keep a set of notes to sustain
~keysDown = Set.new(128); //Keep track of which keys are down. When the sustain pedal is lifted, these notes don't stop
~initialPreset= 1; //Startup preset- much waffling went into chooseing this one :)
~currentPreset = ~initialPreset; //variable for currently RUNNING preset
~nextPreset = ~initialPreset; //variable for currently SHOWN preset
~nextBank = ~presetMeta[~initialPreset][1]; //variable for bank metadata about currently SHOWN preset
~nextBankIndex = (~initialPreset / 512).floor + (~initialPreset % 512); // used in math for providing coarse preset knob
~nextSubIndex = ~initialPreset % 32; // used in math for providing coarse preset knob
~auxPressed = false; //state of aux button on Organelle
~longEncPressState = false; //state of longpress action for Organelle encoder button
~octaveTable = [-2,-1,0,1,2]; //table of available octaves for organelle accordion keys
~currentOctave = 2; // INDEX selected from ~octaveTable.
~organelleTranspose = 0; //Transpose in semitones
~currentScreen = \main; // variable to keep track of what is on the screen- used for governing controls
~modDepthDisplay = 0; //mod depth to display in a friendly manner
~lfoSpeed = ~dx7_voice_lfo_frequency[~vr[132]]; //master LFO frequency in Hz
~selected = "* "; //string used to indicate whether the currently SHOWN preset is also RUNNING, in the main screen
~saveMenuTitle = "LOAD/SAVE"; //Title string for save menu
~newSaveSym = 'SAVE CURRENT'; //symbols for use in text menu
~cancelSym = 'CANCEL'; // " "
~toDelete = nil; //keep track of saved preset to be deleted
~bend = 0.0; // pitchbend value for synth consumption. input from organelle parameter or MIDI
~bendRange = 5; // range for pitch bend. +/- in semitones.
~modWheel = nil; // Modwheel param - input from MIDI or Organelle lfo depth parameter
~selectedLine = 0; // selected line index in text menus
~pageStart = 0; // paging index for text menus
~linesDisplayed= []; //array of strings for text menus

~noteOrder = Array.new(24);
~voiceIndex = 0;

//Use a routine to set things up, waiting 0.1 seconds before doing the other steps in order to avoid issues with 
//supercollider starting up.

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

//FUNCTIONS

//Only one function in main- the one that manages synth voices, the rest are all in lib.scd

~noteParser = { arg note, vel;
	1.do { arg yxx;
		if(vel > 0,
			{
				//150.do({ arg c; ("cc#" ++ c.asString ++ " = " ++ ~vr[c]).postln}); //general cc printer, rates are not inverted.
				if(~noteArrayDX7[note] !== nil){
					~noteArrayDX7[note].free;
					~voiceIndex = ~voiceIndex - 1;
				};

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

				if(~voiceIndex>(~maxVoices-1)){
					~noteOrder.removeAt(0).free;
					~voiceIndex = ~voiceIndex - 1;
				};
				
				~noteArrayDX7[note] = Synth(\DX7 ,~defme.value(note, vel),~groupDX7);
				~noteOrder = ~noteOrder.add(Synth.basicNew(\DX7,s,~noteArrayDX7[note].nodeID));
				~voiceIndex = ~voiceIndex + 1;
			},
			{
				~noteArrayDX7[note].set(\gate,0);
				~noteArrayDX7[note] = nil;
				//s.numSynths.postln;

		})
	}
};


//DEFS
//The rest of main is a set of OSC and MIDI defs that are called when they receive input either from Organelle hardware or 
//via MIDI

//Organelle knob input
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
				if(~modWheel!==nil, ~setModDepth.(msg[4] / 1023 * 127));
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

//input from Organelle physical accordion keys
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

// input from Organelle encoder msg[1] contains direction. 0=right, 1=left
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

//Organelle encoder button behavior.
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

//Organelle aux button (left of the keyboard)
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

//Organelle PEDAL input
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

//MIDI CC for sustain pedal is caught here
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

//input from MIDI and PEDAL are merged here to establish sustain state
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

//Called whenever a note is either received via MIDI or played via Organelle keyboard
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

//Catch MIDI pitchbend input
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

//Catch MIDI modwheel input
MIDIdef.cc(\modDepth,
	{
		arg val;

		~setModDepth.(val);
	},
	1 //MODWHEEL CC
);
