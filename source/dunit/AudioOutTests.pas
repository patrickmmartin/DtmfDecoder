unit AudioOutTests;

interface

uses
  AudioOut,
  TestFrameWork;

type

  {* test class for the TAudioOut class
  <p> tests the base use cases of
  <ul>
  <li> construction / destruction @see TestCreate, @see TestDestroy
  <li> start / stop operation @see TestCanOpen, @see TestStart, @see TestStop
  <li> rudimentary soak testing @see TestCycle
  </ul>
  @see TAudioOut}
  TAudioOutTests = class(TTestCase)
  private
    FAudioOut: TAudioOut;
    procedure CreateAudioOut;


  protected
    {* overriden SetUp to set up objects
    @return void }
    procedure SetUp; override;
    {* overriden TearDown to tear down objects
    @return void}
    procedure TearDown; override;

  published
    {* tests the constructor
    @return void}
    procedure TestCreate;
    {* tests the destructor
    @return void}
    procedure TestDestroy;
    {* tests whether the object can be opened successfully
    @return void}
    procedure TestCanOpen;
    {* tests whether the object can be started successfully
    @return void}
    procedure TestStart;
    {* tests whether the the object can be stopped succesfully
    @return void}
    procedure TestStop;

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
  {* TODO : add some stub events to handle data, for validation }
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
  FAudioOut := nil;
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
  { enable tracing for the units addressed }
  Tracing('AudioBase', true);
  Tracing('AudioOut', true);

end.
