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
