# DTMFDecoder

## Overview 

A DTMF decoder I wrote a long time ago.

## Approach

This was part of a suite of components written in Delphi to implement a real time survey tool.

The style is pretty much "of its era" Delphi, if a little pointer oriented.

A couple of interesting points are:

+ use of the Intel NSP library
+ choice of the Goertzel function to detect tones, over (say) FFT 

## Technology

Originally Delphi 5 / C++ Builder 5

Now builds with Delphi 7, Delphi 2009

## Building on the command line (as everyone should)

### Delphi 7
there is a make file, so you can build everything from a clean start using `make clean all` - you may very well need to setup the environment with `myenv.bat` or your own variant to get around the issue with incorrect paths or path too long for the Borland make version coming with Delphi 7.

### Delphi 2009
this needs to be setup in the command shell using the Delphi bootstrap `rsvars`, then `msbuild DTMFDecoder.groupproj \t:Clean;Build` will build from a clean start and supports all the msbuild features. 



