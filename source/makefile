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
SEARCHPATH = "$(ROOT)\Lib;$(SEARCHPATH);$(ROOT)\dunit\src"

#compiler command line
DCC  = "$(ROOT)\bin\dcc32.exe" \
          -U"$(SEARCHPATH)" \
          -O"$(SEARCHPATH)" \
          -I"$(SEARCHPATH)" \
          -R"$(SEARCHPATH)" \
          -LE"$(DCPDIR)" \
          -LN"$(DCPDIR)" \
          $(DCCOPT) -Q -W -H -M $&.dpr

## create generic rule for executables built from a dpr file
.dpr.exe:
	echo ========== build for $@ ======
	if not exist ..\bin mkdir ..\bin
	if not exist ..\dcu\$& mkdir ..\dcu\$&
#	buildkeys $@
#	$(BRCC) $&.rcscript
        $(DCC) $&.dpr


default: clean all

DtmfDecode.exe:

tests.exe:

targets: tests.exe DtmfDecode.exe

all: targets

clean:
	if exist ..\dcu del /F /Q /S ..\dcu\*.dcu > nul 2> nul
	if exist ..\bin ( cd ..\bin & del %$(TARGETS) ) 


