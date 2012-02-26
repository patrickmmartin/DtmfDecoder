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
