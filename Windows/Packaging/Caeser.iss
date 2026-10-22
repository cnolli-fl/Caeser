#ifndef SourceDirectory
  #error SourceDirectory must point to the generated package
#endif
#ifndef OutputDirectory
  #error OutputDirectory must point to the artifact directory
#endif
#ifndef AppVersion
  #define AppVersion "1.1.1"
#endif

[Setup]
AppId={{8362D1BB-D499-462E-9633-409161F21111}
AppName=Caeser
AppVersion={#AppVersion}
AppVerName=Caeser {#AppVersion} - Windows
AppPublisher=Caio Nolli
AppPublisherURL=https://github.com/cnolli-fl/Caeser
DefaultDirName={localappdata}\Programs\Caeser
DefaultGroupName=Caeser
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19045
OutputDir={#OutputDirectory}
OutputBaseFilename=Caeser-{#AppVersion}-Windows-x64-Setup
SetupIconFile=..\Caeser.App\Assets\Caeser.ico
UninstallDisplayIcon={app}\Caeser.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; Flags: unchecked

[Files]
Source: "{#SourceDirectory}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb"

[Icons]
Name: "{autoprograms}\Caeser"; Filename: "{app}\Caeser.exe"
Name: "{autodesktop}\Caeser"; Filename: "{app}\Caeser.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Caeser.exe"; Description: "Abrir Caeser"; Flags: nowait postinstall skipifsilent

[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  PreviousUninstaller: String;
  ExitCode: Integer;
begin
  Result := '';
  { The legacy installer recorded its own files. Let it remove only those
    recorded files rather than recursively deleting a user's app directory. }
  if FileExists(ExpandConstant('{app}\Caeser.dll')) and
     FileExists(ExpandConstant('{app}\Tools\tools.lock.json')) then
  begin
    PreviousUninstaller := ExpandConstant('{app}\unins000.exe');
    if not FileExists(PreviousUninstaller) then
    begin
      Result := 'Desinstale a versão anterior do Caeser antes de instalar esta atualização.';
      Exit;
    end;
    Log('Removendo arquivos registrados da instalação antiga; downloads e preferências são preservados.');
    if not Exec(PreviousUninstaller, '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART', '', SW_HIDE,
      ewWaitUntilTerminated, ExitCode) then
      Result := 'Não foi possível remover a instalação anterior. Feche o Caeser e tente novamente.'
    else if ExitCode <> 0 then
      Result := 'A remoção da instalação anterior não terminou. Desinstale o Caeser e tente novamente.';
  end;
end;
