unit DTMF;

interface

uses
  Windows,       { Windows }
  Nsp,           { NDSdct, PFloat }
  classes,       { TList }
  DTMFConsts  { consts }
  ;


const
  DEFAULT_FREQRESOLUTION = 40;
  DEFAULT_MINFREQ = 600;
  DEFAULT_MAXFREQ = 2000;
  {the output is is very sensitive to this value
   5 is an ecellent starting point}
  DEFAULT_POWERRATI0 = 5;
  DEFAULT_SILENCECOUNT = 80 {ms};
  DEFAULT_DROPOUTCOUNT = 100 {ms};


  {Nokia d600 detected tones in range}
  { 656-703, 734-765, 812-843, 906-953, 1171-1203, 1296-1328, 1437-1468, ??-??}

  {Nokia nk402 detected tones in range}
  { 687-703, 750-765, 823-859, 921-953, 1187-1203, 1328-1343, 1468-1500, ??-?? }


const

  {may be same as DTMF set, or may be a superset - this values are checked in DTMFDigit}
  RawGoertzelFrequencies : array [0..7] of integer =
     (
       { DTMF frequencies ... }
       697 , 770 , 852, 941, 1209, 1336, 1477, 1633
     );

  GuardedGoertzelFrequencies : array [0..12] of integer =
     (
       { guard bands }
       300, 2000, 3000, 4000, 6000,
       { DTMF frequencies ... }
       697 , 770 , 852, 941, 1209, 1336, 1477, 1633
     );


  DTMFChars : array [0..3, 0..3] of Char =
   (
     ('1', '2', '3', 'A'),
     ('4', '5', '6', 'B'),
     ('7', '8', '9', 'C'),
     ('*', '0', '#', 'D')
   );

type
  { making these available }
  TFloatArray = array[0..65535] of single;
  PFloatArray = ^TFloatArray;

  TSpectrumRecord = record
    Freq : single;
    Value : single;
    Index : integer;
  end;
  PSpectrumRecord = ^TSpectrumRecord;

  TDTMFStatus = (dsUnknown, dsDetected, dsWeak);

  TDTMFTones = record
    High : TSpectrumRecord;
    Low : TSpectrumRecord;
    Status : TDTMFStatus;
    PowerRatio : single;
  end;

  TToneAnalysis = (taFFT, taGoertzel);

resourcestring

  sUnknown = 'unknown';
  sDetected = 'detected';
  sWeak = 'too weak';

const

  DTMFStatusDesc : array[TDTMFStatus] of string = (sUnknown, sDetected, sWeak);

  NullSpectrumRecord : TSpectrumRecord = (Freq : 0 ; Value : 0 ; Index : 0 ;);

const

  NullTone : TDTMFTones = (High : (Freq : 0 ; Value : 0 ; Index : 0 ;) ;
                           Low : (Freq : 0 ; Value : 0 ; Index : 0 ;) ;
                           Status : dsUnknown;
                           PowerRatio : 0);

type
  TDigitEvent = procedure (Sender : TObject ; Digit : Char) of object;
  TAnalyseEvent = procedure (Sender : TObject ; DTMFTones : TDTMFTones) of object;
  TDataEvent = procedure (Sender : TObject ; Values : PFloat ; Count : Cardinal) of object;

