defaultSleep = 100
gCurrentTabId = null
userData = {}
undoData = {}
jsTransCodes = {}
flexkbd = document.getElementById("flexkbd")

notifIcons =
  "info" : "info.png"
  "warn" : "warn.png"
  "err"  : "err.png"
  "chk"  : "chk.png"
  "fav"  : "fav.png"
  "star" : "infostar.png"
  "clip" : "clip.png"
  "close": "close.png"
  "user" : "user.png"
  "users": "users.png"
  "help" : "help.png"
  "flag" : "flag.png"
  "none" : "none.png"
  "cancel"  : "cancel.png"
  "comment" : "comment.png"
  "comments": "comments.png"

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

modifierInits = ["c", "a", "s", "w"]
transKbdEvent = (value, kbdtype) ->
  keys = andy.getKeyCodes()[kbdtype].keys
  modifiers = parseInt(value.substring(0, 2), 16)
  keyCombo = []
  for i in [0...modifierInits.length]
    keyCombo.push modifierInits[i] if modifiers & Math.pow(2, i)
  scanCode = value.substring(2)
  keyIdenfiers = keys[scanCode]
  "[" + keyCombo.join("") + "]" + keyIdenfiers[0]

jsCtxData = ""
execCtxMenu = (info) ->
  jsCtxData = "scd.ctxData = '" + (info.selectionText || info.linkUrl || info.srcUrl || info.pageUrl || "").replace(/'/g, "\\'") + "';"
  for i in [0...andy.local.keyConfigSet.length]
    if (keyConfig = andy.local.keyConfigSet[i]).new is info.menuItemId
      execBatchMode keyConfig.new
      break

chrome.contextMenus.onClicked.addListener (info, tab) ->
  execCtxMenu info

execShortcut = (dfd, doneCallback, transCode, scCode, sleepMSec, execMode, batchIndex) ->
  if transCode
    #scCode = ""
    modifiersCode = 0
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
    kbdtype = andy.local.config.kbdtype
    keys = andy.getKeyCodes()[kbdtype].keys
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
  else if !scCode
    throw new Error "Command argument is not found."
    return

  unless execMode
    for i in [0...andy.local.keyConfigSet.length]
      if (item = andy.local.keyConfigSet[i]).new is scCode
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
        dfd.reject()
    ), 61000)
    try
      switch request.action
        when "callShortcut"
          execShortcut dfd, doneCallback, request.value1, null, request.value2
        when "keydown"
          execShortcut dfd, doneCallback, request.value1, null, request.value2, "keydown"
        when "sleep"
          setTimeout((->
            flexkbd.Sleep request.value1
            doneCallback dfd, 0
          ), 0)
        when "setData"
          setTimeout((->
            userData[request.value1] = request.value2
            doneCallback dfd, 0
          ), 0)
        when "getData"
          setTimeout((->
            sendResponse msg: "done", data: userData[request.value1] || null
            dfd.resolve()
          ), 0)
        when "getTabInfo"
          chrome.tabs.get request.value1, (tab) ->
            chrome.windows.get tab.windowId, {populate: true}, (win) ->
              tab.tabCount = win.tabs.length
              tab.focused = win.focused
              tab.windowState = win.state
              tab.windowType = win.type
              sendResponse msg: "done", data: tab
              dfd.resolve()
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
            sendResponse msg: result, data: text
            dfd.resolve()
          ), 0)
        when "showNotification"
          showNotification dfd, doneCallback, request.value1, request.value2, request.value3, request.value4
        when "openUrl"
          params = request.value1
          preOpenBookmark(null, params).done (tabId) ->
            if tabId && params.noActivate
              gCurrentTabId = tabId
              tabStateNotifier.callComplete params.commandId
            doneCallback dfd, 0
        when "clearActiveTab"
          setTimeout((->
            gCurrentTabId = null
            doneCallback dfd, 0
          ), 0)
        when "clientOnKeyDown"
          setTimeout((->
            if keynames = keyIdentifiers[andy.local.config.kbdtype][request.value1]
              if request.value2
                unless keyname = keynames[1]
                  return
                scCode = "04"
              else
                keyname = keynames[0]
                scCode = "00"
              for i in [0...keys.length]
                if keys[i] && (keyname is keys[i][0] || keyname is keys[i][1])
                  scanCode = i
                  break
              if scanCode
                execBatchMode(scCode + i)
            doneCallback dfd, 0
          ), 0)
    catch e
      setTimeout((->
        sendResponse msg: e.message
        dfd.resolve()
      ), 0)
      dfd.promise()
  true

