library flexkbd;

{$R 'version.res' 'version.rc'}

uses
  SysUtils,
  Classes,
  Windows,
  SyncObjs,
  Messages,
  StrUtils,
  NPPlugin,
  Math,
  KeyHookThread in 'KeyHookThread.pas',
  MouseHookThread in 'MouseHookThread.pas',
  Common in 'Common.pas';

type
  TMyClass = class(TPlugin)
  private
    keyPipeHandle, mousePipeHandle: THandle;
    browser: IBrowserObject;
    keyHookTh: TKeyHookTh;
    mouseHookTh: TMouseHookTh;
    procedure EndHook;
    procedure StartHook(configMode: Boolean);
    procedure ReconfigHook(configMode: Boolean = False);
  public
    constructor Create( AInstance         : PNPP ;
                        AExtraInfo        : TObject ;
                        const APluginType : string ;
                        AMode             : word ;
                        AParamNames       : TStrings ;
                        AParamValues      : TStrings ;
                        const ASaved      : TNPSavedData ) ; override;
    destructor Destroy; override;
  published
    // 設定を反映 & コンフィグモード終了兼監視モード開始
    procedure SetKeyConfig(const params: array of Variant);
    // コンフィグモード開始
    procedure StartConfigMode;
    procedure EndConfigMode;
  end;

var
  hookKey, hookMouse: HHOOK;
  keyConfigList: TStringList;

constructor TMyClass.Create( AInstance         : PNPP ;
                             AExtraInfo        : TObject ;
                             const APluginType : string ;
                             AMode             : word ;
                             AParamNames       : TStrings ;
                             AParamValues      : TStrings ;
                             const ASaved      : TNPSavedData );
begin
  inherited;
  modifiersCode[0]:= SCAN_LCONTROL;
  modifiersCode[1]:= SCAN_LMENU;
  modifiersCode[2]:= SCAN_LSHIFT;
  modifiersCode[3]:= SCAN_LWIN;
  modifiersCode[4]:= SCAN_RCONTROL;
  modifiersCode[5]:= SCAN_RMENU;
  modifiersCode[6]:= SCAN_RSHIFT;
  modifiersCode[7]:= SCAN_RWIN;
  keyPipeHandle:= CreateNamedPipe(
    PChar(keyPipeName), PIPE_ACCESS_DUPLEX,
    PIPE_TYPE_MESSAGE or PIPE_READMODE_MESSAGE or PIPE_WAIT,
    1, 255, 255,
    NMPWAIT_WAIT_FOREVER, nil
  );
  if keyPipeHandle = INVALID_HANDLE_VALUE then begin
    Write2EventLog('FlexKbd', 'Error: CreateNamedPipe');
    Exit;
  end;
  mousePipeHandle:= CreateNamedPipe(
    PChar(mousePipeName), PIPE_ACCESS_DUPLEX,
    PIPE_TYPE_MESSAGE or PIPE_READMODE_MESSAGE or PIPE_WAIT,
    1, 255, 255,
    NMPWAIT_WAIT_FOREVER, nil
  );
  if mousePipeHandle = INVALID_HANDLE_VALUE then begin
    Write2EventLog('FlexKbd', 'Error: CreateNamedPipe(mouse)');
    Exit;
  end;
  browser:= GetBrowserWindowObject;
  keyConfigList:= TStringList.Create;
  Write2EventLog('FlexKbd', 'Start Shortcuts Remapper', EVENTLOG_INFORMATION_TYPE);
end;

destructor TMyClass.Destroy;
begin
  EndHook;
  CloseHandle(keyPipeHandle);
  keyConfigList.Free;
  Write2EventLog('FlexKbd', 'Terminated Shortcuts Remapper', EVENTLOG_INFORMATION_TYPE);
  inherited;
end;

function KeyHookFunc(code: Integer; wPrm: Int64; lPrm: Int64): LRESULT;
var
  cancelFlag: Boolean;
  bytesRead: Cardinal;
  hWindow: HWnd;
  buf: array[0..1000] of AnsiChar;
