unit AppConsts;

interface

uses
  SysUtils,     { UpperCase }
  Windows,      { HWND }
  Forms,        { TForm }
  messages,
  classes,      { TComponent}
  stdctrls      { TListBox }
  ;

  {.$DEFINE VERBOSE}
type
  {* A generic logging event}
  TLogEvent = procedure (Sender : TObject ; const EventTime : TDateTime ; const Msg : string) of object;
  {* a generic parameter validation event}
  TParameterValidateEvent = procedure (const Parameter : string ; var Value : string) of object;
  {* a generic parameter validation event}
  TMsgEvent = procedure (Sender : TObject ; const Msg : string) of object;
  {* progress update event }
  TPercentEvent = procedure (Sender : TObject ; const Percent : double);

  {* Exception type for an invalid parameter }
  EParameterError = class(Exception);

  {* A generic synchronisation enum
  @see smCreatorThread - this means a sendmessage is done
    via a window created in the context of the opening thread
  @see smFreeThreaded - this means a callbacks could happen in any thread context
    and the recipient has to be ready for this }
  type TSynchMethod = ( smCreatorThread,
                        smFreeThreaded);


resourcestring
  sCreatorThread = 'Creator thread';
  sFreeThreaded = 'Free threaded';

const
  SynchMethodDesc : array[TSynchMethod] of string = (sCreatorThread, sFreeThreaded);

  {* the numeric characters}
  NumericChars = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  {* the DTMF character set}
  DigitChars = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '#', 'A', 'B', 'C', 'D'];
  {* the common phone keys}
  KeyDigitChars = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '#'];



type
  {* log severity levels ordered by severity }
  TLogSeverity = (lsInformation, lsNormal, lsWarning, lsError);

const
  {* textual descriptions of the log severities }
  LogSeverityDesc : array [TLogSeverity] of string =
                ('Information', 'Normal', 'Warning', 'Error');


{* add log trace
@param UnitID unit ID for tracing
@param Msg trace message
@param LogSeverity severity level
 }
procedure Trace(const UnitID : BYTE; const Msg : string ; const LogSeverity : TLogSeverity = lsInformation);
{* turns all tracing on/off
@param Enable turn on of true
 }
procedure TraceAll(const Enable : boolean);
{* enable / disable tracing by unitname
@param UnitName
@param Add
}
procedure Tracing(const UnitName : string ; const Add : boolean);
{* obtain a unit ID for unit name
@param UnitName
@return the assigned unit ID
}
function GetUnitID(const UnitName : string) : BYTE;

{* shows the visual trace terminal
@param Show - show or hide
}
procedure TraceTerminal(const Show : boolean);

{* log to file or not
@param Write - log to file or not
@todo remove reliance upon Application
}
procedure TraceLog(const Write : boolean);

{* pump the message queue for the given window handle
@param WindowHandle - handle of the window }
procedure PumpWindowQueue(const WindowHandle : HWND);
{* pump the message queue for the current thread
threads in Windows acquire a message queue after certain API calls,
allowing APC and other elements }
procedure PumpThreadQueue;
{* yet another home brew time slice yield method }
procedure YieldTimeSlice;
{* yields for a given time period
@param Period the period to yield for
@see YieldTimeSlice
}
procedure YieldPeriod(const Period : Cardinal);

{* formats a SYSTEMTIME struct into a string representation
@return the time formatted into a string }
function FormatSystemTime(const SystemTime : TSystemTime) : string;
{* returns the current time in TSystemTime format
@return current time }
function NowSystemTime : TSystemTime;
{* compares tick counts returned from GetTickCount.
<p>
wrapper to get round the GetTickCount wrapping issue
returns -1, 0, 1 for TickCount less, equal or more than current GetTickCount
as per standard approach.
Note that due to the 49 day rollover, the mid point is chosen as the
break point, hence counts 25 days appart will fail
@param TickCount - the compared value
@see GetTickCount
@todo could this be a simpler expression?
}
function CompareTickCount(const TickCount : DWORD) : integer;
{* adds a thread name to list for logging
@param Name thread name
@param Thread thread for monitoring the thread status}
procedure AddThreadName(Name : string ; Thread : TThread);
{* removes the thread name
@param name}
procedure RemoveThreadName(Name : string);
{* utility function to return the current thread name
@return the thread name, if registered }
function ThreadName : string;
{* returns all the thread names }
procedure GetThreadNames(NameList : TStringList);

