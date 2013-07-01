window.fk = {}
flexkbd = document.getElementById("flexkbd")

sendMessage = (message) ->
  chrome.tabs.query {active: true}, (tabs) ->
    chrome.tabs.sendMessage tabs[0].id, message

###
triggerShortcutKey = ->
  #flexkbd.KeyEvent()

chrome.contextMenus.create
  title: "「%s」をページ内検索"
  type: "normal"
  contexts: ["selection"]
  onclick: triggerShortcutKey
###

getActiveTab = ->
  dfd = $.Deferred()
  chrome.windows.getCurrent null, (win) ->
    chrome.tabs.query {active: true, windowId: win.id}, (tabs) ->
      dfd.resolve tabs[0], win.id
  dfd.promise()

getTabs = (options) ->
  dfd = $.Deferred()
  chrome.windows.getCurrent null, (win) ->
    options.windowId = win.id
    chrome.tabs.query options, (tabs) ->
      dfd.resolve tabs
  dfd.promise()

# オプションページ表示時切り替え
optionsTabId = null
chrome.tabs.onActivated.addListener (activeInfo) ->
  chrome.tabs.get activeInfo.tabId, (tab) ->
    if tab.url.indexOf(chrome.extension.getURL("")) is 0
      flexkbd.StartConfigMode()
      optionsTabId = activeInfo.tabId
    else
      if optionsTabId
        chrome.tabs.sendMessage optionsTabId,
          action: "saveConfig"
        optionsTabId = null

chrome.windows.onFocusChanged.addListener (windowId) ->
  if optionsTabId
    chrome.tabs.sendMessage optionsTabId,
      action: "saveConfig"
    optionsTabId = null
  else
    getActiveTab().done (tab) ->
      if tab.url.indexOf(chrome.extension.getURL("")) is 0
        flexkbd.StartConfigMode()
        optionsTabId = tab.id

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

openBookmark = (keyEvent) ->
  local = fk.getConfig()
  local.keyConfigSet.forEach (item) ->
    #console.log keyEvent + ": " + key
    if item.proxy is keyEvent
      url = item.bookmark.url
      chrome.tabs.query {active: true}, (tabs) ->
        chrome.tabs.update tabs[0].id, url: url
      #chrome.tabs.create
      #  url: url

closeTabs = (fnWhere) ->
  getTabs({active: false, currentWindow: true, windowType: "normal"}, fnWhere)
    .done (tabs) ->
      tabIds = []
      tabs.forEach (tab) ->
        tabIds.push tab.id if fnWhere(tab)
      chrome.tabs.remove tabIds if tabIds.length > 0

execCommand = (keyEvent) ->
  local = fk.getConfig()
  pos = 0
  local.keyConfigSet.forEach (item) ->
    #console.log keyEvent + ": " + key
    if item.proxy is keyEvent
      switch command = item.command.name
        when "closeOtherTabs"
          closeTabs -> true
        when "closeTabsRight", "closeTabsLeft"
          getActiveTab().done (tab) ->
            pos = tab.index
            if command is "closeTabsRight"
              closeTabs (tab) -> tab.index > pos
            else
              closeTabs (tab) -> tab.index < pos
        when "moveTabRight", "moveTabLeft"
          getActiveTab().done (tab, windowId) ->
            newpos = tab.index
            if command is "moveTabRight"
              newpos = newpos + 1
            else
              newpos = newpos - 1
            chrome.tabs.move tab.id, {windowId: windowId, index: newpos} if newpos > -1
        when "moveTabFirst"
          getActiveTab().done (tab, windowId) ->
            chrome.tabs.move tab.id, {windowId: windowId, index: 0}
        when "moveTabLast"
          getActiveTab().done (tab, windowId) ->
            chrome.tabs.move tab.id, {windowId: windowId, index: 1000}
        when "detachTab"
          getActiveTab().done (tab, windowId) ->
            chrome.windows.create {tabId: tab.id, focused: true, type: "normal"}
        when "duplicateTab"
          getActiveTab().done (tab, windowId) ->
            chrome.tabs.duplicate tab.id
        when "duplicateTabWin"
          getActiveTab().done (tab, windowId) ->
            chrome.tabs.duplicate tab.id, (tab) ->
              chrome.windows.create {tabId: tab.id, focused: true, type: "normal"}
        when "pinTab"
          getActiveTab().done (tab, windowId) ->
            chrome.tabs.update tab.id, pinned: true
        when "unpinTab"
          getActiveTab().done (tab, windowId) ->
            chrome.tabs.update tab.id, pinned: false
        when "switchNextWin"
          chrome.windows.getAll null, (windows) ->
            for i in [0...windows.length]
              if windows[i].focused
                if i is windows.length - 1
                  chrome.windows.update windows[0].id, {focused: true}
                else
                  chrome.windows.update windows[i + 1].id, {focused: true}
                break
        when "switchPrevWin"
          chrome.windows.getAll null, (windows) ->
            for i in [0...windows.length]
              if windows[i].focused
                if i is 0
                  chrome.windows.update windows[windows.length - 1].id, {focused: true}
                else
                  chrome.windows.update windows[i - 1].id, {focused: true}
                break
        when "pasteText"
          setTimeout((->
            flexkbd.PasteText item.command.content
          ), 1)
      #  when "execJS"
      #  when "insertCSS"

