//An attempt at a mother.scd that meets the needs of complex supercollider patches

~mainPatch = "/tmp/patch/main.scd".standardizePath;

//Environment variables
~mother = "localhost";

//Env variable for organelle destination (use for screen, led, OS communication)
m = NetAddr(~mother, 4001);

//Env variable for sending messages back to sclang
~self = NetAddr(~mother, 57120);

m.sendMsg("/patchLoaded",1);
m.sendMsg("/oled/setscreen",3);

~masterVolume = 0.4;

//Display a helpful message to indicate this is an SC patch
~loadingMessage = "Loading...";
m.sendMsg("/oled/line/1", ~loadingMessage);
m.sendMsg("/oled/line/2", "heating up");
m.sendMsg("/oled/line/3", "Supercollider");

/////OSCdefs with recvPort: 4000 are parsing inputs from Organelle's physical hardware.

OSCdef( \RoutePhysicalKeys,
	{

		arg msg, time, addr, recvPort;

		if(msg[1] == 0){
			~self.sendMsg("/aux", msg[2]);
		}{
			//notes from the physical organelle keyboard are transposed so that the low C on organelle is middle C
			~self.sendMsg("/note", msg[1] + 59, msg[2] / 3 );
		}
	},
	"/key",
	recvPort:4000
);

//NOTE: there are 6 knobs: 4 main knobs on the left, Master Volume knob, Exp input is also treated like a knob (FS and Exp data are BOTH calculated from the "pedal" input on Organelle

OSCdef( \knobs,
	{
		arg msg, time, addr, recvPort;
		//define this in your patch if you need it
	},
	"/knobs",
	recvPort:4000
);

OSCdef( \fs,
	{
		arg msg, time, addr, recvPort;
		//define this in your patch if you need it
	},
	"/fs",
	recvPort:4000
);




OSCdef( \MainVolume,
	{
		arg msg, time, addr, recvPort;
		var vol;

		vol = msg[5] / 1023;

		~masterVolume = vol.ampdb;

		if (s.serverRunning)
		{
			s.volume.volume = ~masterVolume;
		}
	},
	"/knobs",
	recvPort:4000
);


OSCdef( \aux,
	{
		arg msg, time, addr, recvPort;
		//define this in your patch if you need it
	},
	"/aux",
	recvPort:4000
);

OSCdef( \note,
	{
		arg msg, time, addr, recvPort;
		//define this in your patch if you need it
		//both physical keys (transposed to C4) and midi on/off arrive here
	},
	"/note",
	recvPort:57120
);

//Encoder behavior is weird- you need to enable submenu for the messages to even be sent. most patches don't use this at all.
//to use, send mother an /enablepatchsub message: m.sendMsg("/enablepatchsub", 1);
//then you can recieve messages for enc turn and push using defs as seen below but implemented in your patch
//enc turn usually puts you back in the patch menu (which closes automatically after a few seconds without input so you don't need to worry about storing patch state)
//SO make sure you define a way to switch patches by sending m.sendMsg("/gohome"); somewhere!

OSCdef( \enc,
	{
		arg msg, time, addr, recvPort;

		//define this in your patch if you need it, read above
	},
	"/encoder/turn",
	recvPort:4000
);

OSCdef( \encbut,
	{
		arg msg, time, addr, recvPort;
		//define this in your patch if you need it, read above
	},
	"/encoder/button",
	recvPort:4000
);

//VUMeter/////// This section recieves data from the OrganelleIO synth that is created when the server boots, and then parses that data and sends it to the Organelle UI in a way it understands so that the input and output VUmeters work.

//pointer to audio io buses
s.newBusAllocators;
~ioBus = Bus(rate: \audio, index: 0, numChannels: 4);

//def that is instantiated once server has booted
~vuDef = SynthDef(\OrganelleIO, {

	[2,3,0,1].do {
		|input, i|
		SendPeakRMS.kr(
			sig: ~ioBus.subBus(input).kr(1),
			cmdName: '/rcvPeakRMS',
			peakLag: 4,
			replyID: i;
		);
	}

});

~vuVals = 0 ! 4;

//The "peak" bit on each of the 4 meters is managed using a bitmask. Default is nothing clipping.
~peakbits = 0;

