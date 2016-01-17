unit AudioPlay;

interface

  { $DEFINE THREADSAFE}
  { define this to make object threadsafe }

uses
  AppConsts,    { TSynchMethod}
  AppUtils,     { TThreadSafe}
  AudioBase,    { audio types}
  AudioOut,     { TAudioOut }
  Windows,     { PByte}
  classes      { TNotifyEvent }
  ;


  { playback modes }
type TPlayBack = (ptWav, ptRaw);

type TAudioPlay = class(TThreadSafe)

  private
    fPlaySource: string;
    fPlaying: boolean;
    fStopDone : boolean;
    fAudioOut : TAudioOut;
    fWaveData, fFileData, fRawData : array of Byte;
    fWaveDevice: integer;
    fBuffersToSend : Cardinal;
    fBuffersSent : Cardinal;
    fSynchMethod: TSynchMethod;
    fPlayLength : double;
    fBufferSize, fFileBufferSize, fRawBufferSize : integer;
    fFrameRate, fFileFrameRate, fRawFrameRate : integer;
    fQuantization, fFileQuantization, fRawQuantization : integer;
    fOnDone: TNotifyEvent;
    fSynchroniser : TSynchroniser;
    FPlayback: TPlayback;


    procedure SetPlaySource(const Value: string);
    procedure SetPlaying(const Value: boolean);
    procedure SetWaveDevice(const Value: integer);
    procedure BufferNeeded(const Buffer : PByte; var Size : Cardinal);
    procedure SetSynchMethod(const Value: TSynchMethod);
    procedure GetFileData;
    procedure DoDone;
    procedure DoPlayDone(Sender : TObject);

  public
    property Playing : boolean read FPlaying write SetPlaying;
    property PlaySource : string read fPlaySource write SetPlaySource;
    property WaveDevice : integer read fWaveDevice write SetWaveDevice;
    property SynchMethod : TSynchMethod read fSynchMethod write SetSynchMethod;
    property PlayLength : double read fPlayLength;
    property FrameRate : integer read fFrameRate;
    property Quantisation : integer read fQuantization;
    property OnDone : TNotifyEvent read fOnDone write fOnDone;
    procedure SetRawData(Data: PByte; const Size: Cardinal ; Quantization , Framerate : integer);
    property Playback : TPlayback read FPlayback write fPlayback;

    constructor Create; override;
    destructor Destroy; override;

  end;


implementation
uses
  AudioWave,      { TAudioWave}
  SysUtils,     { FileExists}
  typinfo      { BooleanIdents}
  ;

var

  UnitID : BYTE;


procedure Trace(const Msg : string ; const LogSeverity : TLogSeverity = lsInformation);

begin
  AppConsts.Trace(UnitId, Msg, LogSeverity);
end;

{ TAudioPlay }

constructor TAudioPlay.Create;
begin
  inherited;
  fAudioOut := TAudioOut.Create;
  fAudioOut.OnBufferNeeded := BufferNeeded;
  fAudioOut.OnPlayDone := DoPlayDone;
  fAudioOut.SynchMethod := smFreeThreaded;
  SynchMethod := smCreatorThread;
  fPlayLength := -1;
  fSynchroniser := TSynchroniser.Create;
end;

destructor TAudioPlay.Destroy;
begin
  fAudioOut.Free;
  FreeAndNil(fSynchroniser);
  inherited;
end;

procedure TAudioPlay.SetWaveDevice(const Value: integer);
begin
  fWaveDevice := Value;
end;

procedure TAudioPlay.SetPlaying(const Value: boolean);
begin
  { TODO -oPatrick -cAudio playback stall : do we have a dealock here ?!!! }
  Trace(Format('play %d SetPlaying %s', [fWaveDevice, BooleanIdents[Value]]), lsWarning);
  if (fPlaying <> Value) then
  begin

    {$IFDEF THREADSAFE}
    {synchronize access}
    Lock;
    {$ENDIF}
    try
      if Value then
      begin

        { set the fwavedata reference and other properties here }
        case fPlayback of
          ptRaw :
          begin
            fWaveData := fRawData;
            fBufferSize := fRawBufferSize;
            fFrameRate := fRawFrameRate;
            fQuantization := fRawQuantization;

          end
          else { ptWav only, currently }
          begin
            fWaveData := fFileData;
            fBufferSize := fFileBufferSize;
            fFrameRate := fFileFrameRate;
            fQuantization := fFileQuantization;
          end;

        end; { case }

        { if wavedata previously set OK }
        if (Length(fWaveData) > 0) then
        begin

          fAudioOut.WaveDevice := fWaveDevice;
          fAudioOut.Framerate := fFrameRate;
          fAudioOut.Quantization := fQuantization;
          fAudioOut.SynchMethod := smFreeThreaded;
          { set the requested buffer size }
          fAudioOut.BufferSize := fBufferSize;

          fAudioOut.BuffersCount := 1;
          fBuffersSent := 0;
          fBuffersToSend := 1;
          fSynchroniser.SetContext;
          fAudioOut.Start;
          Trace(Format('play %d Audio Started', [fWaveDevice]), lsWarning);
          fPlaying := true;

          fStopDone := false;
        end  { if file exists }
        else
        begin
          fPlaying := false;
          DoDone;
        end;
      end  { start}
      else
      begin
        if fAudioOut.Active then
        begin
          fAudioOut.Stop;
          Trace(Format('play %d Audio Stopped', [fWaveDevice]), lsWarning);
          DoDone;
        end;
      end;  { stop }
    finally
     {$IFDEF THREADSAFE}
      Unlock;
     {$ENDIF}
    end;
  end
  else
  begin
    if (fAudioOut.Active) then
      Trace('Device busy', lsWarning);
  end;
