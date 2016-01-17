unit AudioWave;

interface

uses
  Windows,   { PByte!}
  classes;   { TFileStream}

const
    MaxWaveChannels = 4;    { increase if necessary }

type
  sample16bit = SmallInt;
  sample8bit = Byte;

    RiffChunkHeader = record
        ckID:     longint;    { four-character chunk ID }
        ckSize:   longint;    { length of data in chunk }
    end;


    WaveFormat_ChunkData = record
        wFormatTag:         word;
        nChannels:          word;
        nSamplesPerSec:     longint;
        nAvgBytesPerSec:    longint;
        nBlockAlign:        word;
        nBitsPerSample:     word;
    end;


    WaveFormat_Chunk = record
        header:   RiffChunkHeader;
        data:     WaveFormat_ChunkData;
    end;


    TWaveFile = class
    private
        FileStream: TFileStream;
        fileOpen: boolean;
        writeMode: boolean;

        fRiffHeader: RiffChunkHeader;
        fWaveFormat: WaveFormat_Chunk;
        fDataOffset: longint;
        fDataHeader: RiffChunkHeader;

    public
        numSamples: longint;

        {------- methods ------------------------------------------}

        constructor Create;
        destructor  Destroy; override;

        procedure OpenForRead (Filename: string);

        procedure Seek ( sampleIndex: longint );

        procedure OpenForWrite (  Filename: string;
                                  _SamplingRate:   longint;
                                  _BitsPerSample:  word;
                                  _NumChannels:    word);

        function ReadSampleData (  numToRead: integer;               { NumChannels * NumSamples }
                                    data: PByte ) : integer ;

        procedure WriteSampleData ( numToWrite:  integer;             { NumChannels * NumSamples }
                                    var  numActuallyWritten: integer;
                                    data: PByte );
        procedure Close;

        function SamplingRate:  longint;
        function BitsPerSample: word;
        function NumChannels:   word;
    end;



implementation

uses
  SysUtils;


resourcestring

  sFileNotOpen = 'File not open';
  sCouldNotWriteHeader = 'Could not write Header';

  sCouldNotWriteWave = 'Could not write WAVE chunk';
  sRIFFChunkMissing = 'RIFF chunk missing';

  sWaveChunkMissing = 'WAVE chunk missing';

  sFileIncorrectFormat = 'File incorrect format';
  sCouldNotReadFile = 'Could not read file';

  sCouldNotWriteFormat = 'Could not write format';
  sCouldNotWriteData = 'Could not write data';


  sErrorReadSampleData = 'Error reading sample data:'#13#10 +
    'Unknown sample size = %d bits';
  sErrorWriteSampleData = 'error writing sample data:'#13#10 +
    'Unknown sample size = %d bits';




{========================================================================}
{                             Private types                              }
{========================================================================}


{------------------------------------------------------------------------}
{                             Helper functions                           }
{------------------------------------------------------------------------}


function FourCC ( ChunkName: string ): longint;
var    retbuf: longint;
       i{, shift}: integer;
       c: char;

begin
    retbuf := 0;
    for i := 4 downto 1 do begin
        retbuf := retbuf SHL 8;
        if i <= Length(ChunkName) then
            c := ChunkName[i]
        else
            c := ' ';
        retbuf := retbuf OR longint(c);
    end;
    FourCC := retbuf;
end;


{------------------------------------------------------------------------}
{                            Method implementation                       }
{------------------------------------------------------------------------}

constructor TWaveFile.Create;
begin
    inherited;
    fileOpen := FALSE;
    writeMode := FALSE;
    fRiffHeader.ckID := FourCC('RIFF');
    fRiffHeader.ckSize := 4 + sizeof(fWaveFormat) + sizeof(fRiffHeader);
    fDataOffset := 0;
    numSamples := 0;
    fDataHeader.ckID := FourCC('data');
    fDataHeader.ckSize := 0;
    fWaveFormat.header.ckID := FourCC('fmt');
    fWaveFormat.header.ckSize := sizeof(fWaveFormat.data);
end; { WaveFile.Init }



destructor TWaveFile.Destroy;
begin
    Close;
    inherited;
end; { WaveFile.Destroy }



procedure TWaveFile.OpenForRead ( filename: string );
var
    numRead: integer;
    signature: array [0..3] of char;
begin
    if fileOpen then Close;

    FileStream := TFileStream.Create(filename, fmShareDenyNone);

    fileOpen := TRUE;
    numread := FileStream.Read(fRiffHeader, sizeof(fRiffHeader));

    if (numRead <> sizeof(fRiffHeader)) or
       (fRiffHeader.ckID <> FourCC('RIFF')) then

      raise Exception.Create(sRIFFChunkMissing);

    numread := FileStream.Read( signature, 4);
    if (numRead <> 4) or
       (signature[0] <> 'W') or
       (signature[1] <> 'A') or
       (signature[2] <> 'V') or
       (signature[3] <> 'E') then
      raise Exception.Create(sWaveChunkMissing);

    numread := FileStream.Read(fWaveFormat, sizeof(fWaveFormat));
    if (numRead <> sizeof(fWaveFormat)) or
       (fWaveFormat.header.ckID <> FourCC('fmt')) or
       (fWaveFormat.data.nChannels < 1) or
       (fWaveFormat.data.nChannels > MaxWaveChannels) then
      raise Exception.Create(sFileIncorrectFormat);

    fDataOffset := FileStream.Position;
    numRead := FileStream.Read(fDataHeader, sizeof(fDataHeader));
    if numRead <> sizeof(fDataHeader) then
      raise Exception.Create(sCouldNotReadFile);

    numSamples :=
        (FileStream.Size - FileStream.Position) DIV (NumChannels * BitsPerSample DIV 8);
