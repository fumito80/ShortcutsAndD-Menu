unit Common;

interface

uses
  Classes, SyncObjs, Windows, NPPlugin;

type
  TKeyConfig = class
  public
    mode, origin, orgModified: string;
    modifierFlags: Byte;
    scanCode: Cardinal;
    constructor Create(mode, origin, orgModified: string; modifierFlags: Byte; scanCode: Cardinal);
  end;

  TArrayCardinal = array of Cardinal;

  THookTh = class(TThread)
  protected
    modifierRelCount, seq: Integer;
    virtualModifires, virtualOffModifires: Byte;
    virtualScanCode: Cardinal;
    pipeHandle: THandle;
    browser: IBrowserObject;
    keyConfigList: TStringList;
    configMode, virtualOffModifiresFlag: Boolean;
    lastTarget, lastModified, lastOrgModified: string;
    criticalSection: TCriticalSection;
    function VaridateEvent(wPrm: UInt64): Boolean; virtual; abstract;
    procedure Execute; override;
  public
    constructor Create(pipeHandle: THandle; browser: IBrowserObject; keyConfigList: TStringList; configMode: Boolean);
  end;

const
  keyPipeName   = '\\.\pipe\flexkbd';
  mousePipeName = '\\.\pipe\flexmouse';

var
  modifiersCode: array[0..7] of Cardinal;
  g_configMode: Boolean;
  SCAN_LCONTROL: Cardinal =  $1D;
  SCAN_RCONTROL: Cardinal = $11D;
  SCAN_LMENU   : Cardinal =  $38;
  SCAN_RMENU   : Cardinal = $138;
  SCAN_LSHIFT  : Cardinal =  $2A;
  SCAN_RSHIFT  : Cardinal =  $36;
  SCAN_LWIN    : Cardinal = $15B;
  SCAN_RWIN    : Cardinal = $15C;
  FLAG_CONTROL : Byte     = 1;
  FLAG_MENU    : Byte     = 2;
  FLAG_SHIFT   : Byte     = 4;
  FLAG_WIN     : Byte     = 8;

implementation

constructor TKeyConfig.Create(mode, origin, orgModified: string; modifierFlags: Byte; scanCode: Cardinal);
begin
  Self.mode:= mode;
  Self.origin:= origin;
  Self.orgModified:= orgModified;
  Self.modifierFlags:= modifierFlags;
  Self.scanCode:= scanCode;
end;

constructor THookTh.Create(pipeHandle: THandle; browser: IBrowserObject; keyConfigList: TStringList; configMode: Boolean);
begin
  inherited Create(False);
  FreeOnTerminate:= False;
  Self.pipeHandle:= pipeHandle;
  Self.browser:= browser;
  Self.keyConfigList:= keyConfigList;
  Self.configMode:= configMode;
  criticalSection:= TCriticalSection.Create;
  modifierRelCount:= -1;
end;

procedure THookTh.Execute;
var
  wPrm: UInt64;
  bytesRead, bytesWrite: Cardinal;
  cancelFlag: Boolean;
begin
  while True do begin
    if ConnectNamedPipe(pipeHandle, nil) then begin
      try
        if ReadFile(pipeHandle, wPrm, SizeOf(UInt64), bytesRead, nil) then begin
          if wPrm = 1 then begin // Config reloadŽž
            criticalSection.Acquire;
            Self.configMode:= g_configMode;
            Self.keyConfigList:= keyConfigList;
            criticalSection.Release;
            Continue;
          end;
          cancelFlag:= VaridateEvent(wPrm);
          WriteFile(pipeHandle, cancelFlag, SizeOf(Boolean), bytesWrite, nil);
        end;
      finally
        DisconnectNamedPipe(pipeHandle);
      end;
    end else begin

      Write2EventLog('FlexKbd', 'Error: Connect named pipe');
      Break;
    end;
    if Terminated then
      Break;
  end;
end;

end.
