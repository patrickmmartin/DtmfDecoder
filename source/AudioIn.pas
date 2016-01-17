unit AudioIn;

interface

uses
  Windows,       { windows types}
  MMSystem,      { MM types}
  classes,       { TThread}
  SysUtils,      { system stuff}
  Messages,      { Messages}
  AppConsts,     { TThreadsafe}
  AppUtils,      { TThread}
  AudioBase       { Audio Stuff}
  ;

type

  TWaveInThread = class;

  TAudioIn = class(TAudioBase)
  private
    fWaveDevice : integer;
    fWaveHandle : HWAVEIN;
    fWaveFormat : TWAVEFORMATEX;

    fWaveHeaders : array of TWAVEHDR;
    fWaveBuffers : array of PByte;

    fBufferCount : Cardinal;
    fWaveThread : TWaveInThread;
    fBufferSize, fRequestedBufferSize : Cardinal;
    fOnBufferReturned : TBufferReturnEvent;
    fActive : boolean;
    fStopping : boolean;
    fStarting : boolean;
    fPaused : boolean;
    fSynchMethod : TSynchMethod;
    fWindowHandle : HWND;
    fBuffersOut : integer;
    fThreadPriority : TThreadPriority;
    fGetVolume : boolean;
    fVolume : double;
    fDeviceOpened : boolean;

    procedure OpenDevice;
    procedure CloseDevice;

    procedure ResetDevice;
    procedure StartDevice;
    procedure StopDevice;

    procedure FixupWaveFormat;
    procedure PrepareBuffer(BufferIndex : Cardinal);
    procedure UnprepareBuffer(BufferIndex : Cardinal);
    procedure SendBuffer(BufferIndex : Cardinal);

    procedure CreateQueue;
    procedure DeleteQueue;

    procedure CreateBuffers;
    procedure DeleteBuffers;
    procedure BufferFilled(BufferIndex : Cardinal);
    procedure DoBufferFilled(BufferIndex : Cardinal);
    {! window procedure for the component
    @todo need to delegate to suitable exception handler }
    procedure WndProc(var Msg: TMessage);

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
    procedure SetActive(NewVal : boolean);
    procedure CreateThread;
    procedure InvalidateHandle;
    function CheckHandleValid : boolean;
  protected
    { implement this }
    procedure WaveError(Msg : string ; Err :  MMResult); override;


  public
    constructor Create; override;
    destructor Destroy; override;

    procedure Start;
    procedure Stop;

    property OnBufferFilled : TBufferReturnEvent read fOnBufferReturned write fOnBufferReturned;
    property Active : boolean read fActive write SetActive;
    property Stopping : boolean read fStopping write fStopping;
    property SynchMethod : TSynchMethod read fSynchMethod write fSynchMethod;

    property BufferSize : Cardinal read fBufferSize write SetBufferSize;
    property BufferCount : Cardinal read fBufferCount write SetBufferCount;
    property Framerate : Cardinal read GetFrameRate write SetFrameRate;
    property Stereo : boolean read GetStereo write SetStereo;
    property Quantization : Word read GetBits write SetBits;
    property WaveDevice : integer read fWaveDevice write SetWaveDevice;
    property BuffersOut : integer read fBuffersOut write fBuffersOut;
    property Device : integer read fWaveDevice write SetWaveDevice;
    property ThreadPriority : TThreadPriority read fThreadPriority write fThreadPriority;
    property WindowHandle : HWND read FWindowHandle;
    property GetVolume : boolean read fGetVolume write fGetVolume;
    property Volume : double read fVolume;
    function CanOpen : boolean;

  end;

  TWaveInThread = class (TAppThread)

  private
    fAudioIn : TAudioIn;
  protected

  public
    constructor Create(AudioIn : TAudioIn);
    {! execute method for the thread
    @todo delegate to suitable exception handler }
    procedure Execute; override;
  end;



implementation

uses
  typinfo       { BooleanIdents }
  ;

resourcestring
  sAudioInActive = 'Audio In Device is Active';
  sWaveInThread = 'Wave In ';

const
  { not much use increasing this unless sustained CPU load is experienced}
  IN_BUFFERS_DEFAULT = 2;
  { best size for DTMF chunks, though a can be little heavy on CPU }
  IN_BUFFER_SIZE_DEFAULT = 512;


var UnitID : BYTE;

procedure Trace(const Msg : string ; const LogSeverity : TLogSeverity = lsInformation);

