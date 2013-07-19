keyConfigSetView = null
commandsView = null
bookmarksView = null
commandOptionsView = null

PopupBaseView = Backbone.View.extend

  initialize: (options) ->
    keyConfigSetView.on "showPopup", @onShowPopup, @
  
  events:
    "submit form"        : "onSubmitForm"
    "click  .icon-remove": "onClickIconRemove"
  
  render: -> # Virtual
  
  onShowPopup: (name, model) ->
    unless name is @name
      return false
    @model = model
    shortcut = decodeKbdEvent model.get("new")
    @$(".shortcut").html _.map(shortcut.split(" + "), (s) -> "<span>#{s}</span>").join("+")
    @render()
    @$el.show().draggable
      cursor: "move"
      delay: 200
      cancel: "input,textarea,button,select,option,.bookmarkPanel"
      stop: => @onStopSort()
    @el.style.pixelLeft = Math.round((window.innerWidth  - @el.offsetWidth)  / 2)
    @el.style.pixelTop  = Math.round((window.innerHeight - @el.offsetHeight) / 2)
    @$(".caption").focus()
    $(".backscreen").show()
  
  onStopSort: -> # Virtual
  
  onClickIconRemove: ->
    @hidePopup()
  
  hidePopup: ->
    $(".backscreen").hide()
    @$el.hide()
  
  tmplHelp: _.template """
    <a href="helpview.html#<%=name%>" target="_blank" class="help" title="help">
      <i class="icon-question-sign" title="Help"></i>
    </a>
    """

commandsDisp =
  createTab:      ["tab", "Create new tab"]
  createTabBG:    ["tab", "Create new tab in background"]
  moveTabLeft:    ["tab", "Move current tab left"]
  moveTabRight:   ["tab", "Move current tab right"]
  moveTabFirst:   ["tab", "Move current tab to first position"]
  moveTabLast:    ["tab", "Move current tab to last position"]
  closeOtherTabs: ["tab", "Close other tabs"]
  closeTabsLeft:  ["tab", "Close tabs to the left"]
  closeTabsRight: ["tab", "Close tabs to the right"]
  duplicateTab:   ["tab", "Duplicate current tab"]
  #duplicateTabWin:["tab", "Duplicate current tab to new window"]
  pinTab:         ["tab", "Pin/Unpin current tab"]
  detachTab:      ["tab", "Detach current tab"]
  attachTab:      ["tab", "Attach current tab to the next window"]
  switchPrevWin:  ["win", "Switch to the previous window"]
  switchNextWin:  ["win", "Switch to the next window"]
  closeOtherWins: ["win", "Close other windows"]
  clearCache:     ["clr", "Clear the browser's cache"]
  #clearHistory:   ["clr", "Clear browsing history"]
  clearCookiesAll:["clr", "Clear the browser's cookies and site data"]
  clearCookies:   ["clr", "Clear all cookies for the current domain"]
  #clearHistoryS:  ["clr", "Delete specific browsing history", [], "Clr"]
  #clearCookies:   ["browsdata", "Delete cookies and other site and plug-in data"]
  pasteText:      ["custom", "Paste fixed text", [], "Clip"]
  #copyText:       ["clip", "Copy text with history", "Clip"]
  #showHistory:    ["clip", "Show copy history"     , "Clip"]
  insertCSS:      ["custom", "Inject CSS", [{value:"allFrames", caption:"All frames"}], "CSS"]
  execJS:         ["custom", "Inject script", [
    {value:"allFrames",  caption:"All frames"}
    {value:"useUtilObj", caption:"Use utility object"}
  ], "JS"]

catnames =
  tab: "Tab commands"
  win: "Window commands"
  clr: "Browsing data commands"
  clip: "Clipboard commands"
  custom: "Other"

class CommandOptionsView extends PopupBaseView
  name: "commandOptions"
  el: ".commandOptions"
  constructor: (options) ->
    super(options)
    commandsView.on "showPopup", @onShowPopup, @
  render: ->
    content$ = @$(".content").css("height", "auto")
    if (commandName = @command.name) is "clearHistoryS"
      content$.attr("rows", "1")
    else
      content$.attr("rows", "10")
    @$(".command").html commandsDisp[commandName][1]
    @$(".caption").val(@command.caption)
    content$.val(@command.content)
    commandOption = @$(".inputs").empty()
    commandsDisp[commandName][2].forEach (option) =>
      option.checked = ""
      if @command[option.value]
        option.checked = "checked"
      commandOption.append @tmplOptions option
    @$el.append @tmplHelp @
  onShowPopup: (name, model, options) ->
    @command = options
    unless super(name, model)
      return
    if @command.content
      @$(".content").focus()[0].setSelectionRange(0, 0)
    else
      @$(".caption").focus()
    startEdit()
  onSubmitForm: ->
    unless (content = @$(".content").val()) is ""
      options = {}
      $.each @$(".inputs input[type='checkbox']"), (i, option) =>
        options[option.value] = option.checked
        return
      unless caption = @$(".caption").val()
        caption = content.split("\n")[0]
      @model
        .set
          "command":
            _.extend
              name: @command.name
              caption: caption
              content: content
              options
          {silent: true}
        .trigger "change:command"
      @hidePopup()
    false
  hidePopup: ->
    endEdit()
    super()
  tmplOptions: _.template """
    <label>
      <input type="checkbox" value="<%=value%>" <%=checked%>> <%=caption%>
    </label><br>
    """

