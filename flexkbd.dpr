library flexkbd;

{$R 'version.res' 'version.rc'}

uses
  SysUtils, Classes, Windows, StrUtils, SyncObjs, Messages, NPPlugin, Math;

type
  TArrayCardinal = array of Cardinal;

  TKeyHookTh = class(TThread)
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
    function VaridateKeyEvent(wPrm: UInt64): Boolean;
    procedure Execute; override;
  public
    constructor Create(pipeHandle: THandle; browser: IBrowserObject; keyConfigList: TStringList; configMode: Boolean);
  end;

  TKeyConfig = class
  public
    mode, origin, orgModified: string;
    modifierFlags: Byte;
    scanCode: Cardinal;
    constructor Create(mode, origin, orgModified: string; modifierFlags: Byte; scanCode: Cardinal);
  end;

  TMyClass = class(TPlugin)
  private
    pipeHandle: THandle;
    browser: IBrowserObject;
    keyHookTh: TKeyHookTh;
    procedure EndKeyHook;
    procedure StartKeyHook(configMode: Boolean);
    procedure ReconfigKeyHook(configMode: Boolean = False);
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

const
  pipeName = '\\.\pipe\flexkbd';

var
  hookKey: HHOOK;
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
  modifiersCode: array[0..7] of Cardinal;
  keyConfigList: TStringList;
  g_configMode: Boolean;

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
  pipeHandle:= CreateNamedPipe(
    PChar(pipeName), PIPE_ACCESS_DUPLEX,
    PIPE_TYPE_MESSAGE or PIPE_READMODE_MESSAGE or PIPE_WAIT,
    1, 255, 255,
    NMPWAIT_WAIT_FOREVER, nil
  );
  if pipeHandle = INVALID_HANDLE_VALUE then begin
    Write2EventLog('FlexKbd', 'Error: CreateNamedPipe');
    Exit;
  end;
  browser:= GetBrowserWindowObject;
  keyConfigList:= TStringList.Create;
  Write2EventLog('FlexKbd', 'Start Shortcuts Remapper', EVENTLOG_INFORMATION_TYPE);
end;

destructor TMyClass.Destroy;
begin
  EndKeyHook;
  CloseHandle(pipeHandle);
  keyConfigList.Free;
  Write2EventLog('FlexKbd', 'Terminated Shortcuts Remapper', EVENTLOG_INFORMATION_TYPE);
  inherited;
end;

//constructor TKeyConfig.Create(mode: string; newScans: TArrayCardinal);
constructor TKeyConfig.Create(mode, origin, orgModified: string; modifierFlags: Byte; scanCode: Cardinal);
begin
  Self.mode:= mode;
  Self.origin:= origin;
  Self.orgModified:= orgModified;
  Self.modifierFlags:= modifierFlags;
  Self.scanCode:= scanCode;
end;

constructor TKeyHookTh.Create(pipeHandle: THandle; browser: IBrowserObject; keyConfigList: TStringList; configMode: Boolean);
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