type
  TDTMFDecoder = class
  private
    { Private declarations }
    fQuantisation : Cardinal;
    fFrameRate : Cardinal;
    fLastDetectChar : Char;
    fLastCharCount : DWORD;
    fSilenceStart : DWORD;
    fChunkTime : DWORD;

    fFreqResolution : integer;
    fMinFreq : single;
    fMaxFreq : single;
    fPowerRatio : single;
    fSilenceCount : DWORD;
    fDropoutCount : DWORD;

    fOnDigit : TDigitEvent;
    fOnDetect : TDigitEvent;
    fOnDetectEnd : TDigitEvent;
    fOnAnalyse : TAnalyseEvent;
    fOnData : TDataEvent;
    fOnSpectrum : TDataEvent;
    fAnalysis : TToneAnalysis;
    fList : TList;
    Data : array[0..16384] of single;
    Spectrum : array[0..16384] of single;
    GoertzelFrequencies : array of integer;
    fGuarded: boolean;
    fInDigit : boolean;
    fDigit : Char;
    procedure SetGuarded(const Value: boolean);


  protected
    procedure Analyse(const Buffer: PByte; const Size: Cardinal);
    procedure DoDigit(DTMFDigit : Char);
    procedure DoDetect(DTMFDigit : Char);
    procedure DoDetectEnd(DTMFDigit : Char);
    function PeakRatio(PeakValue : single ; List : TList) : single;
    function DTMFDigit(DTMFTones : TDTMFTones) : Char;
    function GTZTonePair(NumPoints : integer; Data : PFloatArray ; Rate : single) : TDTMFTones;
    function FFTTonePair(NumPoints : integer; Data : PFloatArray ; Rate : single) : TDTMFTones;
    procedure ClearList(Index : integer);
    function ListRecord(Index : integer): PSpectrumRecord;

  public
    { Public declarations }
    procedure AudioInBufferFilled(const Buffer: PByte; const Size: Cardinal);
    procedure Reset;
    property OnDigit : TDigitEvent read fOnDigit write fOnDigit;
    property OnDetect : TDigitEvent read fOnDetect write fOnDetect;
    property OnDetectEnd : TDigitEvent read fOnDetectEnd write fOnDetectEnd;
    property OnAnalyse : TAnalyseEvent read fOnAnalyse write fOnAnalyse;
    property OnData : TDataEvent read fOnData write fOnData;
    property OnSpectrum : TDataEvent read fOnSpectrum write fOnSpectrum;
    property Analysis : TToneAnalysis read fAnalysis write fAnalysis;
    property PowerRatio : single read FPowerRatio write fPowerRatio;
    property DropOutCount : DWORD read fDropoutCount write fDropOutCount;
    property SilenceCount : DWORD read fSilenceCount write fSilenceCount;
    property Quantisation : Cardinal read fQuantisation write fQuantisation;
    property Framerate : Cardinal read fFrameRate write fFrameRate;
    property Guarded : boolean read FGuarded write SetGuarded;
    property ChunkTime : DWORD read fChunkTime write fChunkTime;
    constructor Create;
    destructor Destroy; override;
  end;

implementation

uses
  NSPErrorHandler,        { NSP wrapper for error redirection }
  SysUtils, {TWordArray}
  mmSystem, {wave stuff}
  Dialogs;  {Showmessage}

function CompareSpectrum(Item1, Item2: Pointer): Integer;
begin

  {allows emphasis function to be used}

  if ( PSpectrumRecord(Item1)^.Value > PSpectrumRecord(Item2)^.Value) then
    Result :=  -1
  else
  if ( PSpectrumRecord(Item1)^.Value < PSpectrumRecord(Item2)^.Value) then
    Result :=  1
  else
    Result := 0;

end;


function EmphasisedVal(Frequency : single ; Value : single) :  single;
begin

  {apply some kind of pre-emphasis here if requried}
  Result := Value;

end;

function TDTMFDecoder.PeakRatio(PeakValue : single ; List : TList) : single;
begin

  if (List.Count > 0) and (PSpectrumRecord(List[List.Count div 2])^.Value <> 0) then
  begin
    Result := PeakValue / PSpectrumRecord(List[List.Count div 2])^.Value;
  end
  else
    Result := 0;

end;


function TDTMFDecoder.DTMFDigit(DTMFTones : TDTMFTones) : Char;
var
  i, HighIndex, LowIndex : integer;

