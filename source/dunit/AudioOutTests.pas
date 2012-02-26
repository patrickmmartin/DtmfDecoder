unit AudioOutTests;

interface

uses
  AudioOut,
  TestFrameWork;

type
  TAudioOutTests = class(TTestCase)
  private
    FAudioOut: TAudioOut;
    procedure CreateAudioOut;

  protected

    procedure SetUp; override;
    procedure TearDown; override;

  published

    // Test methods
    procedure TestCreate;
    procedure TestDestroy;
    procedure TestStart;
    procedure TestStop;
    procedure TestCanOpen;

  end;

implementation

uses
  Windows,      { Sleep }
  SysUtils,     { FreeAndNil }
  AppConsts     { Tracing }

  ;

{ TAudioOutTests }


procedure TAudioOutTests.CreateAudioOut;
begin
  CheckFalse(Assigned(FAudioOut));
  { TODO : add some stub events to handle data, for validation }
  FAudioOut := TAudioOut.Create;
end;

procedure TAudioOutTests.SetUp;
begin
  inherited;

end;

procedure TAudioOutTests.TearDown;
begin
  inherited;
  FreeAndNil(FAudioOut);
end;

procedure TAudioOutTests.TestCreate;
begin
  FAudioOut := TAudioOut.Create;
end;

procedure TAudioOutTests.TestDestroy;
begin
  CreateAudioOut;
  FAudioOut.Free;
end;

procedure TAudioOutTests.TestStart;
begin
  CreateAudioOut;
  FAudioOut.Start;
  Sleep(1000);

end;

procedure TAudioOutTests.TestStop;
begin
  CreateAudioOut;
  FAudioOut.Start;
  Sleep(1000);
  FAudioOut.Stop;
end;

procedure TAudioOutTests.TestCanOpen;
begin
  CreateAudioOut;
  Check(FAudioOut.CanOpen, 'the default audio device cannot be opened');
end;

initialization

  TestFramework.RegisterTest('AudioOutTests Suite', TAudioOutTests.Suite);
  Tracing('AudioBase', true);
  Tracing('AudioOut', true);

end.
