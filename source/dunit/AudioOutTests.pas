unit AudioOutTests;

interface

uses
  AudioOut,
  TestFrameWork;

type
  TAudioOutTests = class(TTestCase)
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
  TWaveOutThreadTests = class(TTestCase)
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

{ TAudioOutTests }

procedure TAudioOutTests.TestCanOpen;
begin

end;

procedure TAudioOutTests.TestCreate;
begin

end;

procedure TAudioOutTests.TestDestroy;
begin

end;

procedure TAudioOutTests.TestStart;
begin

end;

procedure TAudioOutTests.TestStop;
begin

end;

{ TWaveOutThreadTests }

procedure TWaveOutThreadTests.TestCreate;
begin

end;

procedure TWaveOutThreadTests.TestExecute;
begin

end;

initialization

  TestFramework.RegisterTest('AudioOutTests Suite',
    TAudioOutTests.Suite);
  TestFramework.RegisterTest('AudioOutTests Suite',
    TWaveOutThreadTests.Suite);

end.
