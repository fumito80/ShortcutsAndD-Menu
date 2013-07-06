unit MouseHookThread;

interface

uses
  Classes, SysUtils, Windows, Messages, NPPlugin, Common;

type
  LPMSLLHOOKSTRUCT = ^MSLLHOOKSTRUCT;
  tagMSLLHOOKSTRUCT = record
    pt: TPOINT;
    mouseData: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: NativeUInt;
  end;
  MSLLHOOKSTRUCT = tagMSLLHOOKSTRUCT;
  TMsllHookStruct = MSLLHOOKSTRUCT;
  PMsllHookStruct = LPMSLLHOOKSTRUCT;

  TMouseHookTh = class(THookTh)
  protected
    stateDownL, stateDownM, stateDownR: Boolean;
    function VaridateEvent(wPrm: UInt64): Boolean; override;
  public
  end;

const
  MSG_MOUSE_LDOWN = WM_LBUTTONDOWN - $0200;
  MSG_MOUSE_LUP   = WM_LBUTTONUP   - $0200;
  MSG_MOUSE_LDBL  = WM_LBUTTONDBLCLK - $200;
  MSG_MOUSE_RDOWN = WM_RBUTTONDOWN - $0200;
  MSG_MOUSE_RUP   = WM_RBUTTONUP   - $0200;
  MSG_MOUSE_RDBL  = WM_RBUTTONDBLCLK - $0200;
  MSG_MOUSE_MDOWN = WM_MBUTTONDOWN - $0200;
  MSG_MOUSE_MUP   = WM_MBUTTONUP   - $0200;
  MSG_MOUSE_MDBL  = WM_MBUTTONDBLCLK - $0200;
  MSG_MOUSE_WHEEL = WM_MOUSEWHEEL  - $0200;
  WM_WHEEL_UP    = $020B;
  WM_WHEEL_DOWN  = $020D;
  FLAG_LDOWN = 16;
  FLAG_RDOWN = 32;
  FLAG_MDOWN = 64;

implementation

function TMouseHookTh.VaridateEvent(wPrm: UInt64): Boolean;
var
  KeyState: TKeyboardState;
  scans: string;
  modifierFlags, modifiersBoth: Byte;
  keyConfig: TKeyConfig;
  index: Integer;
  KeyInputs: array of TInput;
  KeyInputCount: Integer;
  newScans: TArrayCardinal;
  stateButton: Int64;
  procedure  KeybdInput(scanCode: Cardinal; Flags: DWord);
  begin
    Inc(KeyInputCount);
    SetLength(KeyInputs, KeyInputCount);
    KeyInputs[KeyInputCount - 1].Itype := INPUT_KEYBOARD;
    with KeyInputs[KeyInputCount - 1].ki do
    begin
      wVk:= MapVirtualKeyEx(scanCode, 3, kbdLayout);
      wScan := scanCode;
      dwFlags := Flags;
      if scanCode > $100 then begin
        dwFlags := dwFlags or KEYEVENTF_EXTENDEDKEY;
        wScan:= wScan - $100;
        wVk:= MapVirtualKeyEx(wScan, 3, kbdLayout);
      end;
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
  procedure AddScan(scan: Cardinal);
  begin
    SetLength(newScans, Length(newScans) + 1);
    newScans[Length(newScans) - 1]:= scan;
  end;
