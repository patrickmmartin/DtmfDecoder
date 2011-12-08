unit AppUtils;

{$IFDEF VER140}
  {$WARN SYMBOL_PLATFORM OFF}
  {$WARN SYMBOL_DEPRECATED OFF}
{$ENDIF}

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
type TMemoryStream = class(TThreadSafe)
  private
    fMemory : Pointer;
    fPosition : Cardinal;
    fSize : Cardinal;
  procedure SetPosition(const Value: Cardinal);
    procedure SetSize(const Value: Cardinal);
  public
    property Position : Cardinal read FPosition write SetPosition;
    property Size : Cardinal read fSize write SetSize;
    property Memory : Pointer read fMemory;
    function Write(const Buffer; Count: Cardinal): Cardinal;
    constructor Create(Size : Cardinal); reintroduce;
    destructor Destroy; override;
end;

{ thread safe TStringList}
type
  TThreadStringList = class(TStringList)
  private
    fLock : TRTLCriticalSection;
    (* hmmm...
    FList: PStringItemList;
    FCount: Integer;
    FCapacity: Integer;
    FSorted: Boolean;
    FDuplicates: TDuplicates;
    FOnChange: TNotifyEvent;
    FOnChanging: TNotifyEvent;
    *)
    { procedure ExchangeItems(Index1, Index2: Integer);  protected by Exchange }
    { procedure Grow; protected by InsertItem}
    { procedure QuickSort(L, R: Integer; SCompare: TStringListSortCompare); protected by Sort }
    {procedure InsertItem(Index: Integer; const S: string); protected by Changed / Changing }
    { procedure SetSorted(Value: Boolean); protected by Sort }
  protected
    procedure Changed; override;
    procedure Changing; override;
    function Get(Index: Integer): string; override;
    { function GetCapacity: Integer; override; OK }
    { function GetCount: Integer; override; OK }
    function GetObject(Index: Integer): TObject; override;
    procedure Put(Index: Integer; const S: string); override;
    procedure PutObject(Index: Integer; AObject: TObject); override;
    procedure SetCapacity(NewCapacity: Integer); override;
    procedure SetUpdateState(Updating: Boolean); override;

    { from TStrings }

  {$IFDEF VER140} public {$ENDIF}

    function IndexOfObject(AObject: TObject): Integer; {$IFDEF VER140} override; {$ENDIF}
    procedure InsertObject(Index: Integer; const S: string; AObject: TObject); {$IFDEF VER140} override; {$ENDIF}


  {$IFDEF VER140} protected {$ENDIF}

    function GetTextStr: string; override;
    procedure SetTextStr(const Value: string); override;

  public
    constructor Create; virtual;
    destructor Destroy; override;

    { from TStrings }
    procedure Insert(Index: Integer; const S: string); override;

    function Add(const S: string): Integer; override;
    { procedure Clear; override; protected by Changing / Changed }
    procedure Delete(Index: Integer); override;
    procedure Exchange(Index1, Index2: Integer); override;
    function Find(const S: string; var Index: Integer): Boolean; override;
    function IndexOf(const S: string): Integer; override;
    { procedure Insert(Index: Integer; const S: string); override;  protected by Changed / Changing }
    {procedure Sort; virtual; OK protected by CustomSort }
    { procedure CustomSort(Compare: TStringListSortCompare); - protected by Changed / Changing }
    { property Duplicates: TDuplicates read FDuplicates write FDuplicates; }
    { property Sorted: Boolean read FSorted write SetSorted;  already present }
    { property OnChange: TNotifyEvent read FOnChange write FOnChange; already present }
    { property OnChanging: TNotifyEvent read FOnChanging write FOnChanging; already present }

    { use with caution }
    procedure Lock;
    procedure Unlock;

  end;

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
  TMessageQueueThread =  class(TThread)
  end;

  { experimental }
  TDelegate = class

  end;

resourcestring
  sSuspended = 'suspended';
  sRunning = 'running';

const
  SuspendedDesc : array[boolean] of string = (sRunning, sSuspended);



implementation

uses
  SysUtils,     { Exception }
  AppConsts,    { Tracing }
  Forms         { AllocHwnd }
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


{ TMemoryStream }




constructor TMemoryStream.Create(Size: Cardinal);
begin
  inherited Create;
  SetSize(Size);
  fPosition := 0;
