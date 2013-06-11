library flexkbd;

{$R 'version.res' 'version.rc'}

uses
  SysUtils, Classes, Windows, StrUtils, SyncObjs, Messages, NPPlugin;

type
  TArrayCardinal = array of Cardinal;

  TKeyHookTh = class(TThread)
  protected
    seq: Integer;
    pipeHandle: THandle;
    browser: IBrowserObject;
    keyConfigList: TStringList;
    configMode: Boolean;
    criticalSection: TCriticalSection;
    function VaridateKeyEvent(wPrm: UInt64): Boolean;
    procedure Execute; override;
  public
    constructor Create(pipeHandle: THandle; browser: IBrowserObject; keyConfigList: TStringList; configMode: Boolean);
  end;

  TKeyConfig = class
  public
    mode: string;
    newScans: TArrayCardinal;
    constructor Create(mode: string; newScans: TArrayCardinal);
  end;

  TMyClass = class(TPlugin)
  private
    pipeHandle: THandle;
    browser: IBrowserObject;
    keyHookTh: TKeyHookTh;
    //keyConfigList: TStringList;
    procedure EndKeyHook;
    procedure StartKeyHook(configMode: Boolean);
    //procedure ResetKeyHook(configMode: Boolean = False);
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
    procedure SetKeyConfig0(const params: array of Variant);
    procedure SetKeyConfig(const params: array of Variant);
    // コンフィグモード開始
    procedure StartConfigMode;
    function keyEvent(const params: array of Variant): Variant;
  end;

const
  pipeName = '\\.\pipe\flexkbd';

var
  hookKey : HHOOK;
  modifiersCode: array[0..7] of Cardinal = (29,42,54,56,285,312,347,348);
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
  Write2EventLog('FlexKbd', 'Start Shortcut Exchanger', EVENTLOG_INFORMATION_TYPE);
end;

destructor TMyClass.Destroy;
begin
  EndKeyHook;
  CloseHandle(pipeHandle);
  keyConfigList.Free;
  Write2EventLog('FlexKbd', 'Terminated Shortcut Exchanger', EVENTLOG_INFORMATION_TYPE);
  inherited;
end;

constructor TKeyConfig.Create(mode: string; newScans: TArrayCardinal);
begin
  Self.mode:= mode;
  Self.newScans:= newScans;
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
end;

function TKeyHookTh.VaridateKeyEvent(wPrm: UInt64): Boolean;
var
  KeyState: TKeyboardState;
  scans: string;
  scanCode: Cardinal;
  modifierFlags: Byte;
  keyConfig: TKeyConfig;
  scanCodeRept, index, I: Integer;
  KeyInputs: array of TInput;
  KeyInputCount: Integer;
  procedure  KeybdInput(scanCode: Cardinal; Flags: DWord);
  begin
    Inc(KeyInputCount);
    SetLength(KeyInputs, KeyInputCount);
    KeyInputs[KeyInputCount - 1].Itype := INPUT_KEYBOARD;
    //Write2EventLog('FlexKbd', IntToStr(scanCode) + ': '+IntToStr(MapVirtualKeyEx(scanCode, 1, GetKeyboardLayout(0))));
    with KeyInputs[KeyInputCount - 1].ki do
    begin
      wVk:= MapVirtualKeyEx(scanCode, 3, GetKeyboardLayout(0));
      //Write2EventLog('FlexKbd', IntToHex(wVk, 4));
      wScan := scanCode;
      dwFlags := Flags;
      if scanCode > $100 then begin
        dwFlags := dwFlags or KEYEVENTF_EXTENDEDKEY;
        wScan:= wScan - $100;
        wVk:= MapVirtualKeyEx(wScan, 3, GetKeyboardLayout(0));
        //Write2EventLog('FlexKbd', IntToHex(wVk, 4));
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
  procedure MakeKeyInputs(scans: TArrayCardinal; index: Integer);
  begin
    KeybdInput(scans[index], 0);
    if (index + 1) < Length(scans) then
      MakeKeyInputs(scans, index + 1);
    KeybdInput(scans[index], KEYEVENTF_KEYUP);
  end;
