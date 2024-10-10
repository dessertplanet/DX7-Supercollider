
//Load file to declare variables
"/tmp/patch/init.scd".load;

//Load file with additional functions
"/tmp/patch/lib.scd".load;

~graphics.(\Clear);

m.sendMsg("/oled/line/1", "DX7-Supercollider:");
m.sendMsg("/oled/line/2","loading 16384 presets");

~presetMeta = CSVFileReader.read("/tmp/patch/DX7-presets2.csv",true);

~presets = FileReader.read("/tmp/patch/DX7.afx");

~presetPath = "/tmp/patch/dx7_state";

/*
buffers and busses
*/

~busMeAmp = Bus.audio(s, 1);
~busMePitch = Bus.audio(s, 1);

///MAIN FUNCTIONS

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


f = { arg x, y ,z; //y value, z cc no
	if(x == 3,
		{ ~vr[y] = z },
		{ ~vr[y + 128] = z }
	)
};

~sustain = false;
~sustainedNotes = Set.new(128);
~keysDown = Set.new(128);
~initialPreset= 0;
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
~saveMenu = false;
~confirmMenu = false;
~modDepthDisplay = 0;
~lfoSpeed = ~dx7_voice_lfo_frequency[~vr[132]];
~selected = "* ";

~bend = 0.0;
~bendRange = 12; // range for pitch bend. +/- in semitones.
~modWheel = nil;


~updateMetadata = {
	~nextBank = ~presetMeta[~nextPreset][1];
	~nextBankIndex = (~nextPreset / 511).floor + (~nextPreset % 511);
	~nextSubIndex = ~nextPreset % 31;
};

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
	~modDepthDisplay = (~vr[135] / 99 * 100).asInteger;
	~lfo_speed = ~dx7_voice_lfo_frequency[~vr[132]];
	~updateMetadata.();
	~refreshScreen.();
};

~longEncPress = Routine {
	~longEncPressState = false;
	wait(1);
	~longEncPressState = true;		
	m.sendMsg("/gohome")
};

///INTERFACE

~rawKnobs = Array.newClear(6);

