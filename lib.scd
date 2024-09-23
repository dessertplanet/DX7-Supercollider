//functions for use in main

~scale_vrv = { arg dummy, scaling_curve, scaling_depth, vrv;
	switch(scaling_curve,
		0, {(vrv - ((dummy / 45) * scaling_depth).asInteger)}, // -lin
		1, {(vrv - (((dummy - 72) / 13.5).exp * scaling_depth).asInteger)}, // -exp
		2, {(vrv + (((dummy - 72) / 13.5).exp * scaling_depth).asInteger)}, // +exp
		3, {(vrv + ((dummy / 45) * scaling_depth).asInteger)} // +lin
        )
};

~envCal = { arg // Area of hardcore envelope calculation function.
	vr1, //Level Current
	vr2, //Level Next
	vrx, //Speed
	vrv, //Volume
	velo,//Velocity
	velSens,
	level_scaling_bkpoint,
	level_scaling_l_depth,
	level_scaling_r_depth,
	level_scaling_l_curve,
	level_scaling_r_curve,
	transposed_note,
	rate_scaling,
	amp_mod_sens;//not sure if i put this globa
	var dummy, velFin, env_L0, env_L1, env_R0, vrvDec, endR0, dbStr, dbEnd;
	if (((transposed_note < (level_scaling_bkpoint + 21)) && (level_scaling_l_depth > 0)), {
		dummy = (level_scaling_bkpoint - (((transposed_note + 2) / 3).asInteger * 3) + 21);
		vrv = ~scale_vrv.(dummy, level_scaling_l_curve, level_scaling_l_depth, vrv);
	});
	if (((transposed_note > (level_scaling_bkpoint + 21)) && (level_scaling_r_depth > 0)), {
		dummy = (((transposed_note + 2) / 3).asInteger * 3) - level_scaling_bkpoint - 21;
		vrv = ~scale_vrv.(dummy, level_scaling_r_curve, level_scaling_r_depth, vrv);
	});
	rate_scaling = ((rate_scaling * (transposed_note - 21) / (126.0 - 21.0) * 127.0 / 128.0 * 6.5 )- 0.5).asInteger;
	vrx = (rate_scaling + vrx).clip(0,99);
	vrv = vrv.clip(0,99);
	velFin = (~velTable[velo] * velSens);
	//~~vrv = ((~~vrv+(~~velTable[~velo] * ~velSens)).clip(0,127));//old version
	env_L0 = case
	{(100 > vr1) && (vr1 > 20)}   { (64 * (14 + ((vr1) >> 1)))}
	{(21 > vr1)  && (vr1 > 16)}   { (64 * (4 + vr1))}
	{(17 > vr1)  && (vr1 > 5)}    { (64 * (5 + vr1))}
	{(6 > vr1)   && (vr1 > (-1))} { (64 * (2 * vr1))}
	{99 < vr1}  { (64 * (14 + (99 >> 1)))};
	env_L1 = case
	{(100 > vr2) && (vr2 > 20)}   { (64 * (14 + ((vr2) >> 1)))}
	{(21 > vr2)  && (vr2 > 16)}   { (64 * (4 + vr2))}
	{(17 > vr2)  && (vr2 > 5)}    { (64 * (5 + vr2))}
	{(6 > vr2)   && (vr2 > (-1))} { (64 * (2 * vr2 + 5))}
	{99 < vr2}  { (64 * (14 + (99 >> 1)))};

	vrvDec = ((vrv+ velFin).clip(0,127));//is this correct, limit 99?
	env_R0 = (0.2819*(2.pow((vrx)*0.16))); // attack ise -1? decay ise + 0.5?
	vrvDec = case
	{(128 > vrvDec) && (vrvDec > 20)}   {(32 * (vrvDec + 28))}
	{(21 > vrvDec)  && (vrvDec > 16)}   {(32 * (vrvDec + 17))}
	{(17 > vrvDec)  && (vrvDec > 5)}    {(32 * (vrvDec + 11))}
	{(6 > vrvDec)   && (vrvDec > (-1))} {(32 * (vrvDec))};
	dbStr = ((99 - (vr1 + vrv - 99 + velFin)) / 1.33333333);

	dbEnd = ((99 - (vr2 + vrv - 99 + velFin)) / 1.333333);
	endR0 = if( (env_L0 > env_L1),
		{
			((((env_L0 + vrvDec - 4064).clip(1,9000) - (env_L1 + vrvDec - 4064).clip(1,9000))* 0.0235) / env_R0)
		},

		{
			(~voice_eg_rate_rise_duration[vrx] * (~dx7_voice_eg_rate_rise_percent[((((vr2 * vrv) / 99) + velFin).clip(0,99)).asInteger] - ~dx7_voice_eg_rate_rise_percent[((((vr1 * vrv) / 99) + velFin).clip(0,99)).asInteger]))
		}
	);
	//[dbStr, dbEnd, endR0].postln;
	[dbStr, dbEnd, endR0];

};

