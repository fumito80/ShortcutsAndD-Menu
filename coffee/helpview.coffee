mdToHtml = (md, iframe) ->
  iframe.setAttribute("style", "display:none;")
  document.body.setAttribute "style", "overflow:auto;margin:8px;"
  converter = new Showdown.converter()
  document.getElementById("content").innerHTML = converter.makeHtml(md)
  if hash = document.location.hash
    document.location = hash
  Array.prototype.forEach.call document.getElementsByTagName("pre"), (pre) ->
    pre.className = "prettyprint"
  prettyPrint()

getMD = (iframe) ->
  if md = iframe.contentDocument.querySelector("pre")?.textContent
    mdToHtml md, iframe
    true
  else
    false

iframe = document.getElementById "mdloader"
unless getMD iframe
  iframe.addEventListener "load", ->
    getMD @
