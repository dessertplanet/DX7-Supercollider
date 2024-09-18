// Supercollider DX7 Clone v1.0
// Implemented by Aziz Ege Gonul for more info go to www.egegonul.com
// Under GNU GPL 3 as per SuperCollider license

/*
%%%---INSTRUCTIONS---%%%
1) Put the DX7.afx file in the same directory of this file. (If you don't have it you can download it from "http://www.egegonul.com/DX7.afx.zip")
2) Compile the parenthesis below.
3) Run the ~~mainCaller.value function with the desired note, velocity and preset values.

important notes:
-FM7.ar plugin is needed (It comes with the SC3 plugins).
-Velocity value, drastically changes the overall timbre of sound.
-Gate time is in use, so in order to close the node, velocity value zero must be send to the same note number. (Just like the MIDI convention)
-If you change presets on the run, newly opened notes with new presets might affect the existing notes. Most of the time this is a very minimal effect because it only affects the global LFO value. This happens due to the architecture design of DX7. Remember this is a single clone of DX7, not a clones of clones.
-Not all presets have velocity depth. So it might sound same no matter what the velocity is.
-Sometimes you see "FAILURE IN SERVER /n_free Node 808 not found" message, this is due to the DetectSilence.ar UGen which helps me to close some forgotten notes in combination with FreeSelfWhenDone (Sometimes nodes skips detect silence because of DC component). FreeSelfDone commmand has a 10 second duration. So if you need longer duration please increase the argument but don't comment out completely.
-You can ignore all the commented out areas. It is mostly for debug use. Everything works perfectly. Nothing to worry about.

UPDATE: A note about note-off implementation (will be fixed May 2020):
I received a couple of emails about this issue, so I am copying here is one of my answers.
Q: I'm just getting into SC and ran across the DX7 clone.  I'm only a couple days into SC and only today learned how to connect a MIDI keyboard into a SynthDef.  Not sure I'm even calling into your clone correctly as I'm note sure I need to implement a noteOff of some sort.
A: I will get back to it and add lots of new stuff (parameter modulation, micro tuning, finding a good solution for note-offs). Let's say May for DX7.scd, coz for the time being, I got too much work to do. The thing with note-off is, original DX7 doesn't have any mechanism like this. It has some arbitrary number of voices. It has a 16-Polyphony voice, and every new note creates from one of the least recent notes. I couldn't add standard MIDI note-off because each new note has very different release times, and with exponential formulas, it just goes to infinity. So I added Detectsilence.ar option for each new note, but it wasn't working perfectly (it was closing node without no option of notification), and there were always some stuck notes. So I simply add:  FreeSelfWhenDone.kr(Line.kr(0, 1, 10));
and eventually removed Detectsilence.ar. This is a 10-second time-bomb. So for note-off, I recommend adding maybe Detectsilence in combination with FreeSelfWhenDone. But for a SC beginner, your best bet is to change the FreeSelfWhenDone parameter from 10 seconds to something longer in duration. I know this is CPU intensive, but DX7 has lots of things going on, and maybe with a multi-core processing option, you can create lots of voices. I used it only for 2 to 4 voices, so I never had an issue of CPU with it. I also know this current handling of note-off seems very sluggish, and I will fix it ASAP, but I must say everything else is %100 clone of DX-7, wish I kept original vs. SC sound files. This project is a really magnum opus clone project (aside from current note-off handling, which I will fix for sure).


//order of things: [note, velocity, preset]
//note value range: 0 - 127
//velocity value range: 0 - 127
//preset value range: 0 - 16383 (2 ^ 14)
//example: ~~mainCaller.value(note,velocity,preset)
//for more extra info go to the end of this file

extra notes from the developer:
-I've designed this instrument as accurately as possible to the original DX7, all the presets are collected from the vast DX7 libraries across the internet. Some presets were corrupt so I cleaned them according to their unused indexes but there might be still some that might not work. (I haven't found out yet)
-I've worked on this project extensively during my STEIM internship, and compared every tiny bit of detail with the Original DX7 and reverse engineered the C++ code from the best parts of DX7 VSTs out there.
-File extension .afx derived from AFX, an alias name of a band called Aphex Twin, which released Analord 01, Analord 02, Analord 03, Analord 04, Analord 05, Analord 06, Analord 07, Analord 08, Analord 09, Analord 11 and Analogue Bubblebath 3, 4 & 5 and bunch of other stuff.
-For Analord owners, be sure to remove plastic envelopes with a paper sleeve to protect the record.
-I believe each Analord volume has a corresponding soul twin; they pair beautifully with each other and go hand in hand. (1<=>5 or 1<=>6),(2<=>4),(9<=>11),(3<=>8 or 3<=>7),(10<=>10).
-Original DX7 sysex files were converted with the help of Propellerhead's DX7 conversion tool and from there I implemented my own convention, which is just sequence of numbers stacked together, each line is one preset.

Things to be implemented in Q3 2020:
-I will implement a function which will help to send all parameters of DX7. (It has 146 different parameters).
-Adding your own DX7 preset (Propellerhead PX7) option will be implemented.
-That's all folks, for questions just drop a mail to ege@gatech.edu.
-Preset file list with original preset names with rating system.

Things to be implemented when I have access to a DX7:
-Add some examples of original DX7 sounds compared with this Synthdef in order to show accuracy. (During my initial tests it was hard to determine which one is which with the blind tests)

ege
*/