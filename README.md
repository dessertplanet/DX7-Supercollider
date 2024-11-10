# DX7-Supercollider

### Aziz Ege Gonul's accurate Yamaha DX-7 clone. Extended to run on Organelle M/S.

## Features

* 16-voice DX7 FM synth emulation with 16,384 real DX7 presets from across the internet
* Presets are very wide ranging in quality and can have large timbral variation based on note velocity
* Lush stereo reverb with a simple one-knob interface
* Monophonic mode
* Organelle pedal input support for sustain pedal
* MIDI input for notes (including velocity), sustain pedal, pitchbend with configurable range, and mod depth
* MIDI configuration is as simple as plugging in your usb of 3.5mm TRS midi device and relaunching the patch
* Save presets that you like to your own curated list, persisted for next time you open the patch

## Intro from Aziz's README

This is a super-exact clone of DX7 in SC environment. This project began with my (Aziz's) internship at the STEIM during the last year; I was able to get my hands on an original DX7 synth and eventually found out that this instrument has this mystic / unusual sound. So I started fiddling with it and did some experiments with Supercollider. After a while, it became an obsession to play with it and started to copy parts of its synth mechanism just to flex my DSP muscles. Sooner, I found myself in this vast project to clone the entire thing. After 2-3 months of implementing process and lots of sleepless nights. I was able to clone the entire DX7 engine with very high accurate results. Other than the DX7’s vintage sound hiss, it is hard to distinguish between the clone and the original one on the same presets. For my use, I collected some 16384 (2^14) DX7 Sysex bank presets from the internet and converted it to some integer sequences to read it from Supercollider. I am also combining this clone with this 16384 preset package. Have fun!

## Installation

Upload the .zop file to your patches directory under the folder you would like to install the patch. Then launch the installer from the organelle UI itself using the screen and encoder. The installer requires that wi-fi is connected to the internet and will only work on Organelle M or Organelle S, since multi-core processing is required for this patch.

This installation will install the following prerequisites from the internet if they are not already present:
* Jackd for audio interface purposes
* Supercollider 3.11.2 (headless installation including Supernova)
* FM7 Ugen for Supercollider, pulled from the SC3-plugins
* Fverb2 Ugen for Supercollider, a take on the Dattorro plate reverb

## Interface 

The patch is designed so that instead of programming the patches directly (DX7 was notiriously difficult to program), you navigate through a vast set of presets and choose to save the ones you like for easy access. Controls are enumerated below.

* Long-press encoder to return to patch menu
* Aux button acts as shift key, changing knob, encoder, and encoder button behaviors
* Three ways to navigate through the library of 16384 presets
    1) Encoder cycles through presets one at a time
    2) Aux (shift) + encoder cycles through presets one bank at a time (32 presets at a time)
    3) Knob 1 coarsely scans through all of the preset. preset index 0 at far left, 16383 at far right
* Pressing encoder button loads the currently displayed preset (Asterisk at the left indicates that currently shown preset is loaded)
* Aux + Encoder button loads a random preset (this can be done many times in short succession)
* Knobs adjust the currently shown parameters
* Reverb knob simultaneously controls reverb mix, decay time, damping, and more. 0% is dry, 100% is ambient insanity
* Velocity offset affects not only built in accordion keys but MIDI input as well
* Aux button shows secondary parameters (aux + knob 1 = pitchbend)
* Aux + Longpress of the encode launches the save menu
    * In save menu selecting a saved preset with the encode button loads it
    * Long pressing the encoder button in the save menu allows you to delete saved presets from this list (they remain in the main list of presets)
* Polyphony can be set to MONO or POLY at the bottom of the save menu (called "PHONY MODE")
* Changing the polyphony parameter silences all notes, if you ever encounter a preset that drones forever that you need to silence

## Notes to the synthesist

* The names of the patches are often (and sometimes hilariously) incorrect. They are a memory aid for you on your travels to help locate yourself. Aziz mentioned in docs that he had to recompile the preset text file after compiling the pdf doc of preset names that was used to produce the names displayed in this patch.

* A few notes about the huge preset list to keep in mind (these only apply to a small minority of what is in there)
    * Some of the presets sound identical
    * Some of the presets that are named the same sound nothing alike
    * Some of the presets make no sound at all
    * Some of the presets have no name at all 
    * Some of the presets have no velocity sensitivity and therefore sound the same for all velocities

* A few really cool things I have discovered in my own navigation of these presets, very interested in what others find
    * There are a bunch of different LFO shapes - at least sine, triangle, random step, square, saw...
    * Some presets appear to have key-tracking/splitting where different notes at the same velocity have large differences in timbre
    * Presets have individually configured sensitivities to lfo modulation and velocities so each one responds to these differently in terms of both amplitude and pitch
    * Some of the presets are VERY chaotic by design
    * This claims to be a very accurate emulation- what is more important than accuracy for me is that it scratches all the right nostalgia itches that you would expect for DX7 sounds
    * Don't sleep on the bass sounds in here. Try monophonic mode in a low octave. You won't regret it.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* Aziz Ege Gonul for the amazing synth model
* TheTechnoBear for getting things started for Supercollider on Organelle
* Jon Dattorro for the excellent reverb algorithm in [his 1997 paper](https://ccrma.stanford.edu/~dattorro/EffectDesignPart1.pdf)
* Jean Pierre Cimalando for the [faust implementation](https://github.com/jpcima/fverb) of the said Jon Dattorro reverb
* [Zack Scholl](https://github.com/schollz) for porting the faust implementation to Supercollider (I recompiled [his fork](https://github.com/schollz/portedplugins) of Mads Kjeldgaard's portedplugins on my Organelle)
* Hat tip to John Chowning for his work on the OG DX7
* STEIM for letting Aziz use their DX7 and espresso machine.
* All the anonymous preset makers for the Yamaha DX7.
