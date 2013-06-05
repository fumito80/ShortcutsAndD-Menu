kickSHS = (shortcut) ->
  flexkbd = document.getElementById("flexkbd")
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
  flexkbd = document.getElementById("flexkbd")
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
chrome.tabs.onActivated.addListener (activeInfo) ->
  chrome.tabs.get activeInfo.tabId, (tab) ->
    flexkbd = document.getElementById("flexkbd")
    if tab.url.indexOf(chrome.extension.getURL("")) is 0
      flexkbd.startConfigMode()
    else
      flexkbd.endConfigMode()

portOtoB = undefined
chrome.runtime.onConnect.addListener (port) ->
  if port.name is "OtoB"
    portOtoB = port
    portOtoB.onMessage.addListener (msg) ->
      msg.joke is "Knock knock"

    #
    portOtoB.onDisconnect.addListener ->
      portCtoB.onMessage.removeListener onMessageHandler

startConfigMode = ->
  flexkbd = document.getElementById("flexkbd")


#flexkbd.startConfigMode();
getKeyCodes = ->
  JP: keysJP
  US: keysUS

getConfig = ->
  JSON.parse(localStorage.flexkbd or null) or kbdtype: "JP"

#
#var sendMessageSync = function(message) {
#  var dfd = $.Deferred();
#  chrome.tabs.query({active: true}, function(tabs) {
#    return chrome.tabs.sendMessage(tabs[0].id, message, function(resp) {
#      return dfd.resolve(resp);
#    })
#  });
#  return dfd.promise();
#};
#
sendMessage = (message) ->
  chrome.tabs.query {active: true}, (tabs) ->
    chrome.tabs.sendMessage tabs[0].id, message

window.pluginEvent = (key, value) ->
  switch key
    when "log"
      console.log value
    when "kbdEvent"
      sendMessage
        key: "kbdEvent"
        value: value

#console.log(value);