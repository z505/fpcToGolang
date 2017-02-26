unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, SynEdit, SynHighlighterAny, Forms, Controls,
  Graphics, Dialogs, StdCtrls, ExtCtrls;

type

  { TForm1 }

  TForm1 = class(TForm)
    btnConvert: TButton;
    edFile: TEdit;
    Label1: TLabel;
    memoStatus: TMemo;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    Splitter1: TSplitter;
    SynEd: TSynEdit;
    procedure btnConvertClick(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

uses
  FpcToGo;

{ TForm1 }

procedure TForm1.btnConvertClick(Sender: TObject);
var fpath: string;
begin
  fpath := SetDirSeparators(edFile.text);
  if FileExists(fpath) then begin
    SynEd.Text := PasFileToGoStr(fpath);
  end else begin
    SynEd.Lines.Add('FILE DOES NOT EXIST: '+fpath +' (could not convert)');
  end;
end;


procedure DebugShowMessage(s: string);
begin
  Form1.memoStatus.Lines.Add(s);
end;

initialization
  DebugMsg := @DebugShowMessage;
end.

