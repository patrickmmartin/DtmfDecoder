unit AudioLabMainF;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ExtCtrls, StdCtrls, TeEngine, Series, TeeProcs, Chart, ComCtrls,
  AudioIn, AudioOut, AudioPlay, DTMF, {audio components}
  AudioTestThread
  ;

type
  TAudioMainForm = class(TForm)
    tmrIn: TTimer;
    chkTraceForm: TCheckBox;
    dlgOpen: TOpenDialog;
    lblAudioInException: TLabel;
    lblCountIn: TLabel;
    btnTestIn: TButton;
    btnLoopTimerIn: TButton;
    Chart1: TChart;
    Series1: TLineSeries;
    btnResetIn: TButton;
    chkChart: TCheckBox;
    btnLoopCodeIn: TButton;
    cbAudioIn: TComboBox;
    lstMessages: TListBox;
    cbAudioOut: TComboBox;
    btnPlayFileNew: TButton;
    btnTones: TButton;
    ebTones: TEdit;
    tmrOut: TTimer;
    ebFileName: TEdit;
    btnFileName: TButton;
    pbVolume: TProgressBar;
    lblWarnings: TLabel;
    btnTestOut: TButton;
    btnTestTones: TButton;
    tmrTones: TTimer;
    lstWarnings: TListBox;
    chkCheckAudio: TCheckBox;
    cbTestLength: TComboBox;
    lblPlaybackStatus: TLabel;
    lblWarningStatus: TLabel;
    cbTestTime: TComboBox;
    lblKeepOpen: TLabel;
    lblTestTime: TLabel;
    lblAudioInput: TLabel;
    lblAudioOutput: TLabel;
    lblAudioFile: TLabel;
    lblDTMFTones: TLabel;
    lblVolume: TLabel;
    lblVolumeThreshold: TLabel;
    ebVolumeThreshold: TEdit;
    lblCycleCount: TLabel;
    lblWarningCount: TLabel;
    lblAudioOutException: TLabel;
    chkUseThread: TCheckBox;
    cbPlaySynch: TComboBox;
    btnTestWav: TButton;
    btnPlayStart: TButton;
    btnPlayStartTest: TButton;
    tmrTestOut: TTimer;
    lblDTMF: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnTestInClick(Sender: TObject);
    procedure btnLoopTimerInClick(Sender: TObject);
    procedure tmrInTimer(Sender: TObject);
    procedure btnResetInClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnLoopCodeInClick(Sender: TObject);
    procedure chkTraceFormClick(Sender: TObject);
    procedure btnPlayFileNewClick(Sender: TObject);
    procedure btnTonesClick(Sender: TObject);
    procedure btnFileNameClick(Sender: TObject);
    procedure btnTestOutClick(Sender: TObject);
    procedure tmrOutTimer(Sender: TObject);
    procedure btnTestTonesClick(Sender: TObject);
    procedure tmrTonesTimer(Sender: TObject);
    procedure ebVolumeThresholdChange(Sender: TObject);
    procedure btnTestWavClick(Sender: TObject);
    procedure btnPlayStartClick(Sender: TObject);
    procedure tmrTestOutTimer(Sender: TObject);
    procedure btnPlayStartTestClick(Sender: TObject);
    procedure chkUseThreadClick(Sender: TObject);
  private
    { Private declarations }
    fAudioIn : TAudioIn;
    fPlay, fTestPlay : TAudioPlay;
    fAudioTestThread : TAudioTestThread;
    fDTMFDecoder : TDTMFDecoder;
    fDecodeSize : Cardinal;
    Warned : boolean;
    LastStart : Cardinal;
    WarningVolume : double;
    procedure BufferFilled(const Buffer : PByte; const Size : Cardinal);
    procedure UpdateChart(const Buffer : PByte; const Size : Cardinal);
    procedure UpdateDTMF(const Buffer : PByte; const Size : Cardinal);
    procedure DoException(Sender: TObject; E: Exception);
    procedure OnPlayDone(Sender : TObject);
    procedure CreatePlay;
    procedure DestroyPlay;
    procedure CreateTestPlay;
    procedure DestroyTestPlay;
    procedure OnTestPlayDone(Sender: TObject);
    procedure OnDigit(Sender : TObject ; Digit : Char);

  public
    { Public declarations }
  end;

