flexkbd = document.getElementById("flexkbd")

(dfdCommandQueue = $.Deferred()).resolve()

chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
  switch request.action
    when "callShortcut"
      if (transCode = request.value1) is ""
        srCode = ""
      else
        test = transCode.match(/\[(\w*)\](.+)/, "g")
        if (test)
          local = fk.getConfig()
          modifiersCode = 0
          scCode = ""
          if modifiers = RegExp.$1
            modifierChars = modifiers.toLowerCase().split("")
            if ("c" in modifierChars) then modifiersCode  = 1
            if ("a" in modifierChars) then modifiersCode += 2
            if ("s" in modifierChars) then modifiersCode += 4
            if ("w" in modifierChars) then modifiersCode += 8
          if keyIdentifier = RegExp.$2
            kbdtype = local.config.kbdtype
            keys = fk.getKeyCodes()[kbdtype].keys
            scanCode = -1
            for i in [0...keys.length]
              if keys[i] && (keyIdentifier is keys[i][0] || keyIdentifier is keys[i][1])
                scanCode = i
                break
            if scanCode is -1
              sendResponse "Key identifier code '" + keyIdentifier + "' is unregistered code."
              return
            else
              if modifiersCode is 0 && !(scanCode in [0x3B..0x44]) && !(scanCode in [0x57, 0x58])
                sendResponse "Modifier code is not included in '#{transCode}'."
                return
              else
                scCode = "0" + modifiersCode.toString(16) + scanCode
          else
            sendResponse "Key identifier code '" + transCode + "' is not found."
            return
        else
          sendResponse "Shortcut code '" + transCode + "' is invalid."
          return
      dfdCommandQueue = dfdCommandQueue.then ->
        dfd = $.Deferred()
        try
          if (preSleep = request.value3) > 0
            flexkbd.Sleep preSleep
          found = false
          for i in [0...local.keyConfigSet.length]
            if (item = local.keyConfigSet[i]).proxy is scCode
              found = true
              switch item.mode
                when "command"
                  execCommand(scCode).done ->
                    if (postSleep = request.value2) > 0
                      flexkbd.Sleep postSleep
                    dfd.resolve()
                    sendResponse "done"
                when "bookmark"
                  preOpenBookmark(scCode).done ->
                    if (postSleep = request.value2) > 0
                      flexkbd.Sleep postSleep
                    dfd.resolve()
                    sendResponse "done"
                when "sendToDom"
                  preSendKeyEvent(scCode).done ->
                    if (postSleep = request.value2) > 0
                      flexkbd.Sleep postSleep
                    dfd.resolve()
                    sendResponse "done"
                else
                  setTimeout((->
                    flexkbd.CallShortcut scCode
                    if (postSleep = request.value2) > 0
                      flexkbd.Sleep postSleep
                    dfd.resolve()
                    sendResponse "done"
                  ), 0)
              break
          unless found
            setTimeout((->
              flexkbd.CallShortcut scCode
              if (postSleep = request.value2) > 0
                flexkbd.Sleep postSleep
                dfd.resolve()
                sendResponse "done"
            ), 0)
        catch e
          sendResponse e.message
          dfd.resolve()
        dfd.promise()
    when "sleep"
      dfdCommandQueue = dfdCommandQueue.then ->
        dfd = $.Deferred()
        setTimeout((->
          flexkbd.Sleep request.msec
          dfd.resolve()
        ), 0)
        dfd.promise()
    when "setClipboard"
      dfdCommandQueue = dfdCommandQueue.then ->
        dfd = $.Deferred()
        setTimeout((->
          flexkbd.SetClipboard request.value1
          dfd.resolve()
          sendResponse "done"
        ), 0)
        dfd.promise()
  true

jsUitlObj = """
  var Messenger = function() {
    this.doneCallback = null;
    this.done = function(callback) {
      this.doneCallback = callback;
      return this;
    }
    this.failCallback = null;
    this.fail = function(callback) {
      this.failCallback = callback;
      return this;
    }
    this.sendMessage = function(action, value1, value2, value3) {
      var that = this;
      chrome.runtime.sendMessage({
        action: action,
        value1: value1,
        value2: value2,
        value3: value3
      }, function(resp) {
        if (resp === "done") {
          if (that.doneCallback) {
            that.doneCallback(resp);
          }
        } else {
          if (that.failCallback) {
            that.failCallback(resp);
          }
        }
      });
      return this;
    }
  }
  tsc = {
    send: function(transCode, postSleep, preSleep) {
      var postMsec = 100, preMsec = 0;
      if (postSleep != null) {
        if (Number.isNaN(postMsec = parseInt(postSleep, 10))) {
          alert(postSleep + " is not a number.");
          return;
        }
      }
      if (preSleep != null) {
        if (Number.isNaN(preMsec = parseInt(preSleep, 10))) {
          alert(preSleep + " is not a number.");
          return;
        }
      }
      return (new Messenger()).sendMessage("callShortcut", transCode, postMsec, preMsec);
    },
    sleep: function(sleepMSec) {
      var msec = 0;
      if (sleepMSec != null) {
        if (Number.isNaN(msec = parseInt(sleepMSec, 10))) {
          alert(sleepMSec + " is not a number.");
          return;
        }
      }
      if (msec !== 0) {
        chrome.runtime.sendMessage({
          action: "sleep",
          msec: sleepMSec
        });
      }
    },
    clipbd: function(text) {
      return (new Messenger()).sendMessage("setClipboard", text);
    }
  };
  """