begin
  LowIndex := -1;
  HighIndex := -1;

  for i := 0 to 3 do
  begin
    if Abs(DTMFTones.Low.Freq - DTMFFrequencies[i]) < fFreqResolution then
    begin
      LowIndex := i;
      break;
    end;
  end;

  for i := 4 to 7 do
  begin
    if Abs(DTMFTones.High.Freq - DTMFFrequencies[i]) < fFreqResolution then
    begin
      HighIndex := i - 4;
      break;
    end;
  end;

  if (HighIndex <> -1 ) and (LowIndex <> -1) then
    Result := DTMFChars[LowIndex, HighIndex]
  else
    Result := #0;

end;



procedure TDTMFDecoder.AudioInBufferFilled(const Buffer: PByte; const Size: Cardinal);
begin

  Analyse(Buffer, Size);

end;

procedure TDTMFDecoder.DoDigit(DTMFDigit : Char);
begin

  if Assigned(fOnDigit) then
    fOnDigit(self, DTMFDigit);

end;


procedure TDTMFDecoder.DoDetect(DTMFDigit : Char);
begin

  fDigit := DTMFDigit;
  if Assigned(fOnDetect) then
    fOnDetect(self, DTMFDigit);

end;


procedure TDTMFDecoder.DoDetectEnd(DTMFDigit: Char);
begin
  if Assigned(fOnDetectEnd) then
    fOnDetectEnd(self, DTMFDigit);
  fDigit := #0;

end;

procedure TDTMFDecoder.Reset;
begin
  {ensure that state is reset for when audio detection is (re)started }
  fSilenceStart := 0;
  fChunkTime := 0;
  {set last character received marker}
  fLastCharCount := ChunkTime;
  fInDigit := false;
end;

procedure TDTMFDecoder.Analyse(const Buffer: PByte; const Size: Cardinal);
var
  i : integer;
  DataSize : integer;
  DTMFTones : TDTMFTones;
  DTMFResult : Char;

