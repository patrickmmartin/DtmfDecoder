unit DTMFToneGen;

interface



{$IFDEF VER140}
{ lose the deprecated warning }
  {$WARN SYMBOL_DEPRECATED OFF}
{$ENDIF}

{ $DEFINE CHECK_FORMAT}
{ define this to check and downgrade wave format if required }

uses
  Windows,     { THandle }
  mmSystem,    { PWaveFormatEx }
  Messages,    { TMessage }
  Classes,     { TNotifyEvent }
  Forms        { AllocateHwnd }
  ;

type


  TCustomToneGenerator = class
  private
    { Private declarations }
    fOnDone : TNotifyEvent;
    fBusy : boolean;
    fOpen : boolean;
    fDeviceId : integer;
    procedure DoDone;
    procedure SetDeviceID (NewVal : integer);

  public
    { Public declarations }
    procedure PlayDTMF(const Digits : string ; Duration : integer); virtual; abstract;
    property OnDone : TNotifyEvent read fOnDone write fOnDone;
    property DeviceID : integer read fDeviceID write SetDeviceID;
  end;

  { concrete class that implements playback internally }
  TBasicToneGenerator = class(TCustomToneGenerator)
  private
    { Private declarations }
    fWindowHandle : HWND;
    procedure WndProc(var Msg: TMessage);

  public
    { Public declarations }
    constructor Create;
    destructor Destroy; override;
    procedure PlayDTMF(const Digits : string ; Duration : integer); override;
  end;



  { alias for other units }
  type TToneGenerator = TBasicToneGenerator;


function ToneData(const Digits : string ; const Duration, Framerate, SampleSize : Cardinal; var Size : Cardinal) : PByte;


implementation

uses
  SysUtils,             { Exception, Format etc. }
  AppConsts,            { Trace }
  AudioOut,          { TAudioOut }
  DTMFConsts         { duh }
  ;

resourcestring
  sInvalidID = 'Device ID %d out of range';

var UnitID : BYTE;


procedure Trace(const Msg : string ; const LogSeverity : TLogSeverity = lsInformation);

begin
  AppConsts.Trace(UnitId, Msg, LogSeverity);
end;


procedure SystemError;
begin
  raise Exception.Create(SysErrorMessage(GetLastError));
end;


procedure WaveError(retval :  MMResult);
var
  errorBuf : array[0..1023] of Char;
begin
    waveOutGetErrorText(retval, errorBuf, sizeof(errorBuf) -1 );
    raise Exception.Create(errorBuf);
end;

procedure MMCheck(retval :  MMResult);
begin
  if (retval <> 0) then
    WaveError(retval);

end;

  { utility function to return a buffer filled with generated tone data - caller frees }

function ToneData(const Digits : string ; const Duration, Framerate, SampleSize : Cardinal; var Size : Cardinal) : PByte;
var
  DataSize : Cardinal;
  SampleAngle1, SampleAngle2 : single;
  SoundVal : Pointer;
  i, j : integer;
  ToneSize, SilenceSize : Cardinal;

begin
  Result := nil;
  if (Digits = '') then
    exit;

  {work out the datasize }

  {get no. of samples in tone }
  ToneSize := SampleSize * round( (Duration / 1000) * FrameRate);

  {get no. of samples in silence  - use tone duration }
  SilenceSize := ToneSize * 2;

  DataSize := Cardinal(Length(Digits)) * (ToneSize + SilenceSize);

  GetMem(Result, DataSize);

  SoundVal := Pointer (Result);

  for i := 0 To Length(Digits) - 1 do
  begin
    { do tone }
    with CharDTMFFrequencies(Digits[i + 1]) do
    begin
      SampleAngle1 := (2 * Pi * Freq1) / Framerate;
      SampleAngle2 := (2 * Pi * Freq2) / Framerate;
    end;

    for j := 0 to (ToneSize div SampleSize) - 1 do
    begin
      case SampleSize of
      1:
        begin
        { BYTE values are unsigned }
          PByte(SoundVal)^ :=  round(128 + (127 div 3) *( sin ( j * SampleAngle1 ) + sin ( j * SampleAngle2 ) ) );
          Inc(PByte(SoundVal));
        end;
      2 :
        {16 bit values are signed}
        begin
          PSmallInt(SoundVal)^ :=  round( (High(SmallInt) div 3) *( sin ( j * SampleAngle1 ) + sin ( j * SampleAngle2 ) ) );
          Inc(PSmallInt(SoundVal));
        end;
      end;  { case}

    end; { for}

    { do silence  }
    case SampleSize of
    1:
      begin
       { BYTE values are unsigned }
        FillMemory(SoundVal, SilenceSize, 127);
      end;
    2 :
      begin
        { 16 bit values are signed - zero is zero, however}
        FillMemory(SoundVal, SilenceSize, 0);
      end;
    end;  { case}

    Inc(PByte(SoundVal), SilenceSize);

  end;  {for }
  { update size}
  Size := DataSize;
end;


