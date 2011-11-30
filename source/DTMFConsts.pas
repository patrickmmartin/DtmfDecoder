unit DTMFConsts;

interface

const

  DTMFFrequencies : array [0..7] of integer =
    (
      697 , 770 , 852, 941, 1209, 1336, 1477, 1633
    );


type
  TDTMFFrequencies = record
    Freq1, Freq2 : single;
  end;

function CharDTMFFrequencies(Digit : Char) : TDTMFFrequencies;

implementation


function CharDTMFFrequencies(Digit : Char) : TDTMFFrequencies;
begin
{
/*
 *
 * DTMF frequencies
 *
 *      1209 1336 1477 1633
 *  697   1    2    3    A
 *  770   4    5    6    B
 *  852   7    8    9    C
 *  941   *    0    #    D
 *
 */
 }

  with Result do
  begin

    {calc freq1 - down}
    case Digit of
    '1', '4', '7', '*'  : Freq1 := 1209;
    '2', '5', '8', '0'  : Freq1 := 1336;
    '3', '6', '9', '#'  : Freq1 := 1477;
    'A', 'B', 'C', 'D'  : Freq1 := 1633;
    else
      Freq1 := 1000;
    end; {case}

    {calc freq2 - across}
    case Digit of
    '1', '2', '3', 'A'  : Freq2 := 697;
    '4', '5', '6', 'B'  : Freq2 := 770;
    '7', '8', '9', 'C'  : Freq2 := 852;
    '*', '0', '#', 'D'  : Freq2 := 941;
    else
      Freq2 := 1020;
    end; {case}
  end;

end;

end.