jsUtilObj = """var e,t,scd;e=function(){function e(e){this.error=e}return e.prototype.done=function(e){return this},e.prototype.fail=function(e){return e(new Error(this.error)),this},e}(),t=function(){function e(){}return e.prototype.done=function(e){return this.doneCallback=e,this},e.prototype.fail=function(e){return this.failCallback=e,this},e.prototype.sendMessage=function(e,t,n,r,i){var s=this;return chrome.runtime.sendMessage({action:e,value1:t,value2:n,value3:r,value4:i},function(e){var t;if((e!=null?e.msg:void 0)==="done"){if(t=s.doneCallback)return setTimeout(function(){return t(e.data||e.msg)},0)}else if(t=s.failCallback)return setTimeout(function(){return t(e.msg)},0)}),this},e}(),scd={batch:function(n){return n instanceof Array?(new t).sendMessage("batch",n):new e("Argument is not Array.")},send:function(n,r){var i;i=100;if(r!=null){if(isNaN(i=r))return new e(r+" is not a number.");i=Math.round(r);if(i<0||i>6e3)return new e("Range of Sleep millisecond is up to 6000-0.")}return(new t).sendMessage("callShortcut",n,i)},keydown:function(n,r){var i;i=100;if(r!=null){if(isNaN(i=r))return new e(r+" is not a number.");i=Math.round(r);if(i<0||i>6e3)return new e("Range of Sleep millisecond is up to 6000-0.")}return(new t).sendMessage("keydown",n,i)},sleep:function(n){if(n!=null){if(isNaN(n))return new e(n+" is not a number.");n=Math.round(n);if(n<0||n>6e3)return new e("Range of Sleep millisecond is up to 6000-0.")}else n=100;return(new t).sendMessage("sleep",n)},setClipbd:function(e){return(new t).sendMessage("setClipboard",e)},getClipbd:function(){return(new t).sendMessage("getClipboard")},showNotify:function(e,n,r,i){return e==null&&(e=""),n==null&&(n=""),r==null&&(r="none"),i==null&&(i=!1),(new t).sendMessage("showNotification",e,n,r,i)},returnValue:{},cancel:function(){return this.returnValue.cancel=!0},openUrl:function(e,n,r,i){var s,o,u;return n&&(s=(new Date).getTime()),r&&(o=!0),u={url:e,noActivate:n,findStr:r,findtab:o,openmode:i,commandId:s},(new t).sendMessage("openUrl",u),this.returnValue.cid=s},clearCurrentTab:function(){return(new t).sendMessage("clearCurrentTab")},getSelection:function(){var e,t,n,r;n="";if(e=document.activeElement){if((r=e.nodeName)==="TEXTAREA"||r==="INPUT")return n=e.value.substring(e.selectionStart,e.selectionEnd);if((t=window.getSelection()).type==="Range")return n=t.getRangeAt(0).toString()}},setData:function(e,n){return(new t).sendMessage("setData",e,n)},getData:function(e){return(new t).sendMessage("getData",e)},tabId:{},getTabInfo:function(){return(new t).sendMessage("getTabInfo",this.tabId)}};"""

sendMessage = (message) ->
  chrome.tabs.query {active: true}, (tabs) ->
    chrome.tabs.sendMessage tabs[0].id, message

getActiveTab = (execJS) ->
  dfd = $.Deferred()
  #console.log(gCurrentTabId)
  if gCurrentTabId #&& execJS
    chrome.tabs.query {}, (tabs) ->
      for i in [0...tabs.length]
        if tabFound = (currentTab = tabs[i]).id is gCurrentTabId
          break
      if tabFound
        dfd.resolve currentTab, currentTab.windowId
      else
        chrome.windows.getCurrent null, (win) ->
          chrome.tabs.query {active: true, windowId: win.id}, (tabs) ->
            dfd.resolve tabs[0], win.id
  else
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
      unless /editable/.test(tab.url)
        flexkbd.StartConfigMode()
        optionsTabId = activeInfo.tabId
    else
      if optionsTabId
        chrome.tabs.sendMessage optionsTabId,
          action: "saveConfig"
        optionsTabId = null
      if andy.local.config.singleKey && !/^chrome|^about|^https:\/\/chrome.google.com/.test tab.url
        chrome.tabs.sendMessage tab.id, action: "askAlive", (resp) ->
          unless resp is "hello"
            chrome.tabs.executeScript tab.id,
              file: "kbdagent.js"
              allFrames: false
              runAt: "document_end"