function TKeyHookTh.VaridateKeyEvent(wPrm: UInt64): Boolean;
var
  KeyState: TKeyboardState;
  scans: string;
  scanCode: Cardinal;
  modifierFlags, modifiersBoth: Byte;
  keyConfig: TKeyConfig;
  keyDownState, index, I: Integer;
  KeyInputs: array of TInput;
  KeyInputCount: Integer;
  newScans: TArrayCardinal;
  procedure  KeybdInput(scanCode: Cardinal; Flags: DWord);
  begin
    Inc(KeyInputCount);
    SetLength(KeyInputs, KeyInputCount);
    KeyInputs[KeyInputCount - 1].Itype := INPUT_KEYBOARD;
    with KeyInputs[KeyInputCount - 1].ki do
    begin
      wVk:= MapVirtualKeyEx(scanCode, 3, GetKeyboardLayout(0));
      wScan := scanCode;
      dwFlags := Flags;
      if scanCode > $100 then begin
        dwFlags := dwFlags or KEYEVENTF_EXTENDEDKEY;
        wScan:= wScan - $100;
        wVk:= MapVirtualKeyEx(wScan, 3, GetKeyboardLayout(0));
      end;
      time := 0;
      dwExtraInfo:= 0;
    end;
  end;
  procedure  ReleaseModifier(vkCode, scanCode: Cardinal; Flags: DWord);
  begin
    Inc(KeyInputCount);
    SetLength(KeyInputs, KeyInputCount);
    KeyInputs[KeyInputCount - 1].Itype:= INPUT_KEYBOARD;
    with KeyInputs[KeyInputCount - 1].ki do
    begin
      wVk:= vkCode;
      wScan:= scanCode;
      dwFlags := KEYEVENTF_KEYUP or Flags;
      time := 0;
      dwExtraInfo:= 0;
    end;
  end;
  procedure AlterModified(var virtualModifires: Byte; var virtualScanCode: Cardinal; Flags: DWord);
  begin
    if virtualScanCode <> 0 then
      KeybdInput(virtualScanCode, Flags);
    if (virtualModifires and FLAG_CONTROL) <> 0 then begin
      ReleaseModifier(VK_RCONTROL, SCAN_RCONTROL, Flags or KEYEVENTF_EXTENDEDKEY);
      ReleaseModifier(VK_LCONTROL, SCAN_LCONTROL, Flags);
    end;
    if (virtualModifires and FLAG_MENU) <> 0 then begin
      ReleaseModifier(VK_RMENU, SCAN_RMENU, Flags or KEYEVENTF_EXTENDEDKEY);
      ReleaseModifier(VK_LMENU, SCAN_LMENU, Flags);
    end;
    if (virtualModifires and FLAG_SHIFT) <> 0 then begin
      ReleaseModifier(VK_RSHIFT, SCAN_RSHIFT, Flags);
      ReleaseModifier(VK_LSHIFT, SCAN_LSHIFT, Flags);
    end;
    if (virtualModifires and FLAG_WIN) <> 0 then begin
      ReleaseModifier(VK_RWIN, SCAN_RWIN, Flags or KEYEVENTF_EXTENDEDKEY);
      ReleaseModifier(VK_LWIN, SCAN_LWIN, Flags or KEYEVENTF_EXTENDEDKEY);
    end;
    SendInput(KeyInputCount, KeyInputs[0], SizeOf(KeyInputs[0]));
    virtualScanCode:= 0;
    virtualModifires:= 0;
  end;
  procedure AddScan(scan: Cardinal);
  begin
    SetLength(newScans, Length(newScans) + 1);
    newScans[Length(newScans) - 1]:= scan;
  end;
