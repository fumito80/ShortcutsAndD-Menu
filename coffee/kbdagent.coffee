window.scdReadyKbdAgent = true
unless window.scdReadyJQuery
  chrome.runtime.onMessage.addListener (req, sender, sendResponse) ->
    switch req.action
      when "askAlive"
        sendResponse "hello"
      when "askJQuery"
        if window.scdReadyJQuery
          sendResponse "hello"
        else
          sendResponse "no"
      # For Single-Key
      #when "askEditable"
      #  if el = document.activeElement
      #    #searchBox = window.navigator.searchBox
      #    #searchBox = window.navigator.searchBox || window.chrome.searchBox
      #    console.log el
      #    if (el.tagName in ["TEXTAREA", "INPUT", "SELECT"] || el.contentEditable && (el.contentEditable is "true" || el.contentEditable is "plaintext-only"))
      #      sendResponse "yes"
      #    else
      #      sendResponse "no"
      #  else
      #    sendResponse "no"
      else
        sendResponse "no"
document.addEventListener "keydown", ((event) ->
  if event.ctrlKey || event.altKey || event.metaKey || (/F\d/.test event.keyIdentifier)
    return
  if (event.target.tagName in ["TEXTAREA", "INPUT", "SELECT"] || event.target.contentEditable && (event.target.contentEditable is "true" || event.target.contentEditable is "plaintext-only"))
    return
  chrome.runtime.sendMessage
    action: "clientOnKeyDown"
    value1: event.keyIdentifier
    value2: event.shiftKey
    (resp) -> #console.log resp if resp?.msg isnt "done" && resp isnt "no"
), false
