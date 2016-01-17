.silent

!ifndef ROOT
ROOT = $(MAKEDIR)\..
!endif

MAKE = $(ROOT)\bin\make.exe -$(MAKEFLAGS) -f$**
BRCC = $(ROOT)\bin\brcc32.exe $**

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
        $(DCC)

default: clean all

DTMFDecode.exe: DTMFDecode.dpr

tests.exe: tests.dpr

TARGETS=tests.exe DtmfDecode.exe AudioLab.exe

all: $(TARGETS)

# TODO: could do with a specialised target
clean:
        echo ==== cleaning $@ $&& ====
	if exist ..\dcu del /F /Q /S ..\dcu\*.dcu > nul 2> nul
	if exist ..\bin cd ..\bin & del /F $(TARGETS)

tests: clean tests.exe ..\bin\nsp.dll
        ..\bin\tests.exe /CONSOLE        


docs:
	doxygen