begin
  //Inc(seq);
  Result:= False;
  scanCode:= HiWord(wPrm and $00000000FFFFFFFF);
  keyDownState:= 0;
  if (scanCode and $8000) <> $0 then begin
    keyDownState:= KEYEVENTF_KEYUP;
    scanCode:= scanCode and $7FFF;
  end;
  if (scanCode and $6000) <> $0 then begin
    scanCode:= scanCode and $1FFF; // リピート or Alt
  end;
  //Write2EventLog('FlexKbd', IntToStr(seq) + ') ' + IntToStr(scanCode) + ': ' + IntToHex(scanCode, 8) + ': '+ IntToHex(MapVirtualKeyEx(scanCode, 1, GetKeyboardLayout(0)), 4) + ': ' + IntToStr(keyDownState));
  GetKeyState(0);
  GetKeyboardState(KeyState);
  modifierFlags:= 0;
  modifierFlags:= modifierFlags or (Ord((KeyState[VK_CONTROL] and 128) <> 0) * FLAG_CONTROL);
  modifierFlags:= modifierFlags or (Ord((KeyState[VK_MENU]    and 128) <> 0) * FLAG_MENU);
  modifierFlags:= modifierFlags or (Ord((KeyState[VK_SHIFT]   and 128) <> 0) * FLAG_SHIFT);
  modifierFlags:= modifierFlags or (Ord(((KeyState[VK_LWIN]   and 128) <> 0) or ((KeyState[VK_RWIN] and 128) <> 0)) * FLAG_WIN);
  scans:= IntToHex(modifierFlags, 2) + IntToStr(scanCode);
  Write2EventLog('FlexKbd', IntToStr(seq) + '> ' + IntToHex(scanCode, 4) + ': ' + scans + ': ' + IntToHex(MapVirtualKeyEx(scanCode, 1, GetKeyboardLayout(0)), 4) + ': ' + IntToStr(keyDownState));

  // Exit1 --> Modifierキー単独のとき
  for I:= 0 to 7 do begin
    if scanCode = modifiersCode[I] then begin
      if (modifierRelCount > -1) and (keyDownState = KEYEVENTF_KEYUP) then begin
        if modifierRelCount = 0 then begin
          AlterModified(virtualModifires, virtualScanCode, KEYEVENTF_KEYUP);
          virtualOffModifires:= 0;
          virtualOffModifiresFlag:= False;
          modifierRelCount:= -1;
          lastTarget:= '';
          lastModified:= '';
          lastOrgModified:= '';
          Write2EventLog('FlexKbd', 'end');
        end else begin
          Dec(modifierRelCount);
        end;
      end;
      Exit;
    end;
  end;
  // Exit2 --> Modifierキーが押されていない ＆ ファンクションキーじゃないとき
  if (modifierFlags = 0)
    and not(scancode in [$3B..$44, $57, $58])
    and not((keyDownState = 0) and (virtualScanCode in [$3B..$44, $57, $58])) then
      Exit;

  if configMode then begin
    Result:= True;
    browser.Invoke('pluginEvent', ['configKeyEvent', scans]);
  end else begin
    Write2EventLog('FlexKbd', scans + ': ' + lastTarget + ': ' + lastModified + ': ' + IntToStr(modifierFlags) + ': ' + IntToStr(virtualModifires) + ': ' + IntToStr(virtualOffModifires));
    if scans = lastOrgModified then begin
      // リピート対応
      scans:= lastTarget;
      modifierFlags:= StrToInt('$' + LeftBStr(lastModified, 2));
    end
    else if (scans <> lastModified) and ((virtualModifires > 0) or (virtualOffModifires > 0)) then begin
      // Modifier及びキー変更対応
      scans:= IntToHex(modifierFlags and (not virtualModifires) or virtualOffModifires, 2) + IntToStr(scanCode);
    end
    else if (scans = lastModified) and (scanCode = virtualScanCode) then begin
      // 循環参照対応
      Write2EventLog('FlexKbd', 'Exit');
      if keyDownState = KEYEVENTF_KEYUP then
        virtualScanCode:= 0;
      Exit;
    end;

    index:= keyConfigList.IndexOf(scans);
    if index > -1 then begin
      Result:= True;
      keyConfig:= TKeyConfig(keyConfigList.Objects[index]);
      if keyConfig.mode = 'assignOrg' then begin
        modifierRelCount:= 0;
        if keyDownState = KEYEVENTF_KEYUP then
          AddScan(keyConfig.scanCode);
        modifiersBoth:= modifierFlags and keyConfig.modifierFlags;
        // CONTROL
        if (modifiersBoth and FLAG_CONTROL) <> 0 then begin
          ;
        end else begin
          if (keyConfig.modifierFlags and FLAG_CONTROL) <> 0 then begin
            AddScan(SCAN_LCONTROL);
            if (virtualOffModifires and FLAG_CONTROL) = 0 then
              virtualModifires:= virtualModifires or FLAG_CONTROL;
          end
          else if ((modifierFlags and FLAG_CONTROL) <> 0) and (keyDownState = 0) then begin
            ReleaseModifier(VK_RCONTROL, SCAN_RCONTROL, KEYEVENTF_EXTENDEDKEY);
            ReleaseModifier(VK_LCONTROL, SCAN_LCONTROL, 0);
            Inc(modifierRelCount, 2);
            if (virtualModifires and FLAG_CONTROL) = 0 then
              virtualOffModifires:= virtualOffModifires or FLAG_CONTROL;
          end;
        end;
        // ALT
        if (modifiersBoth and FLAG_MENU) <> 0 then begin
          ;
        end else begin
          if (keyConfig.modifierFlags and FLAG_MENU) <> 0 then begin
            AddScan(SCAN_LMENU);
            if (virtualOffModifires and FLAG_MENU) = 0 then
              virtualModifires:= virtualModifires or FLAG_MENU;
          end
          else if ((modifierFlags and FLAG_MENU) <> 0) and (keyDownState = 0) then begin
            ReleaseModifier(VK_RMENU, SCAN_RMENU, KEYEVENTF_EXTENDEDKEY);
            ReleaseModifier(VK_LMENU, SCAN_LMENU, 0);
            Inc(modifierRelCount, 2);
            if (virtualModifires and FLAG_MENU) = 0 then
              virtualOffModifires:= virtualOffModifires or FLAG_MENU;
          end;
        end;
        // SHIFT
        if (modifiersBoth and FLAG_SHIFT) <> 0 then begin
          ;
        end else begin
          if (keyConfig.modifierFlags and FLAG_SHIFT) <> 0 then begin
            AddScan(SCAN_LSHIFT);
            if (virtualOffModifires and FLAG_SHIFT) = 0 then
              virtualModifires:= virtualModifires or FLAG_SHIFT;
          end
          else if ((modifierFlags and FLAG_SHIFT) <> 0) and (keyDownState = 0) then begin
            ReleaseModifier(VK_RSHIFT, SCAN_RSHIFT, 0);
            ReleaseModifier(VK_LSHIFT, SCAN_LSHIFT, 0);
            Inc(modifierRelCount, 2);
            if (virtualModifires and FLAG_SHIFT) = 0 then
              virtualOffModifires:= virtualOffModifires or FLAG_SHIFT;
          end;
        end;
        // WIN
        if (modifiersBoth and FLAG_WIN) <> 0 then begin
          ;
        end else begin
          if (keyConfig.modifierFlags and FLAG_WIN) <> 0 then begin
            Write2EventLog('FlexKbd', 'addwin');
            AddScan(SCAN_LWIN);
            if (virtualOffModifires and FLAG_WIN) = 0 then
              virtualModifires:= virtualModifires or FLAG_WIN;
          end
          else if ((modifierFlags and FLAG_WIN) <> 0) and (keyDownState = 0) then begin
            ReleaseModifier(VK_RWIN, SCAN_RWIN, KEYEVENTF_EXTENDEDKEY);
            ReleaseModifier(VK_LWIN, SCAN_LWIN, KEYEVENTF_EXTENDEDKEY);
            Inc(modifierRelCount, 2);
            if (virtualModifires and FLAG_WIN) = 0 then
              virtualOffModifires:= virtualOffModifires or FLAG_WIN;
          end;
        end;
        if keyDownState = 0 then
          AddScan(keyConfig.scanCode);
        for I:= 0 to Length(newScans) - 1 do begin
          KeybdInput(newScans[I], keyDownState);
        end;
        SendInput(KeyInputCount, KeyInputs[0], SizeOf(KeyInputs[0]));
        lastOrgModified:= keyConfig.orgModified;
        lastTarget:= scans;
        lastModified:= keyConfig.origin;
        virtualScanCode:= keyConfig.scanCode;
      end else if keyConfig.mode = 'simEvent' then begin
        browser.Invoke('pluginEvent', ['sendToDom', scans]);
      end else if keyConfig.mode = 'bookmark' then begin
        browser.Invoke('pluginEvent', ['bookmark', scans]);
      end else if keyConfig.mode = 'through' then begin
        Result:= False;
      end;
    end;
  end;