begin
  Result:= False;
  GetKeyState(0);
  GetKeyboardState(KeyState);
  modifierFlags:= 0;
  modifierFlags:= modifierFlags or (Ord((KeyState[VK_CONTROL] and 128) <> 0) * FLAG_CONTROL);
  modifierFlags:= modifierFlags or (Ord((KeyState[VK_MENU]    and 128) <> 0) * FLAG_MENU);
  modifierFlags:= modifierFlags or (Ord((KeyState[VK_SHIFT]   and 128) <> 0) * FLAG_SHIFT);
  modifierFlags:= modifierFlags or (Ord(((KeyState[VK_LWIN]   and 128) <> 0) or ((KeyState[VK_RWIN] and 128) <> 0)) * FLAG_WIN);
  // Mouse events
  modifierFlags:= modifierFlags or (Ord(stateDownL) * FLAG_LDOWN);
  modifierFlags:= modifierFlags or (Ord(stateDownR) * FLAG_RDOWN);
  modifierFlags:= modifierFlags or (Ord(stateDownM) * FLAG_MDOWN);
  stateButton:= wPrm - $200;
  case stateButton of
    MSG_MOUSE_LDOWN: stateDownL:= True;
    MSG_MOUSE_RDOWN: stateDownR:= True;
    MSG_MOUSE_MDOWN: stateDownM:= True;
    MSG_MOUSE_LUP  : stateDownL:= False;
    MSG_MOUSE_RUP  : stateDownR:= False;
    MSG_MOUSE_MUP  : stateDownM:= False;
  end;
  // Exit 1
  if (modifierFlags = 0) or (stateButton in [MSG_MOUSE_LUP, MSG_MOUSE_RUP, MSG_MOUSE_MUP]) then
    Exit;
  // Exit 2
  if (modifierFlags = FLAG_LDOWN) and (wPrm = WM_LBUTTONDOWN) then begin
    stateDownL:= False;
    Exit;
  end;
  
  scans:= IntToHex(modifierFlags, 2) + IntToStr(wPrm);
  
  if configMode then begin
    Result:= True;
    browser.Invoke('pluginEvent', ['configKeyEvent', scans]);
  end else begin
    index:= keyConfigList.IndexOf(scans);
    if index > -1 then begin
      Result:= True;
      keyConfig:= TKeyConfig(keyConfigList.Objects[index]);
      if keyConfig.mode = 'remap' then begin
        modifiersBoth:= modifierFlags and keyConfig.modifierFlags;
        // CONTROL
        if (modifiersBoth and FLAG_CONTROL) <> 0 then begin
          ;
        end else begin
          if (keyConfig.modifierFlags and FLAG_CONTROL) <> 0 then begin
            AddScan(SCAN_LCONTROL);
          end
          else if ((modifierFlags and FLAG_CONTROL) <> 0) then begin
            ReleaseModifier(VK_RCONTROL, SCAN_RCONTROL, KEYEVENTF_EXTENDEDKEY);
            ReleaseModifier(VK_LCONTROL, SCAN_LCONTROL, 0);
          end;
        end;
        // ALT
        if (modifiersBoth and FLAG_MENU) <> 0 then begin
          ;
        end else begin
          if (keyConfig.modifierFlags and FLAG_MENU) <> 0 then begin
            AddScan(SCAN_LMENU);
          end
          else if ((modifierFlags and FLAG_MENU) <> 0) then begin
            ReleaseModifier(VK_RMENU, SCAN_RMENU, KEYEVENTF_EXTENDEDKEY);
            ReleaseModifier(VK_LMENU, SCAN_LMENU, 0);
          end;
        end;
        // SHIFT
        if (modifiersBoth and FLAG_SHIFT) <> 0 then begin
          ;
        end else begin
          if (keyConfig.modifierFlags and FLAG_SHIFT) <> 0 then begin
            AddScan(SCAN_LSHIFT);
          end
          else if ((modifierFlags and FLAG_SHIFT) <> 0) then begin
            ReleaseModifier(VK_RSHIFT, SCAN_RSHIFT, 0);
            ReleaseModifier(VK_LSHIFT, SCAN_LSHIFT, 0);
          end;
        end;
        // WIN
        if (modifiersBoth and FLAG_WIN) <> 0 then begin
          ;
        end else begin
          if (keyConfig.modifierFlags and FLAG_WIN) <> 0 then begin
            AddScan(SCAN_LWIN);
          end
          else if ((modifierFlags and FLAG_WIN) <> 0) then begin
            ReleaseModifier(VK_RWIN, SCAN_RWIN, KEYEVENTF_EXTENDEDKEY);
            ReleaseModifier(VK_LWIN, SCAN_LWIN, KEYEVENTF_EXTENDEDKEY);
          end;
        end;
        //if keyDownState = 0 then
        AddScan(keyConfig.scanCode);
        MakeKeyInputs(newScans, 0);
        SendInput(KeyInputCount, KeyInputs[0], SizeOf(KeyInputs[0]));
      end else if keyConfig.mode = 'simEvent' then begin
        browser.Invoke('pluginEvent', ['sendToDom', scans]);
      end else if (keyConfig.mode = 'bookmark') or (keyConfig.mode = 'command') then begin
        browser.Invoke('pluginEvent', [keyConfig.mode, scans]);
      end else if keyConfig.mode = 'through' then begin
        Result:= False;
      end;
    end;
  end;
end;

end.