class CommandsView extends PopupBaseView
  name: "command"
  el: ".commands"
  
  render: ->
    target$ = @$(".commandRadios")
    target$.empty()
    categories = []
    for key of commandsDisp
      categories.push commandsDisp[key][0]
    categories = _.unique categories
    categories.forEach (cat) ->
      target$.append """<div class="cat#{cat}"><div class="catname">#{catnames[cat]}</div>"""
    for key of commandsDisp
      target$.find(".cat" + commandsDisp[key][0])
        .append @tmplItem
          key: key
          value: commandsDisp[key][1]
    @
  
  onShowPopup: (name, model, options) ->
    unless super(name, model)
      return
    @$(".radioCommand").val [options.name] if options
    @$el.append @tmplHelp @
  
  onSubmitForm: ->
    if command = @$(".radioCommand:checked").val()
      @hidePopup()
      if commandsDisp[command][2]
        @trigger "showPopup", "commandOptions", @model, name: command
      else
        @model
          .set({"command": name: command}, {silent: true})
          .trigger "change:command"
    false

  tmplItem: _.template """
    <div>
      <label>
        <input type="radio" name="radioCommand" class="radioCommand" value="<%=key%>">
        <%=value%>
      </label>
    </div>
    """

class BookmarkOptionsView extends PopupBaseView
  name: "bookmarkOptions"
  el:   ".bookmarkOptions"
  events: _.extend
    "click input[value='findtab']": "onClickFindTab"
    "change input[name='openmode']:radio": "onChangeOpenmode"
    PopupBaseView.prototype.events
  constructor: (options) ->
    super(options)
    bookmarksView.on "showPopup", @onShowPopup, @
  render: ->
    super()
    @$(".bookmark")
      .css("background-image", "-webkit-image-set(url(chrome://favicon/size/16@1x/#{@bookmark.url}) 1x)")
      .text @bookmark.title
    @$(".url").text @bookmark.url
    @$(".findStr").val @bookmark.findStr || @bookmark.url
    @$("input[value='#{(@bookmark.openmode || 'current')}']")[0].checked = true
    (elFindtab = @$("input[value='findtab']")[0]).checked = if (findtab = @bookmark.findtab) is undefined then true else findtab
    @onClickFindTab currentTarget: elFindtab
    @$el.append @tmplHelp @
  onShowPopup: (name, model, options) ->
    @bookmark = options
    unless super(name, model)
      return
    startEdit()
  onSubmitForm: ->
    options = {}
    $.each @$("form input[type='checkbox']"), (i, option) =>
      options[option.value] = option.checked
      return
    options.findtab = @$("input[value='findtab']").is(":checked")
    options.openmode = @$("input[name='openmode']:checked").attr("value")
    options.findStr = @$(".findStr").val()
    @model
      .set({"bookmark": _.extend @bookmark, options}, {silent: true})
      .trigger "change:bookmark"
    @hidePopup()
    false
  onChangeOpenmode: (event) ->
    openmode = @$("input[name='openmode']:checked").val()
    chkFindtab$ = @$("input[value='findtab']")
    if openmode is "findonly"
      chkFindtab$.attr("disabled", "disabled")[0].checked = true
    else
      chkFindtab$.removeAttr("disabled")
    @onClickFindTab currentTarget: checked: chkFindtab$[0].checked
  onClickFindTab: (event) ->
    if event.currentTarget.checked
      @$(".findStr").removeAttr("disabled")
    else
      @$(".findStr").attr("disabled", "disabled").blur()
  hidePopup: ->
    endEdit()
    super()

