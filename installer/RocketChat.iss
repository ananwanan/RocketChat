#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef SourceDir
  #error SourceDir must be supplied by package.ps1
#endif
#ifndef OutputDir
  #error OutputDir must be supplied by package.ps1
#endif
#ifndef ProjectRoot
  #error ProjectRoot must be supplied by package.ps1
#endif

[Setup]
AppId={{A8CA36AA-EE55-4A31-BE8A-1379A8A8AE7E}
AppName=Rocket.Chat
AppVersion={#AppVersion}
AppVerName=Rocket.Chat {#AppVersion}
AppPublisher=ananwanan
AppPublisherURL=https://github.com/ananwanan/RocketChat
AppSupportURL=https://github.com/ananwanan/RocketChat/issues
AppUpdatesURL=https://github.com/ananwanan/RocketChat/releases
DefaultDirName={autopf}\Rocket.Chat
DefaultGroupName=Rocket.Chat
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=RocketChat-{#AppVersion}-win-x64-Setup
SetupIconFile={#ProjectRoot}\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\rocket_chat_flutter.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
MinVersion=10.0.17763

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Rocket.Chat"; Filename: "{app}\rocket_chat_flutter.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Rocket.Chat"; Filename: "{app}\rocket_chat_flutter.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\rocket_chat_flutter.exe"; Description: "Launch Rocket.Chat"; Flags: nowait postinstall skipifsilent
