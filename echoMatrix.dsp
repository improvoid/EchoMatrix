import("stdfaust.lib");

// Can change the number of delay lines and the matrix size
numberOfDelays = 6;

// Can change the max delay time, calculates samplees
maxDelaySeconds = 2;
maxDelayMsec = maxDelaySeconds * 1000.0;
maxDelaySamples = maxDelaySeconds * float(ma.SR);
minDelaySamples = ma.SR / 10000;

// Define the matrix mixer, can be any N x M size

// Note the hslider label spec.  It defines the knobs for the whole matrix
// t:EchoMatrix : Defines a "t" tab pane called EchoMatrix, essentially the "top" level
// /h:[2]MatrixMixed : Defines one tab page called MatrixMixer, it will be a "h" horizontal layout and the [2] second page
// /v:Unit%2c Out : Defines the "v" vertical knob group for all of the Units, %2c imbeds a 2 digit column number
// /Unit%2c>%1in[style:knob] : Defines the labels on the knobs an styles the sliders as knobs

volume(c, in) = hslider("t:EchoMatrix/h:[2]MatrixMixer/v:Unit%2c Out/Unit%2c>%1in[style:knob]",0.0,0.0,1.0,0.001): si.smoo;
Mixer(N,out) 	= par(in, N, *(volume(in, out)) ) :> _;
Matrix(N,M) 	= par(in, N, _) <: par(out, M, Mixer(N, out));

// Make a square matrix mixer
fdMatrix(N) = Matrix(N, N);

// Modulation waveforms, saw->sine->reverse saw
modsaw(f,m) = (0.5 - m) : max(0.0) : _ * 2.0 * os.lf_saw(f);
modsin(f,m) = (((m < 0.5) * m * 2.0) + ((m >= 0.5) * (1.0 - m) * 2.0)) * os.oscsin(f);
modrevsaw(f,m) = (m - 0.5) : max(0.0) : _ * 2.0 * (0.0 - os.lf_saw(f));

// Slider morphs between wave types

// Note the hslider label spec. It will define the wave morph knobs
// There will be one for each modulator assigned one per delay
// t:EchoMatrix : Defines a "t" tab pane called EchoMatrix, essentially the "top" level
// /v:[1]Delays : Defines one tab page called Delays, it will be a "v" vertical layout and the [1] 1st page
// /h:[4]ModWave : Defines a control group that will group sub-controls in a "h" horizontal layout
// /Unit %j[style:knob] : Defines the labels on the knobs an styles the sliders as knobs

modwave(j,f) = modsaw(f,m) + modsin(f,m) + modrevsaw(f,m) //: si.smoo
with {
    m = hslider("t:EchoMatrix/v:[1]Delays/h:[4]ModWave/Unit %j[style:knob]",0.5, 0.0, 1.0, 0.001);
};

// Define the matrix, delays, and feedback paths
// The last 2 channels just flow through with no feedback path
// The par(..) constructs create multiple signals in parallel
// The ~ (recursive operator) connects the outputs sequentially to the inputs

// The "effect" in this case is a delay implemented by the Faust library fdelay2 function
// This provides a three point interpolated (smoothed) delay that works quite nicely
// There are other delays avalable that work differently, but any effect could really be used

// Note the hslider label specs. They define the delay time, mod frequency and mod depth
// There will be one for each modulator assigned one per delay
// t:EchoMatrix : Defines a "t" tab pane called EchoMatrix, essentially the "top" level
// /v:[1]Delays : Defines one tab page called Delays, it will be a "v" vertical layout and the [1] 1st page
// These same specs are used for all of the controls "paths", so all of the controls will end up on the Delays tab
// Idential control paths define identical controls, so if you want one control to control multiple things
// use the same path for multiple controls
// The control numbers inserted with %j start with 0
// /h:[3]Delay/Unit %j[unit:ms][scale:exp][style:knob] : Defines the delay amount with a msec label as the [3] third group.
// The control is styled as a knob with an exponential range, so there will be more resolution in the low end of the knob
// /h:[4]ModFreq/Unit %j[scale:exp][style:knob] : Defines the mod frequency as the [4] fourth group.
// The control is styled as a knob with an exponential range, so there will be more resolution in the low end of the knob
// /h:[5]ModDepth/Unit %j[scale:exp][style:knob] : Defines the mod depth as the [5] fifth group.
// The control is styled as a knob with an exponential range, so there will be more resolution in the low end of the knob

matrixDelays(N) = _,_ : ( fdMatrix(N + 2) : par(i,N, effects(i)),_,_ ) ~ par(r,N,_) : par(l,N,!),_,_
with {
    // For now, the effect is just the delay with a time and a modulator
	effects(j)	= de.fdelay2(maxDelaySamples, dtime(j));
    dtime(j)	= hslider("t:EchoMatrix/v:[1]Delays/h:[3]Delay/Unit %j[unit:ms][scale:exp][style:knob]", 0, 0, maxDelayMsec, 0.1) : si.smoo :
        *(1.0+modOsc(j))*ma.SR/1000.0
        : min(maxDelaySamples) : max(minDelaySamples);
    modFreq(j) = hslider("t:EchoMatrix/v:[1]Delays/h:[4]ModFreq/Unit %j[scale:exp][style:knob]", 0.05, 0.0, 10.0, 0.001) : si.smoo ;
    modDepth(j) = hslider("t:EchoMatrix/v:[1]Delays/h:[5]ModDepth/Unit %j[scale:exp][style:knob]", 0.0, 0.0, 0.8, 0.001) : si.smoo ;
    modOsc(j) = modwave(j, modFreq(j)) * modDepth(j);
};

// Allow a mono or stereo input, and some gain control on the output

// Note the hslider label specs. They define a mono/stereo input and an overall gain
// t:EchoMatrix : Defines a "t" tab pane called EchoMatrix, essentially the "top" level
// /v:[1]Delays : Defines one tab page called Delays, it will be a "v" vertical layout and the [1] 1st page
// These same specs are used for all of the controls "paths", so all of the controls will end up on the Delays tab
// Idential control paths define identical controls, so if you want one control to control multiple things
// use the same path for multiple controls
// /[1]Mono Input : Defines a checkbox/switch that will provide the left signal to both left and right inputs
// /[2]Stereo Output Gain : Defines the overall volume control as the [2] second control
// The control is styled as a knob with an exponential range, so there will be more resolution in the low end of the knob

stereoSplit = _,_ : (_<:_,_), _ : _, select2(selectMono) <: matrixDelays(numberOfDelays) : (_*outputGain), (_*outputGain)
with {
    selectMono = checkbox("t:EchoMatrix/v:[1]Delays/[1]Mono Input");
    outputGain = hslider("t:EchoMatrix/v:[1]Delays/[2]Stereo Output Gain", 0.9, 0.0, 1.2, 0.01) : si.smoo;
};

process = _,_ : stereoSplit : _,_;