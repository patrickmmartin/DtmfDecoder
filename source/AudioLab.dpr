program AudioLab;

uses
  Forms,
  AudioLabMainF in 'AudioLabMainF.pas' {AudioMainForm},
  AudioPlay in 'AudioPlay.pas',
  AudioWave in 'AudioWave.pas',
  DTMFToneGen in 'DTMFToneGen.pas',
  AudioTestThread in 'AudioTestThread.pas',
  AppConsts in 'AppConsts.pas',
  AudioBase in 'AudioBase.pas',
  AudioIn in 'AudioIn.pas',
  AudioOut in 'AudioOut.pas',
  DTMF in 'DTMF.pas',
  DTMFConsts in 'DTMFConsts.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'Audio Test';
  Application.CreateForm(TAudioMainForm, AudioMainForm);
  Application.Run;
end.
