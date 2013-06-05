library flexkbd;
// Plugin MIME types are specifed in the version info resource
{$R 'version.res' 'version.rc'}

uses
  SysUtils,
  Classes, Windows, NPPlugin, StrUtils, SyncObjs, Messages;

type
  THookfunc = function(code: Integer; wPrm: Int64; lPrm: Int64): LRESULT;

  TMessageTh = class(TThread)
  protected
    pipeHandle: THandle;
    browser: IBrowserObject;
    procedure Execute; override;
  public
    constructor Create(pipeHandle: THandle; browser: IBrowserObject);
    destructor Destroy; override;
  end;

  TMyClass = class(TPlugin)
  private
    pipeHandle: THandle;
    messageTh: TMessageTh;
    procedure endKeyHook;
    procedure startKeyHook(hookFunc: THookfunc);
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
    // 設定を反映
    procedure setKeyConfig(const params: array of Variant);
    // コンフィグモード終了
    procedure endConfigMode(const params: array of Variant);
    // コンフィグモード開始
    procedure startConfigMode;
    function keyEvent(const params: array of Variant): Variant;
  end;

const
  pipeName = '\\.\pipe\flexkbd';

var
  HookKey : HHOOK;
  browser: IBrowserObject;
  modifiersCode: array[0..7] of Cardinal = (29,42,54,56,285,312,347,348);

constructor TMessageTh.Create(pipeHandle: THandle; browser: IBrowserObject);
begin
  Self.pipeHandle:= pipeHandle;
  Self.browser:= browser;
  FreeOnTerminate:= True;
  inherited Create(False);
end;

procedure TMessageTh.Execute;
var
  buf: array of AnsiChar;
  bufSize: Integer;
  bytesRead: Cardinal;
begin
  bufSize:= 255;
  SetLength(buf, bufSize);
  while True do begin
    //Write2EventLog('FlexKbd', 'Start', EVENTLOG_INFORMATION_TYPE);
    if ConnectNamedPipe(pipeHandle, nil) then begin
      try
        if ReadFile(pipeHandle, buf[0], bufSize, bytesRead, nil) then begin
          SetLength(buf, bytesRead);
          //Write2EventLog('FlexKbd', AnsiString(buf), EVENTLOG_INFORMATION_TYPE);
          browser.Invoke('pluginEvent', ['kbdEvent', AnsiString(buf)]);
          SetLength(buf, bufSize);
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

destructor TMessageTh.Destroy;
begin
  DisconnectNamedPipe(pipeHandle);
  CloseHandle(pipeHandle);
  //Write2EventLog('FlexKbd', 'NamedPipe CloseHandle', EVENTLOG_INFORMATION_TYPE);
  inherited;
end;

procedure sendBrowser(msg: string);
begin
  browser.Invoke('pluginEvent', ['DomKeyEvent', msg]);
end;

function hookfuncConfig(code: Integer; wPrm: Int64; lPrm: Int64): LRESULT;
var
  hWindow: HWnd;
  KeyState: TKeyboardState;
  buf: array [0..1000] of Char;
  messages, modifiersList: string;
  pipename: string;
  bytesRead, scanCode, I: Cardinal;
begin
  if (code < 0) then begin
    Result:= CallNextHookEx(HookKey, code, wPrm, lPrm);
    exit;
  end;
  hWindow:= GetforegroundWindow;
  GetWindowModuleFileName(hWindow, buf, SizeOf(buf));
  if AnsiEndsText('chrome.exe', buf)  then begin
    Result:= 1;
    scanCode:= Hiword(wPrm and $00000000FFFFFFFF);
    GetKeyboardState(KeyState);
    if (scanCode > 32767) then // Not Key down
      Exit;
    if ((KeyState[VK_CONTROL] and 128) <> 0) then    // Cntrol
      modifiersList:= 'Ctrl';
    if ((KeyState[VK_MENU] and 128) <> 0) then begin // Alt
      if modifiersList <> '' then
        modifiersList:= modifiersList + '+Alt'
      else
        modifiersList:= 'Alt';
      scanCode:= scanCode - $2000;
    end;
    if ((KeyState[VK_SHIFT] and 128) <> 0) then      // Shift
      if modifiersList <> '' then
        modifiersList:= modifiersList + '+Shift'
      else
        modifiersList:= 'Shift';
    if ((KeyState[VK_LWIN] and 128) <> 0) or ((KeyState[VK_RWIN] and 128) <> 0) then // Win
      if modifiersList <> '' then
        modifiersList:= modifiersList + '+Meta'
      else
        modifiersList:= 'Meta';
    if (modifiersList = '') then
      Exit;
    for I:= 0 to 7 do begin
      if scanCode = modifiersCode[I] then
        Exit;
    end;
    messages:= Trim(modifiersList) + ',' + IntToStr(scanCode);
    pipename:= '\\.\pipe\flexkbd';
    CallNamedPipe(PChar(pipename), PAnsiChar(messages), length(messages), nil, 0, bytesRead, NMPWAIT_NOWAIT);
  end else begin
    Result:= CallNextHookEx(HookKey, code, wPrm, lPrm);
  end;