sendMessage = (message) ->
  chrome.tabs.query {active: true}, (tabs) ->
    chrome.tabs.sendMessage tabs[0].id, message

getActiveTab = ->
  dfd = $.Deferred()
  chrome.windows.getCurrent null, (win) ->
    chrome.tabs.query {active: true, windowId: win.id}, (tabs) ->
      dfd.resolve tabs[0], win.id
  dfd.promise()

getWindowTabs = (options) ->
  dfd = $.Deferred()
  chrome.windows.getCurrent null, (win) ->
    options.windowId = win.id
    chrome.tabs.query options, (tabs) ->
      dfd.resolve tabs
  dfd.promise()

getAllTabs = ->
  dfd = $.Deferred()
  chrome.tabs.query {}, (tabs) ->
    dfd.resolve(tabs)
  dfd.promise()

getAllTabs2 = ->
  dfd = $.Deferred()
  chrome.windows.getAll {populate: true}, (windows) ->
    tabs = []
    windows.forEach (win) ->
      tabs = tabs.concat win.tabs
    dfd.resolve(tabs)
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
  dfd = $.Deferred()
  chrome.tabs.query {active: true}, (tabs) ->
    tabId = tabs[0].id
    chrome.tabs.sendMessage tabId, action: "askAlive", (resp) ->
      if resp is "hello"
        sendKeyEventToDom(keyEvent, tabId)
        dfd.resolve()
      else
        chrome.tabs.executeScript tabId,
          file: "kbdagent.js"
          allFrames: true
          (resp) ->
            sendKeyEventToDom(keyEvent, tabId)
            dfd.resolve()
  dfd.promise()

openBookmark = (dfd, openmode, url) ->
  switch openmode
    when "newtab"
      chrome.tabs.create {url: url}, -> dfd.resolve()
    when "current"
      chrome.tabs.query {active: true}, (tabs) ->
        chrome.tabs.update tabs[0].id, url: url, -> dfd.resolve()
    when "newwin"
      chrome.windows.create url: url, -> dfd.resolve()
    when "incognito"
      chrome.windows.create url: url, incognito: true, -> dfd.resolve()

preOpenBookmark = (keyEvent) ->
  dfd = $.Deferred()
  local = fk.getConfig()
  local.keyConfigSet.forEach (item) ->
    if item.proxy is keyEvent
      {openmode, url, findtab, findStr} = item.bookmark
      if findtab
        getActiveTab().done (activeTab) ->
          getAllTabs().done (tabs) ->
            currentPos = 0
            for i in [0...tabs.length]
              if tabs[i].id is activeTab.id
                currentPos = i
                break
            orderedTabs = []
            if 0 < currentPos < (tabs.length - 1)
              orderedTabs = tabs.slice(currentPos + 1).concat tabs.slice(0, currentPos + 1)
            else
              orderedTabs = tabs
            found = false
            for i in [0...orderedTabs.length]
              unless (orderedTabs[i].title + orderedTabs[i].url).indexOf(findStr) is -1
                chrome.tabs.update orderedTabs[i].id, {active: true}, -> dfd.resolve()
                found = true
                break
            unless found
              openBookmark(dfd, openmode, url)
      else
        openBookmark(dfd, openmode, url)
  dfd.promise()

closeTabs = (dfd, fnWhere) ->
  getWindowTabs({active: false, currentWindow: true, windowType: "normal"}, fnWhere)
    .done (tabs) ->
      tabIds = []
      tabs.forEach (tab) ->
        tabIds.push tab.id if fnWhere(tab)
      if tabIds.length > 0
        chrome.tabs.remove tabIds, -> dfd.resolve()

