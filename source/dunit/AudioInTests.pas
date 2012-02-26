unit AudioInTests;

interface

uses
  AudioIn,
  TestFrameWork;

type
  TAudioInTests = class(TTestCase)
  private

  protected

//    procedure SetUp; override;
//    procedure TearDown; override;

  published

    // Test methods
    procedure TestCreate;
    procedure TestDestroy;
    procedure TestStart;
    procedure TestStop;
    procedure TestCanOpen;

  end;

type
  TWaveInThreadTests = class(TTestCase)
  private

  protected

//    procedure SetUp; override;
//    procedure TearDown; override;

  published

    // Test methods
    procedure TestCreate;
    procedure TestExecute;

  end;

implementation

{ TAudioInTests }

procedure TAudioInTests.TestCanOpen;
begin

end;

procedure TAudioInTests.TestCreate;
begin

end;

procedure TAudioInTests.TestDestroy;
begin

end;

procedure TAudioInTests.TestStart;
begin

end;

procedure TAudioInTests.TestStop;
begin

end;

{ TWaveInThreadTests }

procedure TWaveInThreadTests.TestCreate;
begin

end;

procedure TWaveInThreadTests.TestExecute;
begin

end;

initialization

  TestFramework.RegisterTest('AudioInTests Suite',
    TAudioInTests.Suite);
  TestFramework.RegisterTest('AudioInTests Suite',
    TWaveInThreadTests.Suite);

end.
