
flexkbd = document.getElementById("flexkbd")

tabStateNotifier =
  callbacks: {}
  completes: {}
  reset: (tabId) ->
    @completes[tabId] = false
  register: (tabId, callback) ->
    if @completes[tabId]
      callback()
    else
      @callbacks[tabId] = callback
  callComplete: (tabId) ->
    if callback = @callbacks[tabId]
      callback()
    else
      @completes[tabId] = true

execShortcut = (dfd, doneCallback, transCode, sleepMSec, execMode, batchIndex) ->
  if transCode
    scCode = ""
    modifiersCode = 0
    local = fk.getConfig()
    test = transCode.match(/\[(\w*?)\](.+)/)
    if (test)
      modifiers = RegExp.$1
      keyIdentifier = RegExp.$2
      modifierChars = modifiers.toLowerCase().split("")
      if ("c" in modifierChars) then modifiersCode  = 1
      if ("a" in modifierChars) then modifiersCode += 2
      if ("s" in modifierChars) then modifiersCode += 4
      if ("w" in modifierChars) then modifiersCode += 8
    else
      modifiersCode = 0
      keyIdentifier = transCode
    kbdtype = local.config.kbdtype
    keys = fk.getKeyCodes()[kbdtype].keys
    scanCode = -1
    for i in [0...keys.length]
      if keys[i] && (keyIdentifier is keys[i][0] || keyIdentifier is keys[i][1])
        scanCode = i
        break
    if scanCode is -1
      throw new Error "Key identifier code '" + keyIdentifier + "' is unregistered code."
    else
      if execMode isnt "keydown" && modifiersCode is 0 && !(scanCode in [0x3B..0x44]) && !(scanCode in [0x57, 0x58])
        throw new Error "Modifier code is not included in '#{transCode}'."
      else
        scCode = "0" + modifiersCode.toString(16) + scanCode
    
    unless execMode
      for i in [0...local.keyConfigSet.length]
        if (item = local.keyConfigSet[i]).new is scCode
          execMode = item.mode
          break
    switch execMode
      when "command"
        execCommand(scCode).done ->
          doneCallback dfd, sleepMSec, batchIndex
      when "bookmark"
        preOpenBookmark(scCode).done (tabId) ->
          if tabId
            tabStateNotifier.register tabId, ->
              doneCallback dfd, sleepMSec, batchIndex
          else
            doneCallback dfd, sleepMSec, batchIndex
      when "keydown"
        setTimeout((->
          flexkbd.CallShortcut scCode, 8
          doneCallback dfd, sleepMSec, batchIndex
        ), 0)
      else
        setTimeout((->
          flexkbd.CallShortcut scCode, 4
          doneCallback dfd, sleepMSec, batchIndex
        ), 0)
  else
    throw new Error "Command argument is not found."  

execBatch = (dfdCaller, request, sendResponse) ->
  doneCallback = (dfd, sleepMSec, batchIndex) ->
    dfd.resolve(batchIndex + 1)
  (dfdBatchQueue = dfdKicker = $.Deferred()).promise()
  commands = request.value1
  for i in [0...commands.length]
    dfdBatchQueue = dfdBatchQueue.then (batchIndex) ->
      dfd = $.Deferred()
      try
        if isNaN(command = commands[batchIndex])
          execShortcut dfd, doneCallback, command, 0, null, batchIndex
        else
          sleepMSec = Math.round command
          if (-1 < sleepMSec < 60000)
            setTimeout((->
              flexkbd.Sleep sleepMSec
              dfd.resolve(batchIndex + 1)
            ), 0)
          else
            throw new Error "Range of Sleep millisecond is up to 6000-0."
      catch e
        dfd.reject()
        sendResponse msg: e.message
        dfdCaller.resolve()
      dfd.promise()
  dfdBatchQueue = dfdBatchQueue.then ->
    sendResponse msg: "done"
    dfdCaller.resolve()
  dfdKicker.resolve(0)

dfdCommandQueue = $.Deferred().resolve()

chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
  doneCallback = (dfd, sleepMSec) ->
    flexkbd.Sleep sleepMSec if sleepMSec > 0
    sendResponse msg: "done"
    dfd.resolve()
  dfdCommandQueue = dfdCommandQueue.then ->
    dfd = $.Deferred()
    setTimeout((->
      if dfd.state() is "pending"
        sendResponse msg: "Command has been killed in a time-out."
        dfd.resolve()
    ), 60000)
    try
      switch request.action
        when "batch"
          execBatch dfd, request, sendResponse
        when "callShortcut"
          execShortcut dfd, doneCallback, request.value1, request.value2
        when "keydown"
          execShortcut dfd, doneCallback, request.value1, request.value2, "keydown"
        when "sleep"
          setTimeout((->
            flexkbd.Sleep request.value1
            doneCallback dfd, 0
          ), 0)
        when "setClipboard"
          setTimeout((->
            flexkbd.SetClipboard request.value1
            doneCallback dfd, 0
          ), 0)
        when "getClipboard"
          setTimeout((->
            try
              text = flexkbd.GetClipboard()
              result = "done"
            catch e
              text = ""
              result = e.message
            sendResponse msg: result, text: text
            dfd.resolve()
          ), 0)
    catch e
      sendResponse msg: e.message
      dfd.resolve()
    dfd.promise()
  true

jsUitlObj = """var e,t,tsc;e=function(){function e(e){this.error=e}return e.prototype.done=function(e){return this},e.prototype.fail=function(e){return e(new Error(this.error)),this},e}(),t=function(){function e(){}return e.prototype.done=function(e){return this.doneCallback=e,this},e.prototype.fail=function(e){return this.failCallback=e,this},e.prototype.sendMessage=function(e,t,n,r){var i=this;return chrome.runtime.sendMessage({action:e,value1:t,value2:n,value3:r},function(e){var t;if((e!=null?e.msg:void 0)==="done"){if(t=i.doneCallback)return setTimeout(function(){return t(e.text||e.msg)},0)}else if(t=i.failCallback)return setTimeout(function(){return t(e.msg)},0)}),this},e}(),tsc={batch:function(n){return n instanceof Array?(new t).sendMessage("batch",n):new e("Argument is not Array.")},send:function(n,r){var i;i=100;if(r!=null){if(isNaN(i=r))return new e(r+" is not a number.");i=Math.round(r);if(i<0||i>6e3)return new e("Range of Sleep millisecond is up to 6000-0.")}return(new t).sendMessage("callShortcut",n,i)},keydown:function(n,r){var i;i=100;if(r!=null){if(isNaN(i=r))return new e(r+" is not a number.");i=Math.round(r);if(i<0||i>6e3)return new e("Range of Sleep millisecond is up to 6000-0.")}return(new t).sendMessage("keydown",n,i)},sleep:function(n){if(n!=null){if(isNaN(n))return new e(n+" is not a number.");n=Math.round(n);if(n<0||n>6e3)return new e("Range of Sleep millisecond is up to 6000-0.")}else n=100;return(new t).sendMessage("sleep",n)},clipbd:function(e){return(new t).sendMessage("setClipboard",e)},getClipbd:function(){return(new t).sendMessage("getClipboard")}};"""

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
    if tab.url.indexOf(chrome.extension.getURL("options.html")) is 0
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
      if tab.url.indexOf(chrome.extension.getURL("options.html")) is 0
        flexkbd.StartConfigMode()
        optionsTabId = tab.id

chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) ->
  if changeInfo.status is "complete"
    if tab.url.indexOf(chrome.extension.getURL("options.html")) is 0
      flexkbd.StartConfigMode()
    else
      tabStateNotifier.callComplete tabId
  

notifications = {}
notifications.state = "closed"

chrome.notifications.onButtonClicked.addListener (notifId, index) ->
  if notifId is chrome.runtime.id
    copyHist = JSON.parse(localStorage.copyHistory || null) || []
    flexkbd.PasteText copyHist[index]
    chrome.notifications.clear chrome.runtime.id, ->
      notifications.state = "closed"
  
chrome.notifications.onClosed.addListener (notifId, byUser) ->
  if notifId is chrome.runtime.id
    notifications.state = "closed"

