unit AudioInTests;

interface

uses
  AudioIn,
  TestFrameWork;

type

  {* record to store buffer events }
  TBufferEvents = record
    Count : integer;
  end;

  {* test class for the TAudioIn class
  <p> tests the base use cases of
  <ul>
  <li> construction / destruction @see TestCreate, @see TestDestroy
  <li> start / stop operation @see TestCanOpen, @see TestStart, @see TestStop
  <li> rudimentary soak testing @see TestCycle
  </ul>
  @see TAudioIn}
  TAudioInTests = class(TTestCase)
  private
    { private single instance of a TAudioIn class }
    FAudioIn: TAudioIn;
    { record to track buffer events }
    BufferEvents: TBufferEvents;
    { creates the TAudioIn instance }
    procedure CreateAudioIn;
    { handles the callback for the buffer filled event }
    procedure DoBufferFilled(const Buffer : PByte; const Size : Cardinal);
    { zaps the buffer events records }
    procedure ResetBufferEvents;
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
    {* tests the running the object start/stop in a cycle
    @return void}
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
  { enable tracing for the units addressed }
  Tracing('AudioBase', true);
  Tracing('AudioIn', true);

end.
