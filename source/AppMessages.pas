unit AppMessages;

interface


function ErrorMessage(msg : string; flags : integer) : integer;
function WarningMessage(msg : string; flags : integer) : integer;
function ConfirmationMessage(msg : string; flags : integer) : integer;
function InformationMessage(msg : string; flags : integer) : integer;


{ TODO : maybe a way of getting the result of the call stored? }
procedure ErrorMessageAsync(msg : string; flags : integer);
procedure WarningMessageAsync(msg : string; flags : integer);
procedure ConfirmationMessageAsync(msg : string; flags : integer);
procedure InformationMessageAsync(msg : string; flags : integer);

implementation


uses
  Forms,        { Application }
  Windows,     { MB_* }
  classes
  ;


type
  TMessageBoxThread = class(TThread)
  private
    { Private declarations }
    fMsgType, fMsg : string;
    fFlags : integer;
  protected
    constructor Create(MsgType, Msg  : string ; flags : integer);
    procedure Execute; override;
  end;


resourcestring
  sError = 'Error';
  sWarning = 'Warning';
  sConfirmation = 'Confirmation';
  sInformation = 'Information';

  { TODO : check whether I want windows messagebox or TApplication version }


function DoMessage(msg, MsgType : string; IconType, flags : integer) : integer;
begin
  Result := Application.MessageBox(PChar(msg),  PChar(Application.Title + ' ' + MsgType), IconType or flags);
end;

function ErrorMessage(msg : string; flags : integer) : integer;
begin
  Result := DoMessage(msg, sError, MB_ICONERROR, flags);
end;

function WarningMessage(msg : string; flags : integer) : integer;
begin
  Result := DoMessage(msg, sWarning, MB_ICONWARNING, flags);
end;

function ConfirmationMessage(msg : string; flags : integer) : integer;
begin
  Result := DoMessage(msg, sConfirmation, MB_ICONQUESTION, flags);
end;

function InformationMessage(msg : string; flags : integer) : integer;
begin
  Result := DoMessage(msg, sInformation, MB_ICONINFORMATION, flags);
end;


procedure ErrorMessageAsync(msg : string; flags : integer);
begin
 TMessageBoxThread.Create(sError, msg, MB_ICONERROR or flags);
end;

procedure WarningMessageAsync(msg : string; flags : integer);
begin
 TMessageBoxThread.Create(sWarning, msg, MB_ICONWARNING or flags);
end;

procedure ConfirmationMessageAsync(msg : string; flags : integer);
begin
 TMessageBoxThread.Create(sConfirmation, msg, MB_ICONQUESTION or flags);
end;

procedure InformationMessageAsync(msg : string; flags : integer);
begin
 TMessageBoxThread.Create(sInformation, msg, MB_ICONINFORMATION or flags);
end;



{ TMessageBoxThread }

constructor TMessageBoxThread.Create(MsgType, Msg : string ; flags : integer);
begin
  inherited Create(false);
  FreeOnTerminate := true;
  fFlags := flags;
  fMsgType := MsgType;
  fMsg := Msg
end;

procedure TMessageBoxThread.Execute;
begin

  Application.MessageBox(PChar(fMsg),  PChar(Application.Title + ' ' + fMsgType), fFlags);

end;

end.