~defjamHead1 = {
	var abc = [], algo, fdbIndNo = Array.fill(42, 1);
			algo = (~vr[128]).clip(0,31);
			abc = [\outMult, ~outOscVol[~vr[128]]];
			//abc.postln;
			fdbIndNo[~feedbackSel[algo]] =  ~feedbackIndex[(~vr[129])] * (~vr[129]);
			42.do(
				{
					arg x;
					abc = abc ++ [\dn ++ x, (~wf[algo,x] * fdbIndNo[x])];
			});
			abc;
};

~defjamHead0 = {
	var cba = [], lfoDepth, lfoGet1, lfoGet2;
			if(~vr[133] == 5, {lfoGet1=1; lfoGet2 =0}, {lfoGet1 = 0; lfoGet2 =1 });
			lfoDepth = (~dx7_voice_pms_to_semitones[~vr[138]]) * (~vr[135] / 99);
			//lfoDepth.postln;
			cba = [
				\lfo_speed, ~dx7_voice_lfo_frequency[~vr[132]],
				\lfo_wave, (~waveform_selector[~vr[133]]).bufnum, //random signal icinde yap,
				\lfo_phase, ~phase_selector[~vr[133]],
				\envTrig, 0,
				\envTrig, 1,
				\pitchCons, lfoDepth,
				/* sifirdan baslasin because we need to reset the LFO phase */
				\lfoGet1, lfoGet1,
				\lfoGet2, lfoGet2,
				\tameM, ~pitchTameMult[~vr[133]],
				\tameC, ~pitchTameConst[~vr[133]],
				\lfo_delay, ((~vr[134]).clip(0,99)).linlin(0,99,0.01,3.4),//lineer ramp ile carp
				\lfo_amd, ~dx7_voice_amd_to_ol_adjustment[~vr[136]]
			];
			//cba.postln;
			cba;
			//a y.removeAt(1); ['a', 'b', 'c'].do({ arg item, i; [i, item].postln; });
};


~defPitchEnv = { arg rate_1, rate_2, rate_3, rate_4, level_1, level_2, level_3, level_4;
	var endy,
	envPL0, envPL1, envPL2, envPL3, envPL4, envPR0, envPR1, envPR2,envPR3;
	//functions start here
	envPL0 = ~dx7_voice_pitch_level_to_shift[level_4];
	envPL1 = ~dx7_voice_pitch_level_to_shift[level_1];
	envPL2 = ~dx7_voice_pitch_level_to_shift[level_2];
	envPL3 = ~dx7_voice_pitch_level_to_shift[level_3];
	envPL4 = ~dx7_voice_pitch_level_to_shift[level_4];
	envPR0 = exp((rate_1 - 70.337897) / -25.580953) * abs((envPL1 - envPL0) / 96.0) * 2.45;
	envPR1 = exp((rate_2 - 70.337897) / -25.580953) * abs((envPL2 - envPL1) / 96.0) * 2.45;
	envPR2 = exp((rate_3 - 70.337897) / -25.580953) * abs((envPL3 - envPL2) / 96.0) * 2.45;
	envPR3 = exp((rate_4 - 70.337897) / -25.580953) * abs((envPL4 - envPL3) / 96.0) * 2.45;
	endy = [
		\envPL0, envPL0,
		\envPL1, envPL1,
		\envPL2, envPL2,
		\envPL3, envPL3,
		\envPL4, envPL4,
		\envPR0, envPR0,
		\envPR1, envPR1,
		\envPR2, envPR2,
		\envPR3, envPR3
	];
	//endy.postln;
	endy;
};