end;

procedure TKeyHookTh.Execute;
var
  wPrm: UInt64;
  bytesRead, bytesWrite: Cardinal;
  cancelFlag: Boolean;
begin
  while True do begin
    if ConnectNamedPipe(pipeHandle, nil) then begin
      try
        if ReadFile(pipeHandle, wPrm, SizeOf(UInt64), bytesRead, nil) then begin
          if wPrm = 1 then begin // Config reload時
            criticalSection.Acquire;
            Self.configMode:= g_configMode;
            Self.keyConfigList:= keyConfigList;
            criticalSection.Release;
            Continue;
          end;
          cancelFlag:= VaridateKeyEvent(wPrm);
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

function Hookfunc(code: Integer; wPrm: Int64; lPrm: Int64): LRESULT;
var
  pipename: string;
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
    pipename:= '\\.\pipe\flexkbd';
    CallNamedPipe(PAnsiChar(pipename), @wPrm, SizeOf(UInt64), @cancelFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
    if cancelFlag then
      Result:= 1
    else
      Result:= CallNextHookEx(HookKey, code, wPrm, lPrm);
  end else begin
    Result:= CallNextHookEx(HookKey, code, wPrm, lPrm);
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
    ReconfigKeyHook;
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
    ReconfigKeyHook;
  end;
end;

// コンフィグモード開始
procedure TMyClass.StartConfigMode;
begin
  ReconfigKeyHook(True);
end;

procedure TMyClass.EndConfigMode;
begin
  ReconfigKeyHook(False);
end;

// Start KeyHook
procedure TMyClass.StartKeyHook(configMode: Boolean);
begin
  keyHookTh:= TKeyHookTh.Create(pipeHandle, browser, keyConfigList, configMode);
  hookKey:= SetWindowsHookEx(WH_KEYBOARD, @Hookfunc, hInstance, 0);
  //Write2EventLog('FlexKbd', IntToStr(HookKey));
end;

// Stop KeyHook
procedure TMyClass.EndKeyHook;
var
  cancelValue: UInt64;
  dummyFlag: Boolean;
  bytesRead: Cardinal;
begin
  if hookKey <> 0 then
   	UnHookWindowsHookEX(HookKey);
  if keyHookTh <> nil then begin
    keyHookTh.Terminate;
    cancelValue:= 0;
    CallNamedPipe(PAnsiChar(pipeName), @cancelValue, SizeOf(UInt64), @dummyFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
    keyHookTh.WaitFor;
    FreeAndNil(keyHookTh);
  end;
end;

// Thread config reload
procedure TMyClass.ReconfigKeyHook(configMode: Boolean = False);
var
  reloadValue: UInt64;
  dummyFlag: Boolean;
  bytesRead: Cardinal;
begin
  if keyHookTh = nil then begin
    g_configMode:= False;
    StartKeyHook(false);
  end else begin
    g_configMode:= configMode;
    reloadValue:= 1;
    CallNamedPipe(PAnsiChar(pipeName), @reloadValue, SizeOf(UInt64), @dummyFlag, SizeOf(Boolean), bytesRead, NMPWAIT_NOWAIT);
  end;
end;

begin
  TMyClass.Register('application/x-flexkbd', nil);

end.

