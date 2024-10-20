/*
buffers and busses
*/

~busMeAmp = Bus.audio(s, 1);
~busMePitch = Bus.audio(s, 1);

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
		[coars1 * fine_1 * ((pitch.lag2(0.05) * noteBlok1) + ((detun1-7)/32)) * (envAmpP.midiratio) * Lag2.ar(In.ar(~busMePitch),0.01),  Rand(0,2pi) * osc_sync, envAmp1 * (Lag2.ar(In.ar(~busMeAmp),0.01) * (modSens1/3)).dbamp],
		[coars2 * fine_2 * ((pitch.lag2(0.05)  * noteBlok2) + ((detun2-7)/32)) * (envAmpP.midiratio) * Lag2.ar(In.ar(~busMePitch),0.01),  Rand(0,2pi) * osc_sync, envAmp2 * (Lag2.ar(In.ar(~busMeAmp),0.01) * (modSens2/3)).dbamp],
		[coars3 * fine_3 * ((pitch.lag2(0.05) * noteBlok3) + ((detun3-7)/32)) * (envAmpP.midiratio) * Lag2.ar(In.ar(~busMePitch),0.01),  Rand(0,2pi) * osc_sync, envAmp3 * (Lag2.ar(In.ar(~busMeAmp),0.01) * (modSens3/3)).dbamp],
		[coars4 * fine_4 * ((pitch.lag2(0.05)  * noteBlok4) + ((detun4-7)/32)) * (envAmpP.midiratio) * Lag2.ar(In.ar(~busMePitch),0.01),  Rand(0,2pi) * osc_sync, envAmp4 * (Lag2.ar(In.ar(~busMeAmp),0.01) * (modSens4/3)).dbamp],
		[coars5 * fine_5 * ((pitch.lag2(0.05)  * noteBlok5) + ((detun5-7)/32)) * (envAmpP.midiratio) * Lag2.ar(In.ar(~busMePitch),0.01),  Rand(0,2pi) * osc_sync, envAmp5 * (Lag2.ar(In.ar(~busMeAmp),0.01) * (modSens5/3)).dbamp],
		[coars6 * fine_6 * ((pitch.lag2(0.05)  * noteBlok6) + ((detun6-7)/32)) * (envAmpP.midiratio) * Lag2.ar(In.ar(~busMePitch),0.01),  Rand(0,2pi) * osc_sync, envAmp6 * (Lag2.ar(In.ar(~busMeAmp),0.01) * (modSens6/3)).dbamp]
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
	//Removing this timeout envelope since voice stealing has been implemented (this may cause presets with infinite sustain to hang forever)
	//FreeSelfWhenDone.kr(Line.kr(0, 1, 20));
	kilnod = DetectSilence.ar(out, 0.01, 0.2, doneAction:2);
	//out = out * Lag2.ar(In.ar(busMe),0.01);
	//Out.ar([0,1], 0.5 * In.ar(busMe)); //deneme
	out = out / outMult;
	//DetectSilence.ar(out, 0.01, 0.2,doneAction:2);
	//out = out * ((totVol -15).dbamp);
	Out.ar(outBus, out.dup); //orj

}).add;