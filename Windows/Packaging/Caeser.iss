#ifndef SourceDirectory
  #error SourceDirectory must point to the generated package
#endif
#ifndef OutputDirectory
  #error OutputDirectory must point to the artifact directory
#endif
#ifndef AppVersion
  #define AppVersion "2.3.0"
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
Compression=lzma2/ultra64
LZMAUseSeparateProcess=yes
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; Flags: unchecked

[Dirs]
Name: "{app}"; BeforeInstall: MigratePreviousInstallation

[Files]
Source: "{#SourceDirectory}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb"

[Icons]
Name: "{autoprograms}\Caeser"; Filename: "{app}\Caeser.exe"
Name: "{autodesktop}\Caeser"; Filename: "{app}\Caeser.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Caeser.exe"; Description: "Abrir Caeser"; Flags: nowait postinstall skipifsilent; Check: not IsCaeserUpdate
Filename: "{app}\Caeser.exe"; Flags: nowait runasoriginaluser; Check: IsCaeserUpdate

[Code]
var
  MigrationChecked: Boolean;

function IsCaeserUpdate: Boolean;
begin
  Result := ExpandConstant('{param:CAESERUPDATE|0}') = '1';
end;

procedure MigratePreviousInstallation;
var
  PreviousUninstaller, UninstallerName: String;
  ExitCode, I: Integer;
begin
  if MigrationChecked then Exit;
  MigrationChecked := True;
  { The Dirs callback runs after Restart Manager, before the new uninstaller
    is staged. Running this from Files would delete its staged temporary file.
    The previous uninstaller removes its recorded files only, not user extras.
    Migrate flat installs and raw notices once; later upgrades are in-place. }
  if (FileExists(ExpandConstant('{app}\Caeser.dll')) and
      FileExists(ExpandConstant('{app}\Tools\tools.lock.json'))) or
     (DirExists(ExpandConstant('{app}\Documentacao\Ferramentas')) and
      not FileExists(ExpandConstant('{app}\Documentacao\Ferramentas.zip'))) then
  begin
    if not RegQueryStringValue(HKCU,
      'Software\Microsoft\Windows\CurrentVersion\Uninstall\{8362D1BB-D499-462E-9633-409161F21111}_is1',
      'UninstallString', PreviousUninstaller) then
      RaiseException('Desinstale a versão anterior do Caeser antes de instalar esta atualização.');
    PreviousUninstaller := RemoveQuotes(PreviousUninstaller);
    UninstallerName := Lowercase(ExtractFileName(PreviousUninstaller));
    if (CompareText(AddBackslash(ExtractFileDir(PreviousUninstaller)),
        AddBackslash(ExpandConstant('{app}'))) <> 0) or
       (Length(UninstallerName) <> 12) or (Copy(UninstallerName, 1, 5) <> 'unins') or
       (Copy(UninstallerName, 9, 4) <> '.exe') or not FileExists(PreviousUninstaller) then
      RaiseException('O desinstalador anterior não corresponde a esta pasta do Caeser.');
    for I := 6 to 8 do
      if (UninstallerName[I] < '0') or (UninstallerName[I] > '9') then
        RaiseException('Nome inesperado do desinstalador anterior.');
    Log('Removendo arquivos registrados da instalação antiga; downloads e preferências são preservados.');
    if not Exec(PreviousUninstaller, '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART', '', SW_HIDE,
      ewWaitUntilTerminated, ExitCode) then
      RaiseException('Não foi possível remover a instalação anterior. Feche o Caeser e tente novamente.')
    else if ExitCode <> 0 then
      RaiseException('A remoção da instalação anterior não terminou. Desinstale o Caeser e tente novamente.');
  end;
end;
