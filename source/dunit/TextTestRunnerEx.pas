unit TextTestRunnerEx;

interface

uses
  TestFramework,    { ITest }
  TextTestRunner    { TTextTestListener }
  ;

type

  TTextTestListenerEx = class(TTextTestListener)
  public
    procedure StartTest(test: ITest); override;
    procedure EndTest(test: ITest); override;
    procedure StartSuite(suite: ITest); override;
    procedure AddError(error: TTestFailure); override;
  end;

implementation



{ TTextTestListenerEx }

(* class to improve open the test output for automated usage
 note - the use of Write / WriteLn is inherited from the super class - will raise
 error 105 if there is no console at the point of writing *)



procedure TTextTestListenerEx.StartSuite(suite: ITest);
begin
  WriteLn;
end;

procedure TTextTestListenerEx.StartTest(test: ITest);
begin
  Write(test.Name);
end;

procedure TTextTestListenerEx.AddError(error: TTestFailure);
begin
  WriteLn(error.ThrownExceptionName + ': ' + error.ThrownExceptionMessage)

end;

procedure TTextTestListenerEx.EndTest(test: ITest);
begin
  Writeln(#9 + test.Status);
end;



end.