const
  {* windows message for passing a string over }
  APP_STRING_MSG = WM_USER;

var
  {logging severity level }
  LoggingSeverity : TLogSeverity = lsInformation;

  {* yield quantum }
  YieldSleep : integer = 10;

  {now exposed for direct use by applications }
  TraceForm : TForm = nil;
  TraceFormHwnd : HWND = INVALID_HANDLE_VALUE;

{* utility function to return whether a unit is being traced
@param Index
@return are we tracing that unit}

function TraceUnit(Index : BYTE) : boolean;
{* utility function to return whether a unit name
@param Index
@return are we tracing that unit}
function TraceUnitName(Index : BYTE) : string;


{* coverts a Log Severity string to the enum
@param LogSeverityStr
return the TLogSeverity level - defaults to lsInformation
}
function StrToLogSeverity(LogSeverityStr  : string): TLogSeverity;

{ tracing form base prototypes }

type

  TBaseTraceForm = class(TForm)
  protected
    procedure StringMessage(var Msg : TMessage); message APP_STRING_MSG;
  public
    { Public declarations }
    constructor Create(AOwner : TComponent); override;
  end;

  TDefaultTraceForm = class(TBaseTraceForm)
  private
    { Private declarations }
    ListBox : TListBox;
  protected
    procedure StringMessage(var Msg : TMessage); override;
  public
    { Public declarations }
    constructor Create(AOwner : TComponent); override;
  end;

resourcestring
  sYes = 'Yes';
  sNo = 'No';

const
  YesNoDesc : array [boolean] of string = (sNo, sYes);

implementation


uses
  typinfo,      { BooleanIdents }
  controls     { control stuff }
  ;

var
  TracingAll : boolean = false;
  CurrentUnitID : BYTE = 1;
  UseTerminal : boolean = false;
  TraceFile : THandle;
  ThreadNameLock : TRTLCriticalSection;
  ThreadNames : TStringList = nil;

  TraceUnits : array[BYTE] of boolean;
  {short string to avoid problems with re-allocation}
  TraceUnitNames : array[BYTE] of shortstring;
  { whether to not flush to log every time }
  TraceLogLazyWrite : boolean = true;


const

  TraceFmt = '%s [%s] %s: unit %s thread %s';
  TraceListMax  = 1000;


function StrToLogSeverity(LogSeverityStr  : string): TLogSeverity;
var
  i : TLogSeverity;
begin
  Result := Low(i);
  for i := Low(i) to High(i) do
    if UpperCase(LogSeverityStr) = UpperCase(LogSeverityDesc[i]) then
    begin
      Result := i;
      break;
    end;

end;


function TraceUnit(Index : BYTE) : boolean;
begin
  Result := TracingAll or TraceUnits[Index];
end;

function TraceUnitName(Index : BYTE) : string;
begin
  Result := TraceUnitNames[Index];
end;

procedure Trace(const UnitID : BYTE; const Msg : string ; const LogSeverity : TLogSeverity);
var
  TraceStr : string;
{$IFDEF VERBOSE}
  TracePChar : PChar;
  Written : Cardinal;
{$ENDIF}
begin
  if (LogSeverity >= LoggingSeverity) and ( TracingAll or (UnitID = 0) or (TraceUnits[UnitId])) then
  begin
    TraceStr := Format(TraceFmt, [FormatSystemTime(NowSystemTime),
                       LogSeverityDesc[LogSeverity], Msg,
                       TraceUnitNames[UnitId], ThreadName]);

    OutputDebugString(PChar(TraceStr));
  {$IFDEF VERBOSE}

    if IsWindow(TraceFormHWND) then
    begin
      TracePChar := StrAlloc(Length(TraceStr) + 1);
      StrCopy(TracePChar, PChar(TraceStr));
      PostMessage(TraceFormHWND, APP_STRING_MSG, 0, Longint(TracePChar));
    end;

      if (TraceFile <> 0) then
      begin
        TraceStr := TraceStr + #13#10;
        WriteFile(TraceFile, TraceStr[1], Length(TraceStr), Written, nil);
        if not TraceLogLazyWrite then
          FlushFileBuffers(TraceFile);
      end;
  {$ENDIF}
    end