begin

  {Quantization is restricted to 8, 16}
  DataSize := Size div (fQuantisation shr 3);

  {update chunk time, and account for rollovers }
  ChunkTime := ChunkTime + round(1000 * DataSize / fFrameRate);

  for i := 0 to DataSize - 1 do
  begin
    case fQuantisation of
      8:
        Data[i] := Byte(PByteArray(Buffer)[i]);
      16:
        Data[i] := SmallInt(PWordArray(Buffer)[i]);
    end;
  end;

  if Assigned(fOnData) then
    fOnData(self, PFloat(@Data), DataSize);

  case fAnalysis of
  taFFT :
    DTMFTones := FFTTonePair(DataSize, @Data, fFrameRate );
  taGoertzel :
    DTMFTones := GTZTonePair(DataSize, @Data, fFrameRate );
  end; {case}


  if Assigned(fOnAnalyse) then
     fOnAnalyse(self, DTMFTones);

  DTMFResult := DTMFDigit(DTMFTones);

  { here is the escape hatch for when the digit processing really needs to be altered
    beyond what is implemented using this class
    users can do their own detection of digits based upon the emitted digits, and ignore the OnDetect event}

  DoDigit(DTMFResult);

  { else the results of this test could be used in the other event}


  { desired:
    a digit is emitted once and only once when the second identical digit
    arrives after a period of silence
    ( this eliminates noise very effectively and cheaply )
    - a silence is deemed to have occurred when fSilenceCount ms have elapsed
    and no digits have been detected
    (including those ignored after first emitted digit)
   }


  if (DTMFResult <> #0) then
  begin
    {digit detected}
    {if silence has elapsed and the previous digit is same as last detected then emit digit}
    if ((fSilenceStart <> 0) and ((fSilenceStart + fSilenceCount) < ChunkTime)) and
       (fLastDetectChar = DTMFResult) then
    begin
      fInDigit := true;
      DoDetect(DTMFResult);
      fSilenceStart := 0;
    end;
    {set last character received marker}
    fLastCharCount := ChunkTime;
  end
  else
  begin
    {no digit -  decide whether to flag silence start by testing for a sufficiently long dropout}
    if ((fLastCharCount + fDropoutCount) < ChunkTime) then
    begin
      fSilenceStart := fLastCharCount;
      if (fInDigit) then
      begin
        fInDigit := false;
        DoDetectEnd(fDigit);
      end;
    end;
  end;

  fLastDetectChar := DTMFResult;


end;

function TDTMFDecoder.GTZTonePair(NumPoints : integer; Data : PFloatArray ; Rate : single) : TDTMFTones;
var
  i : integer;
  GState : TNSPSGoertzState;
  GResults: TSCplx;
  TonePowers : array  of single;
  SpectrumRecord : PSpectrumRecord;
  HighRecord : PSpectrumRecord;
  LowRecord : PSpectrumRecord;

begin


  SetLength(TonePowers, Length(GoertzelFrequencies));

  {the goertzel analysis is more efficient than an N-sample FFT for m freqs. where m < 2 log2 N
  this means the breakpoint for simple DTMF ( 8 / 13 bands ) is 512 samples,
  for which size noise, overhead, appropriateness of the processing and other crud may be more important issues}

  { run through the set of frequencies }
  for i := Low(GoertzelFrequencies) to High(GoertzelFrequencies) do
  begin
    {uses normalised frequencies}
    nspsGoertzInit( (GoertzelFrequencies[i] / Rate ) ,GState);
    GResults := nspsbGoertz(GState, PFloat(Data), NumPoints);
    with GResults do
      TonePowers[i] := sqrt(Re*Re + Im*Im) {* 0.01};
  end;

  if Assigned(fOnSpectrum) then
    fOnSpectrum(self, PFloat(@TonePowers[0]), High(GoertzelFrequencies) - Low(GoertzelFrequencies));

  {choose likeliest tone pair}

  ClearList(High(GoertzelFrequencies) - Low(GoertzelFrequencies));
  for i := Low(GoertzelFrequencies) to High(GoertzelFrequencies) do
  begin
    SpectrumRecord := ListRecord(i);
    SpectrumRecord^.Freq := GoertzelFrequencies[i];
    SpectrumRecord^.Index := i;
    SpectrumRecord^.Value := TonePowers[i];
    (* not using emphasis 
    SpectrumRecord^.Value := EmphasisedVal(GoertzelFrequencies[i], TonePowers[i]);
    *)
  end;

  fList.Sort(CompareSpectrum);

  {just get the top values}
  HighRecord := PSpectrumRecord(fList[0]);
  LowRecord := PSpectrumRecord(fList[1]) ;


  if (HighRecord.Freq < LowRecord.Freq) then
  begin
    HighRecord := LowRecord;
    LowRecord := PSpectrumRecord(fList[0]) ;
  end;

  { get average tone pair energy relative to the median value in the set
    - this seems to be a good test in general}

  Result.PowerRatio := PeakRatio((Highrecord^.Value + LowRecord^.Value)/ 2, fList);

  { simple threshhold test to see whether tones are worthwhile }
  { NB for extremely distorted inputs, testing the average power content is useless,
    as there is energy content everywhere,
    a better test is use the absolute value - sad but true}

  if ( Result.PowerRatio > fPowerRatio ) then
  begin
    Result.Status := dsDetected;
    Result.Low := LowRecord^ ;
    Result.High := HighRecord^;
  end
  else
  begin
    Result := NullTone;
    Result.Status := dsWeak;
  end


end;

function TDTMFDecoder.FFTTonePair(NumPoints : integer; Data : PFloatArray ; Rate : single) : TDTMFTones;
var
  i : integer;
  SpectrumRecord : PSpectrumRecord;
  HighRecord : TSpectrumRecord;
  LowRecord : TSpectrumRecord;
  Frequency : single;
begin

  Result := NullTone;
  try
    {optimisation}
    ClearList(NumPoints - 1);

    {do transform}
    nspsDct(PFloat(Data), PFloat(@Spectrum[0]), NumPoints, NSP_DCT_Forward);
    if Assigned(fOnSpectrum) then
      fOnSpectrum(self, PFloat(@Spectrum[0]), NumPoints);

    for i := 0 to NumPoints - 1 do
    begin

      Frequency := i * (Rate / ( 2 * NumPoints));
      if (Frequency > FMinFreq ) and  (Frequency < FMaxFreq ) then
      begin
        SpectrumRecord := ListRecord(i);
        SpectrumRecord^.Freq := Frequency;
        SpectrumRecord^.Value := EmphasisedVal(Frequency, Spectrum[i]);
        SpectrumRecord^.Index := i;
      end;

    end;

    fList.Sort(CompareSpectrum);

    {this is based purely upon the numerical values }
    {a more optimised approach would examine certain frequency bands by value}
    {but let's keep it general for now}

    i := 0;
    {get topmost}
    HighRecord := PSpectrumRecord(fList[i])^ ;
    {now seek the next highest that is also beyond the frequency resolution}
    while (i < NumPoints - 1) and (Abs(HighRecord.Freq - PSpectrumRecord(fList[i])^.Freq) < fFreqResolution) do
      Inc(i);
    LowRecord := PSpectrumRecord(fList[i])^;

    if (HighRecord.Freq < LowRecord.Freq) then
    begin
      HighRecord := LowRecord;
      LowRecord := PSpectrumRecord(fList[0])^ ;
    end;


    Result.PowerRatio := PeakRatio((Highrecord.Value + LowRecord.Value)/ 2, fList);

    {test here for strength}

    if ( Result.PowerRatio > fPowerRatio ) then
    begin
      Result.High := HighRecord;
      Result.Low := LowRecord;
    end
    else
    begin
      Result.Status := dsWeak;
    end;
  except
    on E: Exception do
    begin

    end;
  end;  {try .. except}

end;


procedure TDTMFDecoder.ClearList(Index : integer);
begin
  while fList.Count > Index do
  begin
    Dispose(PSpectrumRecord(fList[fList.Count - 1]));
    fList.Delete(fList.Count - 1);
  end;
end;


function TDTMFDecoder.ListRecord(Index : integer): PSpectrumRecord;
begin

  if (Index >= fList.Count) then
  begin
    New(Result);
    fList.Add(Result);
  end
  else
  begin
    Result := fList[Index];
  end;

end;


constructor TDTMFDecoder.Create;
begin

  inherited;
  fList := TList.Create;

  fAnalysis := taGoertzel;

  fFrameRate := 8000;
  fQuantisation :=  16;
  fFreqResolution := DEFAULT_FREQRESOLUTION;
  fMinFreq := DEFAULT_MINFREQ;
  fMaxFreq := DEFAULT_MAXFREQ;
  fPowerRatio := DEFAULT_POWERRATI0;
  fSilenceCount := DEFAULT_SILENCECOUNT;
  fDropOutCount := DEFAULT_DROPOUTCOUNT;
  SetGuarded(true);

end;


destructor TDTMFDecoder.Destroy;
begin
  ClearList(0);
  fList.Free;
  inherited;
end;



procedure TDTMFDecoder.SetGuarded(const Value: boolean);
var
  i : integer;
begin
  fGuarded := Value;

  if (fGuarded) then
  begin
    SetLength(GoertzelFrequencies, High(GuardedGoertzelFrequencies) + 1);
    {copy over values}
    for i :=  Low(GuardedGoertzelFrequencies) to High(GuardedGoertzelFrequencies) do
      GoertzelFrequencies[i] := GuardedGoertzelFrequencies[i];

  end
  else
  begin
    SetLength(GoertzelFrequencies, High(RawGoertzelFrequencies) + 1);
    for i :=  Low(RawGoertzelFrequencies) to High(RawGoertzelFrequencies) do
      GoertzelFrequencies[i] := RawGoertzelFrequencies[i];
  end;

end;



end.
