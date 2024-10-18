//DEFS!!!

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
