unit AppUtils;

interface

uses

  Windows,      { TRTLCriticalSection}
  classes,      { TNotifyEvent }
  messages      { TMessage }
  ;


{.$DEFINE VERYVERBOSE}
  { very verbose tracing }

  {.$DEFINE NO_LOCK}
  { turn off locking }

  { lockable object ancestor }

type TThreadSafe = class
  private
    fCriticalSection : TRTLCriticalSection;
    fDestroying : boolean;

  public
    procedure Lock;
    function TryLock : boolean;
    procedure Unlock;
    constructor Create; virtual;
    destructor Destroy; override;

  end;

{ synchroniser to allow callbacks to specific thread contexts }
type TSynchroniser = class(TThreadSafe)
  private
    fCallBackContext : Cardinal;
    fWindowHandle : HWND;
    fMethod : TNotifyEvent;
    procedure SetMethod(const Value: TNotifyEvent);
  protected
    procedure DoMethod(Sender : TObject);
    procedure WndProc(var Msg: TMessage);
    procedure GetHandle;
    procedure FreeHandle;
  public
    procedure SetContext;
    procedure RunMethod(Sender : TObject ; ASynch : boolean = false);

    property Method : TNotifyEvent read fMethod write SetMethod;
    constructor Create; override;
    destructor Destroy; override;

end;

{ static buffer memorystream class to get round memory allocation errors - grrr }
type
  TAppThread = class(TThread)
  private
    FThreadName: string;
    procedure SetThreadName(const Value: string);
  protected
    procedure Execute; override;
  public
    property ThreadName : string read FThreadName write SetThreadName;
    destructor Destroy; override;
  end;

  { thread class descendant that creates a message queue
    and implements a thread safe method of waiting for this }
resourcestring
  sSuspended = 'suspended';
  sRunning = 'running';

const
  SuspendedDesc : array[boolean] of string = (sRunning, sSuspended);



implementation

uses
  SysUtils,     { Exception }
  AppConsts     { Tracing }
  ;

var UnitID : BYTE;

procedure Trace(const Msg : string ; const LogSeverity : TLogSeverity = lsInformation);

begin
  AppConsts.Trace(UnitId, Msg, LogSeverity);
end;

var
  GlobalCriticalSection : TRTLCriticalSection;

var
  TryEnterCriticalSection :
     function (var lpCriticalSection: TRTLCriticalSection): BOOL;  stdcall = nil;



function BackFillTryEnterCriticalSection(var lpCriticalSection: TRTLCriticalSection) : boolean; stdcall;
begin
  { stub in case win9x -ugh }
  EnterCriticalSection(GlobalCriticalSection);
  try
    Result := (lpCriticalSection.LockCount < 0);
    if Result then
      EnterCriticalSection(lpCriticalSection);

  finally
    LeaveCriticalSection(GlobalCriticalSection);
  end;  { try / finally }

end;

{ locally override the definition of TryEnterCriticalSection here }

procedure InitTryEnterCriticalSectionPtr;
var
  Kernel: THandle;
begin
  Kernel := GetModuleHandle(Windows.Kernel32);
  if Kernel <> 0 then
    @TryEnterCriticalSection := GetProcAddress(Kernel, 'TryEnterCriticalSection');
  if not Assigned(TryEnterCriticalSection) then
    TryEnterCriticalSection := @BackfillTryEnterCriticalSection;
end;


{ TThreadSafe }

procedure TThreadSafe.Lock;
begin
  if fDestroying then
    raise EAbort.Create('Destroying - cannot lock');
  {$IFNDEF NO_LOCK}
  EnterCriticalSection(fCriticalSection);
  {$ENDIF}
end;

procedure TThreadSafe.Unlock;
begin
  {$IFNDEF NO_LOCK}
  LeaveCriticalSection(fCriticalSection);
  {$ENDIF}
end;

function TThreadSafe.TryLock: boolean;
begin
  {$IFNDEF NO_LOCK}
  Result := TryEnterCriticalSection(fCriticalSection);
  {$ELSE}
  Result := true;
  {$ENDIF}
end;


constructor TThreadSafe.Create;
begin
  inherited;
  InitializeCriticalSection(fCriticalSection);
end;