class BookmarksView extends PopupBaseView
  name: "bookmark"
  el: ".bookmarks"
  events: _.extend
    "click  a"           : "onClickBookmark"
    "click  .title"      : "onClickFolder"
    "click  .expand-icon": "onClickExpandIcon"
    "click  .expand"     : "onClickExpand"
    PopupBaseView.prototype.events
  
  constructor: (options) ->
    super(options)
    @elBookmark$ = @$(".result")
    ctx = document.getCSSCanvasContext('2d', 'triangle', 8, 5.5);
    ctx.fillStyle = '#000000'
    ctx.translate(.5, .5)
    ctx.beginPath()
    ctx.moveTo(0, 0)
    ctx.lineTo(0, 1)
    ctx.lineTo(3.5, 4.5)
    ctx.lineTo(7, 1)
    ctx.lineTo(7, 0)
    ctx.closePath()
    ctx.fill()
    ctx.stroke()
    @$(".result_outer").niceScroll
      cursorwidth: 12
      cursorborderradius: 6
      smoothscroll: true
      cursoropacitymin: .1
      cursoropacitymax: .6
  
  render: ->
    height = window.innerHeight - 60
    @$(".result_outer").height(height - 35)
    @$el.height(height)
    if @$(".result").children().length is 0
      @onSubmitForm()
    @
  
  onClickFolder: (event) ->
    visible = (target$ = $(event.currentTarget).parent()).hasClass("opened")
    if visible
      target$.removeClass("opened expanded")
    else
      target$.addClass("opened expanded")
    windowOnResize()
    event.stopPropagation()
  
  onClickExpandIcon: (event) ->
    expanded = (target$ = $(event.currentTarget).parent()).hasClass("expanded")
    if expanded
      target$.removeClass("expanded")
    else
      target$.addClass("expanded")
    windowOnResize()
    event.stopPropagation()
  
  onClickExpand: ->
    if @$(".expand").is(":checked")
      @$(".folder").addClass("opened expanded")
    else
      @$(".folder").removeClass("opened expanded")
    windowOnResize()
  
  onShowPopup: (name, model) ->
    unless super(name, model)
      return
    if (target = @$("input.query")).val()
      target.focus()
    @$(".result_outer").getNiceScroll().show()
  
  onSubmitForm: ->
    @$(".result").empty()
    query = @$("input.query").focus().val()
    if query
      @$(".expand")[0].checked = true
    state = if @$(".expand").is(":checked") then "opened expanded" else ""
    chrome.bookmarks.getTree (treeNode) =>
      treeNode.forEach (node) =>
        @digBookmarks node, @elBookmark$, query, 0, state
      @elBookmark$.append recent = $(@tmplFolder("title": "Recent", "state": state, "indent": 0))
      recent.find(".title").prepend """<img src="images/star.png">"""
      chrome.bookmarks.getRecent 50, (treeNode) =>
        treeNode.forEach (node) =>
          @digBookmarks node, recent, query, 1, state
    false
  
  digBookmarks: (node, parent, query, indent, state) ->
    if node.title
      node.state = state
      if node.children
        node.indent = indent
        parent.append newParent = $(@tmplFolder(node))
        parent = newParent
      else
        if !query || (node.title + " " + node.url).toUpperCase().indexOf(query.toUpperCase()) > -1
          node.indent = indent + 1
          parent.append $(@tmplLink(node))
    else
      indent--
    if node.children
      parent.parent().addClass("hasFolder")
      node.children.forEach (child) =>
        @digBookmarks child, parent, query, indent + 1, state
  
  hidePopup: ->
    @$(".result_outer").getNiceScroll().hide()
    super()
  
  onClickBookmark: (event) ->
    @hidePopup()
    target = $(event.currentTarget)
    @trigger "showPopup", "bookmarkOptions", @model,
      title: target.text()
      url:   target.attr("title")
      bmId:  target.attr("data-id")
    false
  
  onStopSort: ->
    @$(".result_outer").getNiceScroll().resize()
  
  tmplFolder: _.template """
    <div class="folder <%=state%>" style="text-indent:<%=indent%>em">
      <span class="expand-icon"></span><span class="title"><%=title%></span>
    </div>
    """

  tmplLink: _.template """
    <div class="link" style="text-indent:<%=indent%>em;">
      <a href="#" title="<%=url%>" data-id="<%=id%>" style="background-image:-webkit-image-set(url('chrome://favicon/size/16@1x/<%=url%>') 1x);"><%=title%></a>
    </div>
    """

class CtxMenuOptionsView extends PopupBaseView
  name: "ctxMenuOptions"
  el: ".ctxMenuOptions"
  events: _.extend
    "click .done,.delete": "onClickSubmit"
    PopupBaseView.prototype.events
  render: ->
    @ctxMenu = @model.get "ctxMenu"
    @$(".caption").val @ctxMenu?.caption || @options.desc
    @$el.append @tmplHelp @
    @$("input[value='#{(@ctxMenu?.contexts || 'page')}']")[0].checked = true
    if @ctxMenu
      @$(".delete").removeClass("disabled").removeAttr("disabled")
    else
      @$(".delete").addClass("disabled").attr("disabled", "disabled")
  onShowPopup: (name, model, @options) ->
    unless super(name, model)
      return
    startEdit()
  onSubmitForm: ->
    false
  onClickSubmit: (event) ->
    unless (caption = @$(".caption").val()) is ""
      menutype = @$("input[name='menutype']:checked").attr("value")
      that = this
      if /delete/.test event.currentTarget.className
        unless confirm "Are you sure you want to delete this Context Menu?"
          return false
        type = "delete"
        callback = ->
          that.model.unset("ctxMenu")
          that.hidePopup()
      else
        callback = ->
          that.model.set("ctxMenu", caption: caption, contexts: menutype)
          that.hidePopup()
        if @ctxMenu
          type = "update"
        else
          type = "create"
      chrome.runtime.sendMessage
        action: "aboutCtxMenu"
        type: type
        id: @model.id
        caption: caption
        contexts: menutype
        callback
    false
  hidePopup: ->
    endEdit()
    super()
