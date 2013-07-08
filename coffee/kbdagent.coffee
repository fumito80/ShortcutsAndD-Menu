
triggerKeyEvent = (keyIdentifier, ctrlKey, altKey, shiftKey, metaKey) ->
  opt =
    canBubble: true
    cancelable: false
    view: document.defaultView
    #keyIdentifier: keyIdentifier
    keyLocation: 0x00
    #ctrlKey: ctrlKey
    #altKey: altKey
    #shiftKey: shiftKey
    #metaKey: metaKey
    altGraphKey: false
  
  #kbdEvent = new KeyboardEvent "keydown", opt.canBubble, opt.cancelable, opt.view, keyIdentifier, opt.keyLocation, ctrlKey, altKey, shiftKey, metaKey, opt.altGraphKey
  kbdEvent = document.createEvent "KeyboardEvent"
  kbdEvent.initKeyboardEvent "keydown", opt.canBubble, opt.cancelable, opt.view, keyIdentifier, opt.keyLocation, ctrlKey, altKey, shiftKey, metaKey, opt.altGraphKey
  console.log kbdEvent
  
  document.dispatchEvent(kbdEvent)

tmplCopyHist = """
  <div class="frame">
  </div>
  """

showCopyHistory = (history) ->
  unless window is parent && window is window.top
    return

chrome.runtime.onMessage.addListener (req, sender, sendResponse) ->
  switch req.action
    when "askAlive"
      sendResponse "hello"
    when "keyEvent"
      #console.log req
      triggerKeyEvent req.keyIdentifier, req.ctrl, req.alt, req.shift, req.meta
    when "copyText"
      selection = ""
      if (range = window.getSelection())?.type is "Range"
        selection = range.getRangeAt(0).toString()
        sendResponse selection
    when "showCopyHistory"
      showCopyHistory req.history
  true