unit NSPErrorHandler;

{unit for installing an exception handler for the NSP library}

interface

uses
  Nsp,       { NSP functions }
  SysUtils   { Exception }
  ;

type
  ENSPException = class(Exception);


implementation


resourcestring
  NPSErrorFmt = 'NSP Error in Function %s Context %s, Filename %s, line %d';

function NSPError( Status : NSPStatus ; FuncName, Context, FileName : PChar; Line : Integer) : Integer; stdcall;
begin

  raise
    ENSPException.CreateFmt(NPSErrorFmt , [FuncName, Context, FileName, Line])

end;


initialization

  {restores the NSP error handler}
  nspRedirectError(NSPError);

finalization

  {restores the NSP error handler}
  nspRedirectError(nil)

end.