setConfigPlugin = (keyConfigSet) ->
  sendData = []
  if keyConfigSet
    keyConfigSet.forEach (item) ->
      if (item.proxy)
        sendData.push [item.proxy, item.origin, item.mode].join(";")
        #if item.command?.name is "pasteText"
        #  sendData.push [item.proxy, item.origin, item.mode, item.command.content].join(";")
        #else
        #  sendData.push [item.proxy, item.origin, item.mode].join(";")
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

fk.getScHelp = ->
  scHelp

fk.getScHelpSect = ->
  scHelpSect

fk.getConfig = ->
  JSON.parse(localStorage.flexkbd || null) || config: {kbdtype: "JP"}

fk.startEditing = ->
  flexkbd.EndConfigMode()
fk.endEditing = ->
  flexkbd.StartConfigMode()

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
    when "bookmark"
      openBookmark value
    when "command"
      execCommand value

setConfigPlugin fk.getConfig().keyConfigSet

scHelp = {}
scHelpSect = {}
scHelpPageUrl = "https://support.google.com/chrome/answer/157179?hl="

scrapeHelp = (lang, sectInit, elTab) ->
  targets = $(elTab).find("tr:has(td:first-child:has(strong))")
  $.each targets, (i, elem) ->
  #Array.prototype.forEach.call targets[0], (el) ->
    content = elem.cells[1].textContent.replace /^\s+|\s$/g, ""
    Array.prototype.forEach.call elem.childNodes[1].getElementsByTagName("strong"), (strong) ->
      scKey = strong.textContent.toUpperCase().replace /\s/g, ""
      scKey = scKey.replace("PGUP", "PAGEUP").replace("PGDOWN", "PAGEDOWN").replace(/DEL$/, "DELETE").replace(/INS$/, "INSERT")
      unless scHelp[scKey]?[lang]
        unless scHelp[scKey]
          scHelp[scKey] = {}
        scHelp[scKey][lang] = []
      scHelp[scKey][lang].push sectInit + "^" + content

analyzeScHelpPage = (resp, lang) ->
  doc = $(resp)
  mainSection = doc.find("div.main-section")
  sectInit = ""
  #$.each mainSection.children, (i, el) ->
  Array.prototype.forEach.call mainSection[0].children, (el) ->
    switch el.tagName
      when "H3"
        switch el.textContent
          when "Tab and window shortcuts", "タブとウィンドウのショートカット"
            sectInit = "T"
          when "Google Chrome feature shortcuts", "Google Chrome 機能のショートカット"
            sectInit = "C"
          when "Address bar shortcuts", "アドレスバーのショートカット"
            sectInit = "A"
          when "Webpage shortcuts", "ウェブページのショートカット"
            sectInit = "W"
          when "Text shortcuts", "テキストのショートカット"
            sectInit = "Tx"
        scHelpSect[sectInit] = el.textContent
      when "TABLE"
        scrapeHelp lang, sectInit, el

xhr = new XMLHttpRequest()
forecast = (lang) ->
  xhr.onreadystatechange = ->
    if xhr.readyState is 4 && xhr.status is 200
      analyzeScHelpPage xhr.responseText, lang
      dfd.resolve()
  xhr.open "GET", scHelpPageUrl + lang, true
  xhr.send()
  (dfd = $.Deferred()).promise()

forecast("ja").done ->
  forecast "en"

#indexedDB = new db.IndexedDB
#  schema_name: "scremapper"
#  schema_version: 1
#  keyPath: "proxy"
