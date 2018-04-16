unit UntCorrompido;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Text, Buttons, ExtCtrls, Grids, DBGrids, DB,
  IBDatabase, IBCustomDataSet, IBQuery, Combo, DBClient, ComCtrls,
  IBServices, ShellApi, IBDatabaseInfo, Registry;

type
  TFrmCorrompido = class(TForm)
    PnlBanco: TPanel;
    Label1: TLabel;
    Label2: TLabel;
    Shape1: TShape;
    SpbBanco: TSpeedButton;
    BibConfirmar: TBitBtn;
    BibLimpar: TBitBtn;
    TxtBDAtu: TText;
    OpdBase1: TOpenDialog;
    QryMaster: TIBQuery;
    ItrBD1: TIBTransaction;
    IdbTab1: TIBDatabase;
    VsValidar: TIBValidationService;
    MmResult: TMemo;
    ChkDesligar: TCheckBox;
    IbInfo: TIBDatabaseInfo;
    IbConfService: TIBConfigService;
    TimerDesligar: TTimer;
    procedure SpbBancoClick(Sender: TObject);
    procedure BibConfirmarClick(Sender: TObject);
    procedure BibLimparClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure TimerDesligarTimer(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  Function  fValida(StrCpo: String): Boolean ;
  Function  fConecta(): Boolean ;
  Procedure pValidar();
  Procedure pHabilitar(bHab: Boolean);
  Procedure pDesligar();
  Function  PegaVersaoWin(): String;
  Function  fDesconectar(): Boolean;
  Function  f_Derrubar_Conexoes: Boolean;
  Procedure pGravarRegistro();
  end;

var
  FrmCorrompido: TFrmCorrompido;
  cResultadoValidar : String;
  nCronometro : double;

implementation

{$R *.dfm}

function TFrmCorrompido.fValida(StrCpo: String): Boolean;
begin

   fValida := False;

   If ( StrCpo = '1' ) Or ( StrCpo = 'GERAL' ) Then
      Begin
         If ( Trim(TxtBDAtu.Text) = '' ) Then
            Begin

               MessageDlg('Caminho do banco de dados atualizado é obrigatório !', mtWarning, [mbOk], 0);
               TxtBDAtu.SetFocus;
               Exit;
               
            End
         Else If Not FileExists( TxtBDAtu.Text ) Then
            Begin

               Application.MessageBox('Arquivo de Base de Dados Inexistente!','Base',Mb_OK+MB_IconError);
               TxtBDAtu.Text := '';
               TxtBDAtu.SetFocus;
               Exit;

            End;
      End;

   fValida := True ;

end;

procedure TFrmCorrompido.SpbBancoClick(Sender: TObject);
begin

   OpdBase1.InitialDir := ExtractFilePath( TxtBDAtu.Text ) ;

   If OpdBase1.Execute Then
      Begin

         If Trim( OpdBase1.FileName ) <> '' Then
            Begin

               TxtBDAtu.Text := OpdBase1.FileName;
               fValida('1');
               
            End;
            
      End;

end;

procedure TFrmCorrompido.BibConfirmarClick(Sender: TObject);
var cMsg: String;
    timeInicio : tDateTime;
begin
   
   If not fValida('GERAL') Then Exit ;

   Screen.Cursor := crHourGlass;
   frmCorrompido.Refresh;
   
   pHabilitar(False);
   If Not fConecta() Then
      Begin
         pHabilitar(True);
         Screen.Cursor := crDefault ;
         frmCorrompido.Refresh;
         Exit ;
      End;

   { Fechar ligação com o Banco de Dados }
   IdbTab1.Close;

   { Cronômetro }
   timeInicio := Time ;

   { Validar Banco de Dados }
   pValidar();

   { Resultado da função pValidar }
   If ( MmResult.Text = '' ) Then
      Begin
         cResultadoValidar := 'Normal';
         cMsg := 'Banco de dados não corrompido !' + #13#10 + #13#10;
      End
   Else
      Begin
         cResultadoValidar := 'Corrompido';
         cMsg := 'Banco de dados corrompido !' + #13#10 + #13#10;
      End;

   { Tempo de verificação }
   cMsg := cMsg  + 'Tempo de Verificação: ' + FormatDateTime('hh:mm:ss:zzzz', (Time - timeInicio));

   { Gravar Resultado no Regedit }
   pGravarRegistro();

   { Desligar o computador }
   If ChkDesligar.Checked Then
      TimerDesligar.Enabled := True;

   { Mostrar Resultado da função pValidar }
   ShowMessage(cMsg);

   pHabilitar(True);
   Screen.Cursor := crDefault ;
   frmCorrompido.Refresh;

end;

procedure TFrmCorrompido.BibLimparClick(Sender: TObject);
begin

   TxtBDAtu.Text := '';
   ChkDesligar.Checked := False;

end;

function TFrmCorrompido.fConecta: Boolean;
var cMsg : String;
begin

   fConecta := True ;

   Try

      With IdbTab1 Do
         Begin
            Close ;
            DatabaseName := TxtBDAtu.Text ;
            Open;
         End;

   Except
      MessageDlg('Não foi possível conectar-se ao servidor de dados atualizado.', mtWarning, [mbOk], 0);
      TxtBDAtu.SetFocus ;
      fConecta := False ;
      Exit;
   End;

   { Quantidade de atores conectados no banco de dados }
   If ( IbInfo.UserNames.Count > 1 ) Then
      Begin

         If IbInfo.UserNames.Count > 2 Then
            cMsg := 'Existem ' + IntToStr(IbInfo.UserNames.Count - 1) + ' usuários conectados ao banco de dados !!!' + Chr(13) + Chr(13)
         Else
            cMsg := 'Existe 1 usuário conectado ao banco de dados !!!' + Chr(13) + Chr(13) ;

         cMsg := cMsg +
                 'Solicite aos usuários que saiam das aplicações!' + Chr(13) +
                 'DESEJA FORÇAR O DESLIGAMENTO DESSES USUÁRIOS? ';

         fConecta := False ;
         If Application.MessageBox(pChar(cMsg), 'Confirmação', MB_ICONQUESTION+ MB_YESNO+MB_DEFBUTTON2) = idYes Then
            If fDesconectar() Then
               fConecta := True;

      End;

end;

procedure TFrmCorrompido.pValidar;
var Error : String;
begin

   MmResult.Lines.Clear;

   { Configurações Padrões }
   With VsValidar Do
      Begin

         Params.Clear;
         DatabaseName := TxtBDAtu.Text;
         Params.Add('user_name=sysdba');
         Params.Add('password=masterkey');
         LoginPrompt := False;
         Active := True;

         Try

            { Equivale ao gfix -v -f (Verificação de Corrupção de base) }
            Options := [ValidateDB] + [ValidateFull];

            { Inicia o processo }
            ServiceStart;
            Error := GetNextLine;

            { Verifica os erros }
            If Error <> EmptyStr Then
               Begin

                  Repeat
                     MmResult.Lines.add(Error);
                     Error := GetNextLine;
                  Until(Error = EmptyStr);

               End;

         Finally
            Active := False;
            pHabilitar(True);
            Screen.Cursor := crDefault ;
            frmCorrompido.Refresh;
         End;

      End;
      
end;

procedure TFrmCorrompido.FormShow(Sender: TObject);
begin
//   frmCorrompido.Height := 160;
end;

procedure TFrmCorrompido.pHabilitar(bHab: Boolean);
begin

   SpbBanco.Enabled     := bHab;
   TxtBDAtu.Enabled     := bHab;
   BibLimpar.Enabled    := bHab;
   BibConfirmar.Enabled := bHab;
   ChkDesligar.Enabled  := bHab;

end;

procedure TFrmCorrompido.pDesligar;
var
 hToken       : THandle;
 tkp, tkpo    : TTokenPrivileges;
 zero         : DWord;

begin

   zero := 0;
   If Pos('Windows NT', PegaVersaoWin) = 1 Then
      Begin

         OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES Or TOKEN_QUERY, hToken);
         LookupPrivilegeValue(nil, 'SeShutdownPrivilege', tkp.Privileges[0].Luid);
         tkp.PrivilegeCount := 1;
         tkp.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
         AdjustTokenPrivileges(hToken, False, tkp, SizeOf(TTokenPrivileges), tkpo, zero);
         ExitWindowsEx(EWX_FORCE or EWX_SHUTDOWN, 0);
         
      End
   Else
      ExitWindowsEx(EWX_FORCE or EWX_SHUTDOWN, 0);