end;

procedure TraceAll(const Enable : boolean);
begin
  TracingAll := Enable;
end;

procedure Tracing(const UnitName : string ; const Add : boolean);
var
  i : BYTE;
begin

  { never allow 0 to be turned off }
  for i := 1 to High(BYTE) do
  begin
    if (AnsiCompareText(TraceUnitNames[i], UnitName) =  0) then
    begin
      if (Add) then
      begin
        TraceUnits[i] := true;
        Trace(i, ' tracing started', lsInformation);
        exit;
      end
      else
      begin
        Trace(i, ' tracing stopped', lsInformation);
        TraceUnits[i] := false;
        exit;
      end;
    end;
  end;

end;


function GetUnitID(const UnitName : string) : BYTE;
var
  i : BYTE;
begin

  { 0 is reserved }
  for i := Low(i) + 1 to High(i) do
  if (AnsiCompareText(TraceUnitNames[i], UnitName) = 0) then
  begin
    Result := i;
    exit;
  end;

  {else need new ID}
  Result := CurrentUnitID;
  Inc(CurrentUnitID);
  TraceUnitNames[Result] := UnitName;
  Trace(Result, 'trace ID obtained for ' + UnitName + ' ' + TraceUnitNames[Result], lsInformation);
end;



procedure TraceTerminal(const Show : boolean);
begin

  if (Show) then
  begin
    if not (Assigned(TraceForm)) then
    begin
      TraceForm := TDefaultTraceForm.Create(nil);
      TraceForm.Position := poDesktopCenter;
      TraceForm.Caption := 'trace log';
      TraceFormHWND := TraceForm.Handle;
      TraceForm.Show;

    end;
  end
  else
  begin
    if Assigned(TraceForm) then
    TraceForm.Release;
      TraceForm := nil;
      TraceFormHWND := INVALID_HANDLE_VALUE;
  end;

end;

procedure TraceLog(const Write : boolean);
var
  Written : Cardinal;
  TraceStr  : string;
  SystemTime : TSystemTime;
begin
  if (Write) then
  begin
    if (TraceFile = 0) then


     TraceFile := CreateFile(PChar(Format('%s[%.8x].log',
                                [ChangeFileExt(Application.ExeName, ''),
                                 GetCurrentProcessID])),
                             GENERIC_READ or GENERIC_WRITE,
                             0, nil,
                             OPEN_ALWAYS,
                             0, 0);

    SetFilePointer( TraceFile, 0, nil, FILE_END);

    GetLocalTime(SystemTime);
    { NB integer overflows for negative values of result as all operands unsigned }
    TraceStr := 'Log opened ' + DateTimeToStr(Now) + #13#10;
    WriteFile(TraceFile, TraceStr[1], Length(TraceStr), Written, nil);
    FlushFileBuffers(TraceFile);

  end
  else
  begin
    if (TraceFile <> 0) then
    begin
      TraceStr := 'Log closed ' + DateTimeToStr(Now) + #13#10;
      WriteFile(TraceFile, TraceStr[1], Length(TraceStr), Written, nil);
      FlushFileBuffers(TraceFile);
     CloseHandle(TraceFile);
    end;
    TraceFile := 0;
  end;
end;


{ message queue stuff }

procedure PumpWindowQueue(const WindowHandle : HWND);
var
  Msg : TMsg;
begin
  { check for all messages }
  while (PeekMessage(Msg, WindowHandle, 0, 0, PM_REMOVE)) do
  begin
    TranslateMessage(Msg);
    DispatchMessage(MSg);
  end;
end;


procedure PumpThreadQueue;
begin
  { needed for threads to get ansynchronous callbacks }
  PumpWindowQueue(0);
end;

procedure YieldTimeSlice;
begin
  Sleep(YieldSleep);
end;

procedure YieldPeriod(const Period : Cardinal);
var
  StartCount: Cardinal;
begin
  StartCount := GetTickCount;

  while (CompareTickCount(StartCount + Period) < 0) do
    PumpThreadQueue;

end;

function NowSystemTime : TSystemTime;
begin
  GetSystemTime(Result);
  { now fix up the ms parameters }
end;

