; ============================================================================
; DJI Drone + Control4 Integration Server Installer
; ----------------------------------------------------------------------------
; All file references use ..\ to go up from InnoSetup/ to the installer/ root
; ============================================================================

#define MyAppName "DJI Drone Control4 Server"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Your Company Name"
#define MyAppURL "https://github.com/JoeyBailey3/Drone-Installer-Package"
#define MyAppExeName "DroneServerStart.bat"

[Setup]
AppId={{8B3F2A1C-9D4E-4F5A-B6C7-D8E9F0A1B2C3}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

DefaultDirName=C:\DroneServer
DisableDirPage=no
DefaultGroupName=DJI Drone Server
DisableProgramGroupPage=yes

PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

OutputDir=Output
OutputBaseFilename=DroneServer-Setup-v{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes

WizardStyle=modern

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

LicenseFile=..\Docs\LICENSE.txt
InfoBeforeFile=..\Docs\BEFORE.txt
InfoAfterFile=..\Docs\AFTER.txt

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked
Name: "startmenushortcut"; Description: "Create a &start menu shortcut"; GroupDescription: "Additional icons:"
Name: "autostart"; Description: "&Auto-start services on boot (recommended)"; GroupDescription: "Service configuration:"
Name: "openfirewall"; Description: "Open required &firewall ports"; GroupDescription: "Service configuration:"

[Files]
; ----- Application code (Node.js services) -----
Source: "..\Code\drone-api\*"; DestDir: "{app}\drone-api"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\Code\ws-broadcaster\*"; DestDir: "{app}\ws-broadcaster"; Flags: ignoreversion recursesubdirs createallsubdirs

; ----- Bundled binaries -----
Source: "..\Bin\ffmpeg\*"; DestDir: "{app}\bin\ffmpeg"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\Bin\scrcpy\*"; DestDir: "{app}\bin\scrcpy"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\Bin\platform-tools\*"; DestDir: "{app}\bin\platform-tools"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\Bin\mediamtx\*"; DestDir: "{app}\bin\mediamtx"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\Bin\nssm\*"; DestDir: "{app}\bin\nssm"; Flags: ignoreversion recursesubdirs createallsubdirs

; ----- Configuration templates -----
Source: "..\Configs\mediamtx.yml.template"; DestDir: "{app}\bin\mediamtx"; DestName: "mediamtx.yml"; Flags: ignoreversion
Source: "..\Configs\config.json.template"; DestDir: "{app}\drone-api"; DestName: "config.json"; Flags: onlyifdoesntexist
Source: "..\Configs\patrols.json.template"; DestDir: "{app}\drone-api"; DestName: "patrols.json"; Flags: onlyifdoesntexist

; ----- Helper scripts -----
Source: "..\Scripts\*"; DestDir: "{app}\scripts"; Flags: ignoreversion recursesubdirs

; ----- Documentation -----
Source: "..\Docs\BUILD-INSTRUCTIONS.md"; DestDir: "{app}\docs"; Flags: ignoreversion

; ----- Startup batch files at install root -----
Source: "..\Scripts\DroneServerStart.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Scripts\DroneServerStop.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Scripts\DroneServerHealthCheck.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\DJI Drone Server Start"; Filename: "{app}\DroneServerStart.bat"
Name: "{group}\DJI Drone Server Stop"; Filename: "{app}\DroneServerStop.bat"
Name: "{group}\Health Check"; Filename: "{app}\DroneServerHealthCheck.bat"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\DJI Drone Server"; Filename: "{app}\DroneServerStart.bat"; Tasks: desktopicon

[Run]
; ----- Post-install: Node.js dependencies -----
Filename: "{cmd}"; Parameters: "/C cd /D ""{app}\drone-api"" && npm install --production"; StatusMsg: "Installing Drone API dependencies..."; Flags: runhidden
Filename: "{cmd}"; Parameters: "/C cd /D ""{app}\ws-broadcaster"" && npm install --production"; StatusMsg: "Installing WebSocket broadcaster dependencies..."; Flags: runhidden

; ----- Run customer configuration wizard -----
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\04-Configure-Customer.ps1"" -InstallPath ""{app}"""; StatusMsg: "Configuring for customer..."; Flags: runhidden

; ----- Open firewall ports (optional task) -----
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\02-Configure-Firewall.ps1"" -InstallPath ""{app}"""; StatusMsg: "Configuring firewall..."; Tasks: openfirewall; Flags: runhidden

; ----- Install Windows services (optional task) -----
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\06-Install-Services.ps1"" -InstallPath ""{app}"""; StatusMsg: "Installing Windows services..."; Tasks: autostart; Flags: runhidden

; ----- Verify installation -----
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\05-Test-Installation.ps1"" -InstallPath ""{app}"""; StatusMsg: "Verifying installation..."; Flags: postinstall skipifsilent

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\scripts\99-Uninstall-Services.ps1"" -InstallPath ""{app}"""; Flags: runhidden

[UninstallDelete]
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\drone-api\node_modules"
Type: filesandordirs; Name: "{app}\ws-broadcaster\node_modules"

[Code]
var
  CustomerConfigPage: TInputQueryWizardPage;
  GPSConfigPage: TInputQueryWizardPage;

procedure InitializeWizard;
begin
  CustomerConfigPage := CreateInputQueryPage(wpSelectTasks,
    'Customer Configuration', 'Enter customer-specific values',
    'These values will be saved to the configuration file. You can change them later by editing config.json.');

  CustomerConfigPage.Add('Customer / Site Name:', False);
  CustomerConfigPage.Add('Server LAN IP (e.g. 10.0.40.10):', False);
  CustomerConfigPage.Add('Allowed LAN Subnet (e.g. 10.0.0.0/16):', False);
  CustomerConfigPage.Add('API Key (leave blank to auto-generate):', False);

  CustomerConfigPage.Values[2] := '10.0.0.0/16';

  GPSConfigPage := CreateInputQueryPage(CustomerConfigPage.ID,
    'Drone Base & Geofence', 'Set the drone home position and flight boundary',
    'These coordinates define where the drone returns to and how far it can fly. Use coordinates from where the dock is installed.');

  GPSConfigPage.Add('Base Latitude (decimal degrees):', False);
  GPSConfigPage.Add('Base Longitude (decimal degrees):', False);
  GPSConfigPage.Add('Geofence Radius (meters, default 500):', False);

  GPSConfigPage.Values[2] := '500';
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = CustomerConfigPage.ID then
  begin
    if Trim(CustomerConfigPage.Values[0]) = '' then
    begin
      MsgBox('Customer name is required.', mbError, MB_OK);
      Result := False;
    end;
    if (Result) and (Trim(CustomerConfigPage.Values[1]) = '') then
    begin
      MsgBox('Server LAN IP is required.', mbError, MB_OK);
      Result := False;
    end;
  end;
end;

function GetCustomerName(Param: String): String;
begin
  Result := CustomerConfigPage.Values[0];
end;

function GetServerIP(Param: String): String;
begin
  Result := CustomerConfigPage.Values[1];
end;

function GetLANSubnet(Param: String): String;
begin
  Result := CustomerConfigPage.Values[2];
end;

function GetAPIKey(Param: String): String;
begin
  Result := CustomerConfigPage.Values[3];
end;

function GetBaseLat(Param: String): String;
begin
  Result := GPSConfigPage.Values[0];
end;

function GetBaseLon(Param: String): String;
begin
  Result := GPSConfigPage.Values[1];
end;

function GetGeofenceRadius(Param: String): String;
begin
  Result := GPSConfigPage.Values[2];
end;

[INI]
Filename: "{app}\customer-config.ini"; Section: "Customer"; Key: "Name"; String: "{code:GetCustomerName}"
Filename: "{app}\customer-config.ini"; Section: "Customer"; Key: "ServerIP"; String: "{code:GetServerIP}"
Filename: "{app}\customer-config.ini"; Section: "Customer"; Key: "LANSubnet"; String: "{code:GetLANSubnet}"
Filename: "{app}\customer-config.ini"; Section: "Customer"; Key: "APIKey"; String: "{code:GetAPIKey}"
Filename: "{app}\customer-config.ini"; Section: "Drone"; Key: "BaseLat"; String: "{code:GetBaseLat}"
Filename: "{app}\customer-config.ini"; Section: "Drone"; Key: "BaseLon"; String: "{code:GetBaseLon}"
Filename: "{app}\customer-config.ini"; Section: "Drone"; Key: "GeofenceRadius"; String: "{code:GetGeofenceRadius}"