OSCdef( \rcvPeakRMS,
	{
		arg msg, time, addr, recvPort;
		var replyId, bus, rms, peak, message;

		replyId = msg[2];
		peak = msg[3].ampdb.linlin(-80, 0, 0, 1);
		rms = msg[4].ampdb.linlin(-80, 0, 0, 1);

		~vuVals[replyId] = rms;

		if (peak > 0.9){
			~peakbits = ~peakbits.setBit(replyId, true)
		}{
			~peakbits = ~peakbits.setBit(replyId, false)
		};

		if (s.serverRunning) {
			message = [ "/oled/vumeter" ]  ++ (~vuVals*12).asInteger ++ [ ~peakbits ];
			m.sendMsg(*message);
		}
	},
	"/rcvPeakRMS",
	recvPort: 57120
);

///////MIDI
//Setup MIDI, pulling device from Organelle settings in /sdcard/patch_loaded.sh
//This is overkill really because MidiIn.connectAll would most likely work but this is more performant.

~setupMIDI = {
	var patch_loaded, lines, devicesetting, sources, path;

	//this function is called once the server is booted.

	path = "/sdcard/patch_loaded.sh";

	MIDIClient.init(nil,nil,false);

	sources = MIDIClient.sources;	

	MIDIIn.connect(0, MIDIIn.findPort("ttymidi", "MIDI in"));

	if (File.exists(path)) {

		patch_loaded = File(path, "r");

		lines = patch_loaded.readAllString.split($\n);

		lines.do({arg item;
			if(item.beginsWith("# midiDevice"), {
				devicesetting = item.split($,).at(1).split($:).at(0);
			});
		});

		sources.do({arg item;
			if(item.device == devicesetting, {
				MIDIIn.connect(1, MIDIIn.findPort(item.device, item.name));
			});
		})
	}
};

//By default we route midi note ons and off to the /note OSC address on the language side (57120) so that they can be easily processed alongside physical key input

MIDIdef.noteOn(\midiNoteOn, {
	| vel, note |
	~self.sendMsg("/note", note, vel)
});

MIDIdef.noteOff(\midiNoteOff, {
	| vel, note |
	~self.sendMsg("/note", note, 0)
});


/////System level things

//This gracefully shuts down the SuperCollider server when the kill-patch script is run
OSCdef( \KillPatch,
	{
		arg msg, time, addr, recvPort;
		~graphics.(\ShowInfoBar, true);
		~graphics.(\Clear);
		s.quit;
	},
	"/quit"
);


///////Graphics

//commands follow this pattern! Symbol or string for address (drop the "g" and start upper case), then x, y, other stuff where applicable. color is auto-selected. To use color=black/off use false as final param.

//NOTE: Sending any graphics message will update the screen EVENTUALLY but to get it smooth, you will want to send a bunch of graphics messages in short succession followed by ~graphics.(\Flip);
/* examples

~graphics.(\ShowInfoBar);

~graphics.(\Clear);

~graphics.(\SetPixel, /*x:*/ 200, /*y:*/ 200);

~graphics.(\Circle, /*x:*/ 50, /*y:*/ 50, /*radius:*/ 20);
~graphics.(\Circle, /*x:*/ 50, /*y:*/ 50, /*radius:*/ 20, false);

~graphics.(\Line, /*start x:*/ 0, /*start y:*/ 0, /*end x:*/ 100, /*end y:*/ 100);

~graphics.(\Box, 20, 90, 10, 20);

~graphics.(\Println, 10, 10, 16, "Words!");

~graphics.(\Frame, ~myInt8Array);

*/

~screenNum = 3;

~graphics = {
	|address, x = 1 ... y|
	var msg = ["/oled/g" ++ address] ++ [~screenNum] ++ [x] ++ y;

	//for addresses not in the special case list below, add color:true to the end of the message. This can be overridden by making the last paramater false or 0 (to set color 0)
	switch(address)
	{\InvertArea}{}
	{\Flip}{}
	{\Invert}{}
	{\Waveform}{}
	{\Frame}{}
	{\Println}{
		if ((msg.size == 7) && (msg[6] == false)){
			msg = msg[0..4] ++ false ++ [msg[5]]
		}{
			msg = msg[0..4] ++ true ++ [msg[5]]
		}
	}
	{
		//default case, most messages go here and get a "true" appended, meaning color = white/on
		if ((y.size > 0) && (msg[msg.size - 1] != false)){
			msg = msg ++ [true]
		}
	};

	m.sendMsg(*msg);
	msg
};