var
  AudioMainForm: TAudioMainForm;

implementation

uses
  AudioWave,
  DTMFToneGen,
  AudioBase,
  AppConsts
  ;

{$R *.DFM}

const DEFAULT_WARNING_VOLUME = 0.1;

procedure TAudioMainForm.FormCreate(Sender: TObject);
begin

  Application.OnException := DoException;

//  Traceall(true);
  Tracing('AudioOut', true);
  Tracing('AudioIn', true);
  LoggingSeverity := lsInformation;

  fDecodeSize := 512;

  fAudioIn := TAudioIn.Create;
  fAudioIn.Quantization := 16;
  fAudioIn.Framerate := 8000;

  {NB - this cannot go below 1024 ( = 62 ms)  without big problems on most sound drivers, apparently
   - any greater recording resolution will have to be implemented by operating within the buffers' content }
  { however, can't go too large without incurring large CPU expense when the buffer does arrive,
    and large time lags in deciphering audio stream }

  { was 2048, previously }  
  fAudioIn.BufferSize := (1024 div fDecodeSize) * fDecodeSize;
  { 4096  = 0.125 seconds, 2048  = 0. 0625 seconds, }

  { want to buffer at least n s of audio }
  { n = 1}
  fAudioIn.BufferCount := ((fAudioIn.Quantization div 8) * 8000) div fAudioIn.BufferSize;

  fAudioIn.SynchMethod := smFreeThreaded;



  CreatePlay;
  fAudioTestThread := TAudioTestThread.Create(fPlay);

  GetAudioInDevices(cbAudioIn.Items);
  cbAudioIn.ItemIndex := 0;
  GetAudioOutDevices(cbAudioOut.Items);
  cbAudioOut.ItemIndex := 0;
  cbTestLength.ItemIndex := 2;
  cbTestTime.ItemIndex := 2;
  WarningVolume := DEFAULT_WARNING_VOLUME;

  cbPlaySynch.Items.Add(SynchMethodDesc[smCreatorThread]);
  cbPlaySynch.Items.Add(SynchMethodDesc[smFreeThreaded]);
  cbPlaySynch.ItemIndex := 0;

  fDTMFDecoder := TDTMFDecoder.Create;
  fDTMFDecoder.Quantisation := fAudioIn.Quantization;
  fDTMFDecoder.Framerate := fAudioIn.Framerate;
  { yields slightly better results }
  fDTMFDecoder.Guarded := false;
  fDTMFDecoder.PowerRatio := 5;

  fDTMFDecoder.OnDetectEnd := OnDigit;

end;

procedure TAudioMainForm.FormDestroy(Sender: TObject);
begin

  fAudioTestThread.Terminate;
  fAudioTestThread.Resume;
  fAudioTestThread.WaitFor;
  fAudioTestThread.Free;

  fAudioIn.Free;
  DestroyPlay;

end;

procedure TAudioMainForm.btnTestInClick(Sender: TObject);
var
  EndCount : Cardinal;
  WasFocused : boolean;
  Volume : double;
  Restarted : boolean;
const
  BoolSize = sizeof(boolean);

begin

  WasFocused := btnTestIn.Focused;
  try
    btnTestIn.Enabled := false;
    if (fAudioIn.Active) then
    begin
      fAudioIn.Stop;
      fAudioIn.OnBufferFilled := nil;
      chkChart.Enabled := true;
    end
    else
    begin
      { test no longer needed, if event is set to nil }
      fAudioIn.SynchMethod := smCreatorThread;

      fAudioIn.WaveDevice := cbAudioIn.ItemIndex;
      Warned := false;
      Restarted := false;
      fAudioIn.Start;

      if chkCheckAudio.Checked then
      begin
        { test audio }
        Volume := fAudioIn.Volume;
        while (Volume < 0) do
        begin
          YieldTimeSlice;
          Volume := fAudioIn.Volume
        end;

      { test for 300 ms }
        EndCount := GetTickCount + Cardinal(100 * (cbTestTime.ItemIndex + 1));
        while CompareTickCount(EndCount) < 0 do
        begin
          if (Volume > WarningVolume) then
          begin

            lblWarnings.Caption := IntToStr(StrToIntDef(lblWarnings.Caption, 0) + 1);
            lstWarnings.Items.Insert(0, Format('%s %8.2f %.4f trapped ', [lblWarnings.Caption, GetTickCount / 1000, Volume]));

            { because event is not assigned, we can do this }
            fAudioIn.Stop;
            Sleep(200);
            { because event is not assigned, we can do this }
            fAudioIn.Start;
            Restarted := true;
            while (fAudioIn.Volume < 0) do
              YieldTimeSlice;

            break;
          end;
          { keep testing }
          Volume := fAudioIn.Volume

        end;

        if not Restarted then
          lstWarnings.Items.Insert(0, Format('OK %8.2f %.4f', [GetTickCount / 1000, Volume]))
        else
          lstWarnings.Items.Insert(0, Format('restarted %8.2f %.4f', [GetTickCount / 1000, fAudioIn.Volume]));

      end;

      { now interested in audio data }

      fAudioIn.OnBufferFilled := BufferFilled;

    end;

  finally
    chkChart.Enabled := not fAudioIn.Active;
    cbAudioIn.Enabled := not fAudioIn.Active;

    if fAudioIn.Active then
      btnTestIn.Caption := 'Stop'
    else
      btnTestIn.Caption := 'Start';


    btnTestIn.Enabled := true;
    if (WasFocused) then
      btnTestIn.SetFocus;
  end;


end;

procedure TAudioMainForm.UpdateChart(const Buffer : PByte; const Size : Cardinal);
var
  i : Cardinal;
begin
  if (Size > 0) then
  begin
    Series1.Clear;
    {assuming 16 bit sample}
    for i := 0 to (Size div 2 )- 1 do
    begin
      Series1.AddXY(i, SmallInt(PWordArray(Buffer)[i]), '', clTeeColor);
    end;
  end;
  Chart1.Invalidate;
end;

procedure TAudioMainForm.UpdateDTMF(const Buffer : PByte; const Size : Cardinal);
var
  i : Cardinal;
  ChunkPos : PByte;
begin
  {received buffer of audio stream, now dispatch}

  {this loops through the returned buffer in chunks,
   generating multiple callbacks per chunk}

    ChunkPos := Buffer;
    if (Size >= fDecodeSize) then
    begin
      for i := 0 to (Size div fDecodeSize) - 1 do
      begin
        { pass on buffer in chunks
          - allows cancelling of recording with high precision }

        { pass on the buffers in all cases to keep decoder up to date -
          fMonitorDTMF is checked in the event handler }
        fDTMFDecoder.AudioInBufferFilled(ChunkPos, fDecodeSize);

        Inc(ChunkPos, fDecodeSize);
      end;  {for chunks in buffer}
    end; {if size large enough}

end;

procedure TAudioMainForm.OnDigit(Sender : TObject ; Digit : Char);
begin

  lblDTMF.Caption := lblDTMF.Caption + Digit;

end;


procedure TAudioMainForm.BufferFilled(const Buffer : PByte; const Size : Cardinal);
begin

  Chart1.Title.Text.Text := Format('Volume : %.4f', [fAudioIn.Volume]);
  if not Warned and (fAudioIn.Volume > WarningVolume) then
  begin
    lblWarnings.Caption := IntToStr(StrToIntDef(lblWarnings.Caption, 0) + 1);
    lstWarnings.Items.Insert(0, Format('%s %8.2f %.4f untrapped ', [lblWarnings.Caption, GetTickCount / 1000, fAudioIn.Volume]));
    Warned := true;
  end;

  if (chkChart.Checked) then
  begin
    UpdateChart(Buffer, Size);
  end;

  { TODO : an FFT chart would be super nice here }

  { TODO : pass on to DTMF detector here }

  UpdateDTMF(Buffer, Size);


  pbVolume.Position := round(100 * fAudioIn.Volume);

end;



procedure TAudioMainForm.btnLoopTimerInClick(Sender: TObject);
begin
   tmrIn.Enabled := not tmrIn.Enabled;
   if tmrIn.Enabled then
   begin
     LastStart := GetTickCount; 
     lblCountIn.Caption := '0';
     lblWarnings.Caption := '0';
     lstWarnings.Clear;

     btnLoopTimerIn.Caption := 'Stop Test';
   end
   else
     btnLoopTimerIn.Caption := 'Test';

end;

procedure TAudioMainForm.tmrInTimer(Sender: TObject);
begin

  if (btnTestIn.Enabled) then
  begin
    if (fAudioIn.Active) then
    begin
      if (CompareTickCount(LastStart + Cardinal(500 * (cbTestLength.ItemIndex + 1))) > 0) then
        btnTestInClick(self);

    end
    else
    begin
      LastStart := GetTickCount;
      btnTestInClick(self);
      lblCountIn.Caption := IntToStr(StrToIntDef(lblCountIn.Caption, 0) + 1);
      lblCountIn.Refresh;
    end;

  end;

end;

procedure TAudioMainForm.DoException(Sender: TObject; E: Exception);
begin
  if Sender is TAudioBase then
  begin
    if Sender is TAudioIn then
    begin

      tmrIn.Enabled := false;
      lblAudioInException.Caption := E.Message;
      btnTestIn.Enabled := false;
      btnTestIn.Caption := 'Start';
      fAudioIn.Stop;
      OutputDebugString(PChar(E.Message));
    end
    else
    if Sender is TAudioOut then
    begin

      tmrIn.Enabled := false;
      lblAudioOutException.Caption := E.Message;
      btnTestOut.Enabled := false;
      btnTestOut.Caption := 'Test';
      btnTestTones.Enabled := false;
      btnTestTones.Caption := 'Test';
      OutputDebugString(PChar(E.Message));
    end;
  end
  else
   Application.ShowException(E);


end;
procedure TAudioMainForm.btnResetInClick(Sender: TObject);
begin
  lblAudioInException.Caption := 'Exception <none>';
  btnTestIn.Enabled := true;
end;

procedure TAudioMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin

  fAudioIn.Stop;

end;

procedure TAudioMainForm.btnLoopCodeInClick(Sender: TObject);
begin

  btnTestInClick(self);
  btnTestInClick(self);

end;

procedure TAudioMainForm.chkTraceFormClick(Sender: TObject);
begin
  TraceTerminal(chkTraceForm.Checked);
end;

procedure TAudioMainForm.btnPlayFileNewClick(Sender: TObject);
begin

  { setup messages and playback }
  if (fPlay.Playing) then
  begin
    ;
  end
  else
  begin
    if FileExists(ebFileName.Text) then
    begin
      fPlay.WaveDevice := cbAudioOut.ItemIndex;
      fPlay.PlaySource := ebFileName.Text;
      lstMessages.Items.Add('Start '+ FloatToStr(fPlay.PlayLength));
      fPlay.SynchMethod := TSynchMethod(cbPlaySynch.ItemIndex);
    end;
  end;

  { kick off using the method desired }
  if chkUseThread.Checked then
    fAudioTestThread.PlayActive := not fAudioTestThread.PlayActive
  else
    fPlay.Playing := not fPlay.Playing;

  if (fPlay.Playing) then
    btnPlayFileNew.Caption := 'Stop'
  else
    btnPlayFileNew.Caption := 'Play';


end;

procedure TAudioMainForm.btnTonesClick(Sender: TObject);
var
  ToneGen : TToneGenerator;
begin

  ToneGen := TToneGenerator.Create;
  try
    ToneGen.DeviceID := cbAudioOut.ItemIndex;
    lblDTMF.Caption := '';
    ToneGen.PlayDTMF(ebTones.Text, 150);
  finally
    ToneGen.Free;
  end;

end;

procedure TAudioMainForm.btnFileNameClick(Sender: TObject);
begin
  if dlgOpen.Execute then
    ebFileName.Text := dlgOpen.filename;
end;

procedure TAudioMainForm.OnPlayDone(Sender: TObject);
begin
  btnPlayFileNew.Caption := 'Play';
  lstMessages.Items.Add('Done');
  fAudioTestThread.PlayActive := fPlay.Playing;
end;

procedure TAudioMainForm.OnTestPlayDone(Sender: TObject);
begin
  btnPlayStart.Enabled := true;
  lstMessages.Items.Add('Done');
end;


procedure TAudioMainForm.btnTestOutClick(Sender: TObject);
begin

  tmrOut.Enabled := not tmrOut.Enabled;

  if (tmrOut.Enabled) then
    btnTestOut.Caption := 'Stop Test'
  else
    btnTestOut.Caption := 'Test';

end;

procedure TAudioMainForm.tmrOutTimer(Sender: TObject);
begin

  if not Assigned(fPlay) or not fPlay.Playing then
    btnPlayFileNewClick(self);

end;

procedure TAudioMainForm.btnTestTonesClick(Sender: TObject);
begin

  tmrTones.Enabled := not tmrTones.Enabled; 
  if (tmrTones.Enabled) then
     btnTestTones.Caption := 'Stop Test'
  else
     btnTestTones.Caption := 'Test';

end;

procedure TAudioMainForm.tmrTonesTimer(Sender: TObject);
begin

  btnTonesClick(self);

end;

procedure TAudioMainForm.ebVolumeThresholdChange(Sender: TObject);
begin
  try
    WarningVolume := StrToFloat(ebVolumeThreshold.Text);
  except
   on E: EConvertError do
   begin
     ebVolumeThreshold.Text := FloatToStr(DEFAULT_WARNING_VOLUME);
     raise;
   end;
  end;
end;

type
   TSmallIntArray = array[0..32768] of SmallInt;
   PSmallIntArray = ^TSmallIntArray;

procedure TAudioMainForm.btnTestWavClick(Sender: TObject);
var
  Wave : TWaveFile;
  Data : PByte;
  i : integer;
  Datum : PSmallIntArray;
  SamplesWritten : integer;
begin
  SamplesWritten := 0;
  Wave := TWaveFile.Create;
  try

      { generates an A 440Hz wave file}
      {it's a mono recorder }
      Wave.OpenForWrite('test.wav', 8000, 16, 1);

      GetMem(Data, 32000);
      try
        Datum := PSmallIntArray(Data);
        for i := 0 to 32000 div 2 do
        begin
          Datum[i] := round(sin((i * 2 * Pi * 440)/ 8000) * (High(SmallInt) div 2));
        end;

        { write the data out}
        Wave.WriteSampleData(16000, SamplesWritten, Data);

      finally
        FreeMem(Data);
      end;

  finally
    Wave.Free;
  end;


end;

procedure TAudioMainForm.CreatePlay;
begin

  if not Assigned(fPlay) then
  begin
    fPlay := TAudioPlay.Create;
    fPlay.OnDone := OnPlayDone;
  end;

end;

procedure TAudioMainForm.DestroyPlay;
begin
  FreeAndNil(fPlay);

end;

procedure TAudioMainForm.CreateTestPlay;
begin

  DestroyTestPlay;
  fTestPlay := TAudioPlay.Create;
  fTestPlay.OnDone := OnTestPlayDone;
end;

procedure TAudioMainForm.DestroyTestPlay;
begin
  FreeAndNil(fTestPlay);
end;

procedure TAudioMainForm.btnPlayStartClick(Sender: TObject);
begin
  CreateTestPlay;

  fTestPlay.WaveDevice := cbAudioOut.ItemIndex;
  fTestPlay.PlaySource := ebFileName.Text;
  lstMessages.Items.Add('Start '+ FloatToStr(fTestPlay.PlayLength));
  fTestPlay.Playing := True;
  btnPlayStart.Enabled := false;
  
end;

procedure TAudioMainForm.tmrTestOutTimer(Sender: TObject);
begin
  if btnPlayStart.Enabled then
    btnPlayStartClick(self);

end;

procedure TAudioMainForm.btnPlayStartTestClick(Sender: TObject);
begin
  tmrTestOut.Enabled := not tmrTestOut.Enabled;

  if (tmrTestOut.Enabled) then
    btnPlayStartTest.Caption := 'Stop Test'
  else
    btnPlayStartTest.Caption := 'Test';
end;

procedure TAudioMainForm.chkUseThreadClick(Sender: TObject);
begin
  if chkUseThread.Checked then
    fAudioTestThread.Resume
  else
    fAudioTestThread.Suspend;
end;

end.
