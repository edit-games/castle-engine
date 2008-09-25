{
  Copyright 2001-2008 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "Kambi VRML game engine"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

{ @abstract(Lexer for KambiScript language, see
  [http://vrmlengine.sourceforge.net/kambi_script.php].)

  For specification of tokens that this lexer understands,
  see documentation of KambiScriptParser unit. }

unit KambiScriptLexer;

interface

uses KambiUtils, KambiScript, SysUtils, Math;

type
  TToken = (tokEnd,
    tokConst, {< Value of given constant will be in w TKamScriptLexer.TokenFloat. }
    tokIdentifier, {< Identifier will be in TKamScriptLexer.TokenString. }
    tokFuncName, {< Function class of given function will be in TKamScriptLexer.TokenFunctionClass. }
    tokFunctionKeyword,

    tokMinus, tokPlus,

    tokMultiply, tokDivide, tokPower, tokModulo,

    tokGreater, tokLesser, tokGreaterEqual, tokLesserEqual, tokEqual, tokNotEqual,

    tokLParen, tokRParen, tokComma, tokSemicolon, tokLQaren, tokRQaren);

  TKamScriptLexer = class
  private
    FToken: TToken;
    FTokenFloat: Float;
    FTokenString: string;
    FTokenFunctionClass: TKamScriptFunctionClass;

    FTextPos: Integer;
    FText: string;
  public
    property Token: TToken read FToken;

    property TokenString: string read FTokenString;
    property TokenFloat: Float read FTokenFloat;
    property TokenFunctionClass: TKamScriptFunctionClass read FTokenFunctionClass;

    { Position of lexer in the @link(Text) string. }
    property TextPos: Integer read FTextPos;

    { Text that this lexer reads. }
    property Text: string read FText;

    { NextToken moves to next token (updating fields @link(Token),
      and eventually TokenFloat, TokenString and TokenFunctionClass)
      and returns the value of field @link(Token).

      When @link(Token) is tokEnd, then NextToken doesn't do anything,
      i.e. @link(Token) will remain tokEnd forever.

      @raises EKamScriptLexerError }
    function NextToken: TToken;

    constructor Create(const AText: string);

    { Current token textual description. Useful mainly for debugging lexer. }
    function TokenDescription: string;

    { Check is current token Tok, eventually rise parser error.
      This is an utility for parser.

      @raises(EKamScriptParserError
        if current Token doesn't match required Tok.) }
    procedure CheckTokenIs(Tok: TToken);
  end;

  { A common class for EKamScriptLexerError and EKamScriptParserError }
  EKamScriptSyntaxError = class(EKamScriptError)
  private
    FLexerTextPos: Integer;
    FLexerText: string;
  public
    { Those things are copied from Lexer at exception creation.
      We do not copy reference to Lexer since this would be too dangerous
      in usual situation (you would have to be always sure that you will
      not access it before you Freed it; too troublesome, usually) }
    property LexerTextPos: Integer read FLexerTextPos;
    property LexerText: string read FLexerText;
    constructor Create(Lexer: TKamScriptLexer; const s: string);
    constructor CreateFmt(Lexer: TKamScriptLexer; const s: string;
      const args: array of const);
  end;

  EKamScriptLexerError = class(EKamScriptSyntaxError);

  EKamScriptParserError = class(EKamScriptSyntaxError);

implementation

uses KambiStringUtils;

function Int64Power(base: Integer; power: Cardinal): Int64;
begin
 result := 1;
 while power > 0 do begin
  result := result*base;
  Dec(power);
 end;
end;

constructor TKamScriptLexer.Create(const atext: string);
begin
 inherited Create;
 ftext := atext;
 fTextPos := 1;
 NextToken;
end;

function TKamScriptLexer.NextToken: TToken;
const
  whiteChars = [' ', #9, #10, #13];
  digits = ['0'..'9'];
  litery = ['a'..'z', 'A'..'Z', '_'];

  function ReadSimpleToken: boolean;
  const
    { kolejnosc w toks_strs MA znaczenie - pierwszy zostanie dopasowany string dluzszy,
      wiec aby Lexer pracowal zachlannnie stringi dluzsze musza byc pierwsze. }
    toks_strs : array[0..17] of string=
     ('<>', '<=', '>=', '<', '>', '=', '+', '-', '*', '/', ',',
      '(', ')', '^', '[', ']', '%', ';');
    toks_tokens : array[0..High(toks_strs)]of TToken =
     (tokNotEqual, tokLesserEqual, tokGreaterEqual, tokLesser, tokGreater,
      tokEqual, tokPlus, tokMinus, tokMultiply, tokDivide, tokComma, tokLParen, tokRParen,
      tokPower, tokLQaren, tokRQaren, tokModulo, tokSemicolon);
  var i: integer;
  begin
   for i := 0 to High(toks_strs) do
    if Copy(text, TextPos, Length(toks_strs[i])) = toks_strs[i] then
    begin
     ftoken := toks_tokens[i];
     Inc(fTextPos, Length(toks_strs[i]));
     result := true;
     exit;
    end;
   result := false;
  end;

  function ReadConstant: boolean;
  { czytaj constant od aktualnego miejsca (a wiec uaktualnij
    ftoken i fTokenFloat). Zwraca false jesli nie stoimy na constant. }
  var digitsCount: cardinal;
      val: Int64;
  begin
   result := text[fTextPos] in digits;
   if not result then exit;

   ftoken := tokConst;
   val := DigitAsByte(text[fTextPos]);
   Inc(fTextPos);
   while SCharIs(text, fTextPos, digits) do
   begin
    val := 10*val+DigitAsByte(text[fTextPos]);
    Inc(fTextPos);
   end;
   fTokenFloat := val;

   { czytaj czesc ulamkowa }
   if SCharIs(text, fTextPos, '.') then
   begin
    Inc(fTextPos);
    if not SCharIs(text, fTextPos, digits) then
     raise EKamScriptLexerError.Create(Self, 'digit expected');
    digitsCount := 1;
    val := DigitAsByte(text[fTextPos]);
    Inc(fTextPos);
    while SCharIs(text, fTextPos, digits) do
    begin
     val := 10*val+DigitAsByte(text[fTextPos]);
     Inc(digitsCount);
     Inc(fTextPos);
    end;
    fTokenFloat := fTokenFloat + (val / Int64Power(10, digitsCount));
   end;
  end;

  function ReadIdentifier: string;
  { czytaj identyfikator - to znaczy, czytaj nazwe zmiennej co do ktorej nie
    jestesmy pewni czy nie jest przypadkiem nazwa funkcji. Uwaga - powinien
    zbadac kazdy znak, poczynajac od text[fTextPos], czy rzeczywiscie
    nalezy do identChars.

    Always returns non-empty string (length >= 1) }
  const identStartChars = litery;
        identChars = identStartChars + digits;
  var startPos: integer;
  begin
   if not (text[fTextPos] in identStartChars) then
    raise EKamScriptLexerError.Create(Self, 'wrong token');
   startPos := fTextPos;
   Inc(fTextPos);
   while SCharIs(text, fTextPos, identChars) do Inc(fTextPos);
   result := CopyPos(text, startPos, fTextPos-1);
  end;

const
  consts_str: array[0..1]of string = ('pi', 'enat');
  consts_values: array[0..High(consts_str)]of float = (pi, enatural);
var
  p: integer;
  fc: TKamScriptFunctionClass;
begin
 while SCharIs(text, TextPos, whiteChars) do Inc(fTextPos);
 if TextPos > Length(text) then
  ftoken := tokEnd else
 begin
  if not ReadSimpleToken then
  if not ReadConstant then
  begin
   { It's something that *may* be an identifier.
     Unless it matches some keyword, built-in function or constant. }
   ftoken := tokIdentifier;
   fTokenString := ReadIdentifier;

   { Maybe it's tokFunctionKeyword (the only keyword for now) }
   if ftoken = tokIdentifier then
   begin
     if SameText(fTokenString, 'function') then
     begin
       ftoken := tokFunctionKeyword;
     end;
   end;

   { Maybe it's tokFuncName }
   if ftoken = tokIdentifier then
   begin
     fc := FunctionHandlers.SearchFunctionShortName(fTokenString);
     if fc <> nil then
     begin
      ftoken := tokFuncName;
      fTokenFunctionClass := fc;
     end;
   end;

   { Maybe it's tokConst }
   if ftoken = tokIdentifier then
   begin
    p := ArrayPosText(fTokenString, consts_str);
    if p >= 0 then
    begin
     ftoken := tokConst;
     fTokenFloat := consts_values[p];
    end;
   end;
  end;
 end;
 result := token;
end;

const
  TokenShortDescription: array [TToken] of string =
  ( 'end of stream',
    'constant',
    'identifier',
    'built-in function',
    'function',
    '-', '+',
    '*', '/', '^', '%',
    '>', '<', '>=', '<=', '=', '<>',
    '(', ')',
    ',', ';',
    '[', ']');

function TKamScriptLexer.TokenDescription: string;
begin
  Result := TokenShortDescription[Token];
  case Token of
    tokConst: Result += Format(' %g', [TokenFloat]);
    tokIdentifier: Result += Format(' %s', [TokenString]);
    tokFuncName: Result += Format(' %s', [TokenFunctionClass.Name]);
  end;
end;

procedure TKamScriptLexer.CheckTokenIs(Tok: TToken);
begin
  if Token <> Tok then
    raise EKamScriptParserError.CreateFmt(Self,
      'Expected "%s", but got "%s"',
      [ TokenShortDescription[Tok], TokenDescription ]);
end;

{ EKamScriptSyntaxError --------------------------------------- }

constructor EKamScriptSyntaxError.Create(Lexer: TKamScriptLexer; const s: string);
begin
 inherited Create(s);
 FLexerTextPos := Lexer.TextPos;
 FLexerText := Lexer.Text;
end;

constructor EKamScriptSyntaxError.CreateFmt(Lexer: TKamScriptLexer; const s: string;
  const args: array of const);
begin
 Create(Lexer, Format(s, args))
end;

end.