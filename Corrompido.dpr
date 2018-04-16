program Corrompido;

uses
  Forms,
  UntCorrompido in 'UntCorrompido.pas' {UntCorrompido};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFrmCorrompido, FrmCorrompido);
  Application.Run;
end.
