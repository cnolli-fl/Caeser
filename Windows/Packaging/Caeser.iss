#ifndef SourceDirectory
  #error SourceDirectory must point to the generated package
#endif
#ifndef OutputDirectory
  #error OutputDirectory must point to the artifact directory
#endif
#ifndef AppVersion
  #define AppVersion "2.1.0"
#endif

[Setup]
AppId={{DC43B65A-70C2-49D6-9A25-89E29E5F9E3D}
AppName=Caeser Preview
AppVersion={#AppVersion}
AppVerName=Caeser {#AppVersion} - Windows Preview
AppPublisher=Caio Nolli
AppPublisherURL=https://github.com/cnolli-fl/Caeser
DefaultDirName={localappdata}\Programs\Caeser Preview
DefaultGroupName=Caeser Preview
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19045
OutputDir={#OutputDirectory}
OutputBaseFilename=Caeser-{#AppVersion}-Windows-x64-Preview-Setup
SetupIconFile=..\Caeser.App\Assets\Caeser.ico
UninstallDisplayIcon={app}\Caeser.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; Flags: unchecked

[Files]
Source: "{#SourceDirectory}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb"

[Icons]
Name: "{autoprograms}\Caeser Preview"; Filename: "{app}\Caeser.exe"
Name: "{autodesktop}\Caeser Preview"; Filename: "{app}\Caeser.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Caeser.exe"; Description: "Abrir Caeser"; Flags: nowait postinstall skipifsilent
