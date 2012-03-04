unit AudioInTests;

interface

uses
  AudioIn,
  TestFrameWork;

type


  TBufferEvents = record
    Count : integer;
  end;


  TAudioInTests = class(TTestCase)
  private
    FAudioIn: TAudioIn;
    BufferEvents: TBufferEvents;
    procedure CreateAudioIn;
    procedure DoBufferFilled(const Buffer : PByte; const Size : Cardinal);
    procedure ResetBufferEvents;
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
  FAudioIn := TAudioIn.Create;
  ResetBufferEvents;
  FAudioIn.OnBufferFilled := DoBufferFilled;
end;

procedure TAudioInTests.ResetBufferEvents;
begin
  BufferEvents.Count := 0;
end;

procedure TAudioInTests.DoBufferFilled(const Buffer: PByte; const Size: Cardinal);
begin
  Inc(BufferEvents.Count);
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
end;

procedure TAudioInTests.TestStop;
begin
  CreateAudioIn;
  FAudioIn.Start;
  Sleep(250);
  FAudioIn.Stop;
  CheckTrue(BufferEvents.Count > 0, 'audio buffers should be returned');
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