end;

function TFrmCorrompido.PegaVersaoWin(): String;
var
   VersionInfo : TOSVersionInfo;
   OSName      : String;

begin

   VersionInfo.dwOSVersionInfoSize := SizeOf(TOSVersionInfo);
   If Windows.GetVersionEx(VersionInfo) Then
      Begin

         With VersionInfo Do
            Begin

               Case dwPlatformId Of

                  VER_PLATFORM_WIN32s        : OSName := 'Win32s';
                  VER_PLATFORM_WIN32_WINDOWS : OSName := 'Windows 95';
                  VER_PLATFORM_WIN32_NT      : OSName := 'Windows NT';
                  //VER_PLATFORM_WIN32_CE      : OSName := 'Windows CE';

               End;

               Result := OSName + ' Versão ' + IntToStr( dwMajorVersion ) + '.'  + IntToStr( dwMinorVersion ) +
                                  ' (Build ' + IntToStr( dwBuildNumber )  + ': ' + szCSDVersion + ')';

            End;

      End
   Else
      Result := '';

end; 

function TFrmCorrompido.fDesconectar(): Boolean;
begin

   Result := False;

   If Not f_Derrubar_Conexoes Then
      Begin
         IdbTab1.Close;
         Exit;
      End;

   Result := True;

end;