chrome.windows.onFocusChanged.addListener (windowId) ->
  if optionsTabId
    chrome.tabs.sendMessage optionsTabId,
      action: "saveConfig"
    optionsTabId = null
  else
    getActiveTab().done (tab) ->
      if tab?.url.indexOf(chrome.extension.getURL("options.html")) is 0 && !/editable/.test(tab?.url)
        flexkbd.StartConfigMode()
        optionsTabId = tab.id

chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) ->
  if changeInfo.status is "complete"
    if tab.url.indexOf(chrome.extension.getURL("options.html")) is 0
      if /editable/.test(tab.url)
        flexkbd.EndConfigMode()
        optionsTabId = null
      else
        flexkbd.StartConfigMode()
        optionsTabId = tab.id
    else
      tabStateNotifier.callComplete tabId
      if andy.local.config.singleKey && !/^chrome|^about|^https:\/\/chrome.google.com/.test tab.url
        chrome.tabs.sendMessage tab.id, action: "askAlive", (resp) ->
          unless resp is "hello"
            chrome.tabs.executeScript tab.id,
              file: "kbdagent.js"
              allFrames: false
              runAt: "document_end"

execBatchMode = (scCode) ->
  gCurrentTabId = null
  doneCallback = (dfd, sleepMSec, batchIndex) ->
    flexkbd.Sleep sleepMSec if sleepMSec > 0
    dfd.resolve(batchIndex + 1)
  keyConfigs = []
  andy.local.keyConfigSet.forEach (keyConfig) ->
    if keyConfig.new is scCode || keyConfig.parentId is scCode
      keyConfigs.push keyConfig
  # execute
  (dfdBatchQueue = dfdKicker = $.Deferred()).promise()
  for i in [0...keyConfigs.length]
    dfdBatchQueue = dfdBatchQueue.then (batchIndex) ->
      dfd = $.Deferred()
      setTimeout((->
        if dfd.state() is "pending"
          dfd.reject()
          console.log "Command has been killed in a time-out."
      ), 61000)
      try
        keyConfig = keyConfigs[batchIndex]
        switch keyConfig.mode
          when "remap"
            execShortcut dfd, doneCallback, null, keyConfig.origin, defaultSleep, "keydown", batchIndex
          when "command"
            execCommand(keyConfig.new).done (results) ->
              if results
                for i in [0...results.length]
                  if commandId = results[i]?.cid
                    break
                  else if cancel = results[i]?.cancel
                    break
              if cancel
                #throw new Error "Command canceled"
                dfd.reject()
              else
                if commandId
                  tabStateNotifier.register commandId, ->
                    doneCallback dfd, 0, batchIndex
                else
                  doneCallback dfd, 0, batchIndex
          when "sleep"
            setTimeout((->
              flexkbd.Sleep ~~keyConfig.sleep
              doneCallback dfd, 0, batchIndex
            ), 0)
          when "comment", "through"
            setTimeout((->
              doneCallback dfd, 0, batchIndex
            ), 0)
          else
            execShortcut dfd, doneCallback, null, keyConfig.new, defaultSleep, keyConfig.mode, batchIndex
      catch e
        setTimeout((->
          dfd.reject()
          console.log e.message
        ), 0)
      dfd.promise()
  dfdKicker.resolve(0)

notifications = {}
notifications.state = "closed"

createNotification = (dfd, doneCallback, title, message, icon, newNotif) ->
  if newNotif
    id = "s" + (new Date).getTime()
  else
    id = chrome.runtime.id
  unless iconName = notifIcons[icon]
    iconName = notifIcons.none
  chrome.notifications.create id,
    type: "basic"
    iconUrl: "images/" + iconName
    title: title
    message: message
    eventTime: 60000
    ->
      notifications.state = "opened"
      dfd.resolve()
      #doneCallback dfd, 0

showNotification = (dfd, doneCallback, title, message, icon, newNotif) ->
  if notifications.state is "opened" && !newNotif
    chrome.notifications.clear chrome.runtime.id, ->
      createNotification(dfd, doneCallback, title, message, icon, newNotif)
  else
    createNotification(dfd, doneCallback, title, message, icon, newNotif)

