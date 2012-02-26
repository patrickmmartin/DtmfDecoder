unit AppUtilsTests;

interface

uses
  AppUtils,
  TestFrameWork;

type
  TThreadSafeTests = class(TTestCase)
  private

  protected

//    procedure SetUp; override;
//    procedure TearDown; override;

  published

    // Test methods
    procedure TestLock;
    procedure TestTryLock;
    procedure TestUnlock;
    procedure TestCreate;
    procedure TestDestroy;

  end;

type
  TSynchroniserTests = class(TTestCase)
  private

  protected

//    procedure SetUp; override;
//    procedure TearDown; override;

  published

    // Test methods
    procedure TestSetContext;
    procedure TestRunMethod;
    procedure TestCreate;
    procedure TestDestroy;

  end;

type
  TAppThreadTests = class(TTestCase)
  private

  protected

//    procedure SetUp; override;
//    procedure TearDown; override;

  published

    // Test methods
    procedure TestDestroy;

  end;

implementation

{ TThreadSafeTests }

procedure TThreadSafeTests.TestCreate;
begin

end;

procedure TThreadSafeTests.TestDestroy;
begin

end;

procedure TThreadSafeTests.TestLock;
begin

end;

procedure TThreadSafeTests.TestTryLock;
begin

end;

procedure TThreadSafeTests.TestUnlock;
begin

end;

{ TSynchroniserTests }

procedure TSynchroniserTests.TestCreate;
begin

end;

procedure TSynchroniserTests.TestDestroy;
begin

end;

procedure TSynchroniserTests.TestRunMethod;
begin

end;

procedure TSynchroniserTests.TestSetContext;
begin

end;

{ TAppThreadTests }

procedure TAppThreadTests.TestDestroy;
begin

end;

initialization

  TestFramework.RegisterTest('AppUtilsTests Suite',
    TThreadSafeTests.Suite);
  TestFramework.RegisterTest('AppUtilsTests Suite',
    TSynchroniserTests.Suite);
  TestFramework.RegisterTest('AppUtilsTests Suite',
    TAppThreadTests.Suite);

end.
