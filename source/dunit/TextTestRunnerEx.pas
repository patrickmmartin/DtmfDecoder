unit TextTestRunnerEx;

interface

uses
  TestFramework,    { ITest }
  TextTestRunner    { TTextTestListener }
  ;

type

{* class to improve open the test output for automated usage
 note - the use of Write / WriteLn is inherited from the super class - will raise
 error 105 if there is no console at the point of writing }
  TTextTestListenerEx = class(TTextTestListener)
  public
    {* override of StartTest to implement some output
    @param test - the Test instance }
    procedure StartTest(test: ITest); override;
    {* override of EndTest to implement some output 
    @param test - the Test instance }
    procedure EndTest(test: ITest); override;
    {* override of StartSuite to add a newline 
    @param suite - the Test suite }
    procedure StartSuite(suite: ITest); override;
    {* override of AddError to implement some output upon error
    @param error - the error } 
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
