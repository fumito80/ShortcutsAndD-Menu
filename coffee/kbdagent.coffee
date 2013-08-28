chrome.runtime.onMessage.addListener (req, sender, sendResponse) ->
  switch req.action
    when "askAlive"
      sendResponse "hello"
  true

document.addEventListener "keydown", ((event) ->
  if event.ctrlKey || event.altKey || event.metaKey || (/F\d/.test event.keyIdentifier)
    return
  if (event.target.tagName in ["TEXTAREA", "INPUT", "SELECT"] || event.target.contentEditable && (event.target.contentEditable is "true" || event.target.contentEditable is "plaintext-only"))
    return
  chrome.runtime.sendMessage
    action: "clientOnKeyDown"
    value1: event.keyIdentifier
    value2: event.shiftKey
    (resp) -> console.log resp unless resp?.msg is "done"
), false
