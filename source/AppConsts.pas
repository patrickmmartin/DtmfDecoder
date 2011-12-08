unit AppConsts;

interface

uses
  SysUtils,              { UpperCase }
  Windows,      { HWND }
  Forms,        { TForm }
  messages,
  classes,       { TComponent}
  stdctrls       { TListBox }
  ;

  {$DEFINE VERBOSE}

{internal exception types}
type
  ERSIError = class(Exception);
    ENotImplementedError = class(ERSIError);
    ENotCapableError = class(ERSIError);
    EOutOfRangeError = class(ERSIError);
    EConfigurationError = class(ERSIError);


{ A generic logging event}
type TLogEvent = procedure (Sender : TObject ; const EventTime : TDateTime ; const Msg : string) of object;
{ a generic parameter validation event}
type TParameterValidateEvent = procedure (const Parameter : string ; var Value : string) of object;
{ a generic parameter validation event}
type TMsgEvent = procedure (Sender : TObject ; const Msg : string) of object;
{ progress update event }
type TPercentEvent = procedure (Sender : TObject ; const Percent : double);


type EParameterError = class(Exception);

{ A generic synchronisation enum }
type TSynchMethod = ( smCreatorThread,
                      smFreeThreaded);

{ smCreatorThread - this means a sendmessage is done
  via a window created in the context of the opening thread }
{ smFreeThreaded - this means a callbacks could happen in any thread context
  and the recipient better be ready }

resourcestring
  sCreatorThread = 'Creator thread';
  sFreeThreaded = 'Free threaded';

const
  SynchMethodDesc : array[TSynchMethod] of string = (sCreatorThread, sFreeThreaded);

  {the numeric characters}
  NumericChars = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  {the DTMF character set}
  DigitChars = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '#', 'A', 'B', 'C', 'D'];
  {the common phone keys}
  KeyDigitChars = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '#'];


{ tracing functions and types }

type TLogSeverity = (lsInformation, lsNormal, lsWarning, lsError);

const LogSeverityDesc : array [TLogSeverity] of string =
                ('Information', 'Normal', 'Warning', 'Error');

procedure Trace(const UnitID : BYTE; const Msg : string ; const LogSeverity : TLogSeverity = lsInformation);
procedure TraceAll(const Enable : boolean);
procedure Tracing(const UnitName : string ; const Add : boolean);
function GetUnitID(const UnitName : string) : BYTE;

procedure TraceTerminal(const Show : boolean);
procedure TraceLog(const Write : boolean);

var
  TraceLogLazyWrite : boolean = true;

procedure PumpWindowQueue(const WindowHandle : HWND);
procedure PumpThreadQueue;
procedure YieldTimeSlice;
procedure YieldPeriod(const Period : Cardinal);

{ formats a SYSTEMTIME struct into a string representation }
function FormatSystemTime(const SystemTime : TSystemTime) : string;
function NowSystemTime : TSystemTime;

function CompareTickCount(const TickCount : DWORD) : integer;

procedure AddThreadName(Name : string ; Thread : TThread);
procedure RemoveThreadName(Name : string);
function ThreadName : string;
procedure GetThreadNames(NameList : TStringList);

const
  RSI_STRING_MSG = WM_USER;

var
  YieldSleep : integer = 10;

var
  TrueStr, FalseStr : string;

  {now exposed for direct use by applications }
  TraceForm : TForm = nil;
  TraceFormHwnd : HWND = INVALID_HANDLE_VALUE;

  LoggingSeverity : TLogSeverity = lsInformation;

function TraceUnit(Index : BYTE) : boolean;
function TraceUnitName(Index : BYTE) : string;


function StrToLogSeverity(LogSeverityStr  : string): TLogSeverity;

{ tracing form base prototypes }

type

  TBaseTraceForm = class(TForm)
  protected
    procedure StringMessage(var Msg : TMessage); message RSI_STRING_MSG;
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

var
  TracingAll : boolean = false;

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
  CurrentUnitID : BYTE = 1;
  UseTerminal : boolean = false;
  TraceFile : THandle;
  ThreadNameLock : TRTLCriticalSection;
  ThreadNames : TStringList = nil;

  TraceUnits : array[BYTE] of boolean;
  {short string to avoid problems with re-allocation}
  TraceUnitNames : array[BYTE] of shortstring;

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
{$IFDEF VERBOSE}
var
  TraceStr : string;
  TracePChar : PChar;
  Written : Cardinal;
{$ENDIF}
begin
  {$IFDEF VERBOSE}
  if (LogSeverity >= LoggingSeverity) and ( TracingAll or (UnitID = 0) or (TraceUnits[UnitId])) then
  begin

    TraceStr := Format(TraceFmt, [FormatSystemTime(NowSystemTime),
                       LogSeverityDesc[LogSeverity], Msg,
                       TraceUnitNames[UnitId], ThreadName]);

    if IsWindow(TraceFormHWND) then
    begin
      TracePChar := StrAlloc(Length(TraceStr) + 1);
      StrCopy(TracePChar, PChar(TraceStr));
      PostMessage(TraceFormHWND, RSI_STRING_MSG, 0, Longint(TracePChar));
    end;

    OutputDebugString(PChar(TraceStr));

      if (TraceFile <> 0) then
      begin
        TraceStr := TraceStr + #13#10;
        WriteFile(TraceFile, TraceStr[1], Length(TraceStr), Written, nil);
        if not TraceLogLazyWrite then
          FlushFileBuffers(TraceFile);
      end;
    end
  {$ENDIF}
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
  { needed to threads to get ansynchronous callbacks }
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
  TrueStr := BooleanIdents[true];
  FalseStr := BooleanIdents[false];
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