~defme = { arg note, vel;
	var a , bil, ptchEnv,
	envL  = Array2D.new(6,5),
	envR  = Array2D.new(6,4),
	//~selector = [66, 48, 54, 60, 66],
	envC  = Array2D.new(6,4);
	6.do { arg y;
		4.do(
			{
				arg x;//~selector = [66, 48, 54, 60, 66],
				~dumm = ~envCal.value(
					~vr[~selector[x] + y],//~vr1, //Level Current
					~vr[~selector[x + 1] + y],//~vr2, //Level Next
					(99-~vr[(24 + (x * 6)) + y]),//~vrx, //Speed
					~vr[6 + y],//~vrv, //Volume
					vel,//velo,//Velocity
					~vr[108 + y],//velSens,
					~vr[78 + y],//level_scaling_bkpoint,
					~vr[90 + y],//level_scaling_l_depth,
					~vr[102 + y],//level_scaling_r_depth,
					~vr[84 + y],//level_scaling_l_curve,
					~vr[96 + y],//level_scaling_r_curve,
					(note + 3 + ~vr[131] - 24),//transposed_note,
					~vr[72 + y],//rate_scaling,//not implemented yer
					~vr[18 + y]//amp_mod_sens;//no
				);
				envL[y,x] = ~dumm[0];
				envR[y,x] = ~dumm[2];
				if(~dumm[0] > ~dumm[1], { envC[y,x] = 3} ,{envC[y,x] = -3});
		});
		envL[y,4] = envL[y,0];
	};
	//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	bil = ~defjamHead1.();
	a =[
		\pitch, (note + ~vr[131] - 24 ).midicps,
		\amp, vel.linlin(0,127,-18,18)];
	6.do { arg c;
		var trCoarse, trFine, trDetune, bloke;//176
		if(~vr[176 + c] == 0, //midi CC 128 + 48 fixed frequency
			{
				trCoarse = ~coarseArrR[~vr[0 + c]];
				trFine   = ~fineArrR[~vr[114 + c]];
				trDetune = ~vr[12 + c];
				bloke = 1;
			},
			{
				trCoarse = ~coarseArrF[~vr[0 + c]];
				trFine   = ~fineArrF[~vr[114 + c]];
				trDetune = 39;
				bloke = 0;
		});
		a = a ++ [
			\coars ++ (c + 1), trCoarse,
			\fine_ ++ (c + 1), trFine,
			\detun ++ (c + 1), trDetune,
			\noteBlok ++ (c + 1), bloke,
		];

	};
	6.do { arg k;
		a = a ++ [
			\coars ++ (k + 1), ~coarseArrR[~vr[0 + k]],
			\fine_ ++ (k + 1), ~fineArrR[~vr[114 + k]],
			\env ++ (k + 1) ++ "L0", envL[k,0],
			\env ++ (k + 1) ++ "L1", envL[k,1],
			\env ++ (k + 1) ++ "L2", envL[k,2],
			\env ++ (k + 1) ++ "L3", envL[k,3],
			\env ++ (k + 1) ++ "L4", envL[k,4],
			\env ++ (k + 1) ++ "R0", envR[k,0],
			\env ++ (k + 1) ++ "R1", envR[k,1],
			\env ++ (k + 1) ++ "R2", envR[k,2],
			\env ++ (k + 1) ++ "R3", envR[k,3],
			\env ++ (k + 1) ++ "C0", envC[k,0],
			\env ++ (k + 1) ++ "C1", envC[k,1],
			\env ++ (k + 1) ++ "C2", envC[k,2],
			\env ++ (k + 1) ++ "C3", envC[k,3],
			\modSens ++ (k + 1), ~vr[18 + k],
		];

	};
	ptchEnv = ~defPitchEnv.value((99-~vr[139]),(99-~vr[140]),(99-~vr[141]),(99-~vr[142]),~vr[143],~vr[144],~vr[145],~vr[146]);
	a = bil ++ a ++ ptchEnv;
	a = a ++ [\osc_sync, ((~vr[130] * (-1)) + 1)];
	//a.postln;
	a;

};