end;

procedure TAudioPlay.DoDone;
begin

  Trace('DoDone: Playing ' + BooleanIdents[fplaying], lsInformation);
  if not (fStopDone) and (Assigned(fonDone)) then
  begin
    Trace('DoDone: doing callback', lsInformation);
    fPlaying := false;
    { only one callback, and ignore fPlaying }
    fStopDone := true;
    { execute callback as requested }

    case SynchMethod of
    smCreatorThread :
      begin
        fSynchroniser.Method := fOnDone;
        fSynchroniser.RunMethod(self, true);
      end;
    smFreeThreaded :
      fOnDone(self);  
    end;

  end;

end;


procedure TAudioPlay.BufferNeeded(const Buffer : PByte; var Size : Cardinal);
begin

  if ( fBuffersSent < fBuffersToSend) then
  begin
    Trace('buffer needed', lsInformation);
    { copy in data }
    Move(fWaveData[0], Buffer^, Size);

    Inc(fBuffersSent);
  end
  else
  begin
    Trace('no more buffers', lsInformation);
    { say buffer is empty }
    Size := 0;
  end;

end;

procedure TAudioPlay.SetPlaySource(const Value: string);
begin
  fPlaySource := Value;
  { this gets the data and playlengh}
  GetFileData;
end;

procedure TAudioPlay.SetSynchMethod(const Value: TSynchMethod);
begin
  fSynchMethod := Value;
end;


procedure TAudioPlay.GetFileData;
var
  WaveFile : TWaveFile;
  PlayFile : string;
begin
  {$IFDEF THREADSAFE}
  {synchronize access}
  Lock;
  {$ENDIF}
  try

    if (Length(fFileData) > 0) then
      Setlength(fFileData, 0);

    PlayFile := fPlaySource;
    { fixup for slightly odd Exceletel approach }
    if not FileExists(fPlaySource) then
      if FileExists(fPlaySource + '.wav') then
        PlayFile := fPlaySource + '.wav';

    if FileExists(PlayFile) then
    begin
      WaveFile := TWaveFile.Create;
      try
        WaveFile.OpenForRead(PlayFile);
        fFileFramerate := WaveFile.SamplingRate;
        fFileQuantization := WaveFile.BitsPerSample;

        { set the requested buffer size }
        fFileBufferSize := WaveFile.numSamples * (WaveFile.BitsPerSample div 8);
        { and use to allocate the date }
        SetLength(fFileData, fFileBufferSize);

        WaveFile.ReadSampleData(WaveFile.numSamples, PByte(@fFileData[0]));
        fPlayLength := WaveFile.numSamples / WaveFile.SamplingRate;
      finally
        WaveFile.Free;
      end;
    end  { if file exists }
    else
    begin
      Trace(Format('File "%s" does not exist', [PlayFile]), lsWarning);
      fPlayLength := -1;
    end;

  finally
    {$IFDEF THREADSAFE}
    Unlock;
    {$ENDIF}
  end;

end;


procedure TAudioPlay.SetRawData(Data: PByte; const Size: Cardinal ; Quantization , Framerate : integer);
var
  pRawData : PByte;
begin

  {$IFDEF THREADSAFE}
  Lock;
  {$ENDIF}
  try
    SetLength(fRawData, Size);
    pRawData := @fRawData[0];
    Move(Data, pRawData, Size);
    fRawQuantization := Quantization;
    fRawFramerate := Framerate;
  finally
    {$IFDEF THREADSAFE}
    Unlock;
    {$ENDIF}
  end;


end;


procedure TAudioPlay.DoPlayDone(Sender: TObject);
begin
  fAudioOut.Stopping := true;
  fPlaying := false;
  DoDone;
end;

initialization

  UnitID := GetUnitID('AudioPlay');

finalization


end.