openBookmark = (dfd, openmode = "last", url, noActivate = false) ->
  unless url
    setTimeout (-> dfd.resolve()), 0
    return
  switch openmode.toLowerCase()
    when "newtab", "left", "right", "first", "last"
      getActiveTab().done (tab, windowId) ->
        if openmode is "first"
          newIndex = 0
        else if openmode in ["last", "newtab"]
          newIndex = 1000
        else if openmode is "left"
          newIndex = Math.max 0, tab.index
        else if openmode is "right"
          newIndex = tab.index + 1
        chrome.tabs.create {url: url, index: newIndex, active: !noActivate}, (tab) -> dfd.resolve(tab.id)
    when "current"
      #chrome.tabs.query {active: true}, (tabs) ->
      getActiveTab().done (tab, windowId) ->
        tabStateNotifier.reset(tab.id)
        chrome.tabs.update tab.id, url: url, active: !noActivate, (tab) -> dfd.resolve(tab.id)
    when "newwin"
      chrome.windows.create url: url, focused: !noActivate, (win) -> dfd.resolve(win.tabs[0].id)
    when "incognito"
      chrome.windows.create url: url, focused: !noActivate, incognito: true, (win) -> dfd.resolve(win?.tabs[0].id)
    else #findonly
      setTimeout (-> dfd.resolve()), 0

preOpenBookmark = (keyEvent, params) ->
  dfd = $.Deferred()
  for i in [0...andy.local.keyConfigSet.length]
    item = andy.local.keyConfigSet[i]
    if item.new is keyEvent || params
      unless params
        params = item.bookmark
      {openmode, url, findtab, findStr, noActivate} = params
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
                if noActivate
                  dfd.resolve orderedTabs[i].id
                else
                  chrome.tabs.update orderedTabs[i].id, {active: true}, -> dfd.resolve()
                found = true
                break
            unless found
              openBookmark(dfd, openmode, url, noActivate)
      else
        openBookmark(dfd, openmode, url, noActivate)
      break
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

execJS = (dfd, tabId, code, allFrames) ->
  chrome.tabs.executeScript tabId,
    code: code
    allFrames: allFrames
    runAt: "document_end"
    (results) -> dfd.resolve(results)

execCommand = (keyEvent) ->
  dfd = $.Deferred()
  pos = 0
  andy.local.keyConfigSet.forEach (item) ->
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
          if item.command.coffee
            code = jsTransCodes[item.new]
          else
            code = item.command.content
          getActiveTab(true).done (tab) ->
            if item.command.useUtilObj
              code = jsUtilObj + jsCtxData + ";scd.tabId=#{tab.id};" + code + ";scd.returnValue"
            if item.command.jquery
              chrome.tabs.sendMessage tab.id, action: "askJQuery", (resp) ->
                if resp is "hello"
                  execJS dfd, tab.id, code, item.command.allFrames
                else
                  chrome.tabs.executeScript tab.id,
                    file: "lib/jquery.min.js"
                    allFrames: item.command.allFrames
                    (resp) ->
                      execJS dfd, tab.id, code, item.command.allFrames
            else
              execJS dfd, tab.id, code, item.command.allFrames
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
    kbdtype = andy.local.config.kbdtype
    keys = andy.getKeyCodes()[kbdtype].keys
    keyConfigSet.forEach (item) ->
      scanCode = ~~item.new.substring(2)
      if /^00|^04/.test(item.new) && !/^F\d|^Application/.test(keys[scanCode])
        null
      else if item.batch && item.new && item.mode isnt "through"
        sendData.push [item.new, item.origin, "batch"].join(";")
      else if !/^C/.test item.new
        sendData.push [item.new, item.origin, item.mode].join(";")
    flexkbd.SetKeyConfig sendData.join("|")