//another way to work is to manipulate an Int8Array with exactly 1024 elements and then refresh the whole screen with ~graphics.(\Frame, ~pixels); This means you are updating 128 * 8 blocks of 8 pixels language side, then sending a definition of the WHOLE screen all at once (to MOTHER(port 4001), not SCSYNTH(port 57110)). This can be more performant.

//below are some building blocks for working like this. Based on code from Organelle OS (ported from C++).


~pixels = Int8Array.newClear(1024);

~getByteIndex = {
	|x, y|
	var b;
	b = (y / 8).floor * 128 + x;
	b.asInteger;
};

~setPixel = {
	|x, y, color = true, range|
	var index, bit;

	if (range == nil) { range = [0,0,128,64] };

	if ((x >= range[0]) && (y >= range[1]) && (x < range[2]) && (y < range[3])) {
		index = ~getByteIndex.(x, y);

		bit = y % 8;
		~pixels[index] = ~pixels[index].setBit(bit, color);
	}
};

~getPixel = {
	|x, y|
	var index, bit;

	index = ~getByteIndex.(x, y);

	bit = y % 8;

	if (~pixels[index] != nil) {
		bit = ~pixels[index].asBinaryDigits[bit-1];
		if (bit != 0) {true} {false}
	}{ nil }
};

~frameLine = {
	|x1, y1, x2, y2, color = true, range|

	var dy = y2 - y1,
	dx = x2 - x1,
	stepx, stepy, fraction;

	if (range == nil) { range = [0,0,128,64] };

	if (dy < 0){
		dy = -1 * dy;
		stepy = -1
	}{
		stepy = 1
	};

	if (dx < 0) {
		dx = -1 * dx;
		stepx = -1;
	}{
		stepx = 1
	};
	dy = 2 * dy;
	dx = 2 * dx;

	~setPixel.(x1, y1, color, range);

	if (dx > dy) {
		fraction = dy - (dx / 2);
		while {x1 != x2}{
			if (fraction > 0) {
				y1 = y1 + stepy;
				fraction = fraction - dx;
			};
			x1 = x1 + stepx;
			fraction = fraction + dy;
			~setPixel.(x1, y1, color, range);
		}
	}{
		fraction = dx - (dy/2);
		while {y1 != y2}{
			if (fraction > 0) {
				x1 = x1 + stepx;
				fraction = fraction - dy;
			};
			y1 = y1 + stepy;
			fraction = fraction + dx;
			~setPixel.(x1, y1, color, range)
		}
	}
};

~frameCircle = {
	|h, k, r, color = true, range|

	var x = 0, y = r, p;

	if (range == nil) { range = [0,0,128,64] };

	p = 3 - (2 * r);

	while {x <= y}
	{
		~setPixel.(h + x, k + y, color, range);
		~setPixel.(h + y, k + x, color, range);
		~setPixel.(h + y, k - x, color, range);
		~setPixel.(h + x, k - y, color, range);
		~setPixel.(h - x, k - y, color, range);
		~setPixel.(h - y, k - x, color, range);
		~setPixel.(h - y, k + x, color, range);
		~setPixel.(h - x, k + y, color, range);

		x = x + 1;

		if (p < 0) {
			p = p + ((4 * x) + 6);
		}{
			y = y - 1;
			p = p + ((4 * (x - y)) + 10);
		}
	}
};

~frameCircleFilled = {
	|h, k, r, color = true, range|

	var x = 0, y = r, p;

	if (range == nil) { range = [0,0,128,64] };

	p = 3 - (2 * r);

	while {x <= y}
	{
		~frameLine.(h+x, k+y, h+x, k-y, color, range);
		~frameLine.(h+y, k+x, h+y, k-x, color, range);
		~frameLine.(h-x, k+y, h-x, k-y, color, range);
		~frameLine.(h-y, k-x, h-y, k+x, color, range);


		x = x + 1;

		if (p < 0) {
			p = p + ((4 * x) + 6);
		}{
			y = y - 1;
			p = p + ((4 * (x - y)) + 10);
		}
	}
};

///////Server config and boot

//prepare for remote access
//s.options.maxLogins = 4;
//s.options.bindAddress = "0.0.0.0";


s.waitForBoot({
	(
		s.volume.lag = 0.1;
		s.volume.volume = ~masterVolume;
		s.latency_(0.15);
		~setupMIDI.();

		~vuDef.play;

		m.sendMsg("/oled/line/1", "...ready");

		~mainPatch.load;
	)
});