#notification = null
showNotification = ->
  copyHist = JSON.parse(localStorage.copyHistory || null) || []
  buttons = []
  copyHist.forEach (item) ->
    buttons.push title: item, message: "msg" if item
  if notifications.state in ["opened", "created"]
    chrome.notifications.clear chrome.runtime.id, ->
      chrome.notifications.create chrome.runtime.id,
        type: "list"
        iconUrl: "images/key_bindings.png"
        message: "Select text to paste"
        eventTime: 60000
        title: "Copy history"
        items: buttons  
        ->
          notifications.state = "opened"
  else
    chrome.notifications.create chrome.runtime.id,
      type: "list"
      iconUrl: "images/key_bindings.png"
      message: "Select text to paste"
      eventTime: 60000
      title: "Copy history"
      items: buttons
      ->
        notifications.state = "opened"

showCopyHistory = (dfd, tabId) ->
  #copyHist = JSON.parse(localStorage.copyHistory || null) || []  
  #chrome.tabs.sendMessage tabId,
  #  action: "showCopyHistory"
  #  history: copyHist
  showNotification()
  dfd.resolve()

setClipboardWithHistory = (dfd, tabId) ->
  setTimeout((->
    if dfd.state() is "pending"
      dfd.resolve()
  ), 200)
  chrome.tabs.sendMessage tabId, action: "copyText", (text) ->
    unless text is ""
      flexkbd.SetClipboard text
      copyHist = JSON.parse(localStorage.copyHistory || null) || []
      for i in [0...copyHist.length]
        if copyHist[i] is text
          copyHist.splice i, 1
          break
      copyHist.unshift text
      if copyHist.length > 20
        copyHist.pop()
      localStorage.copyHistory = JSON.stringify copyHist
      if notifications.state is "opened"
        showNotification()
    dfd.resolve()

openBookmark = (dfd, openmode, url) ->
  switch openmode
    when "newtab"
      chrome.tabs.create {url: url}, (tab) -> dfd.resolve(tab.id)
    when "current"
      chrome.tabs.query {active: true}, (tabs) ->
        tabStateNotifier.reset(tabs[0].id)
        chrome.tabs.update tabs[0].id, url: url, (tab) -> dfd.resolve(tab.id)
    when "newwin"
      chrome.windows.create url: url, (tab) -> dfd.resolve(tab.id)
    when "incognito"
      chrome.windows.create url: url, incognito: true, (tab) -> dfd.resolve(tab.id)
    else #findonly
      dfd.resolve()

preOpenBookmark = (keyEvent) ->
  dfd = $.Deferred()
  local = fk.getConfig()
  local.keyConfigSet.forEach (item) ->
    if item.new is keyEvent
      {openmode, url, findtab, findStr} = item.bookmark
      if findtab || openmode is "findonly"
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

removeCookie = (dfd, removeSpecs, index) ->
  if removeSpec = removeSpecs[index]
    chrome.cookies.remove {"url": removeSpec.url, "name": removeSpec.name}, ->
      removeCookie dfd, removeSpecs, index + 1
  else
    dfd.resolve()

deleteHistory = (dfd, deleteUrls, index) ->
  if url = deleteUrls[index]
    chrome.history.deleteUrl {url: url}, ->
      deleteHistory dfd, deleteUrls, index + 1
  else
    dfd.resolve()

closeWindow = (dfd, windows, index) ->
  if win = windows[index]
    if win.focused
      closeWindow dfd, windows, index + 1
    else
      chrome.windows.remove win.id, ->
        closeWindow dfd, windows, index + 1
  else
    dfd.resolve()

closeTabs = (dfd, fnWhere) ->
  getWindowTabs({active: false, currentWindow: true, windowType: "normal"}, fnWhere)
    .done (tabs) ->
      tabIds = []
      tabs.forEach (tab) ->
        tabIds.push tab.id if fnWhere(tab)
      if tabIds.length > 0
        chrome.tabs.remove tabIds, -> dfd.resolve()
      else
        dfd.resolve()

