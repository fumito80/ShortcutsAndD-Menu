class FailImmediate
  constructor: (@error) ->
  done: (callback) ->
    @
  fail: (callback) ->
    callback (new Error(@error))
    @

class Messenger
  done: (callback) ->
    @doneCallback = callback
    @
  fail: (callback) ->
    @failCallback = callback
    @
  sendMessage: (action, value1, value2, value3, value4) ->
    chrome.runtime.sendMessage
      action: action
      value1: value1
      value2: value2
      value3: value3
      value4: value4
    , (resp) =>
      if resp?.msg is "done"
        if callback = @doneCallback
          setTimeout((-> callback(resp.data || resp.msg)), 0)
      else
        if callback = @failCallback
          setTimeout((-> callback resp.msg), 0)
    @

scd =
  batch: (commands) ->
    if commands instanceof Array
      (new Messenger()).sendMessage "batch", commands
    else
      new FailImmediate("Argument is not Array.")

  send: (transCode, sleepMSec) ->
    msec = 100
    if sleepMSec?
      if isNaN(msec = sleepMSec)
        return (new FailImmediate(sleepMSec + " is not a number."))
      else
        msec = Math.round(sleepMSec)
        return (new FailImmediate("Range of Sleep millisecond is up to 6000-0."))  if msec < 0 or msec > 6000
    (new Messenger()).sendMessage "callShortcut", transCode, msec

  keydown: (transCode, sleepMSec) ->
    msec = 100
    if sleepMSec?
      if isNaN(msec = sleepMSec)
        return (new FailImmediate(sleepMSec + " is not a number."))
      else
        msec = Math.round(sleepMSec)
        return (new FailImmediate("Range of Sleep millisecond is up to 6000-0."))  if msec < 0 or msec > 6000
    (new Messenger()).sendMessage "keydown", transCode, msec

  sleep: (sleepMSec) ->
    if sleepMSec?
      if isNaN(sleepMSec)
        return (new FailImmediate(sleepMSec + " is not a number."))
      else
        sleepMSec = Math.round(sleepMSec)
        return (new FailImmediate("Range of Sleep millisecond is up to 6000-0."))  if sleepMSec < 0 or sleepMSec > 6000
    else
      sleepMSec = 100
    (new Messenger()).sendMessage "sleep", sleepMSec

  setClipbd: (text) ->
    (new Messenger()).sendMessage "setClipboard", text

  getClipbd: ->
    (new Messenger()).sendMessage "getClipboard"
  
  showNotify: (title = "", message = "", icon = "none", newNotif = false) ->
    (new Messenger()).sendMessage "showNotification", title, message, icon, newNotif
  
  returnValue: {}
  cancel: ->
    @returnValue.cancel = true
  
  openUrl: (url, noActivate, findTitleOrUrl) ->
    if noActivate
      cid = (new Date).getTime()
    (new Messenger()).sendMessage "openUrl", url, noActivate, findTitleOrUrl, cid
    @returnValue.cid = cid
  
  clearCurrentTab: ->
    (new Messenger()).sendMessage "clearCurrentTab"
  
  getSelection: ->
    selection = ""
    if (elActive = document.activeElement)
      if elActive.nodeName in ["TEXTAREA", "INPUT"]
        selection = elActive.value.substring(elActive.selectionStart, elActive.selectionEnd)
      else
        if (range = window.getSelection()).type is "Range"
          selection = range.getRangeAt(0).toString()

  setData: (name, value) ->
    (new Messenger()).sendMessage "setData", name, value

  getData: (name) ->
    (new Messenger()).sendMessage "getData", name