end; { WaveFile.OpenForRead }



procedure TWaveFile.Seek ( sampleIndex: longint );
var
    sampleSize: word;
    fileOffset: longint;
begin
    if not fileOpen then
      raise Exception.Create(sFileNotOpen);

    sampleSize := (BitsPerSample + 7) DIV 8;
    fileOffset := fDataOffset +
                  sizeof(fDataHeader) +
                  sampleSize * NumChannels * sampleIndex;
    FileStream.Seek(fileOffset, soFromBeginning);
end; { WaveFile.Seek }



procedure TWaveFile.OpenForWrite (  Filename: string;
                                    _SamplingRate:   longint;
                                    _BitsPerSample:  word;
                                    _NumChannels:    word );
var
    result: integer;
    signature: array [0..3] of char;
begin
    if fileOpen then Close;
    FileStream := TFileStream.Create(filename, fmCreate);

        fileOpen := TRUE;
        writeMode := TRUE;
        Result := FileStream.Write(fRiffHeader, sizeof(fRiffHeader));
        if result <> sizeof(fRiffHeader) then
           raise Exception.Create(sCouldNotWriteHeader);

        signature[0] := 'W';
        signature[1] := 'A';
        signature[2] := 'V';
        signature[3] := 'E';
        Result := FileStream.Write(signature, sizeof(signature));

        if result <> 4 then
           raise Exception.Create(sCouldNotWriteWave);

        fWaveFormat.header.ckID := FourCC('fmt');
        fWaveFormat.header.ckSize := sizeof(fWaveFormat.data);
        fWaveFormat.data.wFormatTag := 1;  {PCM}
        fWaveFormat.data.nSamplesPerSec := _SamplingRate;
        fWaveFormat.data.nChannels := _NumChannels;
        fWaveFormat.data.nBitsPerSample := _BitsPerSample;
        fWaveFormat.data.nAvgBytesPerSec := (_NumChannels * _SamplingRate * _BitsPerSample) DIV 8;
        fWaveFormat.data.nBlockAlign := (_NumChannels * _BitsPerSample) DIV 8;

        Result := FileStream.Write(fWaveFormat, sizeof(fWaveFormat));
        if result <> sizeof(fWaveFormat) then
           raise Exception.Create(sCouldNotWriteFormat);

        fDataOffset := FileStream.Position;
        fDataHeader.ckID := FourCC('data');
        fDataHeader.ckSize := 0;   {will need to be backpatched later}
        Result := FileStream.Write(fDataHeader, sizeof(fDataHeader));
        if result <> sizeof(fDataHeader) then
           raise Exception.Create(sCouldNotWriteData);
end; { WaveFile.OpenForWrite }


procedure TWaveFile.Close;
begin
    {no checking here  - it wasn't me}
    if fileOpen then begin
        if writeMode then begin
            {need to backpatch the riff header}
            FileStream.Position := 0;
            FileStream.Write(fRiffHeader, sizeof(fRiffHeader));

            {now backpatch the PCM data chunk}
            FileStream.Seek(fDataOffset, soFromBeginning );
            FileStream.Write(fDataHeader, sizeof(fDataHeader));
        end;

        FileStream.Free;
        FileStream := nil;
        fileOpen := FALSE;
    end;
end; { WaveFile.Close }



function TWaveFile.BitsPerSample: word;
begin
    BitsPerSample := fWaveFormat.data.nBitsPerSample;
end; { WaveFile.BitsPerSample }



function TWaveFile.NumChannels: word;
begin
    NumChannels := fWaveFormat.data.nChannels;
end; { WaveFile.NumChannels }



function TWaveFile.SamplingRate: longint;
begin
    SamplingRate := fWaveFormat.data.nSamplesPerSec;
end; { WaveFile.SamplingRate }



function TWaveFile.ReadSampleData ( numToRead: integer;               { NumChannels * NumSamples }
                                    data: PByte ) : integer;
begin
  { TODO 1 : work out the problem that is fixed by this !! }
  { maybe TWaveFormatEx is actually used, and is there additional data ?}
  Seek(8);
    if BitsPerSample = 16 then
    begin
      Result := FileStream.Read(data^, numToRead * sizeof(sample16bit));
      Result := Result DIV sizeof(sample16bit);
    end
    else
    if BitsPerSample = 8 then
    begin
      Result := FileStream.Read(data^, numToRead * sizeof(sample8bit));
    end
    else
      raise Exception.CreateFmt(sErrorReadSampleData, [BitsPerSample]);
end; { WaveFile.ReadSampleData }


procedure TWaveFile.WriteSampleData (
    numToWrite:  integer;             { NumChannels * NumSamples }
    var  numActuallyWritten: integer;
    data: PByte );
begin

  if not (BitsPerSample  in [8,16]) then
      raise Exception.CreateFmt(sErrorWriteSampleData, [BitsPerSample] );

  numActuallyWritten := FileStream.Write(data^, numToWrite * sizeof(sample16bit));
  INC ( fRiffHeader.ckSize, numActuallyWritten );
  INC ( fDataHeader.ckSize, numActuallyWritten );
  {convert to "samples"}
  numActuallyWritten := numActuallyWritten DIV (BitsPerSample shr 3);
end; { WaveFile.WriteSampleData }


end.
