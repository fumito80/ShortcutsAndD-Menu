copyHist = JSON.parse(localStorage.copyHistory || null) || []
frame = document.querySelector ".frame"
copyHist.forEach (item) ->
  frame.appendChild div = document.createElement("div")
  div.textContent = item
  div.addEventListener "click", (event) ->
    chrome.runtime.sendMessage
      action: "pasteText"
      value1: event.currentTarget.textContent
      (msg) ->
        window.close()
