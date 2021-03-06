{
  Copyright 2019-2019 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Test sound engine backend using "sox" command-line.
  This is not for production use, a lot of sound engine features are not supported.
  Really, it can only just read and play a sound file. }
unit CastleInternalSoxBackend;

{$I castleconf.inc}

interface

uses SysUtils, Classes, Math, Process,
  CastleVectors, CastleTimeUtils, CastleXMLConfig,
  CastleClassUtils, CastleStringUtils,
  CastleInternalAbstractSoundBackend, CastleSoundBase;

type
  TSoxSoundBufferBackend = class(TSoundBufferBackend)
  private
    FileName: String;
  public
    procedure ContextOpen; override;
    procedure ContextClose; override;
  end;

  TSoxSoundSourceBackend = class(TSoundSourceBackend)
  strict private
    FBuffer: TSoxSoundBufferBackend;
    FPlayStart: TTimerResult;
    FPlayStarted: Boolean;
    FPlayProcess: TProcess;
  public
    procedure ContextOpen; override;
    procedure ContextClose; override;
    function PlayingOrPaused: boolean; override;
    procedure Play(const BufferChangedRecently: Boolean); override;
    procedure Stop; override;
    procedure SetPosition(const Value: TVector3); override;
    procedure SetVelocity(const Value: TVector3); override;
    procedure SetLooping(const Value: boolean); override;
    procedure SetRelative(const Value: boolean); override;
    procedure SetGain(const Value: Single); override;
    procedure SetMinGain(const Value: Single); override;
    procedure SetMaxGain(const Value: Single); override;
    procedure SetBuffer(const Value: TSoundBufferBackend); override;
    procedure SetPitch(const Value: Single); override;
    procedure SetRolloffFactor(const Value: Single); override;
    procedure SetReferenceDistance(const Value: Single); override;
    procedure SetMaxDistance(const Value: Single); override;
    function GetOffset: Single; override;
    procedure SetOffset(const Value: Single); override;
  end;

  TSoxSoundEngineBackend = class(TSoundEngineBackend)
  private
    SoxCommand: String;
  public
    function ContextOpen(const ADevice: String; out Information: String): Boolean; override;
    procedure ContextClose; override;
    function CreateBuffer: TSoundBufferBackend; override;
    function CreateSource: TSoundSourceBackend; override;
    procedure SetGain(const Value: Single); override;
    procedure SetDistanceModel(const Value: TSoundDistanceModel); override;
    procedure SetListener(const Position, Direction, Up: TVector3); override;
  end;

implementation

uses StrUtils,
  CastleLog, CastleUtils, CastleURIUtils, CastleInternalSoundFile,
  CastleFilesUtils;

{ TSoxSoundBufferBackend -------------------------------------------------- }

procedure TSoxSoundBufferBackend.ContextOpen;
var
  F: TSoundFile;
