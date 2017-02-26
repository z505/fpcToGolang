{ Routines to convert pascal file/string code to Go. Only basic pascal and
  not everything will be converted obviously. Add patches to this code if you
  can expand it to be more complete

  License: MIT/BSD

  Lars
  http://z505.com
}

(*
TODO:
 -comment /*  */ golang, from pas ( * and {  ptMultiLineComment? vs ptComment
 -record to struct
 -const inside function parameters, different than const declaration. And var/out params
 -type declarations... TSomething = to golang syntax
 -{$ifdef special comment, golang has no {$ifdef... so leave as is for manual conversion
 -for/while loops and repeat, could just convert manually and leave as is
 -var declarations, multiline?  var var var on several lines could look ugly in go
 -{$I and {$include, pull in source inline as golang has nothing similar?
 -case statement to switch
 -string() cast? on bytes
 -
*)

unit FpcToGo; {$mode objfpc} {$H+}

interface
uses
  SysUtils, ChrStream, PasTokenize, MultiType, PcharUtils, TokenTypes;

procedure DefaultDebugLn(s: string);

var DebugMsg: procedure(s: string) = @DefaultDebugLn;

type
  PByteArray = ^TByteArray;
  TByteArray = array[0..maxint -1] of byte;

procedure RedirectStdOut(Outputfile: string);
procedure RestoreStdOut;
procedure WriteGoHeader; overload;
procedure WriteGoFooter; overload;
procedure WriteGoHeader(var fh: text); overload;
procedure WriteGoFooter(var fh: text); overload;


procedure PasFileToStdOutGo(const filename: string);
function PasFileToGoStr(const filename: string): string;
function PasStrToGoStr(const input: string): string;


var
  MainWrite: procedure(s: string);
  MainWriteLn: procedure(s: string);

implementation

{$ifdef windows}
const
  CRLF = #13#10;
{$endif}

{$ifdef unix}
const
  CRLF = #10;
{$endif}

type
  TWriterProc = procedure(input: string; var multi: TMultiType);

procedure DefaultDebugLn(s: string);
begin
  // do nothing by default, let user set debug proc variable
end;

procedure RedirectStdOut(OutputFile: string);
begin
  AssignFile(output, OutputFile);
  rewrite(output);
end;

procedure RestoreStdOut;
begin
  CloseFile(output);
  Assign(output,'');
  rewrite(output);
end;

var
  ChrStrm: PChrStrm;
  PasParser: PPasParser;


procedure StripLastLineFeed(var s: string);
var len: integer;
begin
  len:= length(s);
  if len < 1 then exit;
  case s[len] of
    #13, #10: 
     begin 
       s[len]:= ' ';
       case s[len-1] of #13: s[len-1]:= ' '; end;
     end;
  end;
end;

const
  GO_HEAD = 'package insertname'+CRLF;

procedure WriteGoHeader;
begin
  MainWrite(GO_HEAD);
end;

procedure WriteGoHeader(var fh: text);
begin
  Writeln(fh, GO_HEAD);
end;

procedure WriteGoFooter;
begin

end;

procedure WriteGoFooter(var fh: text);
begin

end;

// CASE of STRING ability
function StrCase(s: string; list: array of string): integer;
var
  i: integer;
begin
   result:= -1;
   for i:=0 to Length(list)-1 do
   if CompareText(s, list[i]) = 0 then begin
     result:= i;
     break;
   end;
end;


procedure AddKeyword(s: string; var mt: TMultiType; AddText: TWriterProc);
const _FUNC = 0; _PROC = 1; _BEGIN = 2; _END = 3;
var
  LowStr: string;
  TokFound: integer;
begin
  LowStr := lowercase(s);

  TokFound := StrCase(LowStr, ['function', 'procedure', 'begin', 'end']);
  case TokFound of
    _FUNC: AddText('func', mt);
    _PROC: AddText('func', mt);
    _BEGIN: AddText('{', mt);
    _END: AddText('}', mt);
    // DEFAULT case
    else begin
      // add code without modification
      AddText(s, mt);
    end;
  end;
end;

procedure AddIdentifer(s: string; var mt: TMultiType; AddText: TWriterProc);
const _boolean = 0; _integer = 1;
var
  LowStr: string;
  TokFound: integer;
begin
  LowStr := lowercase(s);

  TokFound := StrCase(LowStr, ['boolean', 'integer']);
  case TokFound of
    _boolean: AddText('bool', mt);
    _integer: AddText('int', mt);
    // DEFAULT case
    else begin
      // add code without modification
      AddText(s, mt);
    end;
  end;

end;

procedure AddComment(s: string; var mt: TMultiType; AddText: TWriterProc);
begin
  DebugMsg('COMMENT: '+s);
end;

{ Turns pascal into highlighted HTML using CSS classes. Does not write full
  html page, i.e. html header, body and footer, or PRE tag. Do that separately }
procedure PasToGo(AddText: TWriterProc; var mt: TMultiType);
var
  s: string;
  token: TPasToken;
begin
//  mt := nil;
  s:= '';
  repeat
    // TODO: carry a state (record) instead of just token and s VAR param
    // then whether the parser is in certain sections can be qeuried
    // (implentation, code block, const/var declaration, etc.)

    PasParser^.GetToken(token, s, PasParser, ChrStrm);

    if (s = #10) then
      addtext(#10, mt);

    if (s = #13) then
      addtext(#13, mt);

    if (s = ' ') then
      addtext(' ', mt);

    case token of
      ptKeyword: AddKeyword(s, mt, AddText);
      ptInvalidToken: addtext(s, mt);
      ptIdentifier: AddIdentifer(s, mt, AddText);
      ptString: addtext(s, mt);
      ptHexNumber: addtext(s, mt);
      ptNumber: addtext(s, mt);
      ptComment: AddComment(s, mt, AddText);
      ptDirective: addtext(s, mt);
      ptRange: addtext(s, mt);

      ptAssign: addtext('=', mt);
      ptNotEquals: addtext('!=', mt);
      ptEquals: addtext('==', mt);

      ptComma, ptSemicolon, ptColon, ptPeriod, ptPlus, ptMinus,
      ptMultiply, ptLess, ptLessEqual, ptGreater, ptGreaterEqual,
      ptOpenParen, ptCloseParen, ptOpenBracket, ptCloseBracket,
      ptDivide:
      begin addtext(s, mt);
      end;

      ptCaret: addtext(s, mt);
      ptHash: addtext(s, mt);
      ptAddress: addtext(s, mt);
    end;

    if (token =  ptWhitespace) and (s = ' ') then addtext(' ', mt);

    // for debugging
    if token = ptEndOfFile then begin
      addtext('// -- End of File ------' + CRLF, mt);
      addtext('// ---------------------' + CRLF, mt);
    end;
    if token = ptInvalidToken then 
      addtext('/* --invalid token found-- */' + CRLF, mt);
  until (token = ptEndOfFile) or (token = ptInvalidToken); // done
end;

{ usage: InputFile: the file you want to parse, which contains pascal code }
procedure PasFileToGo(InputFile: string; Addtext: TWriterProc; var rslt: TMultiType);
begin
  ChrStrm:= NewChrFileStrm1(inputfile);
  PasParser:= NewPasParser(ChrStrm);
  PasToGo(AddText, rslt);
  FreePasParser(PasParser);
  FreeChrFileStrm(ChrStrm);
end;

{ takes input string containing pascal code, converts to html  }
procedure PasStrToGo(Input: string; Addtext: TWriterProc; var rslt: TMultiType);
begin
  // create char stream 
  ChrStrm:= NewChrStrStrm(input);
  // create pascal parser 
  PasParser:= NewPasParser(ChrStrm);
  // absract pastohtm function accepts our rslt string as input.. RSLT is like a TVarRec
  PasToGo(AddText, rslt);
  // free parser and char stream
  FreePasParser(PasParser);
  FreeChrStrStrm(ChrStrm);
end;

{-- WRITER METHODS ------------------------------------------------------------}

{ append a string to another string (var param allows repetitive concats to the 
  same string over and over again }
procedure StringWriter(s: string; var rslt: TMultiType);
begin
  rslt.aString:= rslt.aString + s; //concat string
  // TODO: could be optimized.. this concat slow when dealing with large data
end;

{ write to stdout }
procedure StdOutWriter(s: string; var rslt: TMultiType);
begin
  system.write(s); // write msg to stdout
end;

{ write to an existing file }
procedure FileHandleWriter(s: string; var rslt: TMultiType);
begin
  system.write(rslt.atextfile, s); // write msg to open file
end;

{------------------------------------------------------------------------------}

{-- HTML CONVERTER METHODS ----------------------------------------------------}
{ Takes a pascal input file, outputs a highlighted pascal snippet in html to
  STDOUT }
procedure PasFileToStdOutGo(const filename: string);
var
  dummy: TMultiType; // nil parameter
begin
  PasFileToGo(filename, @StdOutWriter, dummy);
end;

{ takes a pascal input file, converts to highlighted pascal string in html }
function PasFileToGoStr(const filename: string): string;
var
  tmp: TMultiType;
begin
  result:= '';
  tmp.aString:= result;
  tmp.mtype:= mtString;
  PasFileToGo(filename, @StringWriter, tmp);
  result:= tmp.astring; 
end;

{ takes a pascal input string, converts to a highlighted html string }
function PasStrToGoStr(const input: string): string;
var
  tmp: TMultiType;
begin
  result:= '';
  tmp.aString:= result;
  tmp.mtype:= mtString;
  PasStrToGo(input, @StringWriter, tmp);
  result:= tmp.aString;
end;

{ TO DO
function PasStrToGoFile(const input: string; outfile: string);
begin
end

function PasFileGoFile(const FNameIn: string; FNameOut: string);
begin
end

}
{------------------------------------------------------------------------------}


end.

