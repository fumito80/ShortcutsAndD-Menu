unit KeyHookThread;

interface

uses
  Classes, SysUtils, Windows, StrUtils, NPPlugin, Common;

type
  TArrayCardinal = array of Cardinal;

  TKeyHookTh = class(THookTh)
  protected
    singleKeyFlag: Boolean;
    function VaridateEvent(wPrm: UInt64): Boolean; override;
  public
  end;

implementation

function TKeyHookTh.VaridateEvent(wPrm: UInt64): Boolean;
var
  KeyState: TKeyboardState;
  scans: string;
  scanCode: Cardinal;
  modifierFlags, modifiersBoth, modifierFlags2: Byte;
  keyConfig: TKeyConfig;
  keyDownState, index, I: Integer;
  KeyInputs: array of TInput;
  KeyInputCount: Integer;
  newScans: TArrayCardinal;
  scriptMode: Boolean;
  procedure  KeybdInput(scanCode: Cardinal; Flags: DWord);
  begin
    Inc(KeyInputCount);
    SetLength(KeyInputs, KeyInputCount);
    KeyInputs[KeyInputCount - 1].Itype := INPUT_KEYBOARD;
    with KeyInputs[KeyInputCount - 1].ki do
    begin
      wVk:= MapVirtualKeyEx(scanCode, 3, kbdLayout);
      wScan:= scanCode;
      dwFlags:= Flags;
      if scanCode > $100 then begin
        dwFlags:= dwFlags or KEYEVENTF_EXTENDEDKEY;
        wScan:= wScan - $100;
        wVk:= MapVirtualKeyEx(wScan, 3, kbdLayout);
      end;
      time:= 0;
      dwExtraInfo:= 0;
    end;
  end;
  procedure ReleaseModifier(vkCode, scanCode: Cardinal; Flags: DWord);
  begin
    Inc(KeyInputCount);
    SetLength(KeyInputs, KeyInputCount);
    KeyInputs[KeyInputCount - 1].Itype:= INPUT_KEYBOARD;
    with KeyInputs[KeyInputCount - 1].ki do
    begin
      wVk:= vkCode;
      wScan:= scanCode;
      dwFlags:= KEYEVENTF_KEYUP or Flags;
      time:= 0;
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
      ReleaseModifier(VK_RSHIFT, SCAN_RSHIFT, Flags or KEYEVENTF_EXTENDEDKEY);
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
  procedure ClearAll;
  begin
    virtualOffModifires:= 0;
    virtualOffModifiresFlag:= False;
    modifierRelCount:= -1;
    lastTarget:= '';
    lastModified:= '';
    lastOrgModified:= '';
    singleKeyFlag:= False;
    AlterModified(virtualModifires, virtualScanCode, KEYEVENTF_KEYUP);
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
  keyDownState:= 0;
  scriptMode:= False;
  modifierFlags2:= 0;
  // Paste Text Mode
  if wPrm = g_pasteText then begin
    scanCode:= 86;
    scans:= '0086';
  end else if (wPrm and g_callShortcut) <> 0 then begin
    scriptMode:= True;
    scanCode:= HiWord(wPrm);
    modifierFlags2:= HiByte(LoWord(wPrm));
    scans:= IntToHex(modifierFlags2, 2) + IntToStr(scanCode);
    //Write2EventLog('FlexKbd', IntToStr(seq) + '> ' + IntToHex(scanCode, 4) + ': ' + scans + ': ' + IntToHex(MapVirtualKeyEx(scanCode, 1, kbdLayout), 4) + ': ' + IntToStr(keyDownState));
  end else begin
    scanCode:= HiWord(wPrm and $00000000FFFFFFFF);
    if (scanCode and $8000) <> 0 then begin
      keyDownState:= KEYEVENTF_KEYUP;
      scanCode:= scanCode and $7FFF;
    end;
    if (scanCode and $6000) <> 0 then begin
      scanCode:= scanCode and $1FFF; // リピート or Alt
    end;
    scans:= IntToHex(modifierFlags, 2) + IntToStr(scanCode);
  end;
  Write2EventLog('FlexKbd', IntToHex(scanCode, 4) + ': ' + scans + ': ' + IntToHex(MapVirtualKeyEx(scanCode, 1, kbdLayout), 4) + ': ' + IntToStr(keyDownState));

  // Exit1 --> Modifierキー単独のとき
  for I:= 0 to 7 do begin
    if scanCode = modifiersCode[I] then begin
      if (modifierRelCount > -1) and (keyDownState = KEYEVENTF_KEYUP) then begin
        if modifierRelCount = 0 then begin
          ClearAll;
        end else begin
          Dec(modifierRelCount);
        end;
      end;
      Exit;
    end;
  end;
  // Exit2 --> Modifierキーが押されていない or Shiftのみ ＆ ファンクションキーじゃないとき
  if (modifierFlags in [0, 4])
    and not(scancode in [$3B..$44, $56, $57, $58])
    and not((keyDownState = 0) and (virtualScanCode in [$3B..$44, $56, $57, $58]))
    and not(scriptMode) then
      Exit;

  if configMode and (keyDownState = 0) then begin
    Result:= True;
    browser.Invoke('pluginEvent', ['configKeyEvent', scans]);
  end else begin
    if (scans = lastOrgModified) and (keyDownState = 0) then begin
      // リピート対応
      scans:= lastTarget;
      modifierFlags:= StrToInt('$' + LeftBStr(lastModified, 2));
    end
    else if (scans <> lastModified) and ((virtualModifires > 0) or (virtualOffModifires > 0)) then begin
      // Modifier及びキー変更対応
      scans:= IntToHex(modifierFlags and (not virtualModifires) or virtualOffModifires, 2) + IntToStr(scanCode);
    end
    else if (scans = lastModified) {and (scanCode = virtualScanCode)} then begin
      // エコーバックは捨てる(循環参照対応)
      if keyDownState = KEYEVENTF_KEYUP then
        virtualScanCode:= 0;
        // 単独キーのとき --> 中止
        if singleKeyFlag then begin
          ClearAll;
        end;
      Exit;
    end;

    index:= keyConfigList.IndexOf(scans);
    if (index > -1) or scriptMode then begin
      Result:= True;
      if (index = -1) and scriptMode then begin
        keyConfig:= TKeyConfig.Create(
          'assignOrg',
          scans,
          '',
          modifierFlags2,
          scanCode);
      end else
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
            ReleaseModifier(VK_RSHIFT, SCAN_RSHIFT, KEYEVENTF_EXTENDEDKEY);
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
        if (modifierFlags = 0) or singleKeyFlag then
          singleKeyFlag:= True
        else
          singleKeyFlag:= False;
        //if (wPrm and g_callShortcut) <> 0 then begin
        //  ClearAll;
        //end;
        if (wPrm = g_pasteText) or scriptMode then begin
          SetLength(KeyInputs, 0);
          AlterModified(modifierFlags, scanCode, KEYEVENTF_KEYUP);
        end;
      end else if (keyDownState = 0) and (keyConfig.mode = 'simEvent') then begin
        browser.Invoke('pluginEvent', ['sendToDom', scans]);
      end else if (keyDownState = 0) and ((keyConfig.mode = 'bookmark') or (keyConfig.mode = 'command')) then begin
        //Write2EventLog('FlexKbd', 'command');
        SetLength(KeyInputs, 0);
        AlterModified(modifierFlags, scanCode, KEYEVENTF_KEYUP);
        browser.Invoke('pluginEvent', [keyConfig.mode, scans]);
      end else if keyConfig.mode = 'through' then begin
        Result:= False;
      end;
    end;
  end;
end;

end.
