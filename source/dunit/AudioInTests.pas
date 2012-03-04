unit AudioInTests;

interface

uses
  AudioIn,
  TestFrameWork;

type
  TAudioInTests = class(TTestCase)
  private
    FAudioIn: TAudioIn;
    procedure CreateAudioIn();
  protected

    procedure SetUp; override;
    procedure TearDown; override;

  published

    // Test methods
    procedure TestCreate;
    procedure TestDestroy;
    procedure TestCanOpen;
    procedure TestStart;
    procedure TestStop;
    procedure TestCycle;

  end;

implementation

uses
  Windows,    { Sleep}
  SysUtils,   { FreeAndNil }
  AppConsts   { Tracing }
  ;

{ TAudioInTests }

procedure TAudioInTests.CreateAudioIn;
begin
  CheckFalse(Assigned(FAudioIn));
  { TODO : add some stub events to handle data, for validation }
  FAudioIn := TAudioIn.Create;
end;

procedure TAudioInTests.SetUp;
begin
  inherited;
end;

procedure TAudioInTests.TearDown;
begin
  inherited;
  FreeAndNil(FAudioIn);
end;

procedure TAudioInTests.TestCreate;
begin
  FAudioIn := TAudioIn.Create;
end;

procedure TAudioInTests.TestDestroy;
begin
  CreateAudioIn;
  FreeAndNil(FAudioIn);
end;

procedure TAudioInTests.TestCanOpen;
begin
  CreateAudioIn;
  Check(FAudioIn.CanOpen, 'the default audio device cannot be opened');
end;

procedure TAudioInTests.TestStart;
begin
  CreateAudioIn;
  FAudioIn.Start;
  Sleep(1000);
end;

procedure TAudioInTests.TestStop;
begin
  CreateAudioIn;
  FAudioIn.Start;
  FAudioIn.Stop;
end;


procedure TAudioInTests.TestCycle;
var
  i : integer;
begin
  CreateAudioIn;
  for i := 0 to 9 do
  begin
    FAudioIn.Start;
    FAudioIn.Stop;
  end;
end;

initialization

  TestFramework.RegisterTest('AudioInTests Suite', TAudioInTests.Suite);
  Tracing('AudioBase', true);
  Tracing('AudioIn', true);

end.