begin
  if (code < 0) then begin
    Result:= CallNextHookEx(HookKey, code, wPrm, lPrm);
    Exit;
  end;
  hWindow:= GetforegroundWindow;
  GetWindowModuleFileName(hWindow, buf, SizeOf(buf));
  if AnsiEndsText('chrome.exe', buf) then begin
    CallNamedPipe(PAnsiChar(keypipename), @wPrm, SizeOf(wPrm), @cancelFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
    if cancelFlag then
      Result:= 1
    else
      Result:= CallNextHookEx(HookKey, code, wPrm, lPrm);
  end else begin
    Result:= CallNextHookEx(HookKey, code, wPrm, lPrm);
  end;
end;

function MouseHookFunc(code: Integer; wPrm: WPARAM; lPrm: LPARAM): LRESULT; stdcall;
var
  cancelFlag: Boolean;
  bytesRead: Cardinal;
  hWindow: HWnd;
  buf: array[0..1000] of AnsiChar;
  mouseInfo: TMsllHookStruct;
  msgAlt: Int64;
  msgFlag: UInt64;
  mouseData: Smallint;
begin
  if (code <> HC_ACTION) then begin
    Result:= CallNextHookEx(hookMouse, code, wPrm, lPrm);
    Exit;
  end;
  msgAlt:= wPrm - $0200;
  if (msgAlt in [MSG_MOUSE_LDBL, MSG_MOUSE_RDBL, MSG_MOUSE_MDBL]) or not (msgAlt in [MSG_MOUSE_LDOWN..MSG_MOUSE_WHEEL]) then begin
    Result:= CallNextHookEx(HookMouse, code, wPrm, lPrm);
    Exit;
  end;
  hWindow:= GetforegroundWindow;
  GetWindowModuleFileName(hWindow, buf, SizeOf(buf));
  if AnsiEndsText('chrome.exe', buf) then begin
    mouseInfo:= PMsllHookStruct(lPrm)^;
    Write2EventLog('FlexKbd', IntToHex(mouseInfo.mouseData, 16));
    if wPrm = WM_MOUSEWHEEL then begin
      mouseData:= Hiword(mouseInfo.mouseData);
      if mouseData > 0 then
        msgFlag:= WM_WHEEL_UP
      else
        msgFlag:= WM_WHEEL_DOWN;
    end else begin
      msgFlag:= wPrm; //msg^.message;
    end;
    CallNamedPipe(PAnsiChar(mousepipename), @msgFlag, SizeOf(msgFlag), @cancelFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
    if cancelFlag then
      Result:= 1
    else
      Result:= CallNextHookEx(hookMouse, code, wPrm, lPrm);
  end else begin
    Result:= CallNextHookEx(hookMouse, code, wPrm, lPrm);
  end;
end;

procedure TMyClass.SetKeyConfig(const params: array of Variant);
var
  modifierFlags, targetModifierFlags, I: Byte;
  paramsList, paramList: TStringList;
  mode, orgModified, target, origin, proxyTarget, proxyOrgModified: string;
  scanCode, targetScanCode, proxyScanCode: Cardinal;
  scans: TArrayCardinal;
  function GetProxyScanCode(scanCode: Cardinal): Cardinal;
  var
    I, J: Integer;
    exists: Boolean;
  begin
    for I:= 0 to 100 do begin
      exists:= False;
      for J:= 0 to keyConfigList.Count - 1 do begin
        if IntToStr(scanCode) = Copy(keyConfigList.Strings[J], 3, 10) then begin
          exists:= True;
          Break;
        end;
      end;
      if exists then
        Inc(scanCode)
      else
        Break;
    end;
    Result:= scanCode;
  end;
begin
  if params[0] = '' then begin
    keyConfigList.Clear;
    ReconfigHook;
    Exit;
  end;
  paramsList:= TStringList.Create;
  paramsList.Delimiter:= '|';
  paramsList.DelimitedText:= params[0];
  paramList:= TStringList.Create;
  keyConfigList.Clear;
  try
    for I:= 0 to paramsList.Count - 1 do begin
      SetLength(scans, 0);
      paramList.Delimiter:= ';';
      paramList.DelimitedText:= paramsList.Strings[I];

      target:= paramList.Strings[0];
      targetModifierFlags:= StrToInt('$' + LeftBStr(target, 2));
      targetScanCode:= StrToInt(Copy(target, 3, 10));

      mode:= paramList.Strings[2];

      origin:= paramList.Strings[1];
      modifierFlags:= StrToInt('$' + LeftBStr(origin, 2));
      scanCode:= StrToInt(Copy(origin, 3, 10));
      orgModified:= LeftBStr(origin, 2) + Copy(target, 3, 10);

      if (scanCode = targetScanCode) and (modifierFlags <> targetModifierFlags) and (mode = 'assignOrg') then begin
        // Make Proxy
        proxyScanCode:= GetProxyScanCode($59);
        proxyTarget:= LeftBStr(target, 2) + IntToStr(proxyScanCode);
        proxyOrgModified:= LeftBStr(origin, 2) + IntToStr(proxyScanCode);
        //Write2EventLog('FlexKbd', 'MakeProxy: ' + proxyTarget + ': ' + IntToHex(scanCode, 4) + ': ' + IntToStr(modifierFlags) + ': ' + orgModified);
        keyConfigList.AddObject(proxyTarget, TKeyConfig.Create(
          mode,
          origin,
          proxyOrgModified,
          modifierFlags,
          scanCode
        ));
        // Make Origin
        orgModified:= LeftBStr(target, 2) + Copy(target, 3, 10);
        modifierFlags:= StrToInt('$' + LeftBStr(target, 2));;
        scanCode:= proxyScanCode;
        //Write2EventLog('FlexKbd', 'MakeProxy: ' + target + ': ' + IntToHex(scanCode, 4) + ': ' + IntToStr(modifierFlags) + ': ' + orgModified);
      end else begin
        //Write2EventLog('FlexKbd', 'Normal: ' + target + ': ' + IntToHex(scanCode, 4) + ': ' + IntToStr(modifierFlags) + ': ' + orgModified);
      end;

      keyConfigList.AddObject(target, TKeyConfig.Create(
        mode,
        origin,
        orgModified,
        modifierFlags,
        scanCode
      ));
    end;
  finally
    paramsList.Free;
    paramList.Free;
    // コンフィグモード終了兼監視モード開始
    ReconfigHook;
  end;
end;

// コンフィグモード開始
procedure TMyClass.StartConfigMode;
begin
  ReconfigHook(True);
end;

procedure TMyClass.EndConfigMode;
begin
  ReconfigHook(False);
end;

// Start KeyHook
procedure TMyClass.StartHook(configMode: Boolean);
begin
  mouseHookTh:= TMouseHookTh.Create(mousePipeHandle, browser, keyConfigList, configMode);
  hookMouse:= SetWindowsHookEx(14, @MouseHookFunc, hInstance, 0);
  keyHookTh:= TKeyHookTh.Create(keyPipeHandle, browser, keyConfigList, configMode);
  hookKey:= SetWindowsHookEx(WH_KEYBOARD, @KeyHookFunc, hInstance, 0);
end;

// Stop KeyHook
procedure TMyClass.EndHook;
var
  cancelValue: UInt64;
  dummyFlag: Boolean;
  bytesRead: Cardinal;
begin
  if hookKey <> 0 then
   	UnHookWindowsHookEX(hookKey);
   	UnHookWindowsHookEX(hookMouse);
  if keyHookTh <> nil then begin
    cancelValue:= 0;
    keyHookTh.Terminate;
    CallNamedPipe(PAnsiChar(keyPipeName), @cancelValue, SizeOf(UInt64), @dummyFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
    keyHookTh.WaitFor;
    FreeAndNil(keyHookTh);
    // Mouse hook
    mouseHookTh.Terminate;
    CallNamedPipe(PAnsiChar(mousePipeName), @cancelValue, SizeOf(UInt64), @dummyFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
    mouseHookTh.WaitFor;
    FreeAndNil(mouseHookTh);
  end;
end;

// Thread config reload
procedure TMyClass.ReconfigHook(configMode: Boolean = False);
var
  reloadFlag: UInt64;
  dummyFlag: Boolean;
  bytesRead: Cardinal;
begin
  if keyHookTh = nil then begin
    g_configMode:= False;
    StartHook(false);
  end else begin
    g_configMode:= configMode;
    reloadFlag:= 1;
    CallNamedPipe(PAnsiChar(keyPipeName)  , @reloadFlag, SizeOf(UInt64), @dummyFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
    CallNamedPipe(PAnsiChar(MousePipeName), @reloadFlag, SizeOf(UInt64), @dummyFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
  end;
end;

begin
  TMyClass.Register('application/x-flexkbd', nil);

end.

