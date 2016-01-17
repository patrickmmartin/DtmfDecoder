unit AudioTestThread;

interface

uses
  AudioPlay,
  Classes;

type
  TAudioTestThread = class(TThread)
  private
    fPlayActive: boolean;
    fDoSet : boolean;
    fPlay : TAudioPlay;
    procedure SetPlayActive(const Value: boolean);
    procedure SetPlay(const Value: TAudioPlay);
    { Private declarations }
  protected
    procedure Execute; override;
  public
    constructor Create(Play : TAudioPlay);
    property PlayActive : boolean read fPlayActive write SetPlayActive;
    property Play: TAudioPlay read FPlay write SetPlay;
  end;

implementation


uses
  Windows,       { Sleep }
  AppConsts
  ;

{ TAudioTestThread }

constructor TAudioTestThread.Create(Play : TAudioPlay);
begin
  inherited Create(true);
  fPlay := Play;
end;

procedure TAudioTestThread.Execute;
begin
  { Place thread code here }
  while not Terminated do
  begin
    {}
    if (fDoSet) then
      if (fPlayActive <> fPlay.Playing) then
      begin
        fPlay.Playing := fPlayActive;
        fDoSet := false;
      end;
    PumpThreadQueue;
    Sleep(20);

  end;
end;

procedure TAudioTestThread.SetPlay(const Value: TAudioPlay);
begin
  Suspend;
  FPlay := Value;
  Resume;
end;

procedure TAudioTestThread.SetPlayActive(const Value: boolean);
begin
  fDoSet := true;
  fPlayActive := Value;
end;

end.
