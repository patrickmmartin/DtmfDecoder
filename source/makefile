.silent

!ifndef ROOT
ROOT = $(MAKEDIR)\..
!endif

MAKE = "$(ROOT)\bin\make.exe" -$(MAKEFLAGS) -f$**
BRCC = "$(ROOT)\bin\brcc32.exe" $**

# the Delphi 7 make doesn't like the path to be too long
# this is a very simple fix
PATH=$(ROOT)\bin

# compiler options
DCCOPT=-Q -M -W -H

# for Controls.res, WindowsXP.res or anything else in lib...
SEARCHPATH = "$(ROOT)\Lib;$(SEARCHPATH)"

#compiler command line
DCC  = "$(ROOT)\bin\dcc32.exe" \
          -U"$(SEARCHPATH)" \
          -O"$(SEARCHPATH)" \
          -I"$(SEARCHPATH)" \
          -R"$(SEARCHPATH)" \
          -LE"$(DCPDIR)" \
          -LN"$(DCPDIR)" \
          $(DCCOPT) -Q -W -H -M $&.dpr


default: clean all


bin: 
	if not exist ..\bin mkdir ..\bin

dcu-base:
	if not exist ..\dcu mkdir ..\dcu
dcu-DtmfDecode: dcu-base
	if not exist ..\dcu\DtmfDecode mkdir ..\dcu\DtmfDecode


dcu: dcu-base dcu-DtmfDecode

DtmfDecode.exe: bin dcu-DtmfDecode
	$(DCC) DtmfDecode.dpr


targets: DtmfDecode.exe

all: targets

clean:
	if exist ..\dcu del /F /Q /S ..\dcu\*.* > nul
	if exist ..\bin del /F /Q /S ..\bin\*.* > nul


