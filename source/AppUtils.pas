unit AppUtils;

interface

uses

  Windows,      { TRTLCriticalSection}
  classes,      { TNotifyEvent }
  messages      { TMessage }
  ;


{.$DEFINE VERYVERBOSE}

{*
  A Threadsafe base class supplying internal locking.
}
type
  TThreadSafe = class
  private
    {* internal critical section }
    fCriticalSection : TRTLCriticalSection;

    {* TODO : used to prevent concurrent operations on an object in ther process of destruction - is there a better way? }
    {* destroy in process flag }
    fDestroying : boolean;

  public
    {* locks the object - blocks if already locked in a different thread }
    procedure Lock;
    {* attempts to lock the object - returns true if successful }
    function TryLock : boolean;
    {* unlocks the object}
    procedure Unlock;
    {* virtual constructor  }
    constructor Create; virtual;
    {* virtual destructor }
    destructor Destroy; override;

  end;

  {* A synchroniser class to allow callbacks to specific thread contexts from other threads. }
  TSynchroniser = class(TThreadSafe)
  private
    {* stores the creating thread context ID }
    fCallBackContext : Cardinal;
    {* window handle employed for cross thread calls }
    fWindowHandle : HWND;
    {* callback method to be invoked }
    fMethod : TNotifyEvent;
    {* sets fMethod wrapped in a lock }
    procedure SetMethod(const Value: TNotifyEvent);
  protected
    {* actual runner that invokes fMethod, if assigned }
    procedure DoMethod(Sender : TObject);
    {* handle for the fWindowHandle WndProc }
    procedure WndProc(var Msg: TMessage);
    {* allocates the window handle }
    procedure GetHandle;
    {* frees the window handle }
    procedure FreeHandle;
  public
    {* sets the thread context and obtains a window handle for the current thread context }
    procedure SetContext;
    {* runs the method property, optionally asynchronously }
    procedure RunMethod(Sender : TObject ; ASynch : boolean = false);
    {* the method property }
    property Method : TNotifyEvent read fMethod write SetMethod;
    {* constructor override }
    constructor Create; override;
    {* destructor override }
    destructor Destroy; override;

end;

type
  {* application defined thread class to allow setting the thread name }
  {* TODO : recent VCL versions render the custom code obselete }
  TAppThread = class(TThread)
  private
    {* thread name }
    FThreadName: string;
    {* procedure to set the thread name in the thread context }
    procedure SetThreadName(const Value: string);
  protected
    {* overridden execute procedure for the main thread code }
    procedure Execute; override;
  public
    {* thread name accessor }
    property ThreadName : string read FThreadName write SetThreadName;
    {* overriden destructor }
    destructor Destroy; override;
  end;

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
  {* stub in case win9x -ugh }
  EnterCriticalSection(GlobalCriticalSection);
  try
    Result := (lpCriticalSection.LockCount < 0);
    if Result then
      EnterCriticalSection(lpCriticalSection);

  finally
    LeaveCriticalSection(GlobalCriticalSection);
  end;  {* try / finally }

end;

{* locally override the definition of TryEnterCriticalSection here }

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


{* TThreadSafe }

procedure TThreadSafe.Lock;
begin
  if fDestroying then
    raise EAbort.Create('Destroying - cannot lock');
  EnterCriticalSection(fCriticalSection);
end;

procedure TThreadSafe.Unlock;
begin
  LeaveCriticalSection(fCriticalSection);
end;

function TThreadSafe.TryLock: boolean;
begin
  Result := TryEnterCriticalSection(fCriticalSection);
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


{* TSynchroniser }

constructor TSynchroniser.Create;
begin
  inherited;
  {* initially set to creator context }
  SetContext;
end;

destructor TSynchroniser.Destroy;
begin
  {* free window handle }
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
  {* this is also protected to prevent odd behaviour when the handle is undefined }
  Trace('SetContext', lsInformation);
  Lock;
  try
    {* tests for whether context has been altered }
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
        {* if want caller to continue to run asynchronously }
        if (boolean(Msg.LParam)) then
          ReplyMessage(0);
        DoMethod(TObject(Msg.WParam));
      end
  except
    on E: Exception do
      Trace('Exception in synchroniser :' + E.ClassName + #13#10 + E.Message, lsWarning);

  end

end;


{* TAppThread }

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
