window.fk = {}

flexkbd = document.getElementById("flexkbd")

#sendMessageSync = (message) ->
#  dfd = $.Deferred();
#  chrome.tabs.query {active: true}, (tabs) ->
#    chrome.tabs.sendMessage tabs[0].id, message, (resp) ->
#      dfd.resolve(resp);
#  dfd.promise()

portOtoB = undefined
chrome.runtime.onConnect.addListener (port) ->
  if port.name is "OtoB"
    portOtoB = port
    portOtoB.onMessage.addListener (msg) ->
      msg.joke is "Knock knock"
    #
    portOtoB.onDisconnect.addListener ->
      portCtoB.onMessage.removeListener onMessageHandler

sendMessage = (message) ->
  chrome.tabs.query {active: true}, (tabs) ->
    chrome.tabs.sendMessage tabs[0].id, message

kickSHS = (shortcut) ->
  flexkbd.keyEvent shortcut

chrome.commands.getAll (commands) ->
  commands.forEach (command) ->
    if command.name is "_execute_browser_action"
      chrome.contextMenus.create
        title: "「%s」をページ内検索"
        type: "normal"
        contexts: ["selection"]
        onclick: kickSHS(command.shortcut)

keydown = ->
  flexkbd.keyEvent()

#chrome.tabs.getSelected(null, function(tab) {
#  chrome.tabs.executeScript(tab.id, {file: "DomKeyEvent.js"});
#});
chrome.contextMenus.create
  title: "「%s」をページ内検索"
  type: "normal"
  contexts: ["selection"]
  onclick: keydown

# オプションページ表示時切り替え
isActivated = false
chrome.tabs.onActivated.addListener (activeInfo) ->
  chrome.tabs.get activeInfo.tabId, (tab) ->
    if tab.url.indexOf(chrome.extension.getURL("")) is 0
      flexkbd.startConfigMode()
      isActivated = true
    else
      flexkbd.endConfigMode()
      if isActivated
        sendMessage
          action: "saveConfig"
      isActivated = false

fk.saveConfig = (saveData) ->
  localStorage.flexkbd = JSON.stringify saveData
  sendData = JSON.parse saveData.keyConfigSet
  flexkbd.setKeyConfig.apply null, saveData

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