function TFrmCorrompido.f_Derrubar_Conexoes: Boolean;
var
   cSql: String;

   { Verifica se a versão do firebird é 2.5 ou maior }
   Function fVersaoFirebird() : Boolean;
      var nVersao : Integer;
      Begin

         cSql := 'Select rdb$get_context(''SYSTEM'', ''ENGINE_VERSION'') as VERSION From rdb$database';
         QryMaster.Close;
         QryMaster.SQL.Text := cSql;
         QryMaster.Open;

         nVersao := StrToInt(StringReplace(QryMaster.FieldByName('VERSION').AsString, '.', '', [rfReplaceAll]));

         If nVersao > 250 Then
            Result := True
         Else
            Result := False;

      End;

Begin

   Try

      If fVersaoFirebird Then
         Begin

            { Firebird 2.5 }
            cSql := ' Delete From Mon$Attachments ' +
                    ' Where Mon$Attachment_ID <> CURRENT_CONNECTION ';

            QryMaster.Close;
            QryMaster.SQL.Text := cSql;

            Try
               QryMaster.ExecSQL;
               IdbTab1.DefaultTransaction.Commit;
            Except
               QryMaster.CancelUpdates;
               IdbTab1.DefaultTransaction.Rollback;
               Result := False;
               Exit;
            End;

         End
      Else
         Begin

            { Firebird Versões Anteriores }
            Try 
               IbConfService.Active := True;
               IbConfService.ShutdownDatabase(Forced,0);
            Except
               Result := False;
               Exit;
            End;

         End;
      Result := True; 
   Except
      Result := False;
   End;
   
End;

procedure TFrmCorrompido.TimerDesligarTimer(Sender: TObject);
begin
   pDesligar();
end;

procedure TFrmCorrompido.pGravarRegistro;
var Reg: TRegistry;
begin

   Try

      Reg := TRegistry.Create;
      With Reg Do
         Begin

            RootKey := HKEY_CURRENT_USER;

            If OpenKey('PxTech', False) Then
               Begin

                  WriteString('PxCorrompido', UpperCase(cResultadoValidar));
                  CloseKey;

               End;

         End;
         
   Except
      { Esse Try é usado para garantir que caso o programa tenha algum problema
        para gravar os registro no windows o sistema não trave e não seja feita
        o desligamente automático pela a função pDesligar()}
   End;

end;

end.