function FormatSystemTime(const SystemTime : TSystemTime) : string;
begin
  Result := Format(' %.2d:%.2d:%.2d.%.3d ',[SystemTime.wHour, SystemTime.wMinute, SystemTime.wSecond, SystemTime.wMilliseconds]);
end;

function CompareTickCount(const TickCount : DWORD) : integer;
var
  NowTickCount : DWORD;
  RolloverDir : integer;
begin
  { wrapper to get round the GetTickCount wrapping issue }
  { returns -1, 0, 1 for TickCount less, equal or more than current GetTickCount
    as per standard approach}

  NowTickCount := GetTickCount;

  { cope with TickCount obtained before rollover,
    and NowTickCount after rollover }

  { this fails if the tickcounts are over 25 days apart}
  if (TickCount < $80000000) and (NowTickCount > $80000000) then
    RolloverDir := -1
  else
    { "normal" case }
    RollOverDir := 1;

  if (NowTickCount > TickCount) then
    Result := RolloverDir
  else
  if (NowTickCount < TickCount) then
    Result := -RolloverDir
  else
    Result := 0;

end;

function InitThreadNames : TStringList;
begin
  if not Assigned(ThreadNames) then
    ThreadNames := TStringList.Create;
  Result := ThreadNames;
end;


procedure AddThreadName(Name : string ; Thread : TThread);
begin

  InitThreadNames;
  EnterCriticalSection(ThreadNameLock);
  try
    if (ThreadNames.IndexOfObject(Thread) > -1) then
      ThreadNames[ThreadNames.IndexOfObject(Thread)] := Name
    else
      ThreadNames.AddObject(Name, Thread);
  finally
    LeaveCriticalSection(ThreadNameLock);
  end;

end;

procedure RemoveThreadName(Name : string);
begin

  InitThreadNames;
  EnterCriticalSection(ThreadNameLock);
  try
    if (ThreadNames.IndexOf(Name) > -1) then
      ThreadNames.Delete(ThreadNames.IndexOf(Name));
  finally
    LeaveCriticalSection(ThreadNameLock);
  end;

end;


function ThreadName : string;
var
  i : integer;
begin

  InitThreadNames;
  Result := IntToStr(GetCurrentThreadID);
  EnterCriticalSection(ThreadNameLock);
  try

    if (GetCurrentThreadID = MainThreadId) then
     Result := 'process main';

    for i := 0 to ThreadNames.Count - 1 do
    begin
      if (ThreadNames.Objects[i] is TThread) then
        if TThread(ThreadNames.Objects[i]).ThreadID = GetCurrentThreadID then
        begin
          Result := Format('%s', [ThreadNames[i], GetCurrentThreadID]);
          exit;
        end;

    end;  { for }

  finally
    LeaveCriticalSection(ThreadNameLock);
  end;


end;

procedure GetThreadNames(NameList : TStringLIst);
begin
  InitThreadNames;
  try
    EnterCriticalSection(ThreadNameLock);
    NameList.Assign(ThreadNames);
  finally
    LeaveCriticalSection(ThreadNameLock);
  end;

end;

{ TDefaultTraceForm }

constructor TDefaultTraceForm.Create(AOwner: TComponent);
begin
  inherited;
  ListBox := TListBox.Create(self);
  ListBox.Parent := self;
  ListBox.Align := alClient;
end;

procedure TDefaultTraceForm.StringMessage(var Msg : TMessage);
begin
  ListBox.Items.Add(PChar(Msg.lParam));
  inherited;
end;

{ TBaseTraceForm }

constructor TBaseTraceForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);

end;

procedure TBaseTraceForm.StringMessage(var Msg: TMessage);
begin
  StrDispose(PChar(Msg.lParam));
end;

initialization

  InitializeCriticalSection(ThreadNameLock);
  { ensure that tracing to ID 0 goes to a known place }
  TraceUnitNames[0] := 'Main';
  TraceUnits[0] := true;
  AddThreadName('main', nil);


finalization

  if Assigned(TraceForm) then
   TraceTerminal(false);
  if (TraceFile <> 0) then
  begin
    TraceLog(false);
  end;
  if Assigned(ThreadNames) then
    FreeAndNil(ThreadNames);

  DeleteCriticalSection(ThreadNameLock);
end.