execCommand = (keyEvent) ->
  dfd = $.Deferred()
  local = fk.getConfig()
  pos = 0
  local.keyConfigSet.forEach (item) ->
    #console.log keyEvent + ": " + key
    if item.proxy is keyEvent
      switch command = item.command.name
        when "closeOtherTabs"
          closeTabs dfd, -> true
        when "closeTabsRight", "closeTabsLeft"
          getActiveTab().done (tab) ->
            pos = tab.index
            if command is "closeTabsRight"
              closeTabs dfd, (tab) -> tab.index > pos
            else
              closeTabs dfd, (tab) -> tab.index < pos
        when "moveTabRight", "moveTabLeft"
          getActiveTab().done (tab, windowId) ->
            newpos = tab.index
            if command is "moveTabRight"
              newpos = newpos + 1
            else
              newpos = newpos - 1
            if newpos > -1
              chrome.tabs.move tab.id, {windowId: windowId, index: newpos}, -> dfd.resolve()
        when "moveTabFirst"
          getActiveTab().done (tab, windowId) ->
            chrome.tabs.move tab.id, {windowId: windowId, index: 0}, -> dfd.resolve()
        when "moveTabLast"
          getActiveTab().done (tab, windowId) ->
            chrome.tabs.move tab.id, {windowId: windowId, index: 1000}, -> dfd.resolve()
        when "detachTab"
          getActiveTab().done (tab, windowId) ->
            chrome.windows.create {tabId: tab.id, focused: true, type: "normal"}, -> dfd.resolve()
        when "attachTab"
          getActiveTab().done (tab, windowId) ->
            chrome.windows.getAll {populate: true}, (windows) ->
              for i in [0...windows.length]
                for j in [0...windows[i].tabs.length]
                  if tab.id is windows[i].tabs[j].id
                    currentWindowId = i
                    break
              if newwin = windows[++currentWindowId]
                newWindowId = newwin.id
              else
                newWindowId = windows[0].id
              chrome.tabs.move tab.id, windowId: newWindowId, index: 1000, ->
                chrome.tabs.update tab.id, active: true, -> dfd.resolve()
        when "duplicateTab"
          getActiveTab().done (tab, windowId) ->
            chrome.tabs.duplicate tab.id, -> dfd.resolve()
        when "duplicateTabWin"
          getActiveTab().done (tab, windowId) ->
            chrome.tabs.duplicate tab.id, (tab) ->
              chrome.windows.create {tabId: tab.id, focused: true, type: "normal"}, -> dfd.resolve()
        when "pinTab"
          getActiveTab().done (tab, windowId) ->
            chrome.tabs.update tab.id, pinned: !tab.pinned, -> dfd.resolve()
        #when "unpinTab"
        #  getActiveTab().done (tab, windowId) ->
        #    chrome.tabs.update tab.id, pinned: false
        when "switchNextWin"
          chrome.windows.getAll null, (windows) ->
            for i in [0...windows.length]
              if windows[i].focused
                if i is windows.length - 1
                  chrome.windows.update windows[0].id, {focused: true}, -> dfd.resolve()
                else
                  chrome.windows.update windows[i + 1].id, {focused: true}, -> dfd.resolve()
                break
        when "switchPrevWin"
          chrome.windows.getAll null, (windows) ->
            for i in [0...windows.length]
              if windows[i].focused
                if i is 0
                  chrome.windows.update windows[windows.length - 1].id, {focused: true}, -> dfd.resolve()
                else
                  chrome.windows.update windows[i - 1].id, {focused: true}, -> dfd.resolve()
                break
        when "pasteText"
          setTimeout((->
            flexkbd.PasteText item.command.content
            dfd.resolve()
          ), 0)
        when "insertCSS"
          getActiveTab().done (tab) ->
            chrome.tabs.insertCSS tab.id,
              code: item.command.content
              allFrames: item.command.allFrames
              -> dfd.resolve()
        when "execJS"
          code = item.command.content
          if item.command.useUtilObj
            code = jsUitlObj + code
          getActiveTab().done (tab) ->
            chrome.tabs.executeScript tab.id,
              code: code
              allFrames: item.command.allFrames
              -> dfd.resolve()
  dfd.promise()

setConfigPlugin = (keyConfigSet) ->
  sendData = []
  if keyConfigSet
    keyConfigSet.forEach (item) ->
      if (item.proxy)
        sendData.push [item.proxy, item.origin, item.mode].join(";")
    flexkbd.SetKeyConfig sendData.join("|")

window.fk =
  saveConfig: (saveData) ->
    localStorage.flexkbd = JSON.stringify saveData
    setConfigPlugin saveData.keyConfigSet
  getKeyCodes: ->
    JP:
      keys: keysJP
      name: "JP 109 Keyboard"
    US:
      keys: keysUS
      name: "US 104 Keyboard"
  getScHelp: ->
    scHelp
  getScHelpSect: ->
    scHelpSect
  getConfig: ->
    JSON.parse(localStorage.flexkbd || null) || config: {kbdtype: "JP"}
  startEdit: ->
    flexkbd.EndConfigMode()
  endEdit: ->
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
      preOpenBookmark value
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
