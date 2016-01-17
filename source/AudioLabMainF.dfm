object AudioMainForm: TAudioMainForm
  Left = 545
  Top = 189
  Width = 899
  Height = 554
  Caption = 'Audio Test Project'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object lblAudioInException: TLabel
    Left = 240
    Top = 8
    Width = 169
    Height = 25
    AutoSize = False
    Caption = 'Exception <none>'
  end
  object lblCountIn: TLabel
    Left = 96
    Top = 136
    Width = 6
    Height = 13
    Caption = '0'
  end
  object lblWarnings: TLabel
    Left = 248
    Top = 136
    Width = 6
    Height = 13
    Caption = '0'
  end
  object lblPlaybackStatus: TLabel
    Left = 680
    Top = 136
    Width = 77
    Height = 13
    Caption = 'Playback Status'
  end
  object lblWarningStatus: TLabel
    Left = 8
    Top = 416
    Width = 73
    Height = 13
    Caption = 'Warning Status'
  end
  object lblKeepOpen: TLabel
    Left = 104
    Top = 64
    Width = 89
    Height = 21
    AutoSize = False
    Caption = 'Keep Open'
    Layout = tlCenter
  end
  object lblTestTime: TLabel
    Left = 104
    Top = 88
    Width = 89
    Height = 21
    AutoSize = False
    Caption = 'Test Time'
    Layout = tlCenter
  end
  object lblAudioInput: TLabel
    Left = 8
    Top = 8
    Width = 80
    Height = 21
    AutoSize = False
    Caption = 'Audio Input'
    Layout = tlCenter
  end
  object lblAudioOutput: TLabel
    Left = 480
    Top = 8
    Width = 80
    Height = 21
    AutoSize = False
    Caption = 'Audio Output'
    Layout = tlCenter
  end
  object lblAudioFile: TLabel
    Left = 480
    Top = 40
    Width = 46
    Height = 13
    Caption = 'Audio File'
  end
  object lblDTMFTones: TLabel
    Left = 480
    Top = 248
    Width = 63
    Height = 13
    Caption = 'DTMF Tones'
  end
  object lblVolume: TLabel
    Left = 8
    Top = 152
    Width = 35
    Height = 13
    Caption = 'Volume'
  end
  object lblVolumeThreshold: TLabel
    Left = 104
    Top = 112
    Width = 89
    Height = 21
    AutoSize = False
    Caption = 'Threshold'
    Layout = tlCenter
  end
  object lblCycleCount: TLabel
    Left = 8
    Top = 136
    Width = 57
    Height = 13
    Caption = 'Cycle Count'
  end
  object lblWarningCount: TLabel
    Left = 152
    Top = 136
    Width = 71
    Height = 13
    Caption = 'Warning Count'
  end
  object lblAudioOutException: TLabel
    Left = 704
    Top = 8
    Width = 169
    Height = 25
    AutoSize = False
    Caption = 'Exception <none>'
  end
  object lblDTMF: TLabel
    Left = 488
    Top = 336
    Width = 201
    Height = 13
    AutoSize = False
  end
  object chkTraceForm: TCheckBox
    Left = 712
    Top = 344
    Width = 97
    Height = 17
    Caption = 'Trace Form'
    TabOrder = 0
    OnClick = chkTraceFormClick
  end
  object btnTestIn: TButton
    Left = 8
    Top = 40
    Width = 75
    Height = 25
    Caption = 'Start'
    TabOrder = 1
    OnClick = btnTestInClick
  end
  object btnLoopTimerIn: TButton
    Left = 8
    Top = 72
    Width = 75
    Height = 25
    Caption = 'Test'
    TabOrder = 2
    OnClick = btnLoopTimerInClick
  end
  object Chart1: TChart
    Left = 8
    Top = 184
    Width = 465
    Height = 225
    BackWall.Brush.Color = clWhite
    BackWall.Brush.Style = bsClear
    Title.Text.Strings = (
      'TChart')
    LeftAxis.Automatic = False
    LeftAxis.AutomaticMaximum = False
    LeftAxis.AutomaticMinimum = False
    LeftAxis.Maximum = 33000.000000000000000000
    LeftAxis.Minimum = -33000.000000000000000000
    Legend.Visible = False
    View3D = False
    TabOrder = 3
    object Series1: TLineSeries
      Marks.ArrowLength = 8
      Marks.Visible = False
      SeriesColor = clRed
      Pointer.InflateMargins = True
      Pointer.Style = psRectangle
      Pointer.Visible = False
      XValues.DateTime = False
      XValues.Name = 'X'
      XValues.Multiplier = 1.000000000000000000
      XValues.Order = loAscending
      YValues.DateTime = False
      YValues.Name = 'Y'
      YValues.Multiplier = 1.000000000000000000
      YValues.Order = loNone
    end
  end
  object btnResetIn: TButton
    Left = 264
    Top = 40
    Width = 75
    Height = 25
    Caption = 'Reset'
    TabOrder = 4
    OnClick = btnResetInClick
  end
  object chkChart: TCheckBox
    Left = 264
    Top = 72
    Width = 97
    Height = 17
    Caption = 'Chart'
    Checked = True
    State = cbChecked
    TabOrder = 5
  end
  object btnLoopCodeIn: TButton
    Left = 8
    Top = 104
    Width = 75
    Height = 25
    Caption = 'Test Loop'
    TabOrder = 6
    OnClick = btnLoopCodeInClick
  end
  object cbAudioIn: TComboBox
    Left = 88
    Top = 8
    Width = 145
    Height = 21
    Style = csDropDownList
    ItemHeight = 13
    TabOrder = 7
  end
  object lstMessages: TListBox
    Left = 680
    Top = 152
    Width = 153
    Height = 113
    ItemHeight = 13
    TabOrder = 8
  end
  object cbAudioOut: TComboBox
    Left = 552
    Top = 8
    Width = 145
    Height = 21
    Style = csDropDownList
    ItemHeight = 13
    TabOrder = 9
  end
  object btnPlayFileNew: TButton
    Left = 480
    Top = 96
    Width = 75
    Height = 25
    Caption = 'Play'
    TabOrder = 10
    OnClick = btnPlayFileNewClick
  end
  object btnTones: TButton
    Left = 480
    Top = 304
    Width = 75
    Height = 25
    Caption = 'Play'
    TabOrder = 11
    OnClick = btnTonesClick
  end
  object ebTones: TEdit
    Left = 480
    Top = 272
    Width = 185
    Height = 21
    TabOrder = 12
    Text = '0123456789ABCD#*'
  end
  object ebFileName: TEdit
    Left = 480
    Top = 64
    Width = 289
    Height = 21
    TabOrder = 13
    Text = '..\bin\test.wav'
  end
  object btnFileName: TButton
    Left = 768
    Top = 64
    Width = 23
    Height = 21
    Caption = '...'
    TabOrder = 14
    OnClick = btnFileNameClick
  end
  object pbVolume: TProgressBar
    Left = 56
    Top = 156
    Width = 416
    Height = 8
    Max = 50
    Smooth = True
    TabOrder = 15
  end
  object btnTestOut: TButton
    Left = 568
    Top = 96
    Width = 75
    Height = 25
    Caption = 'Test'
    TabOrder = 16
    OnClick = btnTestOutClick
  end
  object btnTestTones: TButton
    Left = 568
    Top = 304
    Width = 75
    Height = 25
    Caption = 'Test'
    TabOrder = 17
    OnClick = btnTestTonesClick
  end
  object lstWarnings: TListBox
    Left = 8
    Top = 432
    Width = 465
    Height = 73
    ItemHeight = 13
    TabOrder = 18
  end
  object chkCheckAudio: TCheckBox
    Left = 264
    Top = 96
    Width = 97
    Height = 17
    Caption = 'Check Audio'
    Checked = True
    State = cbChecked
    TabOrder = 19
  end
  object cbTestLength: TComboBox
    Left = 168
    Top = 64
    Width = 81
    Height = 21
    Style = csDropDownList
    ItemHeight = 13
    TabOrder = 20
    Items.Strings = (
      '0.5'
      '1'
      '1.5'
      '2'
      '2.5'
      '3'
      '3.5'
      '4'
      '4.5'
      '5')
  end
  object cbTestTime: TComboBox
    Left = 168
    Top = 88
    Width = 81
    Height = 21
    Style = csDropDownList
    ItemHeight = 13
    TabOrder = 21
    Items.Strings = (
      '100'
      '200'
      '300'
      '400'
      '500'
      '600'
      '700'
      '800'
      '900'
      '1000'
      '')
  end
  object ebVolumeThreshold: TEdit
    Left = 168
    Top = 112
    Width = 81
    Height = 21
    TabOrder = 22
    Text = '0.1'
    OnChange = ebVolumeThresholdChange
  end
  object chkUseThread: TCheckBox
    Left = 480
    Top = 128
    Width = 97
    Height = 17
    Caption = 'Use Thread'
    TabOrder = 23
    OnClick = chkUseThreadClick
  end
  object cbPlaySynch: TComboBox
    Left = 680
    Top = 96
    Width = 145
    Height = 21
    Style = csDropDownList
    ItemHeight = 13
    TabOrder = 24
  end
  object btnTestWav: TButton
    Left = 480
    Top = 176
    Width = 75
    Height = 25
    Caption = 'Test Wav'
    TabOrder = 25
    OnClick = btnTestWavClick
  end
  object btnPlayStart: TButton
    Left = 480
    Top = 208
    Width = 75
    Height = 25
    Caption = 'Play Start'
    TabOrder = 26
    OnClick = btnPlayStartClick
  end
  object btnPlayStartTest: TButton
    Left = 568
    Top = 208
    Width = 75
    Height = 25
    Caption = 'Test'
    TabOrder = 27
    OnClick = btnPlayStartTestClick
  end
  object tmrIn: TTimer
    Enabled = False
    Interval = 200
    OnTimer = tmrInTimer
    Left = 208
    Top = 65528
  end
  object dlgOpen: TOpenDialog
    Ctl3D = False
    DefaultExt = 'wav'
    Filter = 'wav files (*.wav)|*.wav'
    Left = 172
    Top = 65528
  end
  object tmrOut: TTimer
    Enabled = False
    OnTimer = tmrOutTimer
    Left = 248
    Top = 65528
  end
  object tmrTones: TTimer
    Enabled = False
    Interval = 500
    OnTimer = tmrTonesTimer
    Left = 288
    Top = 65528
  end
  object tmrTestOut: TTimer
    Enabled = False
    OnTimer = tmrTestOutTimer
    Left = 336
    Top = 65528
  end
end
