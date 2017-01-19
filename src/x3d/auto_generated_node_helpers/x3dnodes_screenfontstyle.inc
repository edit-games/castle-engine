{ -*- buffer-read-only: t -*-

  Copyright 2015-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Automatically generated X3D node class helpers.
  Do not edit manually, instead regenerate using
  castle_game_engine/src/x3d/doc/generate_x3d_nodes_to_pascal.lpr . }

{$ifdef read_interface}

  private
    function GetHorizontal: boolean;
    procedure SetHorizontal(const Value: boolean);
    function GetLanguage: string;
    procedure SetLanguage(const Value: string);
    function GetLeftToRight: boolean;
    procedure SetLeftToRight(const Value: boolean);
    function GetPointSize: Single;
    procedure SetPointSize(const Value: Single);
    function GetSpacing: Single;
    procedure SetSpacing(const Value: Single);
    function GetTopToBottom: boolean;
    procedure SetTopToBottom(const Value: boolean);
  public
    property Horizontal: boolean read GetHorizontal write SetHorizontal;
    property Language: string read GetLanguage write SetLanguage;
    property LeftToRight: boolean read GetLeftToRight write SetLeftToRight;
    property PointSize: Single read GetPointSize write SetPointSize;
    property Spacing: Single read GetSpacing write SetSpacing;
    property TopToBottom: boolean read GetTopToBottom write SetTopToBottom;

{$endif read_interface}

{$ifdef read_implementation}

{ TScreenFontStyleNode ----------------------------------------------- }

function TScreenFontStyleNode.GetHorizontal: boolean;
begin
  Result := FdHorizontal.Value;
end;

procedure TScreenFontStyleNode.SetHorizontal(const Value: boolean);
begin
  FdHorizontal.Send(Value);
end;

function TScreenFontStyleNode.GetLanguage: string;
begin
  Result := FdLanguage.Value;
end;

procedure TScreenFontStyleNode.SetLanguage(const Value: string);
begin
  FdLanguage.Send(Value);
end;

function TScreenFontStyleNode.GetLeftToRight: boolean;
begin
  Result := FdLeftToRight.Value;
end;

procedure TScreenFontStyleNode.SetLeftToRight(const Value: boolean);
begin
  FdLeftToRight.Send(Value);
end;

function TScreenFontStyleNode.GetPointSize: Single;
begin
  Result := FdPointSize.Value;
end;

procedure TScreenFontStyleNode.SetPointSize(const Value: Single);
begin
  FdPointSize.Send(Value);
end;

function TScreenFontStyleNode.GetSpacing: Single;
begin
  Result := FdSpacing.Value;
end;

procedure TScreenFontStyleNode.SetSpacing(const Value: Single);
begin
  FdSpacing.Send(Value);
end;

function TScreenFontStyleNode.GetTopToBottom: boolean;
begin
  Result := FdTopToBottom.Value;
end;

procedure TScreenFontStyleNode.SetTopToBottom(const Value: boolean);
begin
  FdTopToBottom.Send(Value);
end;

{$endif read_implementation}