~refreshScreen = {
		~nextBank = ~presetMeta[~nextPreset][1];
		m.sendMsg("/oled/line/1",(~selected ++ ~presetMeta[~nextPreset][3]).padRight(15) ++ ("#" ++ (~nextPreset.asInteger + 1)).asString.padLeft(6));
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
			if(~auxPressed){
				~randomPatch.();
			}{
				~longEncPress.reset.play;
			}
		}{
			//enc button up
			~longEncPress.stop;
			if(~longEncPressState == false){
				~setPreset.(~nextPreset);
				if(~nextPreset == ~currentPreset){
					~selected = "* ";
				}{
					~selected = "";
				};
				~refreshScreen.();
			};
			~longEncPressState = false;
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

		~refreshScreen.();
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

MIDIdef.cc(\modDepth,
	{
		arg val;

		~setModDepth.(val);
	},
	1 //MODWHEEL CC
);

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

/////SYNTHDEFS

SynthDef(\InfEfx, {
	arg outBus=0, gate,
	lfoGet1 = 0, lfoGet2=1,
	lfo_speed, lfo_wave, lfo_phase,
	lfo_delay, lfo_amd, pitchCons,envTrig, tameC, tameM;
	//
	var lfo, pitchenv, output, randomlfo, multiPitch, lfoAmp;
	//
	FreeSelf.kr(gate);
	lfo = Osc.ar(lfo_wave,lfo_speed, lfo_phase, 0.5 * lfoGet2, 0.5 * lfoGet2) + LFNoise0.ar(lfo_speed, 0.5 * lfoGet1, 0.5 * lfoGet1);
	lfo = lfo * EnvGen.ar(Env.asr(lfo_delay,releaseTime:0.01, curve: -5),envTrig);
	multiPitch = LinLin.ar(lfo, 0, 1, (pitchCons.lag2.neg.midiratio * tameM) + tameC, pitchCons.lag2.midiratio);
	lfoAmp = LinLin.ar(lfo, 0, 1, lfo_amd.lag2 * (-3/4), 0);

	//Poll.ar(Impulse.ar(10), lfoAmp);
	//PHASE PART++
	//tri en tepeden basliyor
	//sawdown en asagidan baslio
	//pms 4, pmd 40, +-1 semitone yapiyor
	//sawup en yukardan
	//square en asaidan
	//sine sifirdan baslio

	Out.ar(~busMePitch, multiPitch);
	Out.ar(~busMeAmp, lfoAmp)
}).add;


SynthDef(\DX7, {
	arg outBus=0, pitch, gate = 1,
	envPL0, envPL1, envPL2, envPL3, envPL4, envPR0, envPR1, envPR2, envPR3,
	coars1, fine_1,	coars2, fine_2,	coars3, fine_3,	coars4, fine_4,	coars5, fine_5,	coars6, fine_6,
	env1L0, env1L1, env1L2, env1L3, env1L4, env1R0, env1R1, env1R2, env1R3, env1C0, env1C1, env1C2, env1C3,
	env2L0, env2L1, env2L2, env2L3, env2L4, env2R0, env2R1, env2R2, env2R3, env2C0, env2C1, env2C2, env2C3,
	env3L0, env3L1, env3L2, env3L3, env3L4, env3R0, env3R1, env3R2, env3R3, env3C0, env3C1, env3C2, env3C3,
	env4L0, env4L1, env4L2, env4L3, env4L4, env4R0, env4R1, env4R2, env4R3, env4C0, env4C1, env4C2, env4C3,
	env5L0, env5L1, env5L2, env5L3, env5L4, env5R0, env5R1, env5R2, env5R3, env5C0, env5C1, env5C2, env5C3,
	env6L0, env6L1, env6L2, env6L3, env6L4, env6R0, env6R1, env6R2, env6R3, env6C0, env6C1, env6C2, env6C3,
	noteBlok1, noteBlok2, noteBlok3, noteBlok4, noteBlok5, noteBlok6,
	dn0, dn1, dn2, dn3, dn4, dn5,
	dn6, dn7, dn8, dn9, dn10, dn11,
	dn12, dn13, dn14, dn15, dn16, dn17,
	dn18, dn19, dn20, dn21, dn22, dn23,
	dn24, dn25, dn26, dn27, dn28, dn29,
	dn30, dn31, dn32, dn33, dn34, dn35,
	dn36, dn37, dn38, dn39, dn40, dn41,
	detun1, detun2, detun3, detun4, detun5, detun6,
	modSens1, modSens2, modSens3, modSens4, modSens5, modSens6, outMult,
	//below is the general,
	osc_sync, transpose,
	gate1=1, gate1Rel = 1, amp=0.1, totVol;
	var ctls, mods, chans, out, kilnod,
	envAmp1, envEnv1, envAmp2, envEnv2, envAmp3, envEnv3 ,envAmp4, envEnv4, envAmp5, envEnv5, envAmp6, envEnv6, dca, envAmpP, envEnvP;
	//
	envEnvP = Env.new([ envPL0, envPL1, envPL2, envPL3, envPL4], [envPR0,envPR1,envPR2,envPR3], 0, 3);
	envAmpP = EnvGen.kr(envEnvP, gate, doneAction:0);
	envEnv1 = Env.new([(-1 * env1L0).dbamp ,(-1 * env1L1).dbamp, (-1 * env1L2).dbamp, (-1 * env1L3).dbamp, (-1 * env1L4).dbamp], [env1R0,env1R1,env1R2,env1R3], [env1C0,env1C1,env1C2,env1C3], 3);
	envAmp1 = EnvGen.kr(envEnv1, gate, doneAction:0 );
	envEnv2 = Env.new([(-1 * env2L0).dbamp ,(-1 * env2L1).dbamp, (-1 * env2L2).dbamp, (-1 * env2L3).dbamp, (-1 * env2L4).dbamp], [env2R0,env2R1,env2R2,env2R3], [env2C0,env2C1,env2C2,env2C3], 3);
	envAmp2 = EnvGen.kr(envEnv2, gate, doneAction:0 );
	envEnv3 = Env.new([(-1 * env3L0).dbamp ,(-1 * env3L1).dbamp, (-1 * env3L2).dbamp, (-1 * env3L3).dbamp, (-1 * env3L4).dbamp], [env3R0,env3R1,env3R2,env3R3], [env3C0,env3C1,env3C2,env3C3], 3);
	envAmp3 = EnvGen.kr(envEnv3, gate, doneAction:0 );
	envEnv4 = Env.new([(-1 * env4L0).dbamp ,(-1 * env4L1).dbamp, (-1 * env4L2).dbamp, (-1 * env4L3).dbamp, (-1 * env4L4).dbamp], [env4R0,env4R1,env4R2,env4R3], [env4C0,env4C1,env4C2,env4C3], 3);
	envAmp4 = EnvGen.kr(envEnv4, gate, doneAction:0 );
	envEnv5 = Env.new([(-1 * env5L0).dbamp ,(-1 * env5L1).dbamp, (-1 * env5L2).dbamp, (-1 * env5L3).dbamp, (-1 * env5L4).dbamp], [env5R0,env5R1,env5R2,env5R3], [env5C0,env5C1,env5C2,env5C3], 3);
	envAmp5 = EnvGen.kr(envEnv5, gate, doneAction:0 );
	envEnv6 = Env.new([(-1 * env6L0).dbamp ,(-1 * env6L1).dbamp, (-1 * env6L2).dbamp, (-1 * env6L3).dbamp, (-1 * env6L4).dbamp], [env6R0,env6R1,env6R2,env6R3], [env6C0,env6C1,env6C2,env6C3], 3);
	envAmp6 = EnvGen.kr(envEnv6, gate, doneAction:0 );
	//	envEnv1.test.plot;
	ctls = [
		[coars1 * fine_1 * ((pitch.lag2 * noteBlok1) + ((detun1-7)/32)) * (envAmpP.midiratio) * Lag2.ar(In.ar(~busMePitch),0.01),  Rand(0,2pi) * osc_sync, envAmp1 * (Lag2.ar(In.ar(~busMeAmp),0.01) * (modSens1/3)).dbamp],
		[coars2 * fine_2 * ((pitch.lag2  * noteBlok2) + ((detun2-7)/32)) * (envAmpP.midiratio) * Lag2.ar(In.ar(~busMePitch),0.01),  Rand(0,2pi) * osc_sync, envAmp2 * (Lag2.ar(In.ar(~busMeAmp),0.01) * (modSens2/3)).dbamp],
		[coars3 * fine_3 * ((pitch.lag2 * noteBlok3) + ((detun3-7)/32)) * (envAmpP.midiratio) * Lag2.ar(In.ar(~busMePitch),0.01),  Rand(0,2pi) * osc_sync, envAmp3 * (Lag2.ar(In.ar(~busMeAmp),0.01) * (modSens3/3)).dbamp],
		[coars4 * fine_4 * ((pitch.lag2  * noteBlok4) + ((detun4-7)/32)) * (envAmpP.midiratio) * Lag2.ar(In.ar(~busMePitch),0.01),  Rand(0,2pi) * osc_sync, envAmp4 * (Lag2.ar(In.ar(~busMeAmp),0.01) * (modSens4/3)).dbamp],
		[coars5 * fine_5 * ((pitch.lag2  * noteBlok5) + ((detun5-7)/32)) * (envAmpP.midiratio) * Lag2.ar(In.ar(~busMePitch),0.01),  Rand(0,2pi) * osc_sync, envAmp5 * (Lag2.ar(In.ar(~busMeAmp),0.01) * (modSens5/3)).dbamp],
		[coars6 * fine_6 * ((pitch.lag2  * noteBlok6) + ((detun6-7)/32)) * (envAmpP.midiratio) * Lag2.ar(In.ar(~busMePitch),0.01),  Rand(0,2pi) * osc_sync, envAmp6 * (Lag2.ar(In.ar(~busMeAmp),0.01) * (modSens6/3)).dbamp]
	];
	mods = [
		[dn0, dn1, dn2, dn3, dn4, dn5],
		[dn6, dn7, dn8, dn9, dn10, dn11],
		[dn12, dn13, dn14, dn15, dn16, dn17],
		[dn18, dn19, dn20, dn21, dn22, dn23],
		[dn24, dn25, dn26, dn27, dn28, dn29],
		[dn30, dn31, dn32, dn33, dn34, dn35]
	];
	chans = [0, 1, 2, 3, 4, 5];
	out = FM7.ar(ctls, mods).slice(chans) * -12.dbamp;
	out = Mix.new([
		(out[0] * 1 * dn36),
		(out[1] * 1 * dn37),
		(out[2] * 1 * dn38),
		(out[3] * 1 * dn39),
		(out[4] * 1 * dn40),
		(out[5] * 1 * dn41),
	]);
	FreeSelfWhenDone.kr(Line.kr(0, 1, 20));
	kilnod = DetectSilence.ar(out, 0.01, 0.2, doneAction:2);
	//out = out * Lag2.ar(In.ar(busMe),0.01);
	//Out.ar([0,1], 0.5 * In.ar(busMe)); //deneme
	out = out / outMult;
	//DetectSilence.ar(out, 0.01, 0.2,doneAction:2);
	//out = out * ((totVol -15).dbamp);
	Out.ar(outBus, out.dup); //orj

}).add;

fork {
	wait(0.1);
	~setPreset.(~initialPreset);
	~drawKeyboard.();
	postln("Initial preset loaded");
	if(File.exists(~presetPath)){
		postln("found preset file, loading saved presets");
		~savedPresets = FileReader.read(~presetPath);
		~savedPresets.do({
			arg item, i;
			if(item[0] == "nil"){
				~savedPresets[i] = nil;
			}{
				~savedPresets[i] = item[0].asInteger;
			}
		});

	}{
		~savedPresets = Array.newClear(24);
	};

	m.sendMsg("/enablepatchsub", 1);
	~graphics.(\Clear);
	~refreshScreen.();	
};


OSCdef( \save,
	{
		arg msg, time, addr, recvPort;
		var presetFile, state = "";

		File.mkdir("/tmp/state");

		presetFile = File.open("/tmp/state/dx7_state","w");

		~savedPresets.do({
			arg item;
			state = state ++ item ++ "\n"
		});

		presetFile.write(state);
		presetFile.close;

		},
	"/saveState",
	recvPort:4000
);
