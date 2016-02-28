unit AudioOut;

interface

uses
  Windows,       { windows types}
  MMSystem,      { MM types}
  classes,       { TThread}
  SysUtils,      { system stuff}
  Messages,      { Messages}
  AppConsts,     { TThreadsafe}
  AppUtils,      { TThread}
  AudioBase,     { Audio Stuff}
  syncobjs       { TEvent }
  ;

  { use this to get periodic updates of the thread status }

type

  TWaveOutThread = class;

  { base class to manage wave device and wave format }
  TAudioOut = class(TAudioBase)
  private
    fWaveDevice : integer;
    fWaveHandle : HWAVEOUT;
    fWaveFormat : TWAVEFORMATEX;
    fBufferSize, fRequestedBufferSize : Cardinal;

    fWaveHeaders : array of TWAVEHDR;
    fWaveBuffers : array of PByte;

    fBufferCount : Cardinal;
    fWaveThread : TWaveOutThread;
    fOnBufferNeeded : TBufferFillEvent;
    fActive : boolean;
    fStopping : boolean;
    fStarting : boolean;
    fPaused : boolean;
    fSynchMethod : TSynchMethod;
    fWindowHandle : HWND;
    fBuffersOut : integer;
    fThreadPriority : TThreadPriority;
    fDeviceOpened : boolean;
    fOnPlayDone: TNotifyEvent;

    procedure OpenDevice;
    procedure CloseDevice;
    procedure ResetDevice;
    procedure PlayDone;

    procedure FixupWaveFormat;
    procedure PrepareBuffer(BufferIndex : Cardinal);
    procedure UnprepareBuffer(BufferIndex : Cardinal);
    procedure SendBuffer(BufferIndex : Cardinal);

    procedure CreateQueue;
    procedure DeleteQueue;

    procedure CreateBuffers;
    procedure DeleteBuffers;
    procedure BufferNeeded(BufferIndex : Cardinal);
    {! window procedure for this component
    @todo need to delegate to suitable exception handler }
    procedure WndProc(var Msg: TMessage);
    procedure SetActive(NewVal : boolean);

    { property functions }
    procedure SetBufferSize(NewVal : Cardinal);
    procedure SetBufferCount(NewVal : Cardinal);
    function GetFrameRate : Cardinal;
    procedure SetFrameRate(NewVal : Cardinal);
    procedure SetStereo(NewVal : boolean);
    function GetBits : Word;
    procedure SetBits(NewVal : Word);
    function  GetStereo : boolean;
    procedure SetWaveDevice(NewVal : integer);
    procedure DoPlayDone;
    procedure CreateThread;

  protected
    { implement this }
    procedure WaveError(Msg : String ; Err :  MMResult); override;

  public
    constructor Create; override;
    destructor Destroy; override;

    procedure Start;
    procedure Stop;

    property OnBufferNeeded : TBufferFillEvent read fOnBufferNeeded write fOnBufferNeeded;
    property Active : boolean read fActive write SetActive;
    property Stopping : boolean read fStopping write fStopping;
    property SynchMethod : TSynchMethod read fSynchMethod write fSynchMethod;

    property BufferSize : Cardinal read fBufferSize write SetBufferSize;
    property BuffersCount : Cardinal read fBufferCount write SetBufferCount;
    property BuffersOut : integer read fBuffersOut write fBuffersOut;
    property Framerate : Cardinal read GetFrameRate write SetFrameRate;
    property Stereo : boolean read GetStereo write SetStereo;
    property Quantization : Word read GetBits write SetBits;
    property WaveDevice : integer read fWaveDevice write SetWaveDevice;
    function CanOpen : boolean;

    property ThreadPriority : TThreadPriority read fThreadPriority write fThreadPriority;
    property WindowHandle : HWND read FWindowHandle;
    property OnPlayDone : TNotifyEvent read fOnPlayDone write fOnPlayDone;

  end;


TWaveOutThread = class (TThread)

  private
    fAudioOut : TAudioOut;
    fEvent : TEvent;
  protected

  public
    constructor Create(AudioOut : TAudioOut);
    {! execute procedure for the thread
    @todo delegate to suitable exception handler }
    procedure Execute; override;
  end;


implementation

uses
  typinfo,      { BooleanIdents }
  Appmessages   { *MessageAsynch }
  ;