window.andy =
  local: null
  setLocal: ->
    dfd = $.Deferred()
    chrome.storage.local.get null, (items) =>
      @local = items
      unless @local.ctxMenuFolderSet
        @local.ctxMenuFolderSet = []
      if @local.config
        dfd.resolve()
      else
        chrome.i18n.getAcceptLanguages (langs) =>
          if /^ja/.test langs
            @local.config = {kbdtype: "JP", lang: "ja"}
          else
            @local.config = {kbdtype: "US", lang: "en"}
          $.Deferred().resolve()
    dfd.promise()
  ###
  setLocal: ->
    dfd = $.Deferred()
    setTimeout((=>
      items = {}
      unless items.config
        items.config = {kbdtype: "JP"}
      unless items.ctxMenuFolderSet
        items.ctxMenuFolderSet = []
      @local = items
      dfd.resolve()
    ), 0)
    dfd.promise()
  ###
  saveConfig: (saveData) ->
    chrome.storage.local.set saveData, =>
      @local = saveData
      setConfigPlugin @local.keyConfigSet
  updateCtxMenu: (id, ctxMenu, pause) ->
    ctxMenu.id = id
    if pause
      ctxMenu.type = "update pause"
    else
      ctxMenu.type = "update"
    registerCtxMenu $.Deferred(), [ctxMenu], 0
  remakeCtxMenu: (saveData) ->
    dfd = $.Deferred()
    chrome.storage.local.set saveData, =>
      @local = saveData
      createCtxMenus().done ->
        dfd.resolve()
    dfd.promise()
  getKeyCodes: ->
    US:
      keys: keysUS
      name: "US 104 Keyboard"
    JP:
      keys: keysJP
      name: "JP 109 Keyboard"
  getScHelp: ->
    scHelp
  getScHelpSect: ->
    scHelpSect
  startEdit: ->
    flexkbd.EndConfigMode()
    return
  endEdit: ->
    flexkbd.StartConfigMode()
    return
  getCtxMenus: ->
  getUndoData: (id) ->
    undoData[id]
  setUndoData: (id, data) ->
    undoData[id] = data
  changePK: (id, prev) ->
    if jsTransCodes[id] = jsTransCodes[prev]
      jsTransCodes[prev] = null
  coffee2JS: (id, coffee) ->
    try
      jsTransCodes[id] = CoffeeScript.compile coffee, bare: "on"
      success: true
    catch e
      jsTransCodes[id] = ""
      success: false, err: e.message

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
      #execCommand value
      execBatchMode value
    when "batch"
      execBatchMode value

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

registerCtxMenu = (dfd, ctxMenus, index) ->
  if ctxMenu = ctxMenus[index]
    {id, type, caption, contexts, parentId} = ctxMenus[index]
    if /pause/.test type
      ctxData = type: "normal", enabled: false
    else
      ctxData = type: "normal", enabled: true
    if caption
      ctxData.title = caption
      ctxData.contexts = [contexts]
    unless parentId is "route"
      ctxData.parentId = parentId
    if /create/.test type
      ctxData.id = id
      chrome.contextMenus.create ctxData, ->
        registerCtxMenu dfd, ctxMenus, index + 1
    else if /update/.test type
      chrome.contextMenus.update id, ctxData, ->
        registerCtxMenu dfd, ctxMenus, index + 1
  else
    dfd.resolve()

createCtxMenus = ->
  if keyConfigSet = andy.local.keyConfigSet
    ctxMenuFolderSet = andy.local.ctxMenuFolderSet
    dfdMain = $.Deferred()
    chrome.contextMenus.removeAll ->
      targetCtxMenus = []
      keyConfigSet.forEach (keyConfig) ->
        if (ctxMenu = keyConfig.ctxMenu)
          ctxMenu.id = keyConfig.new
          ctxMenu.order = ctxMenu.order || 999
          if keyConfig.mode is "through"
            ctxMenu.type = "create pause"
          else
            ctxMenu.type = "create"
          targetCtxMenus.push ctxMenu
      targetCtxMenus.sort (a, b) -> a.order - b.order
      ctxMenus = []
      targetCtxMenus.forEach (ctxMenu) ->
        unless ctxMenu.parentId is "route"
          existsFolder = false
          for i in [0...ctxMenus.length]
            if ctxMenus[i].id is ctxMenu.parentId
              existsFolder = true
              break
          unless existsFolder
            for i in [0...ctxMenuFolderSet.length]
              if ctxMenuFolderSet[i].id is ctxMenu.parentId
                folder = ctxMenuFolderSet[i]
                ctxMenus.push
                  id: folder.id
                  order: ctxMenu.order
                  parentId: "route"
                  type: "create"
                  caption: folder.title
                  contexts: folder.contexts
                break
        ctxMenus.push ctxMenu
      registerCtxMenu dfdMain, ctxMenus, 0
    dfdMain.promise()

$ ->
  andy.setLocal().done ->
    if keyConfigSet = andy.local.keyConfigSet
      setConfigPlugin keyConfigSet
      createCtxMenus()
      for i in [0...keyConfigSet.length]
        if (item = keyConfigSet[i]).mode is "command" && item.command.name is "execJS" && item.command.coffee
          andy.coffee2JS item.new, item.command.content
  
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
