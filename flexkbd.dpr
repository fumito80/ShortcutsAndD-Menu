library flexkbd;

{$R 'version.res' 'version.rc'}

uses
  SysUtils, Classes, Windows, StrUtils, SyncObjs, Messages, NPPlugin;

type
  TKeyHookTh = class(TThread)
  protected
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
    new, mode: string;
    constructor Create(new, mode: string);
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

constructor TKeyConfig.Create(new, mode: string);
begin
  Self.new:= new;
  Self.mode:= mode;
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
  shortcut, modifiersList: string;
  scanCode, vkCode, I: Cardinal;
begin
  Result:= False;
  scanCode:= HiWord(wPrm and $00000000FFFFFFFF);
  GetKeyState(0);
  GetKeyboardState(KeyState);
  if (scanCode > 32767) then // Not Key down
    Exit;
  if ((KeyState[VK_CONTROL] and 128) <> 0) then    // Cntrol
    modifiersList:= 'Ctrl';
  if ((KeyState[VK_MENU] and 128) <> 0) then begin // Alt
    if modifiersList <> '' then
      modifiersList:= modifiersList + ' + Alt'
    else
      modifiersList:= 'Alt';
    scanCode:= scanCode - $2000;
  end;
  if ((KeyState[VK_SHIFT] and 128) <> 0) then      // Shift
    if modifiersList <> '' then
      modifiersList:= modifiersList + ' + Shift'
    else
      modifiersList:= 'Shift';
  if ((KeyState[VK_LWIN] and 128) <> 0) or ((KeyState[VK_RWIN] and 128) <> 0) then // Win
    if modifiersList <> '' then
      modifiersList:= modifiersList + ' + Meta'
    else
      modifiersList:= 'Meta';
  vkCode:= MapVirtualKeyEx(scanCode, 1, GetKeyboardLayout(0));
  if (modifiersList = '') or (vkCode in [0, VK_CONTROL, VK_SHIFT, VK_MENU, VK_LWIN, VK_RWIN]) then
    Exit;
  for I:= 0 to 7 do begin
    if scanCode = modifiersCode[I] then
      Exit;
  end;
  shortcut:= Trim(modifiersList) + '#' + IntToStr(scanCode);
  browser.Invoke('pluginEvent', ['kbdEvent', shortcut]);
  if configMode then
    Result:= True
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
    //Write2EventLog('FlexKbd', IntToStr(Ord(goFlag^)), EVENTLOG_INFORMATION_TYPE);
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

procedure TMyClass.SetKeyConfig(const params: array of Variant);
var
  I: Integer;
  paramsList, paramList: TStringList;
begin
  paramsList:= TStringList.Create;
  paramsList.Delimiter:= '|';
  paramsList.DelimitedText:= params[0];
  paramList:= TStringList.Create;
  paramList.Delimiter:= ';';
  keyConfigList.Clear;
  try
    for I:= 0 to paramsList.Count - 1 do begin
      paramList.DelimitedText:= paramsList.Strings[I];
      keyConfigList.AddObject(paramList.Strings[0], TKeyConfig.Create(paramList.Strings[1], paramList.Strings[2]));
      //Write2EventLog('FlexKbd', TKeyConfig(keyConfigList.Objects[I]).mode);
    end;
  finally
    paramsList.Free;
    paramList.Free;
  end;
  // コンフィグモード終了兼監視モード開始
  ReconfigKeyHook;
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