destructor TThreadSafe.Destroy;
begin
  {protect against destruction while locked ?}
  fDestroying := true;
  DeleteCriticalSection(fCriticalSection);
  inherited;
end;
const
  RM_SYNCH = WM_APP;


{ TSynchroniser }

constructor TSynchroniser.Create;
begin
  inherited;
  { initially set to creator context }
  SetContext;
end;

destructor TSynchroniser.Destroy;
begin
  { free window handle }
  FreeHandle;
  inherited;

end;

procedure TSynchroniser.DoMethod(Sender: TObject);
begin
  {$IFDEF VERYVERBOSE}
  Trace(Format('DoMethod', [GetCurrentThreadID]), lsInformation);
  {$ENDIF}
  if Assigned(fMethod) then
    fMethod(Sender);
end;

procedure TSynchroniser.FreeHandle;
begin
  Lock;
  try
    if (fWindowHandle <> 0) then
    begin
      DeallocateHWnd(fWindowHandle);
      fWindowHandle := 0;
    end;
  finally
    Unlock;
  end;
end;

procedure TSynchroniser.GetHandle;
begin
  Lock;
  try
    if (fWindowHandle = 0) then
      fWindowHandle := AllocateHwnd(WndProc);
  finally
    Unlock;
  end;
end;

procedure TSynchroniser.RunMethod(Sender: TObject ; ASynch : boolean = false);
begin
  {$IFDEF VERYVERBOSE}
  Trace('RunMethod start');
  {$ENDIF}
  if (GetCurrentThreadId <> fCallBackContext) then
  begin
    {$IFDEF VERYVERBOSE}
    Trace('Contexts differ : forcing switch', lsInformation);
    {$ENDIF}
    SendMessage(fWindowHandle, RM_SYNCH, Integer(Sender), Integer(ASynch));
  end
  else
  begin
    {$IFDEF VERYVERBOSE}
    Trace('Contexts same : running directly', lsInformation);
    {$ENDIF}
    DoMethod(Sender);
  end;
  {$IFDEF VERYVERBOSE}
  Trace('RunMethod end', lsInformation);
  {$ENDIF}

end;

procedure TSynchroniser.SetContext;
begin
  { this is also protected to prevent odd behaviour when the handle is undefined }
  Trace('SetContext', lsInformation);
  Lock;
  try
    { tests for whether context has been altered }
    if (fCallBackContext = 0) then
    begin
      Trace('Thread context set', lsInformation);
      fCallBackContext := GetCurrentThreadID;
      GetHandle;
    end
    else
    if (fCallBackContext <> GetCurrentThreadID) then
    begin
      Trace('Thread context altered - get new', lsInformation);
      fCallBackContext := GetCurrentThreadID;
      FreeHandle;
      GetHandle;
    end;
  finally
    UnLock;
  end;

end;

procedure TSynchroniser.SetMethod(const Value: TNotifyEvent);
begin
  if (@Value <> @fMethod) then
  begin
    Lock;
    try
      fMethod := Value;
    finally
      UnLock;
    end;
  end;  

end;

procedure TSynchroniser.WndProc(var Msg: TMessage);
begin
  try
    if Msg.Msg = RM_SYNCH then
      begin
        { if want caller to continue to run asynchronously }
        if (boolean(Msg.LParam)) then
          ReplyMessage(0);
        DoMethod(TObject(Msg.WParam));
      end
  except
    on E: Exception do
      Trace('Exception in synchroniser :' + E.ClassName + #13#10 + E.Message, lsWarning);

  end

end;


{ TAppThread }

destructor TAppThread.Destroy;
begin
  RemoveThreadName(FThreadName);
  inherited;

end;

procedure TAppThread.Execute;
begin
  if (fThreadName = '') then
    AddThreadName(ClassName, self)
  else
    AddThreadName(FThreadName, self);

end;

procedure TAppThread.SetThreadName(const Value: string);
begin
  if (FThreadName = '') then
    FThreadName := Value;
end;



initialization

  UnitID := GetUnitID('AppUtils');
  InitializeCriticalSection(GlobalCriticalSection);
  InitTryEnterCriticalSectionPtr;

finalization

  DeleteCriticalSection(GlobalCriticalSection);

end.
