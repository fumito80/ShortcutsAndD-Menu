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
  
setConfigPlugin = (keyConfigSet) ->
  sendData = []
  if keyConfigSet
    keyConfigSet.forEach (item) ->
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
  switch action
    when "log"
      console.log value
    when "kbdEvent"
      sendMessage
        action: "kbdEvent"
        value: value
      #console.log value

setConfigPlugin fk.getConfig().keyConfigSet
