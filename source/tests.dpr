program tests;

{$APPTYPE CONSOLE}

uses
  TestFramework,
  SysUtils,
  Forms,
  Windows,
  GUITestRunner,
  TextTestRunner,
  TextTestRunnerEx in 'dunit\TextTestRunnerEx.pas',
  DTMFConsts in 'DTMFConsts.pas',
  DTMF in 'DTMF.pas',
  AppConsts in 'AppConsts.pas',
  AppMessages in 'AppMessages.pas',
  AppUtils in 'AppUtils.pas',
  AudioBase in 'AudioBase.pas',
  AudioIn in 'AudioIn.pas',
  AudioOut in 'AudioOut.pas',
  AudioInTests in 'dunit\AudioInTests.pas',
  AudioOutTests in 'dunit\AudioOutTests.pas',
  AppUtilsTests in 'dunit\AppUtilsTests.pas',
  AudioBaseTests in 'dunit\AudioBaseTests.pas';

{$R *.RES}

begin
  Application.Initialize;
  if FindCmdLineSwitch('CONSOLE') then
  begin
    { Console Mode }
    TestFramework.RunTest(RegisteredTests, [TTextTestListenerEx.Create]);
  end
  else
  begin
    { GUI mode }
    FreeConsole;
    IsConsole := False;
    GUITestRunner.RunRegisteredTests;
  end;

end.

 