begin
  AppConsts.Trace(UnitId, Msg, LogSeverity);
end;

var
  ThreadCount : integer = 0;


{ TAudioIn }


procedure TAudioIn.WaveError(Msg : String ; Err :  MMRESULT);
var
  errorBuf : array[0..MAXERRORLENGTH + 1] of Char;
begin
  errorBuf[0] := #0;
  WaveInGetErrorText(Err, errorBuf, sizeof(errorBuf) -1 );
  raise EAudioWave.CreateError(Msg + #13#10 + errorBuf, Err);

end;


procedure TAudioIn.FixupWaveFormat;
begin

  with fWaveFormat do
   begin
      wFormatTag := WAVE_FORMAT_PCM;
      nBlockAlign := (wBitsPerSample div 8) * nchannels;
      nAvgBytesPerSec := nSamplesPerSec * nBlockAlign;
   end;

  { need to always increase buffer from requested size }
  fbufferSize := fWaveFormat.nblockalign *
                 (fRequestedBufferSize div fWaveFormat.nblockalign);
  if ((fRequestedBufferSize mod fWaveFormat.nblockalign) <> 0) then
    Inc(fbufferSize, fWaveFormat.nblockalign);

end;


constructor TAudioIn.Create;
begin
  inherited;
  fWaveDevice := integer(WAVE_MAPPER);
  InvalidateHandle;
  fBufferCount := IN_BUFFERS_DEFAULT;
  fRequestedBufferSize := IN_BUFFER_SIZE_DEFAULT;

  fActive := false;
  fStopping := false;
  fStarting := false;
  fPaused := false;
  fWindowHandle := 0;
  fBuffersOut := 0;
  fSynchMethod := smCreatorThread;
  fGetVolume := true;
  fThreadPriority := tpNormal;

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

destructor TAudioIn.Destroy;
begin

  if (fActive) then
    Stop;
  if (Assigned (fWaveThread)) then
  begin
    fWaveThread.Terminate;
    fWaveThread.Resume;
    { in case never started }
    fWaveThread.Resume;
  end;

  DeleteBuffers;
  if (fWindowHandle <> 0) then
    DeAllocateHwnd(fWindowHandle);

  inherited;


end;

procedure TAudioIn.SetActive(NewVal : boolean);
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


procedure TAudioIn.Start;
var
  StartCount : Cardinal;
begin

  Trace(Format('AudioIn %d Start', [WaveDevice]), lsInformation);

  { protect this section
    note that as it makes no sense to start from two threads simultaneously,
    the whole chunk can be locked out with a critical section,
    and a flag set to avoid recursion}
  Lock;
  try
    Trace(Format('AudioIn %d Inside lock', [WaveDevice]), lsInformation);
    if ((not fStarting) and (not fActive)) then
    begin

       try
         {query device capabilities}
         MMCheck(sCheckFormat, waveInOpen( nil, DWORD(fWaveDevice),  @fwaveformat,  0,  0,  WAVE_FORMAT_QUERY));
       except
         on E : EAudio do
         begin
           Stop;
           raise;
         end;
       end;

      if (SynchMethod = smCreatorThread) and (fWindowHandle = 0) then
        fWindowHandle := AllocateHWnd(WndProc);

      Trace(Format('AudioIn %d Start Set', [WaveDevice]), lsInformation);
      {create thread, and start}

      if not Assigned(fWaveThread) then
        CreateThread;

      fStarting := true;
      fStopping := false;
      fVolume := -1;

      try
        OpenDevice;
      except
        { flag stop so wave thread will exit loop }
        fStopping := true;
        fStarting := false;
        raise;
      end;  {try }
      fVolume := 0;

      YieldTimeSlice;

      StartCount := GetTickCount;
      fWaveThread.Resume;

      { this appears to be required,
        as Open notification not received when device has been opened for playback }

      Trace(Format('AudioIn %d Waiting for device open from thread', [WaveDevice]), lsInformation);
      while not (fActive) and (CompareTickCount(StartCount + 200) < 0 ) do
      begin

      if (SynchMethod = smCreatorThread) then
        PumpWindowQueue(fWindowHandle)
      else
        PumpThreadQueue;

        Sleep(30);
      end;

      fDeviceOpened := fActive;

      if (fActive) then
      begin
       Trace(Format('AudioIn %d device has opened', [WaveDevice]), lsInformation)
      end
      else
      begin
       Trace(Format('AudioIn %d device presumed already open', [WaveDevice]), lsWarning);
       fActive := true;
      end;

      CreateQueue;
      Trace(Format('AudioIn %d device queue created', [WaveDevice]), lsInformation);
      StartDevice;
      Trace(Format('AudioIn %d device started', [WaveDevice]), lsInformation);

    end;
  finally
    Unlock;
  end;

end;

procedure TAudioIn.Stop;
begin

  Trace(Format('AudioIn %d Stop', [WaveDevice]), lsInformation);
  if (fActive) and (not fStopping) then
  begin
    { the following section is critical,
    as a buffer could potentially be returned after a WaveInReset has been performed,
    this leads to a buffer that is and cannot be returned}
    { note that in contrast to start, because the wavein thread checks stopping,
      we cannot lock for the entire function, as deadlock would occur}
    Lock;
    try
      Trace(Format('AudioIn %d Inside Stoplock', [WaveDevice]), lsInformation);
      fStopping := true;
      fStarting := false;
      Trace(Format('AudioIn %d Stop Set', [WaveDevice]), lsInformation);
    finally
      Unlock;
    end;

    Trace(Format('AudioIn %d Synch Method', [WaveDevice]) + SynchMethodDesc[SynchMethod], lsInformation);

    StopDevice;
    ResetDevice;

    if CheckHandleValid then
    begin
      { occasional hang here on buffersout = 1 }
      Trace(Format('AudioIn %d about to wait for device', [WaveDevice]), lsInformation);
      while (fBuffersOut > 0) do
      begin
        { if using message synchronisation pump the message queue}
        if (SynchMethod = smCreatorThread) then
          PumpWindowQueue(fWindowHandle)
        else
          PumpThreadQueue;

        Sleep(50);
      end;
      Trace(Format('AudioIn %d wait complete', [WaveDevice]) );
    end  { device handle still valid }
    else
    begin
      BuffersOut := 0;
    end;

    DeleteQueue;
    CloseDevice;

    {need this?}
    { the device close message can NOT be relied upon}


    if (CheckHandleValid) and (fDeviceOpened) then
    begin
      Trace(Format('AudioIn %d opened device : waiting for close', [fWaveDevice]), lsInformation);
      while (fActive) do
      begin
        { if using message synchronisation pump the message queue}
        if (SynchMethod = smCreatorThread) then
          PumpWindowQueue(fWindowHandle)
        else
          PumpThreadQueue;

        Sleep(50);
      end;
    end
    else

    begin
      Trace(Format('AudioIn %d Did not get device open', [fWaveDevice]), lsWarning);
      fActive := false;
    end;

    Trace(Format('AudioIn %d inactive', [fWaveDevice]), lsInformation);

    if (FWindowHandle <> 0) then
    begin
      DeallocateHWnd(fWindowHandle);
      fWindowHandle := 0;
    end;
  end;  {if fActive}
end;

{ start of MMsystem wrappers }

procedure TAudioIn.OpenDevice;
begin
  try
    { TODO : is WAVE_FORMAT_DIRECT of any use ? }
    MMCheck(Format('device%d WaveInOpen', [fWaveDevice]),
            WaveInOpen(@fWaveHandle, DWORD(fWaveDevice), @fWaveFormat, fWaveThread.ThreadID,
                          0, CALLBACK_THREAD));
  except
    InvalidateHandle;
    raise;
  end;
end;

procedure TAudioIn.CloseDevice;
begin
  try
    if CheckHandleValid then
      MMCheck(Format('device %d WaveInClose', [fWaveDevice]), WaveInClose(fWaveHandle))
    else
     Trace('WaveInClose on invalid device handle ignored', lsWarning);
  finally
    InvalidateHandle;
  end;
end;

procedure TAudioIn.ResetDevice;
begin
  try
    if CheckHandleValid then
      MMCheck(Format('device %d WaveInReset', [fWaveDevice]), waveInReset(fWaveHandle))
    else
     Trace('WaveInReset on invalid device handle ignored', lsWarning);
  except
    InvalidateHandle;
    raise;
  end;
end;

procedure TAudioIn.StartDevice;
begin
  Trace(Format('AudioIn %d StartDevice', [fWaveDevice]), lsInformation);
  try

    if CheckHandleValid then
      MMCheck(Format('device %d WaveInStart', [fWaveDevice]), waveInStart(fWaveHandle))
    else
     Trace('WaveInStart on invalid device handle ignored', lsWarning);

  except
    InvalidateHandle;
    raise;
  end;
end;

procedure TAudioIn.StopDevice;
begin
  Trace(Format('AudioIn %d StopDevice', [fWaveDevice]), lsInformation);
  {this appears to be asynchronous, dependent upon device ?}
  try
    if CheckHandleValid then
      MMCheck(Format('device %d WaveInStop', [fWaveDevice]), waveInStop(fWaveHandle))
    else
     Trace('WaveInStop on invalid device handle', lsWarning);
  except
    InvalidateHandle;
    raise;
  end;
end;

procedure TAudioIn.PrepareBuffer(BufferIndex : Cardinal);
begin
  { The lpData, dwBufferLength, and dwFlags members of the WAVEHDR structure
    must be set before calling this function (dwFlags must be zero).  }
  try
    if CheckHandleValid then
      MMCheck(Format('device %d WaveInPrepareHeader(%d)', [fWaveDevice, BufferIndex]), WaveInPrepareHeader(fWaveHandle, @fWaveHeaders[BufferIndex], sizeof(TWaveHdr)))
    else
     Trace('WaveInPrepareHeader on invalid device handle ignored', lsWarning);
  except
    InvalidateHandle;
    raise;
  end;
end;

procedure TAudioIn.UnprepareBuffer(BufferIndex : Cardinal);
begin
  try
    if CheckHandleValid then
      MMCheck(Format('device %d WaveInUnPrepareHeader(%d)', [fWaveDevice, BufferIndex]), WaveInUnprepareHeader(fWaveHandle, @fWaveHeaders[BufferIndex], sizeof(TWaveHdr)))
    else
     Trace('WaveInUnPrepareHeader on invalid device handle ignored', lsWarning);
  except
    InvalidateHandle;
    raise;
  end;
end;

procedure TAudioIn.SendBuffer(BufferIndex : Cardinal);
begin
  try
    if CheckHandleValid then
      MMCheck(Format('device %d WaveInAddBuffer(%d)', [fWaveDevice, BufferIndex]), waveInAddBuffer(fWaveHandle, @fWaveHeaders[BufferIndex], sizeof(TWaveHdr)))
    else
     Trace('WaveInAddBuffer on invalid device handle', lsWarning);
    Inc(fBuffersOut);
  except
    InvalidateHandle;
    raise;
  end;
end;


procedure TAudioIn.CreateQueue;
var
  i : Cardinal;
begin

  Trace(Format('AudioIn %d CreateQueue', [fWaveDevice]), lsInformation);
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
    SendBuffer(i);
  end;

end;


procedure TAudioIn.DeleteQueue;
var
  i : Cardinal;
begin
  Trace(Format('AudioIn %d DeleteQueue', [fWaveDevice]), lsInformation);
  for i := Low(fWaveBuffers) to High(fWaveBuffers) do
  begin
    UnprepareBuffer(i);
  end;

end;


procedure TAudioIn.CreateBuffers;
var
  i : Cardinal;
begin
  Trace(Format('AudioIn %d CreateBuffers', [fWaveDevice]), lsInformation);
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

procedure TAudioIn.DeleteBuffers;
var
  i : Cardinal;
begin

  Trace(Format('AudioIn %d DeleteBuffers', [fWaveDevice]), lsInformation);
  {delete the byte buffers}
  for i := Low(fWaveBuffers) to High(fWaveBuffers) do
  begin
    Dispose(fWaveBuffers[i]);
  end;

  {this resets the arrays appropriately}
  SetLength(fWaveHeaders, 0);
  SetLength(fWaveBuffers, 0);

end;


procedure TAudioIn.SetBufferSize(NewVal : Cardinal);
begin
  if (NewVal <> fRequestedBufferSize) then
  begin
    if (Active) then
      InvalidOp(sCannotSetBufferSize + sColon + sAudioInActive);

    fRequestedBufferSize := NewVal;
    DeleteBuffers;
    FixupWaveFormat;
    CreateBuffers;
 end;
end;


procedure TAudioIn.SetBufferCount(NewVal : Cardinal);
begin
  if (NewVal <> fBufferCount) then
  begin
    {could reallocate on the fly, but...}
    if (Active) then
      InvalidOp(sCannotSetBufferCount + sColon + sAudioInActive);
    DeleteBuffers;
    fBufferCount := NewVal;
    CreateBuffers;
  end;

end;

procedure TAudioIn.SetStereo(NewVal : Boolean);
begin
  if (NewVal <> Stereo) then
  begin
    if (Active) then
      InvalidOp(sCannotSetStereo + sColon + sAudioInActive);
    if NewVal then
       FWaveFormat.nChannels := 2
    else
       FWaveFormat.nChannels := 1;
    FixupWaveFormat;
  end;
end;


function TAudioIn.GetBits : Word;
begin
  Result := fWaveFormat.wBitsPerSample;
end;

procedure TAudioIn.SetBits(NewVal : Word);
begin

  if (NewVal <> Quantization) then
  begin
    if (Active) then
      InvalidOp(sCannotSetBits + sColon + sAudioInActive);
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

function TAudioIn.GetFrameRate : Cardinal;
begin
   Result := FWaveFormat.nSamplesPerSec;
end;

procedure TAudioIn.SetFrameRate(NewVal : Cardinal);
begin
  if (NewVal <> FrameRate) then
  begin
    if (Active) then
      InvalidOp(sCannotSetFrameRate + sColon + sAudioInActive);
     FWaveFormat.nSamplesPerSec := NewVal;
     FixupWaveFormat;
   end;
end;

function TAudioIn.GetStereo : Boolean;
begin
  Result := (FWaveFormat.nChannels = 2);
end;

procedure TAudioIn.SetWaveDevice(NewVal : integer);
begin

  if (NewVal <> fWaveDevice) then
  begin
    if (Active) then
      InvalidOp(sCannotSetWaveDevice + sColon + sAudioInActive);
    if ((NewVal < integer(WAVE_MAPPER)) or
      (NewVal >= integer(WaveInGetNumDevs))) then
      InvalidOp(Format(sCannotSetWaveDevice + sColon + sDeviceIDOutOfRangeFmt, [NewVal]));

    if CheckHandleValid then
      CloseDevice;
    fWaveDevice := NewVal;
  end;

end;


procedure TAudioIn.WndProc(var Msg: TMessage);
begin
  try
    case Msg.Msg of
    APPM_BUFFER :
      DoBufferFilled(Msg.WParam);
    end;
  except
    // Application.HandleException(Self);
  end;
end;


procedure TAudioIn.BufferFilled(BufferIndex : Cardinal);
var
  VolTotal: integer;
  i : integer;
  Counted : integer;
const
  Step = 1;
  BYTEMax = (High(BYTE) + 1) div 2;
  SmallIntMax = High(SmallInt);
begin

  { calculate volume first }
  if (fGetVolume) and (fWaveHeaders[BufferIndex].dwBytesRecorded > 0) then
  begin
    { get volume now }
    VolTotal := 0;
    case fWaveFormat.wBitsPerSample of
      16 :
      begin
        Counted := fWaveHeaders[BufferIndex].dwBytesRecorded div (2 * Step);
        for i := 0 to Counted do
        begin
          VolTotal := VolTotal + Abs(SmallInt(PWordArray(fWaveHeaders[BufferIndex].lpData)[i]));
        end;
        fVolume := (VolTotal) / (SmallIntMax * Counted);
      end;
      8 :
      begin
        Counted := fWaveHeaders[BufferIndex].dwBytesRecorded div Step;
        for i := 0 to Counted do
        begin
          VolTotal := VolTotal + PByteArray(fWaveHeaders[BufferIndex].lpData)[i];
        end;
        fVolume := (VolTotal) / (BYTEMax * Counted);
      end;

      { only cases catered for }

    end; { case }
  end;

  { kick off event now in desired thread conetxt, if required }

  if (Assigned(fOnBufferReturned) and (fWaveHeaders[BufferIndex].dwBytesRecorded <> 0)) then
  begin
    case SynchMethod of
      smCreatorThread :
        SendMessage(fWindowHandle, APPM_BUFFER, BufferIndex, 0);
      smFreeThreaded :
        DoBufferFilled(BufferIndex);
    end;
  end;

end;

procedure TAudioIn.DoBufferFilled(BufferIndex : Cardinal);
begin

  {dispatch the event}

  if (Assigned(fOnBufferReturned) and (fWaveHeaders[BufferIndex].dwBytesRecorded <> 0)) then
    fOnBufferReturned(fWaveBuffers[BufferIndex], Cardinal(fWaveHeaders[BufferIndex].dwBytesRecorded ));

end;


function TAudioIn.CanOpen: boolean;
begin

  Result := (waveInOpen( nil, DWORD(fWaveDevice),  @fwaveformat,  0,  0,  WAVE_FORMAT_QUERY) = MMSYSERR_NOERROR);

end;


{  ====  TWaveInThread  ====}


constructor TWaveInThread.Create(AudioIn : TAudioIn);
begin
  inherited Create(true);
  FreeOnTerminate := true;
  FAudioIn := AudioIn;
  Priority := AudioIn.ThreadPriority;

end;



procedure TWaveInThread.Execute;
var
  BufferIndex : Cardinal;
  Msg : TMsg;
  Stopping : boolean;

begin
  {implement thread code}
  inherited;
  PeekMessage(msg, 0, WM_USER, WM_USER, PM_NOREMOVE); { Create message queue }
  Suspend;

  repeat
  if (not fAudioIn.Stopping) then
  begin
    try
      repeat
        { need to get this once only ! }
        if PeekMessage(Msg, 0, 0, 0, PM_REMOVE) then
        begin
          try
            case
              Msg.message of
              MM_WIM_DATA :
              begin
                {we need to prevent buffers being re-processed
                 when the parent is in the process of stopping}
                { find buffer }
                  for BufferIndex := Low(fAudioIn.fWaveHeaders) to High(fAudioIn.fWaveHeaders) do
                  begin
                    { find header returned - could use WHDR_DONE flag ?}
                    if (PWAVEHDR(Msg.lParam) = @fAudioIn.fWaveHeaders[BufferIndex]) then
                      begin
                        Trace(Format('AudioIn %d returned Buffer %d', [fAudioIn.WaveDevice, BufferIndex]), lsInformation);

                        fAudioIn.Lock;
                        try
                          fAudioIn.UnprepareBuffer(BufferIndex);
                          fAudioIn.BuffersOut := fAudioIn.BuffersOut - 1;
                        finally
                          fAudioIn.UnLock;
                        end;
                        {NB as this may use SendMessage,
                        we need to ensure the main thread is not blocked to call this }
                        fAudioIn.BufferFilled(BufferIndex);

                        fAudioIn.Lock;
                        try
                          Stopping := fAudioIn.Stopping;
                          if (not Stopping) then
                          begin
                            fAudioIn.PrepareBuffer(BufferIndex);
                            fAudioIn.SendBuffer(BufferIndex);
                          end;

                        finally
                          fAudioIn.Unlock;
                        end;
                        break; {for loop}
                      end;
                  end;
              end;

              MM_WIM_OPEN :
              begin
                Trace(Format('AudioIn %d opened', [fAudioIn.WaveDevice]), lsNormal);
                fAudioIn.fActive :=  true;
              end;


              MM_WIM_CLOSE :
              begin
                Trace(Format('AudioIn %d closed', [fAudioIn.WaveDevice]), lsNormal);
                fAudioIn.fActive := false;
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
      until ((fAudioIn.fStopping) and (not fAudioIn.fActive));

      except
        //Application.HandleException(self);
      end;

      Trace(Format('AudioIn %d thread suspend', [fAudioIn.WaveDevice] ), lsInformation);
      Suspend;
    end
    else
    begin
      Trace(Format('AudioIn %d Stopping thread suspend', [fAudioIn.WaveDevice] ), lsInformation);
      Suspend;
    end;
       {if not stopping}
  until Terminated;
  Trace(Format('AudioIn %d thread quitting execute', [fAudioIn.WaveDevice] ), lsNormal);

end;


procedure TAudioIn.CreateThread;
begin
  fStarting := false;
  fStopping := true;

  fWaveThread := TWaveInThread.Create(self);
  InterlockedIncrement(ThreadCount);
  fWaveThread.ThreadName := sWaveInThread + IntToStr(ThreadCount);
  { get this thread to create message queue }
  fWaveThread.Resume;
  YieldTimeSlice;
  while not fWaveThread.Suspended do
  begin
    Sleep(20);
  end;

end;

procedure TAudioIn.InvalidateHandle;
begin
  fWaveHandle := HWAVEOUT(INVALID_HANDLE_VALUE);
//  fStopping := true;
//  fStarting := false;
end;

function TAudioIn.CheckHandleValid: boolean;
begin
  Result := DWORD(fWaveHandle) <> INVALID_HANDLE_VALUE;
end;


initialization

  UnitID := GetUnitID('AudioIn');

finalization


end.
