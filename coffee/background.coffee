window.fk = {}
flexkbd = document.getElementById("flexkbd")

sendMessage = (message) ->
  chrome.tabs.query {active: true}, (tabs) ->
    chrome.tabs.sendMessage tabs[0].id, message

#keydown = ->
#  flexkbd.KeyEvent()

#chrome.contextMenus.create
#  title: "「%s」をページ内検索"
#  type: "normal"
#  contexts: ["selection"]
#  onclick: keydown

# オプションページ表示時切り替え
optionTabId = null
chrome.tabs.onActivated.addListener (activeInfo) ->
  chrome.tabs.get activeInfo.tabId, (tab) ->
    if tab.url.indexOf(chrome.extension.getURL("")) is 0
      flexkbd.StartConfigMode()
      optionTabId = activeInfo.tabId
    else
      if optionTabId
        chrome.tabs.sendMessage optionTabId,
          action: "saveConfig"
        optionTabId = null

chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) ->
  if tab.url.indexOf(chrome.extension.getURL("")) is 0 && changeInfo.status = "complete"
    flexkbd.StartConfigMode()  

sendKeyEventToDom = (keyEvent, tabId) ->
  local = fk.getConfig()
  keys = fk.getKeyCodes()[local.config.kbdtype].keys
  modifiers = parseInt(keyEvent.substring(0, 2), 16)
  scanCode = keyEvent.substring(2)
  keyIdentifiers = keys[scanCode]
  if shift = (modifiers & 4) isnt 0
    keyIdentifier = keyIdentifiers[1] || keyIdentifiers[0]
  else
    keyIdentifier = keyIdentifiers[0]
  chrome.tabs.sendMessage tabId,
    action: "keyEvent"
    keyIdentifier: keyIdentifier
    ctrl:  (modifiers & 1) isnt 0
    alt:   (modifiers & 2) isnt 0
    shift: shift
    meta:  (modifiers & 8) isnt 0

preSendKeyEvent = (keyEvent) ->
  chrome.tabs.query {active: true}, (tabs) ->
    tabId = tabs[0].id
    chrome.tabs.sendMessage tabId, action: "askAlive", (resp) ->
      if resp is "hello"
        sendKeyEventToDom(keyEvent, tabId)
      else
        chrome.tabs.executeScript tabId,
          file: "kbdagent.js"
          allFrames: true
          (resp) ->
            sendKeyEventToDom(keyEvent, tabId)
  
setConfigPlugin = (keyConfigSet) ->
  sendData = []
  if keyConfigSet
    keyConfigSet.forEach (item) ->
      if (item.disShortcut)
        sendData.push item.disShortcut + ";" + item.newShortcut + ";" + item.option
    flexkbd.SetKeyConfig sendData.join("|")
  
fk.saveConfig = (saveData) ->
  localStorage.flexkbd = JSON.stringify saveData
  setConfigPlugin saveData.keyConfigSet

fk.getKeyCodes = ->
  JP:
    keys: keysJP
    name: "JP 109 Keyboard"
  US:
    keys: keysUS
    name: "US 104 Keyboard"

fk.getConfig = ->
  JSON.parse(localStorage.flexkbd || null) || config: {kbdtype: "JP"}

window.pluginEvent = (action, value) ->
  #console.log action + ": " + value
  switch action
    when "log"
      console.log value
    when "configKeyEvent"
      sendMessage
        action: "kbdEvent"
        value: value
    when "sendToDom"
      preSendKeyEvent value

setConfigPlugin fk.getConfig().keyConfigSet
