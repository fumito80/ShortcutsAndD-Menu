unit Common;

interface

uses
  SysUtils, Classes, SyncObjs, Windows, NPPlugin;

type
  TKeyConfig = class
  public
    mode, origin, orgModified: string;
    modifierFlags: Byte;
    scanCode: Cardinal;
    constructor Create(
      mode,
      origin,
      orgModified: string;
      modifierFlags: Byte;
      scanCode: Cardinal
    );
  end;

  TArrayCardinal = array of Cardinal;

  THookTh = class(TThread)
  protected
    modifierRelCount, seq: Integer;
    virtualModifires, virtualOffModifires: Byte;
    virtualScanCode, kbdLayout: Cardinal;
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
  targetProg     = 'chrome.exe';
  keyPipeName    = '\\.\pipe\flexkbd';
  mousePipeName  = '\\.\pipe\flexmouse';
  SCAN_LCONTROL  =  $1D;
  SCAN_RCONTROL  = $11D;
  SCAN_LMENU     =  $38;
  SCAN_RMENU     = $138;
  SCAN_LSHIFT    =  $2A;
  SCAN_RSHIFT    =  $36;
  SCAN_LWIN      = $15B;
  SCAN_RWIN      = $15C;
  FLAG_CONTROL   = 1;
  FLAG_MENU      = 2;
  FLAG_SHIFT     = 4;
  FLAG_WIN       = 8;

var
  modifiersCode: array[0..7] of Cardinal;
  g_configMode: Boolean;
  g_destroy     : UInt64 = 0;
  g_reloadConfig: UInt64 = 1;
  g_pasteText   : UInt64 = 2;
  g_callShortcut: UInt64 = 4;
  g_keydown     : UInt64 = 8;

  KeyInputs: array of TInput;
  KeyInputCount: Integer;

procedure gpcStrToClipboard(const sWText: WideString);
function gfnsStrFromClipboard: WideString;
procedure  KeybdInput(scanCode: Cardinal; vkCode: Word; Flags: DWord);

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
  kbdLayout:= GetKeyboardLayout(0);
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
          if wPrm = g_destroy then begin // Destroy時
            Break;
          end else if wPrm = g_reloadConfig then begin // Config reload時
            criticalSection.Acquire;
            Self.configMode:= g_configMode;
            Self.keyConfigList:= keyConfigList;
            criticalSection.Release;
            Continue;
          end else if wPrm = g_pasteText then begin // Paste Text時
            VaridateEvent(wPrm);
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

function gfnsStrFromClipboard: WideString;
//クリップボードの文字列を取得して返す
var
  li_Format: array[0..1] of Integer;
  li_Text: Integer;
  lh_Clip, lh_Data: THandle;
  lp_Clip, lp_Data: Pointer;
begin
  Result := '';
  li_Format[0] := CF_UNICODETEXT;
  li_Format[1] := CF_TEXT;
  li_Text := GetPriorityClipboardFormat(li_Format, 2);
  if (li_Text > 0) then begin
    if (OpenClipboard(GetActiveWindow)) then begin
      lh_Clip := GetClipboardData(li_Text);
      if (lh_Clip <> 0) then begin
        lh_Data := 0;
        if (GlobalFlags(lh_Clip) <> GMEM_INVALID_HANDLE) then begin
          try
            if (li_Text = CF_UNICODETEXT)  then begin
              //Unicode文字列を優先
              lh_Data := GlobalAlloc(GHND or GMEM_SHARE, GlobalSize(lh_Clip));
              lp_Clip := GlobalLock(lh_Clip);
              lp_Data := GlobalLock(lh_Data);
              lstrcpyW(lp_Data, lp_Clip);
              Result := WideString(PWideChar(lp_Data));
              GlobalUnlock(lh_Data);
              GlobalFree(lh_Data);
              GlobalUnlock(lh_Clip); //GlobalFreeはしてはいけない
            end else if (li_Text = CF_TEXT) then begin
              lh_Data := GlobalAlloc(GHND or GMEM_SHARE, GlobalSize(lh_Clip));
              lp_Clip := GlobalLock(lh_Clip);
              lp_Data := GlobalLock(lh_Data);
              lstrcpy(lp_Data, lp_Clip);
              Result := AnsiString(PAnsiChar(lp_Data));
              GlobalUnlock(lh_Data);
              GlobalFree(lh_Data);
              GlobalUnlock(lh_Clip); //GlobalFreeはしてはいけない
            end;
          finally
            if (lh_Data <> 0) then GlobalUnlock(lh_Data);
            CloseClipboard;
          end;
        end;
      end;
    end;
  end;
end;

procedure gpcStrToClipboard(const sWText: WideString);
//クリップボードへ文字列をセットする
//Unicode文字列としてセットすると同時に（Unicodeでない）プレーンテキストとしてもセットする
var
  li_WLen, li_Len: Integer;
  ls_Text: AnsiString;
  lh_Mem: THandle;
  lp_Data: Pointer;
begin
  li_WLen := Length(sWText) * 2 + 2;
  ls_Text := AnsiString(sWText);
  li_Len  := Length(ls_Text) + 1;
  if (OpenClipboard(GetActiveWindow)) then begin
    try
      EmptyClipboard;
      if (sWText <> '') then begin
        //CF_UNICODETEXT
        lh_Mem  := GlobalAlloc(GHND or GMEM_SHARE, li_WLen);
        lp_Data := GlobalLock(lh_Mem);
        lstrcpyW(lp_Data, PWideChar(sWText));
        GlobalUnlock(lh_Mem);
        SetClipboardData(CF_UNICODETEXT, lh_Mem);
        //CF_TEXT
        lh_Mem  := GlobalAlloc(GHND or GMEM_SHARE, li_Len);
        lp_Data := GlobalLock(lh_Mem);
        lstrcpy(lp_Data, PAnsiChar(ls_Text));
        GlobalUnlock(lh_Mem);
        SetClipboardData(CF_TEXT, lh_Mem);
      end;
    finally
      CloseClipboard;
    end;
  end;
end;

procedure  KeybdInput(scanCode: Cardinal; vkCode: Word; Flags: DWord);
begin
  Inc(KeyInputCount);
  SetLength(KeyInputs, KeyInputCount);
  KeyInputs[KeyInputCount - 1].Itype := INPUT_KEYBOARD;
  with KeyInputs[KeyInputCount - 1].ki do
  begin
    wVk:= vkCode;
    wScan:= scanCode;
    dwFlags:= Flags;
    time:= 0;
    dwExtraInfo:= 0;
  end;
end;

end.