end;

destructor TMemoryStream.Destroy;
begin
  if Assigned(fMemory) then
    FreeMem(fMemory);
  inherited;

end;

procedure TMemoryStream.SetPosition(const Value: Cardinal);
begin
  FPosition := Value;
end;

procedure TMemoryStream.SetSize(const Value: Cardinal);
begin
  if not Assigned(fMemory) then
    GetMem(fMemory, Value)
  else
    ReallocMem(fMemory, Value);
  fSize := Value;
end;

function TMemoryStream.Write(const Buffer; Count: Cardinal): Cardinal;
begin
  {does NOT reallocate size}
  if (fPosition + Count) < fSize then
  begin
    System.Move(Buffer, Pointer(Cardinal(FMemory) + FPosition)^, Count);
    Inc(fPosition, Count);
    Result := Count;
  end
  else
  begin
    { simple algorithm for enlarging }
    SetSize(fSize * 2);
    Result := Write(Buffer, Count);
  end;

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

  { TThreadStringList }


constructor TThreadStringList.Create;
begin
  InitializeCriticalSection(fLock);
  inherited Create;

end;


destructor TThreadStringList.Destroy;
begin
  inherited Destroy;
  DeleteCriticalSection(fLock);
end;

function TThreadStringList.Add(const S: string): Integer;
begin
  Lock;
  try
    Result := inherited Add(S);
  finally
   UnLock;
  end;
end;

procedure TThreadStringList.Changed;
begin
  if {(FUpdateCount = 0) and }Assigned(OnChange) then OnChange(Self);
  UnLock;
end;

procedure TThreadStringList.Changing;
begin
  Lock;
  if {(FUpdateCount = 0) and }Assigned(OnChanging) then OnChanging(Self);
end;

(*
procedure TThreadStringList.Clear;
begin
  if FCount <> 0 then
  begin
    Changing;
    Finalize(FList^[0], FCount);
    FCount := 0;
    SetCapacity(0);
    Changed;
  end;
end;
*)

procedure TThreadStringList.Delete(Index: Integer);
begin

  Lock;
  try
    inherited Delete(Index);
  finally
    UnLock;
  end;

end;

procedure TThreadStringList.Exchange(Index1, Index2: Integer);
begin

  Lock;
  try
    inherited Exchange(Index1, Index2);
  finally
    UnLock;
  end;

end;

(*
procedure TThreadStringList.ExchangeItems(Index1, Index2: Integer);
var
  Temp: Integer;
  Item1, Item2: PStringItem;
begin
  Item1 := @FList^[Index1];
  Item2 := @FList^[Index2];
  Temp := Integer(Item1^.FString);
  Integer(Item1^.FString) := Integer(Item2^.FString);
  Integer(Item2^.FString) := Temp;
  Temp := Integer(Item1^.FObject);
  Integer(Item1^.FObject) := Integer(Item2^.FObject);
  Integer(Item2^.FObject) := Temp;
end;
*)

function TThreadStringList.Find(const S: string; var Index: Integer): Boolean;
begin

  Lock;
  try
    Result := inherited Find(S, Index);
  finally
    UnLock;
  end;

end;

function TThreadStringList.Get(Index: Integer): string;
begin

  Lock;
  try
    Result := inherited Get(Index);
  finally
    UnLock;
  end;

end;

(*
function TThreadStringList.GetCapacity: Integer;
begin
  Result := FCapacity;
end;
*)

(*
function TThreadStringList.GetCount: Integer;
begin
  Result := FCount;
end;
*)

function TThreadStringList.GetObject(Index: Integer): TObject;
begin
  Lock;
  try
    Result := inherited GetObject(Index);
  finally
    UnLock;
  end;
end;