resourcestring
  sAudioOutActive = 'Audio Out Device is Active';
  sWaveOutThread = 'Wave Out ';


const
  { not much use increasing this unless sustained CPU load is experienced}
  { NB very large files just do not work}
  OUT_BUFFERS_DEFAULT = 1;
  { normal file sector size - 0.25 secs @ 8000Hz 16 bit}
  OUT_BUFFER_SIZE_DEFAULT = 4096;


var UnitID : BYTE;

procedure Trace(const Msg : string ; const LogSeverity : TLogSeverity = lsInformation);

begin
  AppConsts.Trace(UnitId, Msg, LogSeverity);
end;

var
  ThreadCount : integer = 0;


{ TAudioOut }


procedure TAudioOut.WaveError(Msg : String ; Err :  MMRESULT);
var
  errorBuf : array[0..MAXERRORLENGTH + 1] of Char;
begin
  errorBuf[0] := #0;
  WaveOutGetErrorText(Err, errorBuf, sizeof(errorBuf) -1 );
  raise EAudioWave.CreateError(Msg + #13#10 + errorBuf, Err);

end;


procedure TAudioOut.FixupWaveFormat;
begin

  with fWaveFormat do
   begin
      wFormatTag := WAVE_FORMAT_PCM;
      nBlockAlign := (wBitsPerSample div 8) * nchannels;
      nAvgBytesPerSec := nSamplesPerSec*nBlockAlign;
   end;

  { need to always increase buffer from requested size }
  fbufferSize := fWaveFormat.nblockalign * (fRequestedBufferSize div fWaveFormat.nblockalign);
  if ((fRequestedBufferSize mod fWaveFormat.nblockalign) <> 0) then
    Inc(fbufferSize, fWaveFormat.nblockalign);

end;


constructor TAudioOut.Create;
begin
  inherited;
  fWaveDevice := integer(WAVE_MAPPER);
  fWaveHandle := 0;

  fBufferCount := OUT_BUFFERS_DEFAULT;
  fActive := false;
  fStopping := false;
  fStarting := false;
  fPaused := false;
  fWindowHandle := 0;
  fBuffersOut := 0;
  fSynchMethod := smCreatorThread;
  { avoid infrequent hangs ? }
  fThreadPriority := tpNormal;

  fRequestedBufferSize := OUT_BUFFER_SIZE_DEFAULT;

  { Set the indendent sampling rates }
  { default is the UniModemV stream format}
  fWaveFormat.wFormatTag := WAVE_FORMAT_PCM;
  fWaveFormat.wBitsPerSample := 16;
  fWaveFormat.nchannels := 1;
  fWaveFormat.nSamplesPerSec := 8000;

  {fixes up values}
  FixupWaveFormat;

  CreateBuffers;


end;

destructor TAudioOut.Destroy;
begin

  if (fActive) then
    Stop;
  if (Assigned (fWaveThread)) then
  begin
    fWaveThread.Terminate;
    fWaveThread.Resume;
    fWaveThread.WaitFor;
    fWaveThread.Free;
  end;

  DeleteBuffers;
  if (fWindowHandle <> 0) then
    DeAllocateHwnd(fWindowHandle);

  inherited;

end;


procedure TAudioOut.SetActive(NewVal : boolean);
begin
  if (NewVal <> fActive) then
  begin
    if (NewVal) then
      Start
    else
      Stop;
    fActive := NewVal;
  end;
end;

procedure TAudioOut.Start;
var
  StartCount : Cardinal;
begin

  Trace(Format('AudioOut %d Start', [WaveDevice]), lsInformation);

  {protect this section}
  Lock;
  try
    Trace(Format('AudioOut %d inside lock', [WaveDevice]), lsInformation);
    if ((not fStarting) and (not fActive)) then
    begin

       try
         {query device capabilities}
         MMCheck(Format('device %d ',[fWaveDevice]) + sCheckFormat, waveOutOpen( nil, DWORD(fWaveDevice),  @fwaveformat,  0,  0,  WAVE_FORMAT_QUERY));
       except
         on E : EAudio do
         begin
           Stop;
           raise;
         end;
       end;

      if (SynchMethod = smCreatorThread) and (fWindowHandle = 0) then
        fWindowHandle := AllocateHWnd(WndProc);

      Trace(Format('AudioOut %d Start Set', [WaveDevice]), lsInformation);

      if not Assigned(fWaveThread) then
        CreateThread;

      fStarting := true;
      fStopping := false;
      { create thread, and start }
      fWaveThread.Resume;

      try
        OpenDevice;
      except
        { flag stop so wave thread will exit }
        fStopping := true;
        fStarting := false;
        raise;
      end;  {try }

      StartCount := GetTickCount;

      { this appears to be required,
        as Open notification not received when device has been opened for playback }
      Trace(Format('AudioOut %d Waiting for device open from thread', [WaveDevice]),
                        lsInformation);
      while not (fActive) and (CompareTickCount(StartCount + 200) < 0 )do
      begin

      if (SynchMethod = smCreatorThread) then
        PumpWindowQueue(fWindowHandle)
      else
        PumpThreadQueue;

        YieldTimeSlice;
      end;
      fDeviceOpened := fActive;

      if (fActive) then
      begin
        Trace(Format('AudioOut %d device open', [WaveDevice]), lsInformation)
      end
      else
      begin
       Trace(Format('AudioOut %d did not get device open: device presumed already open', [WaveDevice]), lsWarning);
       fActive := true;
      end;

     { write out buffer queue here }
     CreateQueue;
     Trace(Format('AudioOut %d buffers queued', [WaveDevice]), lsInformation);
     fStarting := false;

    end;
  finally
    Unlock;
  end;

end;

procedure TAudioOut.Stop;
begin

  Trace(Format('AudioOut %d Stop', [WaveDevice]), lsInformation);
  if (fActive) and (not fStopping) then
  begin
    Lock;
    try
      fStopping := true;
      fStarting := false;
      Trace(Format('AudioOut %d inside lock', [WaveDevice]), lsInformation);
      Trace(Format('AudioOut %d synch method', [WaveDevice]) + SynchMethodDesc[SynchMethod], lsInformation);
    finally
      Unlock;
    end;

    { TODO -oPMM -cactions : Reset should not be called on an invalid handle }
    ResetDevice;

  { occasional hang here on buffersout = 1 }
    { the device close message can NOT be relied upon }
    Trace(Format('AudioOut %d about to wait for device', [WaveDevice]), lsInformation);
    while (fBuffersOut > 0) do
    begin
      { if using message synchronisation pump the message queue}
      if (SynchMethod = smCreatorThread) then
        PumpWindowQueue(fWindowHandle)
      else
        PumpThreadQueue;

      Sleep(50);
    end;
    Trace(Format('AudioOut %d wait complete', [WaveDevice]));

    { letting thread handle stopping and end of playback }
    while fActive do
      YieldPeriod(50);

    Trace(Format('AudioOut %d inactive', [WaveDevice]), lsInformation);

    if (FWindowHandle <> 0) then
    begin
      DeallocateHWnd(fWindowHandle);
      fWindowHandle := 0;
    end;

  end;  {if fActive}

end;


procedure TAudioOut.OpenDevice;
begin
  MMCheck(Format('device %d WaveOutOpen',[fWaveDevice]),
                                          WaveOutOpen(@fWaveHandle,
                                          DWORD(fWaveDevice),
                                          @fWaveFormat,
                                          fWaveThread.ThreadID,
                                          0,
                                          CALLBACK_THREAD));
  Trace(Format('WaveOutOpen handle %d', [fWaveHandle]));

end;

procedure TAudioOut.CloseDevice;
begin
  MMCheck(Format('device %d WaveOutClose', [fWaveDevice]), WaveOutClose(fWaveHandle));
  fWaveHandle := 0;
end;

procedure TAudioOut.ResetDevice;
begin
  if (fWaveHandle <> 0) then
    MMCheck(Format('device %d WaveOutReset', [fWaveDevice]), WaveOutReset(fWaveHandle));
end;


procedure TAudioOut.PrepareBuffer(BufferIndex : Cardinal);
begin
  MMCheck(Format('device %d WaveOutPrepareHeader(%d)', [fWaveDevice, BufferIndex]), WaveOutPrepareHeader(fWaveHandle, @fWaveHeaders[BufferIndex], sizeof(fWaveHeaders[BufferIndex])));
end;

procedure TAudioOut.UnprepareBuffer(BufferIndex : Cardinal);
begin
  MMCheck(Format('device %d WaveUnPrepareHeader(%d)', [fWaveDevice, BufferIndex]), WaveOutUnprepareHeader(fWaveHandle, @fWaveHeaders[BufferIndex], sizeof(fWaveHeaders[BufferIndex])));
end;

procedure TAudioOut.SendBuffer(BufferIndex : Cardinal);
begin
  MMCheck(Format('device %d WaveWrite(%d)', [fWaveDevice, BufferIndex]), WaveOutWrite(fWaveHandle, @fWaveHeaders[BufferIndex], sizeof(fWaveHeaders[BufferIndex])));
  BuffersOut := BuffersOut + 1;
end;

procedure TAudioOut.CreateQueue;
var
  i : Cardinal;
begin

  Trace(Format('AudioOut %d CreateQueue', [fWaveDevice]), lsInformation);
  for i := Low(fWaveBuffers) to High(fWaveBuffers) do
  begin

    with fWaveHeaders[i] do
    begin
        dwbufferlength := fbufferSize;
        dwbytesrecorded := 0;
        dwuser := 0;
        dwflags := 0;
        dwloops := 0;
        lpnext := nil;
        reserved := 0;
     end;

    PrepareBuffer(i);

    {get data for the buffer in the callback}
    BufferNeeded(i);
    SendBuffer(i);
  end;

end;


procedure TAudioOut.DeleteQueue;
var
  i : Cardinal;
begin

  Trace(Format('AudioOut %d DeleteQueue', [fWaveDevice]), lsInformation);
  for i := Low(fWaveBuffers) to High(fWaveBuffers) do
  begin
    UnprepareBuffer(i);
  end;

end;


procedure TAudioOut.CreateBuffers;
var
  i : Cardinal;
begin
  Trace(Format('AudioOut %d CreateBuffers', [fWaveDevice]), lsInformation);
  SetLength(fWaveHeaders, fBufferCount);
  SetLength(fWaveBuffers, fBufferCount);

  for i := Low(fWaveBuffers) to High(fWaveBuffers) do
  begin
    GetMem(fWaveBuffers[i], fBufferSize);
    ZeroMemory(fWaveBuffers[i], fBufferSize);

    with fWaveHeaders[i] do
    begin
        lpdata := PAnsiChar(fWaveBuffers[i]);
        dwbufferlength := fbufferSize;
        dwbytesrecorded := 0;
        dwuser := 0;
        dwflags := 0;
        dwloops := 0;
        lpnext := nil;
        reserved := 0;
     end;

  end;

end;

procedure TAudioOut.DeleteBuffers;
var
  i : Cardinal;
begin
  Trace(Format('AudioOut %d DeleteBuffers', [fWaveDevice]), lsInformation);
  {delete the byte buffers}
  for i := Low(fWaveBuffers) to High(fWaveBuffers) do
  begin
    Dispose(fWaveBuffers[i]);
  end;

  {this resets the arrays appropriately}
  SetLength(fWaveHeaders, 0);
  SetLength(fWaveBuffers, 0);

end;


procedure TAudioOut.SetBufferSize(NewVal : Cardinal);
begin
  
  if (fRequestedBufferSize <> NewVal) then
  begin
    if (Active) then
      InvalidOp(sCannotSetBufferSize + sColon + sAudioOutActive);

    fRequestedBufferSize := NewVal;
    DeleteBuffers;
    FixupWaveFormat;
    CreateBuffers;
  end;
end;


procedure TAudioOut.SetBufferCount(NewVal : Cardinal);
begin

  {could reallocate on the fly, but...}
  if (NewVal <> fBufferCount) then
  begin
    if (Active) then
      InvalidOp(sCannotSetBufferCount + sColon + sAudioOutActive);
    DeleteBuffers;
    fBufferCount := NewVal;
    CreateBuffers;
  end;

end;

procedure TAudioOut.SetStereo(NewVal : Boolean);
begin
  if (NewVal <> Stereo) then
  begin
    if (Active) then
      InvalidOp(sCannotSetStereo + sColon + sAudioOutActive);
    if NewVal then
       FWaveFormat.nChannels := 2
    else
       FWaveFormat.nChannels := 1;
    FixupWaveFormat;
  end;
end;


function TAudioOut.GetBits : Word;
begin
  Result := fWaveFormat.wBitsPerSample;
end;

procedure TAudioOut.SetBits(NewVal : Word);
begin

  if (NewVal <> Quantization) then
  begin
    if (Active) then
      InvalidOp(sCannotSetBits + sColon + sAudioOutActive);
    case NewVal of
    8,16:
      {}
    else
      InvalidOp(Format(sInvalidBitsPerSample, [NewVal]));
    end; {case}

    fWaveFormat.wBitsPerSample := NewVal;
    FixupWaveFormat;
  end;
end;

function TAudioOut.GetFrameRate : Cardinal;
begin
   Result := FWaveFormat.nSamplesPerSec;
end;

procedure TAudioOut.SetFrameRate(NewVal : Cardinal);
begin
  if (NewVal <> FrameRate) then
  begin
    if (Active) then
      InvalidOp(sCannotSetFrameRate + sColon + sAudioOutActive);
     FWaveFormat.nSamplesPerSec := NewVal;
     FixupWaveFormat;
   end;
end;

function TAudioOut.GetStereo : Boolean;
begin
  Result := (FWaveFormat.nChannels = 2);
end;

procedure TAudioOut.SetWaveDevice(NewVal : integer);
begin

  if (NewVal <> fWaveDevice) then
  begin
    if (Active) then
      InvalidOp(sCannotSetWaveDevice + sColon + sAudioOutActive);

    if (NewVal <> fWaveDevice) then
    begin

      if ((NewVal < integer(WAVE_MAPPER)) or
        (NewVal >= integer(WaveOutGetNumDevs))) then
        InvalidOp(Format(sCannotSetWaveDevice + sColon + sDeviceIDOutOfRangeFmt, [NewVal]));

      if (fWaveHandle <> 0) then
        CloseDevice;
      fWaveDevice := NewVal;
    end;
  end;

end;


procedure TAudioOut.WndProc(var Msg: TMessage);
begin
  try
    case Msg.Msg of
      APPM_BUFFER :
      begin
        BufferNeeded(Msg.WParam);
      end;
      APPM_PLAYDONE :
      begin
        PlayDone;
        ReplyMessage(0);
      end;
    end;
  except
    // Application.HandleException(Self);
  end;
end;


procedure TAudioOut.BufferNeeded(BufferIndex : Cardinal);
begin

  if (Assigned(fOnBufferNeeded)) then
    fOnBufferNeeded(fWaveBuffers[BufferIndex], Cardinal(fBufferSize ));
end;


procedure TAudioOut.PlayDone;
begin
  if Assigned(fOnPlayDone) then
   fOnPlayDone(self);
end;


procedure TAudioOut.DoPlayDone;
begin

  case SynchMethod of

    smCreatorThread :
      SendMessage(fWindowHandle, APPM_PLAYDONE, 0, 0);

    smFreeThreaded :
      PlayDone;

  end;

end;


function TAudioOut.CanOpen: boolean;
begin

  Result := (waveOutOpen( nil, DWORD(fWaveDevice),  @fwaveformat,  0,  0,  WAVE_FORMAT_QUERY) = MMSYSERR_NOERROR);

end;


{  ====  TWaveOutThread  ====}


constructor TWaveOutThread.Create(AudioOut : TAudioOut);
begin
  inherited Create(true);
  fEvent := TEvent.Create(nil, false, false, '');
  FreeOnTerminate := false;
  FAudioOut := AudioOut;
  Priority := AudioOut.ThreadPriority;

end;


procedure TWaveOutThread.Execute;
var
  BufferIndex : Cardinal;
  Msg : TMsg;

begin
  {implement thread code}
  inherited;
  PeekMessage(msg, 0, WM_USER, WM_USER, PM_NOREMOVE); { Create message queue }
  fEvent.SetEvent;
  Suspend;

  repeat

    if not Terminated then
  if (not fAudioOut.Stopping) then
  begin
    repeat
      { need to get this once only ! }
      if PeekMessage(Msg, 0, 0, 0, PM_REMOVE) then
      begin
        try
          case
            Msg.message of
              MM_WOM_DONE :
            begin
              {we need to prevent buffers being re-processed
               when the parent is in the process of stopping}
              { find buffer }
                for BufferIndex := Low(fAudioOut.fWaveHeaders) to High(fAudioOut.fWaveHeaders) do
                begin
                    { find header returned - could just cast it - naughty?}
                  if (PWAVEHDR(Msg.lParam) = @fAudioOut.fWaveHeaders[BufferIndex]) then
                    begin
                        Trace(Format('AudioOut %d returned Buffer %d', [fAudioOut.WaveDevice, BufferIndex]), lsInformation);

                      fAudioOut.Lock;
                      try
                        fAudioOut.UnprepareBuffer(BufferIndex);
                        fAudioOut.BuffersOut := fAudioOut.BuffersOut - 1;
                      finally
                          fAudioOut.Unlock;
                      end;

                        if (fAudioOut.BuffersOut = 0) then
                        begin
                          fAudioOut.DeleteQueue;
                          fAudioOut.CloseDevice;
                        end;

                      break; {for loop}
                    end;
                end;
            end;

              MM_WOM_OPEN :
            begin
              Trace(Format('AudioOut %d opened', [fAudioOut.WaveDevice]), lsNormal);
              fAudioOut.fActive :=  true;
            end;


              MM_WOM_CLOSE :
            begin
              Trace(Format('AudioOut %d closed', [fAudioOut.WaveDevice]), lsNormal);
                { TODO -oPMM -cactions : this does not work, whereas Stop() does }
                fAudioOut.fStopping := true;
                fAudioOut.fActive := false;
                fAudioOut.DoPlayDone;

            end;

          end; {message case}

        except
          on E : EAudio do
          begin
            E.Message := 'Execute: ' +  E.Message;
            raise;
          end;
          else
            raise;
        end;
        {be nice to system in the event there are no more events to process}

        YieldTimeSlice;
      end
      else
      begin
        {be nice to system in the event there are no more events to process}
        YieldTimeSlice;
      end;

    {need to wait for the buffers to be returned}
    until ((fAudioOut.fStopping) and (not fAudioOut.fActive));

    Trace(Format('AudioOut %d thread suspend', [fAudioOut.WaveDevice] ), lsInformation);
    Suspend;
    end {if not stopping}
    else
    begin
      Trace(Format('AudioOut %d Stopping thread suspend', [fAudioOut.WaveDevice] ), lsInformation);
      Suspend;
    end;
       {if not stopping}
  until Terminated;
  Trace(Format('AudioOut %d finished : Quitting Execute', [fAudioOut.WaveDevice]), lsNormal);

end;


procedure TAudioOut.CreateThread;
begin
  fStarting := false;
  fStopping := true;
  fWaveThread := TWaveOutThread.Create(self);
  InterlockedIncrement(ThreadCount);
  { get this thread to create message queue and suspend }
  fWaveThread.Resume;
  YieldTimeSlice;
//  StartCount := GetTickCount;

  case (fWaveThread.fEvent.WaitFor(200)) of
    wrSignaled :
      Trace(Format('Audio out thread %d message queue creation signalled.', [WaveDevice]), lsNormal);
    wrTimeout :
    begin
      Trace(Format('Audio out thread %d message queue creation timeout.', [WaveDevice]), lsError);
      Abort;
    end;
    wrAbandoned :
    begin
      Trace(Format('Audio out thread %d message queue creation abandoned.', [WaveDevice]), lsError);
      Abort;
    end;
    wrError :
    begin
      Trace(Format('Audio out thread %d message queue creation error %s.', [WaveDevice]), lsError);
      Abort;
    end;  
    else
      Trace(Format('Audio out thread %d message queue creation unknown status.', [WaveDevice]), lsError);
      Abort;
  end;



  (*
  while not fWaveThread.Suspended do
  begin
    Sleep(20);
    if (CompareTickCount(StartCount + 200) > 0) then
    begin

      {  }
      WarningMessageAsync(Format('Gave up on wait for thread suspend for device %d'#13#130#13#10 +
                          'this may be bad.', [fWaveDevice]), MB_OK);

      break;

    end;
  end;
  *)
//  InformationMessageAsync(Format('Audio out thread for device %d created.', [fWaveDevice]), MB_OK);

end;

initialization

  UnitID := GetUnitID('AudioOut');

finalization

end.