end;

function hookfuncAll(code: Integer; wPrm: Int64; lPrm: Int64): LRESULT;
var
  hWindow: HWnd;
  KeyState: TKeyboardState;
  buf: array [0..1000] of char;
  modifiersList: string;
begin
  //Write2EventLog('FlexKbd', 'hookfuncAll');
  if (code < 0) then begin
    Result:= CallNextHookEx(HookKey, code, wPrm, lPrm);
    exit;
  end;
  hWindow:= GetforegroundWindow;
  GetWindowModuleFileName(hWindow, buf, 1000);
  if AnsiEndsText('chrome.exe', buf)  then begin
    GetKeyboardState(KeyState);
    if ((KeyState[vk_Control] and 128) <> 0) then // Cntrol
      modifiersList := 'Control ';
    if ((KeyState[vk_Shift] and 128) <> 0) then   // Shift
      modifiersList := modifiersList + 'Shift ';
    if ((KeyState[vk_Menu] and 128) <> 0) then    // Alt
      modifiersList := modifiersList + 'Alt';
    Result:= 1;
  end else begin
    Result:= CallNextHookEx(HookKey, code, wPrm, lPrm);
  end;
end;

procedure TMyClass.setKeyConfig(const params: array of Variant);
var
  I: Integer;
begin
  for I:= 0 to Length(params) - 1 do begin

  end;
end;

// コンフィグモード開始
procedure TMyClass.startConfigMode;
begin
  endKeyHook;
  startKeyHook(hookfuncConfig);
end;

// コンフィグモード終了
procedure TMyClass.endConfigMode(const params: array of Variant);
begin
  endKeyHook;
  //startKeyHook(hookfuncAll);
end;

function TMyClass.keyEvent(const params: array of Variant): Variant;
begin
  //Write2EventLog('FlexKbd', params[0]);
  keybd_event(VK_CONTROL, 0, 0, 0);
  keybd_event(Byte('Q'), 0, 0, 0);
  keybd_event(Byte('Q'), 0, KEYEVENTF_KEYUP, 0);
  keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0);
  //browser.Invoke('pluginEvent', ['UHOOOO!']);
end;

procedure TMyClass.startKeyHook(hookFunc: THookfunc);
begin
  HookKey:= SetWindowsHookEx(WH_KEYBOARD, @hookfunc, hInstance, 0);
  //Write2EventLog('FlexKbd', IntToStr(HookKey));
end;

procedure TMyClass.endKeyHook;
begin
 	UnHookWindowsHookEX(HookKey);
end;

constructor TMyClass.Create( AInstance         : PNPP ;
                             AExtraInfo        : TObject ;
                             const APluginType : string ;
                             AMode             : word ;
                             AParamNames       : TStrings ;
                             AParamValues      : TStrings ;
                             const ASaved      : TNPSavedData );
begin
  inherited;
  //startKeyHook(hookfuncAll);
  browser:= GetBrowserWindowObject;
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
  messageTh:= TMessageTh.Create(pipeHandle, browser);
  Write2EventLog('FlexKbd', 'Start Flex KBD', EVENTLOG_INFORMATION_TYPE);
end;

destructor TMyClass.Destroy;
var
  dummy: string;
  bytesRead: Cardinal;
begin
 	UnHookWindowsHookEX(HookKey);
  messageTh.Terminate;
  dummy:= 'close';
  CallNamedPipe(PChar(pipeName), PChar(dummy), length(dummy), nil, 0, bytesRead, NMPWAIT_NOWAIT);
  Write2EventLog('FlexKbd', 'Terminated Flex KBD', EVENTLOG_INFORMATION_TYPE);
  inherited;
end;

begin
  TMyClass.Register('application/x-flexkbd', nil);

end.