execCommand = (keyEvent) ->
  dfd = $.Deferred()
  local = fk.getConfig()
  pos = 0
  local.keyConfigSet.forEach (item) ->
    #console.log keyEvent + ": " + key
    if item.new is keyEvent
      switch command = item.command.name
        when "createTab"
          getActiveTab().done (tab, windowId) ->
            chrome.tabs.create windowId: windowId, index: tab.index + 1, (tab) ->
              tabStateNotifier.register tab.id, ->
                dfd.resolve()
        when "createTabBG"
          getActiveTab().done (tab, windowId) ->
            chrome.tabs.create windowId: windowId, index: tab.index + 1, active: false, (tab) ->
              tabStateNotifier.register tab.id, ->
                dfd.resolve()
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
            else
              dfd.resolve()
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
        when "closeOtherWins"
          chrome.windows.getAll null, (windows) ->
            closeWindow dfd, windows, 0
        when "pasteText"
          setTimeout((->
            flexkbd.PasteText item.command.content
            dfd.resolve()
          ), 0)
        when "copyText"
          getActiveTab().done (tab) ->
            chrome.tabs.sendMessage tab.id, action: "askAlive", (resp) ->
              if resp is "hello"
                setClipboardWithHistory dfd, tab.id
              else
                chrome.tabs.executeScript tab.id,
                  file: "kbdagent.js"
                  allFrames: true
                  runAt: "document_end"
                  (resp) -> setClipboardWithHistory dfd, tab.id
        when "showHistory"
          getActiveTab().done (tab) ->
            chrome.tabs.sendMessage tab.id, action: "askAlive", (resp) ->
              if resp is "hello"
                showCopyHistory dfd, tab.id
              else
                chrome.tabs.executeScript tab.id,
                  file: "kbdagent.js"
                  allFrames: true
                  runAt: "document_end"
                  (resp) -> showCopyHistory dfd, tab.id
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
              runAt: "document_end"
              -> dfd.resolve()
        when "clearHistory"
          chrome.browsingData.removeHistory {}, -> dfd.resolve()
        when "clearHistoryS"
          findStr = item.command.content
          chrome.history.search
            text: ""
            startTime: 0
            maxResults: 10000
            (histories) ->
              deleteUrls = []
              for i in [0...histories.length]
                history = histories[i]
                unless (history.title + history.url).indexOf(findStr) is -1
                  deleteUrls.push history.url
              if deleteUrls.length > 0
                deleteHistory dfd, deleteUrls, 0
        when "clearCookiesAll"
          chrome.browsingData.removeCookies {}, -> dfd.resolve()
        when "clearCookies"
          getActiveTab().done (tab) ->
            domain = tab.url.match(/:\/\/(.[^/:]+)/)[1]
            removeSpecs = []
            chrome.cookies.getAll {}, (cookies) ->
              cookies.forEach (cookie) ->
                unless ("." + domain).indexOf(cookie.domain) is -1
                  secure = if cookie.secure then "s" else ""
                  url = "http#{secure}://" + cookie.domain + cookie.path
                  removeSpecs.push {"url": url, "name": cookie.name}
              removeCookie dfd, removeSpecs, 0
        when "clearCache"
          chrome.browsingData.removeCache {}, -> dfd.resolve()
  dfd.promise()

setConfigPlugin = (keyConfigSet) ->
  sendData = []
  if keyConfigSet
    keyConfigSet.forEach (item) ->
      if (item.new)
        sendData.push [item.new, item.origin, item.mode].join(";")
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
      scKey = scKey.replace("PGUP", "PAGEUP").replace("PGDOWN", "PAGEDOWN").replace(/DEL$/, "DELETE").replace(/INS$/, "INSERT").replace("ホーム", "HOME").replace("バー", "")
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

$ ->
  getHelp = (lang) ->
    $.get(scHelpPageUrl + lang).done (responseText) ->
      analyzeScHelpPage responseText, lang
      dfd.resolve()
    (dfd = $.Deferred()).promise()
  
  getHelp("ja").done ->
    getHelp("en").done ->
      delete scHelp["-"]
      delete scHelp["+"]
      scHelp["CTRL+;"] = ja: ["W^ページ全体を拡大表示します。"]
      scHelp["CTRL+="] = en: ["W^Enlarges everything on the page."]
      scHelp["CTRL+-"] =
        en: ["W^Makes everything on the page smaller."]
        ja: ["W^ページ全体を縮小表示します。"]

#indexedDB = new db.IndexedDB
#  schema_name: "scremapper"
#  schema_version: 1
#  keyPath: "new"
