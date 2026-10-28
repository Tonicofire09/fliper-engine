; Instalador da Fliper Engine para Windows (Inno Setup). Gerado no workflow "Fliper Engine: compilar e publicar".
#ifndef Versao
  #define Versao "0.1"
#endif
[Setup]
AppId={{6F1E5D2A-F11B-4C1E-9E1A-F11BE4E9E001}
AppName=Fliper Engine
AppVersion={#Versao}
AppPublisher=Fliper Studio
AppPublisherURL=https://fliperstudio.com
DefaultDirName={autopf}\Fliper Engine
DefaultGroupName=Fliper Engine
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputBaseFilename=FliperEngineSetup
SetupIconFile=overlay\platform\windows\godot.ico
UninstallDisplayIcon={app}\FliperEngine.exe
Compression=lzma2/ultra
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Files]
Source: "dist\FliperEngine\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\Fliper Engine"; Filename: "{app}\FliperEngine.exe"
Name: "{autodesktop}\Fliper Engine"; Filename: "{app}\FliperEngine.exe"; Tasks: atalho

[Tasks]
Name: atalho; Description: "Create a desktop shortcut"

[Run]
Filename: "{app}\FliperEngine.exe"; Description: "Open Fliper Engine"; Flags: nowait postinstall skipifsilent
