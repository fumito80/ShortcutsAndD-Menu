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
    function VaridateEvent(wPrm: UInt64): Boolean; override;
  public
  end;

const
  MSG_MOUSE_LDOWN = WM_LBUTTONDOWN - $0200;
  MSG_MOUSE_RDOWN = WM_RBUTTONDOWN - $0200;
  MSG_MOUSE_MDOWN = WM_MBUTTONDOWN - $0200;
  MSG_MOUSE_WHEEL = WM_MOUSEWHEEL  - $0200;
  WM_WHEEL_UP   = $020B;
  WM_WHEEL_DOWN = $020D;

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
  //Write2EventLog('FlexKbd', IntToStr(seq) + '> ' + IntToHex(wPrm, 4) + ': ' + scans);
  // Exit 1
  if (modifierFlags = 0) then
    Exit;

  scans:= IntToHex(modifierFlags, 2) + IntToStr(wPrm);
  
  if configMode then begin
    Result:= True;
    browser.Invoke('pluginEvent', ['configKeyEvent', scans]);
  end else begin
    index:= keyConfigList.IndexOf(scans);
    if index > -1 then begin
      Result:= True;
      keyConfig:= TKeyConfig(keyConfigList.Objects[index]);
      if keyConfig.mode = 'assignOrg' then begin
        //modifierRelCount:= 0;
        modifiersBoth:= modifierFlags and keyConfig.modifierFlags;
        // CONTROL
        if (modifiersBoth and FLAG_CONTROL) <> 0 then begin
          ;
        end else begin
          if (keyConfig.modifierFlags and FLAG_CONTROL) <> 0 then begin
            AddScan(SCAN_LCONTROL);
            //if (virtualOffModifires and FLAG_CONTROL) = 0 then
            //  virtualModifires:= virtualModifires or FLAG_CONTROL;
          end
          else if ((modifierFlags and FLAG_CONTROL) <> 0) then begin
            ReleaseModifier(VK_RCONTROL, SCAN_RCONTROL, KEYEVENTF_EXTENDEDKEY);
            ReleaseModifier(VK_LCONTROL, SCAN_LCONTROL, 0);
            //Inc(modifierRelCount, 2);
            //if (virtualModifires and FLAG_CONTROL) = 0 then
            //  virtualOffModifires:= virtualOffModifires or FLAG_CONTROL;
          end;
        end;
        // ALT
        if (modifiersBoth and FLAG_MENU) <> 0 then begin
          ;
        end else begin
          if (keyConfig.modifierFlags and FLAG_MENU) <> 0 then begin
            AddScan(SCAN_LMENU);
            //if (virtualOffModifires and FLAG_MENU) = 0 then
            //  virtualModifires:= virtualModifires or FLAG_MENU;
          end
          else if ((modifierFlags and FLAG_MENU) <> 0) then begin
            ReleaseModifier(VK_RMENU, SCAN_RMENU, KEYEVENTF_EXTENDEDKEY);
            ReleaseModifier(VK_LMENU, SCAN_LMENU, 0);
            //Inc(modifierRelCount, 2);
            //if (virtualModifires and FLAG_MENU) = 0 then
            //  virtualOffModifires:= virtualOffModifires or FLAG_MENU;
          end;
        end;
        // SHIFT
        if (modifiersBoth and FLAG_SHIFT) <> 0 then begin
          ;
        end else begin
          if (keyConfig.modifierFlags and FLAG_SHIFT) <> 0 then begin
            AddScan(SCAN_LSHIFT);
            //if (virtualOffModifires and FLAG_SHIFT) = 0 then
            //  virtualModifires:= virtualModifires or FLAG_SHIFT;
          end
          else if ((modifierFlags and FLAG_SHIFT) <> 0) then begin
            ReleaseModifier(VK_RSHIFT, SCAN_RSHIFT, 0);
            ReleaseModifier(VK_LSHIFT, SCAN_LSHIFT, 0);
            //Inc(modifierRelCount, 2);
            //if (virtualModifires and FLAG_SHIFT) = 0 then
            //  virtualOffModifires:= virtualOffModifires or FLAG_SHIFT;
          end;
        end;
        // WIN
        if (modifiersBoth and FLAG_WIN) <> 0 then begin
          ;
        end else begin
          if (keyConfig.modifierFlags and FLAG_WIN) <> 0 then begin
            //Write2EventLog('FlexKbd', 'addwin');
            AddScan(SCAN_LWIN);
            //if (virtualOffModifires and FLAG_WIN) = 0 then
            //  virtualModifires:= virtualModifires or FLAG_WIN;
          end
          else if ((modifierFlags and FLAG_WIN) <> 0) then begin
            ReleaseModifier(VK_RWIN, SCAN_RWIN, KEYEVENTF_EXTENDEDKEY);
            ReleaseModifier(VK_LWIN, SCAN_LWIN, KEYEVENTF_EXTENDEDKEY);
            //Inc(modifierRelCount, 2);
            //if (virtualModifires and FLAG_WIN) = 0 then
            //  virtualOffModifires:= virtualOffModifires or FLAG_WIN;
          end;
        end;
        //if keyDownState = 0 then
        AddScan(keyConfig.scanCode);
        //for I:= 0 to Length(newScans) - 1 do begin
        //  KeybdInput(newScans[I], keyDownState);
        //end;
        MakeKeyInputs(newScans, 0);
        SendInput(KeyInputCount, KeyInputs[0], SizeOf(KeyInputs[0]));
        //lastOrgModified:= keyConfig.orgModified;
        //lastTarget:= scans;
        //lastModified:= keyConfig.origin;
        //virtualScanCode:= keyConfig.scanCode;
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

end.