(*
procedure TThreadStringList.Grow;
var
  Delta: Integer;
begin
  { can't inherit }
  if Capacity > 64 then Delta := Capacity div 4 else
    if Capacity > 8 then Delta := 16 else
      Delta := 4;
  SetCapacity(Capacity + Delta);
end;
*)

function TThreadStringList.IndexOf(const S: string): Integer;
begin
  if not Sorted then Result := inherited IndexOf(S) else
    if not Find(S, Result) then Result := -1;
end;

(*
procedure TThreadStringList.Insert(Index: Integer; const S: string);
begin
  if Sorted then Error(@SSortedListError, 0);
  if (Index < 0) or (Index > FCount) then Error(@SListIndexError, Index);
  InsertItem(Index, S);
end;
*)

(*
procedure TThreadStringList.InsertItem(Index: Integer; const S: string);
begin
  Changing;
  if Count = FCapacity then Grow;
  if Index < FCount then
    System.Move(FList^[Index], FList^[Index + 1],
      (FCount - Index) * SizeOf(TStringItem));
  with FList^[Index] do
  begin
    Pointer(FString) := nil;
    FObject := nil;
    FString := S;
  end;
  Inc(FCount);
  Changed;
end;
*)

procedure TThreadStringList.Put(Index: Integer; const S: string);
begin
  Lock;
  try
    inherited Put(Index, S);
  finally
    UnLock;
  end;
end;

procedure TThreadStringList.PutObject(Index: Integer; AObject: TObject);
begin
  Lock;
  try
    inherited PutObject(Index, AObject);
  finally
    UnLock;
  end;
end;

(*
procedure TThreadStringList.QuickSort(L, R: Integer; SCompare: TStringListSortCompare);
var
  I, J, P: Integer;
begin
  repeat
    I := L;
    J := R;
    P := (L + R) shr 1;
    repeat
      while SCompare(Self, I, P) < 0 do Inc(I);
      while SCompare(Self, J, P) > 0 do Dec(J);
      if I <= J then
      begin
        ExchangeItems(I, J);
        if P = I then
          P := J
        else if P = J then
          P := I;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if L < J then QuickSort(L, J, SCompare);
    L := I;
  until I >= R;
end;
*)

procedure TThreadStringList.SetCapacity(NewCapacity: Integer);
begin
  Lock;
  try
    inherited SetCapacity(NewCapacity);
  finally
    UnLock;
  end;
end;

(*
procedure TThreadStringList.SetSorted(Value: Boolean);
begin
  if FSorted <> Value then
  begin
    if Value then Sort;
    FSorted := Value;
  end;
end;
*)

procedure TThreadStringList.SetUpdateState(Updating: Boolean);
begin
  if Updating then Changing else Changed;
end;

(*
function StringListAnsiCompare(List: TStringList; Index1, Index2: Integer): Integer;
begin
  Result := AnsiCompareText(List.FList^[Index1].FString,
                            List.FList^[Index2].FString);
end;
*)

(*
procedure TThreadStringList.Sort;
begin
  CustomSort(StringListAnsiCompare);
end;
*)

(*
procedure TThreadStringList.CustomSort(Compare: TStringListSortCompare);
begin
  if not Sorted and (FCount > 1) then
  begin
    Changing;
    QuickSort(0, FCount - 1, Compare);
    Changed;
  end;
end;
*)


procedure TThreadStringList.Lock;
begin
  EnterCriticalSection(fLock)
end;

procedure TThreadStringList.Unlock;
begin
  LeaveCriticalSection(fLock)
end;

function TThreadStringList.GetTextStr: string;
begin
  Lock;
  try
    Result := inherited GetTextStr;
  finally
    Unlock;
  end;

end;

procedure TThreadStringList.SetTextStr(const Value: string);
begin
  Lock;
  try
    inherited SetTextStr(Value);
  finally
    Unlock;
  end;
end;

function TThreadStringList.IndexOfObject(AObject: TObject): Integer;
begin
  Lock;
  try
    Result := inherited IndexOfObject(AObject);
  finally
    Unlock;
  end;
end;

procedure TThreadStringList.Insert(Index: Integer; const S: string);
begin
  Lock;
  try
    inherited Insert(Index, S);
  finally
    Unlock;
  end;
end;

procedure TThreadStringList.InsertObject(Index: Integer;
  const S: string; AObject: TObject);
begin
  Lock;
  try
    inherited Insert(Index, S);
    inherited PutObject(Index, AObject);
  finally
    Unlock;
  end;
end;

{ TThread }

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

  UnitID := GetUnitID('RSIClasses');
  InitializeCriticalSection(GlobalCriticalSection);
  InitTryEnterCriticalSectionPtr;

finalization

  DeleteCriticalSection(GlobalCriticalSection);

end.
