
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

chrome.runtime.onMessage.addListener (req, sender, sendResponse) ->
  switch req.action
    when "askAlive"
      sendResponse "hello"
    when "keyEvent"
      #console.log req
      triggerKeyEvent req.keyIdentifier, req.ctrl, req.alt, req.shift, req.meta
