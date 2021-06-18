import("stdfaust.lib");

numberOfDelays = 6;

maxDelaySeconds = 2;
maxDelayMsec = maxDelaySeconds * 1000.0;
maxDelaySamples = maxDelaySeconds * float(ma.SR);
minDelaySamples = ma.SR / 10000;

//volume(c, in) = hslider("t:Page/h:[1]MatrixMixer/v:InTo%2c-->/r%3in[style:knob]",0.0,0.0,1.0,0.001): si.smoo;
//Mixer(N,out) 	= par(in, N, *(volume(in, in+10*out)) ) :> _;
volume(c, in) = hslider("t:EchoMatrix/h:[2]MatrixMixer/v:Unit%2c Out/Unit%2c>%1in[style:knob]",0.0,0.0,1.0,0.001): si.smoo;
Mixer(N,out) 	= par(in, N, *(volume(in, out)) ) :> _;
Matrix(N,M) 	= par(in, N, _) <: par(out, M, Mixer(N, out));

fdMatrix(N) = Matrix(N, N);

//Zero < MAX(wNumber-1,0)/wCount and > MIN(wNumber+1,wCount) /wCount 
morphZero(wCount,wNumber,wMorph) = (wMorph < ((wNumber-1)/wCount)) * (wMorph >= ((wNumber+1)/wCount));

morphFactor(wCount,wNumber,wMorph) = (wMorph - (wNumber/wNumber));

modsaw(f,m) = (0.5 - m) : max(0.0) : _ * 2.0 * os.lf_saw(f);
modsin(f,m) = (((m < 0.5) * m * 2.0) + ((m >= 0.5) * (1.0 - m) * 2.0)) * os.oscsin(f);
//modtri(f,m) = (((m < 0.5) * m * 2.0) + ((m >= 0.5) * (1.0 - m) * 2.0)) * os.lf_triangle(f);
modrevsaw(f,m) = (m - 0.5) : max(0.0) : _ * 2.0 * (0.0 - os.lf_saw(f));

modwave(j,f) = modsaw(f,m) + modsin(f,m) + modrevsaw(f,m) //: si.smoo
with {
    m = hslider("t:EchoMatrix/v:[1]Delays/h:[4]ModWave/Unit %j[style:knob]",0.5, 0.0, 1.0, 0.001);
};

matrixDelays(N) = _,_ : ( fdMatrix(N + 2) : par(i,N, voice(i)),_,_ ) ~ par(r,N,_) : par(l,N,!),_,_ //par(k,2, _*vol(k):sp.panner(pan(k))) :> _,_
with {
	voice(j)	= de.fdelay2(M, dtime(j));
    dtime(j)	= hslider("t:EchoMatrix/v:[1]Delays/h:[3]Delay/Unit %j[unit:ms][scale:exp][style:knob]", 0, 0, maxDelayMsec, 0.1) : si.smoo :
        *(1.0+modOsc(j))*ma.SR/1000.0
        : min(maxDelaySamples) : max(minDelaySamples);
    modFreq(j) = hslider("t:EchoMatrix/v:[1]Delays/h:[4]ModFreq/Unit %j[scale:exp][style:knob]", 0.05, 0.0, 10.0, 0.001) : si.smoo ;
    modDepth(j) = hslider("t:EchoMatrix/v:[1]Delays/h:[5]ModDepth/Unit %j[scale:exp][style:knob]", 0.0, 0.0, 0.8, 0.001) : si.smoo ;
    modOsc(j) = modwave(j, modFreq(j)) * modDepth(j);
    //vol(k) = vslider("t:Page/v:[3]IO/h:[3]Delay Output Volume/%k[scale:exp][style:knob]", 0.8, 0.0, 1.2, 0.01) : si.smoo ;
    //pan(k) = vslider("t:Page/v:[3]IO/h:[4]Delay Output Pan/%k[style:knob]",0.5,0.0,1.0,0.001)  : si.smoo;
    M 		= int(2^19); 
};


stereoSplit = _,_ : (_<:_,_), _ : _, select2(selectMono) <: matrixDelays(numberOfDelays) : (_*outputGain), (_*outputGain)
with {
    selectMono = checkbox("t:EchoMatrix/v:[1]Delays/[1]Mono Input");
    outputGain = hslider("t:EchoMatrix/v:[1]Delays/[2]Stereo Output Gain", 0.9, 0.0, 1.2, 0.01) : si.smoo;
};

process = _,_ : stereoSplit : _,_;