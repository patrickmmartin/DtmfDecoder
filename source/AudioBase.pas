unit AudioBase;

interface

uses
  Windows, MMSystem, classes,
  SysUtils,
  Messages,
  AppConsts,    { constants }
  AppUtils    { TThreadSafe }
  ;

type

  EAudio = class(Exception)
  public
    MMError : MMResult;
    constructor CreateError(Msg : string ; Error : MMResult);
  end;
    EAudioInvalidOp = class(EAudio);
    EAudioWave = class(EAudio);
    EAudioSystem = class(EAudio);

  TBufferReturnEvent = procedure(const Buffer : PByte; const Size : Cardinal) of object;
  TBufferFillEvent = procedure(const Buffer : PByte; var Size : Cardinal) of object;


  { base class }

  TAudioBase = class(TThreadSafe)
  protected
    procedure InvalidOp(Msg : string); virtual;
    procedure WaveError(Msg : String ; Err :  MMResult); virtual; abstract;
    procedure MMCheck(const Msg : String ; Err : MMResult); virtual;
    procedure SystemError; virtual;
  end;

procedure GetAudioInDevices(DeviceList : TStrings);
procedure GetAudioOutDevices(DeviceList : TStrings);

function IsFormatSupported(pwfx : PWAVEFORMATEX ; uDeviceID : integer) : MMRESULT;

const

  RSIM_BUFFER = WM_USER;
  RSIM_PLAYDONE = RSIM_BUFFER + 1;

resourcestring

  sCheckFormat = 'Check Format';
  sDeviceIDOutOfRangeFmt = 'Device ID %d out of range';
  sInvalidBitsPerSample = 'Bits per sample value %d not allowed';

  sColon = ': ';
  sCannotSetBufferSize = 'Cannot set buffer size';
  sCannotSetBufferCount = 'Cannot set buffer count';
  sCannotSetStereo = 'Cannot set stereo';
  sCannotSetBits = 'Cannot set bits';
  sCannotSetFrameRate = 'Cannot set frame rate';
  sCannotSetWaveDevice = 'Cannot set wave device';


implementation

resourcestring

  sAudioFailed = ' failed'#13#10;
  sAudioOperationFailed = 'An operation failed:'#13#10;

var UnitID : BYTE;

procedure Trace(const Msg : string ; const LogSeverity : TLogSeverity = lsInformation);

begin
  AppConsts.Trace(UnitId, Msg, LogSeverity);
end;

function IsFormatSupported(pwfx : PWAVEFORMATEX ; uDeviceID : integer) : MMRESULT;
begin
  Result := (waveOutOpen(nil, DWORD(uDeviceID), pwfx, 0, 0, WAVE_FORMAT_QUERY));
end;



constructor  EAudio.CreateError(Msg : string ; Error : MMResult);
begin
  inherited Create(Msg);
  MMError := Error;
end;



procedure GetAudioInDevices(DeviceList : TStrings);
var
  i : integer;
  NumDevs : integer;
  WaveInCaps : TWaveInCaps;
begin

  DeviceList.Clear;
  NumDevs := waveInGetNumDevs;
  for i := 0 to NumDevs -1 do
  begin
    waveInGetDevCaps(i, @WaveInCaps, sizeof(WaveInCaps));
    DeviceList.AddObject(WaveInCaps.szPname, TObject(i));
  end;

end;

procedure GetAudioOutDevices(DeviceList : TStrings);
var
  i : integer;
  NumDevs : integer;
  WaveOutCaps : TWaveOutCaps;
begin

  DeviceList.Clear;
  NumDevs := waveOutGetNumDevs;
  for i := 0 to NumDevs -1 do
  begin
    waveOutGetDevCaps(i, @WaveOutCaps, sizeof(WaveOutCaps));
    DeviceList.AddObject(WaveOutCaps.szPname, TObject(i));
  end;
end;

{ TAudioBase }

procedure TAudioBase.InvalidOp(Msg : string);
begin
  raise EAudioInvalidOp.Create(Msg);
end;

procedure TAudioBase.SystemError;
begin
  raise EAudioSystem.Create(SysErrorMessage(GetLastError));
end;

procedure TAudioBase.MMCheck(const Msg : string; Err : MMRESULT);
begin
  if (Err <> MMSYSERR_NOERROR) then
    if (Msg <> '') then
      WaveError(Msg + sAudioFailed, Err)
    else
      WaveError(Msg + sAudioOperationFailed, Err)

end;



initialization

  UnitID := GetUnitID('AudioBase');

finalization

end.
