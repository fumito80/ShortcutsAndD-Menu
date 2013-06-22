unit KeyHookThread;

interface

uses
  Classes, SysUtils, Windows, StrUtils, NPPlugin, Common;

type
  TArrayCardinal = array of Cardinal;

  TKeyHookTh = class(THookTh)
  protected
    function VaridateEvent(wPrm: UInt64): Boolean; override;
  public
  end;

implementation

function TKeyHookTh.VaridateEvent(wPrm: UInt64): Boolean;
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
  //Write2EventLog('FlexKbd', IntToHex(scanCode, 8));
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
  //Write2EventLog('FlexKbd', IntToStr(seq) + '> ' + IntToHex(scanCode, 4) + ': ' + scans + ': ' + IntToHex(MapVirtualKeyEx(scanCode, 1, GetKeyboardLayout(0)), 4) + ': ' + IntToStr(keyDownState));

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
          //Write2EventLog('FlexKbd', 'end');
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
    //Write2EventLog('FlexKbd', scans + ': ' + lastTarget + ': ' + lastModified + ': ' + IntToStr(modifierFlags) + ': ' + IntToStr(virtualModifires) + ': ' + IntToStr(virtualOffModifires));
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
      //Write2EventLog('FlexKbd', 'Exit');
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
            //Write2EventLog('FlexKbd', 'addwin');
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

end.
