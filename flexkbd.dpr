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
  Common in 'Common.pas',
  ClipBrd;

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
    // 設定を反映 & コンフィグモード終了兼監視モード開始
    procedure PasteText(const params: array of Variant);
    procedure CallShortcut(const params: array of Variant);
    procedure SetClipboard(const params: array of Variant);
    procedure Sleep(const params: array of Variant);
  end;

var
  hookKey, hookMouse, hookMouseWheel: HHOOK;
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
  //Write2EventLog('FlexKbd', 'Start Shortcuts Remapper', EVENTLOG_INFORMATION_TYPE);
end;

destructor TMyClass.Destroy;
begin
  EndHook;
  CloseHandle(keyPipeHandle);
  CloseHandle(mousePipeHandle);
  keyConfigList.Free;
  inherited Destroy;
  //Write2EventLog('FlexKbd', 'Terminated Shortcuts Remapper', EVENTLOG_INFORMATION_TYPE);
end;

function KeyHookFunc(code: Integer; wPrm: Int64; lPrm: Int64): LRESULT;
var
  cancelFlag: Boolean;
  bytesRead: Cardinal;
  hWindow: HWnd;
  buf: array[0..1000] of AnsiChar;
begin
  if (code <> HC_ACTION) then begin
    Result:= CallNextHookEx(HookKey, code, wPrm, lPrm);
    Exit;
  end;
  hWindow:= GetActiveWindow;
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
  msgAlt: Int64;
  msgFlag: UInt64;
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
  hWindow:= GetActiveWindow;
  //Write2EventLog('FlexKbd', IntToHex(mouseInfo.mouseData, 16));
  GetWindowModuleFileName(hWindow, buf, SizeOf(buf));
  if AnsiEndsText('chrome.exe', buf) and (wPrm <> WM_MOUSEWHEEL) then begin
    msgFlag:= wPrm;
    CallNamedPipe(PAnsiChar(mousepipename), @msgFlag, SizeOf(msgFlag), @cancelFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
    if cancelFlag then
      Result:= 1
    else
      Result:= CallNextHookEx(hookMouse, code, wPrm, lPrm);
  end else begin
    Result:= CallNextHookEx(hookMouse, code, wPrm, lPrm);
  end;
end;

function MouseWheelHookFunc(code: Integer; wPrm: WPARAM; lPrm: LPARAM): LRESULT; stdcall;
var
  cancelFlag: Boolean;
  bytesRead: Cardinal;
  hWindow: HWnd;
  buf: array[0..1000] of AnsiChar;
  msgFlag: UInt64;
  msg: TMsg;
begin
  if (code <> HC_ACTION) then begin
    Result:= CallNextHookEx(hookMouseWheel, code, wPrm, lPrm);
    Exit;
  end;
  msg:= PMsg(lPrm)^;
  if msg.message = WM_MOUSEWHEEL then begin
    hWindow:= GetActiveWindow;
    GetWindowModuleFileName(hWindow, buf, SizeOf(buf));
    if AnsiEndsText('chrome.exe', buf) then begin
      //Write2EventLog('FlexKbd', IntToStr(msg.wParam));
      if msg.wParam > 0 then
        msgFlag:= WM_WHEEL_UP
      else
        msgFlag:= WM_WHEEL_DOWN;
      CallNamedPipe(PAnsiChar(mousepipename), @msgFlag, SizeOf(msgFlag), @cancelFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
      if cancelFlag then
        PMsg(lPrm)^.message:= WM_NULL;
    end;
  end;
  Result:= CallNextHookEx(hookMouseWheel, code, wPrm, lPrm);
end;

procedure TMyClass.SetKeyConfig(const params: array of Variant);
var
  modifierFlags, targetModifierFlags, I: Byte;
  paramsList, paramList: TStringList;
  mode, orgModified, target, origin, proxyTarget, proxyOrgModified: string;
  scanCode, targetScanCode, proxyScanCode, kbdLayout: Cardinal;
  scans: TArrayCardinal;
  function GetProxyScanCode(scanCode: Cardinal): Cardinal;
  var
    I, J: Integer;
    exists: Boolean;
  begin
    for I:= 0 to 200 do begin
      exists:= False;
      for J:= 0 to keyConfigList.Count - 1 do begin
        if IntToStr(scanCode) = Copy(keyConfigList.Strings[J], 3, 10) then begin
          exists:= True;
          Break;
        end;
      end;
      if exists then begin
        Inc(scanCode)
      end else begin
        if MapVirtualKeyEx(scanCode, 3, kbdLayout) <> VK_NONAME then begin
          //Write2EventLog('FlexKbd VK_', IntToStr(MapVirtualKeyEx(scanCode, 3, kbdLayout)));
          Inc(scanCode);
        end else
          Break;
      end;
    end;
    Result:= scanCode;
  end;
begin
  if params[0] = '' then begin
    keyConfigList.Clear;
    ReconfigHook;
    Exit;
  end;
  kbdLayout:= GetKeyboardLayout(0);
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

      if (scanCode = targetScanCode) and (mode = 'remap') then begin
        if (modifierFlags = targetModifierFlags) then begin
          mode:= 'through'
        end else begin
          // Make Proxy
          proxyScanCode:= GetProxyScanCode($5A);
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
          modifierFlags:= StrToInt('$' + LeftBStr(target, 2));
          scanCode:= proxyScanCode;
          //Write2EventLog('FlexKbd', 'MakeProxy: ' + target + ': ' + IntToHex(scanCode, 4) + ': ' + IntToStr(modifierFlags) + ': ' + orgModified);
        end;
      end;

      keyConfigList.AddObject(target, TKeyConfig.Create(
        mode,
        origin,
        orgModified,
        modifierFlags,
        scanCode
      ));
    end;
    // For Paste Text
    keyConfigList.AddObject('0086', TKeyConfig.Create(
      'remap',
      '0147',
      '0186',
      1,
      47
    ));
    // For Copy Text
    {
    keyConfigList.AddObject('0085', TKeyConfig.Create(
      'remap',
      '0146',
      '0185',
      1,
      46
    ));
    }
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
  hookMouse:= SetWindowsHookEx(WH_MOUSE, @MouseHookFunc, hInstance, 0);
  hookMouseWheel:= SetWindowsHookEx(WH_GETMESSAGE, @MouseWheelHookFunc, hInstance, 0);
  keyHookTh:= TKeyHookTh.Create(keyPipeHandle, browser, keyConfigList, configMode);
  hookKey:= SetWindowsHookEx(WH_KEYBOARD, @KeyHookFunc, hInstance, 0);
end;

// Stop KeyHook
procedure TMyClass.EndHook;
var
  dummyFlag: Boolean;
  bytesRead: Cardinal;
begin
  if keyHookTh <> nil then begin
    keyHookTh.Terminate;
    CallNamedPipe(PAnsiChar(keyPipeName), @g_destroy, SizeOf(UInt64), @dummyFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
    keyHookTh.WaitFor;
    keyHookTh.Free;
    FreeAndNil(keyHookTh);
    // Mouse hook
    mouseHookTh.Terminate;
    CallNamedPipe(PAnsiChar(mousePipeName), @g_destroy, SizeOf(UInt64), @dummyFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
    mouseHookTh.WaitFor;
    mouseHookTh.Free;
    FreeAndNil(mouseHookTh);
  end;
  if hookKey <> 0 then begin
   	UnHookWindowsHookEX(hookKey);
   	UnHookWindowsHookEX(hookMouse);
   	UnHookWindowsHookEX(hookMouseWheel);
  end;
end;

// Thread config reload
procedure TMyClass.ReconfigHook(configMode: Boolean = False);
var
  dummyFlag: Boolean;
  bytesRead: Cardinal;
begin
  if keyHookTh = nil then begin
    g_configMode:= False;
    StartHook(false);
  end else begin
    g_configMode:= configMode;
    CallNamedPipe(PAnsiChar(keyPipeName)  , @g_reloadConfig, SizeOf(UInt64), @dummyFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
    CallNamedPipe(PAnsiChar(MousePipeName), @g_reloadConfig, SizeOf(UInt64), @dummyFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
  end;
end;

procedure TMyClass.PasteText(const params: array of Variant);
var
  dummyFlag: Boolean;
  bytesRead: Cardinal;
begin
  if params[0] = '' then Exit;
  Clipboard.AsText:= params[0];
  CallNamedPipe(PAnsiChar(keyPipeName), @g_pasteText, SizeOf(UInt64), @dummyFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
end;

procedure TMyClass.SetClipboard(const params: array of Variant);
begin
  Clipboard.AsText:= params[0];
end;

procedure TMyClass.Sleep(const params: array of Variant);
begin
  Windows.Sleep(params[0]);
end;

procedure TMyClass.CallShortcut(const params: array of Variant);
var
  dummyFlag: Boolean;
  bytesRead: Cardinal;
  scansInt64, scanCode: UInt64;
  Modifiers: Cardinal;
begin
  try
    //Write2EventLog('FlexKbd', params[0]);
    if (params[0] <> VarEmpty) and (params[1] <> VarEmpty) then begin
      scanCode:= StrToInt(Copy(params[0], 3, 10));
      scansInt64:= scanCode shl 16;
      Modifiers:= StrToInt(LeftBStr(params[0], 2));
      scansInt64:= scansInt64 + (Modifiers shl 8) + params[1];
      //Write2EventLog('FlexKbd', IntToStr(scansInt64));
      CallNamedPipe(PAnsiChar(keyPipeName), @scansInt64, SizeOf(UInt64), @dummyFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
    end;
  except
  end;
end;

begin
  TMyClass.Register('application/x-flexkbd', nil);

end.

