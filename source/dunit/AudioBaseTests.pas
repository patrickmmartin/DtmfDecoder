unit AudioBaseTests;

interface

uses
  AudioBase,
  TestFrameWork;

type
  EAudioTests = class(TTestCase)
  private

  protected

//    procedure SetUp; override;
//    procedure TearDown; override;

  published

    // Test methods
    procedure TestCreateError;

  end;

implementation

{ EAudioTests }

procedure EAudioTests.TestCreateError;
begin

end;

initialization

  TestFramework.RegisterTest('AudioBaseTests Suite',
    EAudioTests.Suite);

end.
 