begin
  Inc(seq);
  Result:= False;
  scanCode:= HiWord(wPrm and $00000000FFFFFFFF);
  // Exit1
  if (scanCode > 32767) then // Not Key down
    Exit;
  GetKeyState(0);
  GetKeyboardState(KeyState);
  modifierFlags:= 0;
  modifierFlags:= modifierFlags or (Ord((KeyState[VK_CONTROL] and 128) <> 0) * 1);
  modifierFlags:= modifierFlags or (Ord((KeyState[VK_MENU]    and 128) <> 0) * 2);
  modifierFlags:= modifierFlags or (Ord((KeyState[VK_SHIFT]   and 128) <> 0) * 4);
  modifierFlags:= modifierFlags or (Ord(((KeyState[VK_LWIN]   and 128) <> 0) or ((KeyState[VK_RWIN] and 128) <> 0)) * 8);
  if (modifierFlags and 2) <> 0 then
    scanCode:= scanCode - $2000;
  //if (modifierFlags = 0) or (vkCode in [0, VK_CONTROL, VK_SHIFT, VK_MENU, VK_LWIN, VK_RWIN]) then
  scanCodeRept:= scanCode - $4000;
  if scanCodeRept > 0 then
    scanCode:= scanCodeRept;
  scans:= IntToHex(modifierFlags, 2) + IntToStr(scanCode);
  //Write2EventLog('FlexKbd', IntToStr(seq) + '> ' + IntToHex(scanCode, 4) + ': ' + scans + ': ' + IntToHex(MapVirtualKeyEx(scanCode, 1, GetKeyboardLayout(0)), 4) + ': ' + IntToStr(GetAsyncKeyState(VK_CONTROL)));

  // Exit2 --> Modifierキーが押されていない ＆ ファンクションキーじゃないとき
  if (modifierFlags = 0) and not(scancode in [$3B..$44, $57, $58]) then
    Exit;
  // Exit3 --> Modifierキー単独のとき
  for I := 0 to 7 do begin
    if scanCode = modifiersCode[I] then
      Exit;
  end;

  if configMode then begin
    Result:= True;
    browser.Invoke('pluginEvent', ['configKeyEvent', scans]);
  end else begin
    index:= keyConfigList.IndexOf(scans);
    if index > -1 then begin
      Result:= True;
      keyConfig:= TKeyConfig(keyConfigList.Objects[index]);
      if keyConfig.mode = 'assignOrg' then begin
        ReleaseModifier(VK_RCONTROL, $11D, KEYEVENTF_EXTENDEDKEY);
        ReleaseModifier(VK_LCONTROL, $1D, 0);
        ReleaseModifier(VK_RMENU, $138, KEYEVENTF_EXTENDEDKEY);
        ReleaseModifier(VK_LMENU, $38, 0);
        MakeKeyInputs(keyConfig.newScans, 0);
        SendInput(KeyInputCount, KeyInputs[0], SizeOf(KeyInputs[0]));
      end else if keyConfig.mode = 'simEvent' then begin
        browser.Invoke('pluginEvent', ['sendToDom', scans]);
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
          //if wPrm = 0 then // 終了呼び出し時
          //  Break
          //end;
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

function TMyClass.KeyEvent(const params: array of Variant): Variant;
begin
  //Write2EventLog('FlexKbd', params[0]);
  keybd_event(VK_CONTROL, 0, 0, 0);
  keybd_event(Byte('Q'), 0, 0, 0);
  keybd_event(Byte('Q'), 0, KEYEVENTF_KEYUP, 0);
  keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0);
  //browser.Invoke('pluginEvent', ['UHOOOO!']);
end;

procedure TMyClass.SetKeyConfig0(const params: array of Variant);
begin
  ReconfigKeyHook;
end;

procedure TMyClass.SetKeyConfig(const params: array of Variant);
var
  modifiers, I: Byte;
  paramsList, paramList: TStringList;
  target, mode, test: string;
  scan: Cardinal;
  scans: TArrayCardinal;
  procedure AddScan(scan: Cardinal);
  begin
    SetLength(scans, Length(scans) + 1);
    scans[Length(scans) - 1]:= scan;
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
      mode:= paramList.Strings[2];
      test:= paramList.Strings[1];

      modifiers:= StrToInt('$' + LeftBStr(test, 2));
      if (modifiers and 1) <> 0 then AddScan($1D);  // VK_LCONTROL
      if (modifiers and 2) <> 0 then AddScan($38);  // VK_LMENU
      if (modifiers and 4) <> 0 then AddScan($2A);  // VK_LSHIFT
      if (modifiers and 8) <> 0 then AddScan($15B); // VK_LWIN

      scan:= StrToInt(Copy(test, 3, 10));
      AddScan(scan);
      //AddScan(MapVirtualKeyEx(scan, 1, GetKeyboardLayout(0)));

      keyConfigList.AddObject(target, TKeyConfig.Create(mode, scans));
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
  ReconfigKeyHook(true);
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

{
procedure TMyClass.ResetKeyHook(configMode: Boolean = False);
begin
  EndKeyHook;
  StartKeyHook(configMode);
end;
}

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