procedure TCustomToneGenerator.DoDone;
begin
  fBusy := false;
  if Assigned(fOnDone) then
    fOnDone(self);
end;



procedure TCustomToneGenerator.SetDeviceID(NewVal: integer);
begin
  
  if (NewVal < 0) or (NewVal > integer(waveInGetNumDevs)) then
    raise Exception.CreateFmt(sInvalidID, [NewVal]);
  if (NewVal <> fDeviceId) then
    fDeviceID := NewVal;
end;



{ TBasicToneGenerator }

constructor TBasicToneGenerator.Create;
begin
  inherited;
  fWindowHandle := AllocateHWnd(WndProc);
  {set defaults}
  fDeviceId := 0;
  fBusy := false;
  fOnDone := nil;
end;

destructor TBasicToneGenerator.Destroy;
begin
  DeallocateHWnd(FWindowHandle);
  inherited;
end;

procedure TBasicToneGenerator.PlayDTMF(const Digits : string ; Duration : integer);
var
    lpData : PChar;
    WaveHdr : TWaveHdr;
    hWaveOut : HWAVE;
    WaveFormat : TWaveFormatEx;
    DataSize : DWORD;
    SampleSize : Word;

const
  SAMPLE_RATE = 8000;
  { important : must be these initially, as only format supported by UnimodemV }

  DEFAULT_SAMPLE_SIZE = 1;
begin

  lpData := nil;
  SampleSize := DEFAULT_SAMPLE_SIZE;

  {get no. of samples}
  try

    WaveFormat.wFormatTag := WAVE_FORMAT_PCM;
    WaveFormat.nChannels := 1;
    WaveFormat.nSamplesPerSec := SAMPLE_RATE;

    WaveFormat.nAvgBytesPerSec := WaveFormat.nSamplesPerSec;
    WaveFormat.nBlockAlign := 1;
    WaveFormat.wBitsPerSample := 8 * SampleSize;


    {check for device caps - may not work with UnimodemV ?}
    {$IFDEF CHECK_FORMAT}
    if (SampleSize > 1 ) and (IsFormatSupported(@WaveFormat, fDeviceID) <> 0) then
    begin
      { downgrade }
      Trace('16 bit output not supported - trying 8 bit', lsWarning);
      SampleSize := 1;
      DataSize := SampleSize * round( (Duration / 1000) * SAMPLE_RATE);
      WaveFormat.wBitsPerSample := 8 * SampleSize;
    end;

    { last try format - this will throw }
    MMCheck(IsFormatSupported(@WaveFormat, fDeviceID));
    {$ENDIF}

    { Open a waveform device for output using window callback. }
    MMCheck(waveOutOpen( @hWaveOut,
                          DWORD(fDeviceID),
                          @WaveFormat,
                          FWindowHandle,
                          0,
                          CALLBACK_WINDOW));

    { in the meantime do this }

    { crappy typecast because of definition in TWaveFormatEx }
    lpdata := PChar(ToneData(Digits, Duration, WaveFormat.nSamplesPerSec, SampleSize, DataSize));


    {now check opened}
    while not fOpen do
    begin
      PumpWindowQueue(fWindowHandle);
      Sleep(50);
    end;


    { After allocation, set up and prepare header. }

    WaveHdr.lpData := lpData;
    WaveHdr.dwBufferLength := DataSize;
    WaveHdr.dwFlags := 0;
    WaveHdr.dwLoops := 0;

    MMCheck(waveOutPrepareHeader(hWaveOut, @WaveHdr, sizeof(TWaveHdr)));

    { Now the data block can be sent to the output device. The
      waveOutWrite function returns immediately and waveform
       data is sent to the output device in the background. }

   fBusy := true;
   MMCheck(waveOutWrite(hWaveOut, @WaveHdr, sizeof(TWaveHdr)));

    while fBusy do
    begin
      PumpThreadQueue;
      { a resolution related to the duration is sufficient }
      Sleep(Duration div 4);
    end;

    waveOutUnprepareHeader(hWaveOut, @WaveHdr, sizeof(TWaveHdr));
    waveOutClose(hWaveOut);

    while fOpen do
    begin
      PumpThreadQueue;
      Sleep(50);
    end;

  finally

    if Assigned(lpData) then
      FreeMem(lpData);

  end;  {try}

end;


procedure TBasicToneGenerator.WndProc(var Msg: TMessage);
begin
  case Msg.Msg of

    MM_WOM_OPEN :
       fOpen := true;

    MM_WOM_CLOSE :
       fOpen := false;

    MM_WOM_DONE :
    begin
      try
        { Frees hData memory. }
        DoDone;
      except
        {?!}
        raise;
      end
    end;
    else

    { removed as very CPU intense}
{      Msg.Result := DefWindowProc(FWindowHandle, Msg.Msg, Msg.wParam, Msg.lParam); }
    {Result := 0;}
    end; {case}
end;



initialization

  UnitID := GetUnitID('DTMFToneGen');

finalization


end.
