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
  sendMessage: (action, value1, value2, value3) ->
    chrome.runtime.sendMessage
      action: action
      value1: value1
      value2: value2
      value3: value3
    , (resp) =>
      if resp is "done"
        if callback = @doneCallback
          setTimeout((-> callback resp), 0)
      else
        if callback = @failCallback
          setTimeout((-> callback resp), 0)
    @

tsc =
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

  sleep: (sleepMSec) ->
    if sleepMSec?
      if isNaN(sleepMSec)
        return (new FailImmediate(sleepMSec + " is not a number."))
      else
        sleepMSec = Math.round(sleepMSec)
        return (new FailImmediate("Range of Sleep millisecond is up to 6000-0."))  if sleepMSec < 0 or sleepMSec > 6000
    else
      sleepMSec = 100
    chrome.runtime.sendMessage
      action: "sleep"
      msec: sleepMSec

  clipbd: (text) ->
    (new Messenger()).sendMessage "setClipboard", text