begin
  F := TSoundFile.CreateFromFile(URL);
  try
    Duration := F.Duration;
  finally F.Free end;

  FileName := URIToFilenameSafe(URL);
  { Workaround sox on Windows being unable to process filenames with backslashes. }
  {$ifdef MSWINDOWS}
  FileName := SReplaceChars(FileName, '\', '/');
  {$endif}
  if FileName = '' then
    raise ESoundFileError.CreateFmt('URL "%s" does not translate to a filename, and SOX can only play local files',
      [URL]);
end;

procedure TSoxSoundBufferBackend.ContextClose;
begin
end;

{ TSoxSoundSourceBackend -------------------------------------------------- }

procedure TSoxSoundSourceBackend.ContextOpen;
begin
end;

procedure TSoxSoundSourceBackend.ContextClose;
begin
  Stop;
end;

function TSoxSoundSourceBackend.PlayingOrPaused: boolean;
begin
  Result := (FBuffer <> nil) and FPlayStarted and (FPlayStart.ElapsedTime < FBuffer.Duration);
end;

procedure TSoxSoundSourceBackend.Play(const BufferChangedRecently: Boolean);
begin
  Stop;

  FPlayProcess := TProcess.Create(nil);
  { We invoke "sox xxx.wav --default-device" instead of "play xxx.wav",
    because on Windows (Cygwin) the "play" is only a symbolic link,
    so we would have to execute it through bash, making the code more complicated. }
  FPlayProcess.Executable := (SoundEngine as TSoxSoundEngineBackend).SoxCommand;
  FPlayProcess.Parameters.Add(FBuffer.FileName);
  FPlayProcess.Parameters.Add('--default-device');
  FPlayProcess.Execute;

  FPlayStarted := true;
  FPlayStart := Timer;
end;

procedure TSoxSoundSourceBackend.Stop;
begin
  { Terminate and free FPlayProcess.
    Otherwise on Unix the sox process may be left hanging forever,
    even after the main CGE application terminated. }
  if FPlayProcess <> nil then
  begin
    FPlayProcess.Terminate(0);
    FreeAndNil(FPlayProcess);
  end;
end;

procedure TSoxSoundSourceBackend.SetPosition(const Value: TVector3);
begin
end;

procedure TSoxSoundSourceBackend.SetVelocity(const Value: TVector3);
begin
end;

procedure TSoxSoundSourceBackend.SetLooping(const Value: boolean);
begin
end;

procedure TSoxSoundSourceBackend.SetRelative(const Value: boolean);
begin
end;

procedure TSoxSoundSourceBackend.SetGain(const Value: Single);
begin
end;

procedure TSoxSoundSourceBackend.SetMinGain(const Value: Single);
begin
end;

procedure TSoxSoundSourceBackend.SetMaxGain(const Value: Single);
begin
end;

procedure TSoxSoundSourceBackend.SetBuffer(const Value: TSoundBufferBackend);
begin
  FBuffer := Value as TSoxSoundBufferBackend;
end;

procedure TSoxSoundSourceBackend.SetPitch(const Value: Single);
begin
end;

procedure TSoxSoundSourceBackend.SetRolloffFactor(const Value: Single);
begin
end;

procedure TSoxSoundSourceBackend.SetReferenceDistance(const Value: Single);
begin
end;

procedure TSoxSoundSourceBackend.SetMaxDistance(const Value: Single);
begin
end;

function TSoxSoundSourceBackend.GetOffset: Single;
begin
  Result := 0;
end;

procedure TSoxSoundSourceBackend.SetOffset(const Value: Single);
begin
end;

{ TSoxSoundEngineBackend -------------------------------------------------- }

function TSoxSoundEngineBackend.ContextOpen(const ADevice: String;
  out Information: String): Boolean;
var
  SoxVersion: String;
begin
  SoxCommand := FindExe('sox');
  if SoxCommand = '' then
  begin
    Information := 'SOX executable not found on $PATH';
    Exit(false);
  end;
  if not RunCommand(SoxCommand, ['--version'], SoxVersion) then
  begin
    Information := 'Failed to execute SOX executable with --version';
    Exit(false);
  end;

  SoxVersion := Trim(SoxVersion); // remove final newline

  Result := true;
  Information := 'SOX command found:' + NL +
    'Executable path: ' + SoxCommand + NL +
    'Version: ' + SoxVersion;
end;

procedure TSoxSoundEngineBackend.ContextClose;
begin
end;

procedure TSoxSoundEngineBackend.SetGain(const Value: Single);
begin
end;

procedure TSoxSoundEngineBackend.SetDistanceModel(const Value: TSoundDistanceModel);
begin
end;

procedure TSoxSoundEngineBackend.SetListener(const Position, Direction, Up: TVector3);
begin
end;

function TSoxSoundEngineBackend.CreateBuffer: TSoundBufferBackend;
begin
  Result := TSoxSoundBufferBackend.Create(Self);
end;

function TSoxSoundEngineBackend.CreateSource: TSoundSourceBackend;
begin
  Result := TSoxSoundSourceBackend.Create(Self);
end;

end.
