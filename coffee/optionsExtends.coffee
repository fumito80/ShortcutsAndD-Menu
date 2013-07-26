headerView = null
keyConfigSetView = null
commandsView = null
bookmarksView = null
commandOptionsView = null
ctxMenuOptionsView = null
ctxMenuManagerView = null

PopupBaseView = Backbone.View.extend
  initialize: (options) ->
    keyConfigSetView.on "showPopup", @onShowPopup, @
  events:
    "submit form"        : "onSubmitForm"
    "click  .icon-remove": "onClickIconRemove"
  render: -> # Virtual
  onSubmitForm: -> # Virtual
  onShowPopup: (name, model, options) ->
    unless name is @name
      return false
    @options = options
    if @model = model
      shortcut = decodeKbdEvent model.get("new")
      @$(".shortcut").html _.map(shortcut.split(" + "), (s) -> "<span>#{s}</span>").join("+")
    @render()
    @$el.show().draggable
      cursor: "move"
      delay: 200
      cancel: "input,textarea,button,select,option,.bookmarkPanel,span.contexts,span.menuCaption,span.title"
      stop: => @onStopDrag()
    @el.style.pixelLeft = Math.round((window.innerWidth  - @el.offsetWidth)  / 2)
    @el.style.pixelTop  = Math.round((window.innerHeight - @el.offsetHeight) / 2)
    @$(".caption").focus()
    $(".backscreen").show()
  onStopDrag: -> # Virtual
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

class EditableBaseView extends PopupBaseView
  onShowPopup: (name, model, options) ->
    unless super(name, model, options)
      return false
    startEdit()
  hidePopup: ->
    endEdit()
    super()

class ExplorerBaseView extends PopupBaseView
  events: _.extend
    "click .expand-icon": "onClickExpandIcon"
    "click .expandAll"  : "onClickExpandAll"
    PopupBaseView.prototype.events
  constructor: (options) ->
    super(options)
    ctx = document.getCSSCanvasContext("2d", "triangle", 10, 6);
    ctx.translate(.5, .5)
    ctx.fillStyle = "#000000"
    ctx.beginPath()
    ctx.moveTo(8, 0)
    ctx.lineTo(8, .5)
    ctx.lineTo(8/2-.5, 8/2+.5)
    ctx.lineTo(0, .5)
    ctx.lineTo(0, 0)
    ctx.closePath()
    ctx.fill()
    ctx.stroke()
    @$(".result_outer").niceScroll
      cursorwidth: 12
      cursorborderradius: 6
      smoothscroll: true
      cursoropacitymin: .1
      cursoropacitymax: .6
    @elResult$ = @$(".result")
  onShowPopup: (name, model, options) ->
    unless super(name, model, options)
      return false
    @$(".result_outer").getNiceScroll().show()
  onStopDrag: ->
    @$(".result_outer").getNiceScroll().resize()
  hidePopup: ->
    @$(".result_outer").getNiceScroll().hide()
    super()
  onClickExpandAll: ->
    if @$(".expandAll").is(":checked")
      @$(".folder,.contexts").addClass("opened expanded")
    else
      @$(".folder,.contexts").removeClass("opened expanded")
    windowOnResize()

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

class CommandOptionsView extends EditableBaseView
  name: "commandOptions"
  el: ".commandOptions"
  constructor: (options) ->
    super(options)
    commandsView.on "showPopup", @onShowPopup, @
  render: ->
    content$ = @$(".content").css("height", "auto")
    if (commandName = @options.name) is "clearHistoryS"
      content$.attr("rows", "1")
    else
      content$.attr("rows", "10")
    @$(".command").html commandsDisp[commandName][1]
    @$(".caption").val(@options.caption)
    content$.val(@options.content)
    commandOption = @$(".inputs").empty()
    commandsDisp[commandName][2].forEach (option) =>
      option.checked = ""
      if @options[option.value]
        option.checked = "checked"
      commandOption.append @tmplOptions option
    @$el.append @tmplHelp @
  onShowPopup: (name, model, options) ->
    unless super(name, model, options)
      return
    if @options.content
      @$(".content").focus()[0].setSelectionRange(0, 0)
    else
      @$(".caption").focus()
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
              name: @options.name
              caption: caption
              content: content
              options
          {silent: true}
        .trigger "change:command"
      @hidePopup()
    false
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

class BookmarkOptionsView extends EditableBaseView
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
      .css("background-image", "-webkit-image-set(url(chrome://favicon/size/16@1x/#{@options.url}) 1x)")
      .text @options.title
    @$(".url").text @options.url
    @$(".findStr").val @options.findStr || @options.url
    @$("input[value='#{(@options.openmode || 'current')}']")[0].checked = true
    (elFindtab = @$("input[value='findtab']")[0]).checked = if (findtab = @options.findtab) is undefined then true else findtab
    @onClickFindTab currentTarget: elFindtab
    @$el.append @tmplHelp @
  onSubmitForm: ->
    options = {}
    $.each @$("form input[type='checkbox']"), (i, option) =>
      options[option.value] = option.checked
      return
    options.findtab = @$("input[value='findtab']").is(":checked")
    options.openmode = @$("input[name='openmode']:checked").attr("value")
    options.findStr = @$(".findStr").val()
    @model
      .set({"bookmark": _.extend @options, options}, {silent: true})
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

class BookmarksView extends ExplorerBaseView
  name: "bookmark"
  el: ".bookmarks"
  events: _.extend
    "click  a": "onClickBookmark"
    "click .title"      : "onClickFolder"
    "click .expand-icon": "onClickExpandIcon"
    ExplorerBaseView.prototype.events
  render: ->
    height = window.innerHeight - 60
    @$(".result_outer").height(height - 35)
    @$el.height(height)
    if @$(".result").children().length is 0
      @onSubmitForm()
    @
  onShowPopup: (name, model) ->
    unless super(name, model)
      return
    if (target = @$("input.query")).val()
      target.focus()
  onSubmitForm: ->
    @$(".result").empty()
    query = @$("input.query").focus().val()
    if query
      @$(".expandAll")[0].checked = true
    state = if @$(".expandAll").is(":checked") then "opened expanded" else ""
    chrome.bookmarks.getTree (treeNode) =>
      treeNode.forEach (node) =>
        @digBookmarks node, @elResult$, query, 0, state
      @elResult$.append recent = $(@tmplFolder("title": "Recent", "state": state, "indent": 0))
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
  onClickBookmark: (event) ->
    @hidePopup()
    target = $(event.currentTarget)
    @trigger "showPopup", "bookmarkOptions", @model,
      title: target.text()
      url:   target.attr("title")
      bmId:  target.attr("data-id")
    false
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

tmplCtxMenus =
  page:      ["Return the page URL", "icon-file-alt"]
  selection: ["Return the selection text", "icon-font"]
  editable:  ["Return the page URL or selection text", "icon-edit"]
  link:      ["Return the link URL", "icon-link"]
  image:     ["Return the image URL", "icon-picture"]
  all:       ["Return any of the above", "icon-asterisk"]

getUuid = ->
  S4 = ->
    (((1+Math.random())*0x10000)|0).toString(16).substring(1)
  [S4(), S4()].join("") + (new Date / 1000 | 0)

class CtxMenuOptionsView extends EditableBaseView
  name: "ctxMenuOptions"
  el: ".ctxMenuOptions"
  events: _.extend
    "click  .done,.delete": "onClickSubmit"
    "change .selectParent": "onChangeSelectParent"
    "click  .selectParent": "onClickSelectParent"
    "focus  .parentName"  : "onFocusParentName"
    "blur   .parentName"  : "onBlurParentName"
    PopupBaseView.prototype.events
  render: ->
    if @ctxMenu = @model.get "ctxMenu"
      unless @ctxMenu.parentId is "route"
        @ctxMenu.contexts = @collection.get(@ctxMenu.parentId).get "contexts"
    @$(".caption").val @ctxMenu?.caption || @options.desc
    @$el.append @tmplHelp @
    @$("input[value='#{((contexts = @ctxMenu?.contexts) || 'page')}']")[0].checked = true
    if @ctxMenu
      @$(".delete").addClass("orange").removeClass("disabled").removeAttr("disabled")
    else
      @$(".delete").removeClass("orange").addClass("disabled").attr("disabled", "disabled")
    lastParentId = (selectParent$ = @$(".selectParent")).val()
    ctxType = @$("input[name='ctxType']:checked").attr("value")
    selectParent$.html @tmplParentMenu
    #models = @collection.where contexts: ctxType
    @collection.models.forEach (model) ->
      selectParent$.append """<option value="#{model.id}">#{model.get("title")}</option>"""
    if parentId = @ctxMenu?.parentId
      selectParent$.val parentId
    else if selectParent$.find("option[value='#{lastParentId}']").length > 0  #lastParentId in container.parents
      selectParent$.val lastParentId
    else
      selectParent$.val "route"
    @$(".parentName").val("").hide()
  onChangeSelectParent: (event) ->
    if event.currentTarget.value isnt "new"
      @$(".parentName").hide()
    else
      @$(".parentName").show().focus()
  onClickSelectParent: (event) ->
    event.preventDefault()
  onFocusParentName: (event) ->
    @$(".selectParent").addClass "focus"
  onBlurParentName: ->
    @$(".selectParent").removeClass "focus"
  onSubmitForm: ->
    false
  onClickSubmit: (event) ->
    if (parentId = @$(".selectParent").val()) is "new"
      if (parentName = $.trim @$(".parentName").val()) is ""
        return false
    if (caption = $.trim @$(".caption").val()) is ""
      return false
    if /delete/.test event?.currentTarget.className
      unless confirm "Are you sure you want to delete this Context Menu?"
        return false
      @model.unset("ctxMenu")
    else
      ctxType = @$("input[name='ctxType']:checked").attr("value")
      if parentId is "route"
        @model.set("ctxMenu", caption: caption, contexts: ctxType, parentId: parentId, order: @ctxMenu?.order)
      else
        if parentId is "new"
          if model = @collection.findWhere(contexts: ctxType, title: parentName)
            parentId = model.id
        else
          parentName = @$(".selectParent option[value='#{parentId}']").text()
        unless @collection.findWhere(id: parentId, contexts: ctxType)
          @collection.add
            id: parentId = getUuid()
            contexts: ctxType
            title: parentName
        @model.set("ctxMenu", caption: caption, parentId: parentId, order: @ctxMenu?.order)
    @trigger "getCtxMenues", container = {}
    (_.difference @collection.pluck("id"), _.pluck(container.ctxMenus, "parentId")).forEach (id) =>
      @collection.remove @collection.get(id)
    (dfd = $.Deferred()).promise()
    @trigger "remakeCtxMenu", dfd: dfd
    dfd.done =>
      @hidePopup()
      #if @$("input[value='chkShowManager']").is(":checked")
      #  @trigger "showPopup", "ctxMenuManager", @model
    false
  tmplParentMenu: """
    <option value="route">None(Root)</option>
    <option value="new">Create under new parent menu...</option>
    """

CtxMenuFolder = Backbone.Model.extend {}
CtxMenuFolderSet = Backbone.Collection.extend model: CtxMenuFolder

class CtxMenuGetterView extends PopupBaseView
  el: ".ctxMenusGetter"
  events: _.extend
    "click .add": "onClickAdd"
    "click .cancel": "onClickCancel"
    PopupBaseView.prototype.events
  constructor: (options) ->
    super(options)
    @$el
      .css(top: 0, right: "30px")
      .draggable
        cursor: "move"
        delay: 200
        cancel: "input,textarea,button,select,option"
  render: (message) ->
    @$(".message").html @tmplMessage message
    @$el.show(200)
    @
  hidePopup: ->
    @$el.hide(200)
  onClickAdd: ->
    @$el.hide(200)
    @trigger "addCtxMenus"
  onClickCancel: ->
    @$el.hide(200)
    @trigger "addCtxMenus", true
  #tmplMessage: _.template """
  #  Add entries to the <span class="ctxmenu-icon"><i class="<%=icon%>"></i></span><strong><%=contexts%></strong> context menu <%=folder%><br>you can select the functions of the keyboard shortcut.
  #  """
  tmplMessage: _.template """
    Add entries to the context menu <span class="ctxmenu-icon"><i class="<%=icon%>"></i></span><strong><%=contextName%></strong><%=folder%>, <br>from the functions that you selected.
    """

class CtxMenuManagerView extends ExplorerBaseView
  name: "ctxMenuManager"
  el: ".ctxMenuManager"
  events: _.extend
    "mousedown span[tabindex='0']": "onClickItem"
    "mousedown button,input,a": "onClickClickable"
    "mousedown .newmenu"  : "onClickNew"
    "mousedown .newfolder": "onClickNewFolder"
    "mousedown .rename"   : "onClickRen"
    "dblclick  .menuCaption,.title": "onClickRen"
    "keydown   .menuCaption,.title": "onKeydownCaption"
    "mousedown .remove"   : "onClickRemove"
    "submit .editCaption" : "doneEditCaption"
    "blur .editCaption input": "cancelEditCaption"
    "mousedown"           : "onClickBlank"
    "click .done"         : "onClickDone"
    ExplorerBaseView.prototype.events
  constructor: (options) ->
    super(options)
    @ctxMenuGetterView = new CtxMenuGetterView {}
    @ctxMenuGetterView.on "addCtxMenus", @onAddCtxMenus, @
    ctxMenuOptionsView.on "showPopup", @onShowPopup, @
    headerView.on "showPopup", @onShowPopup, @
    keyConfigSetView.on "addCtxMenu", @onAddCtxMenu, @
    ctx = document.getCSSCanvasContext("2d", "empty", 18, 18);
    ctx.strokeStyle = "#CC0000"
    ctx.lineWidth = "2"
    ctx.lineCap = "round"
    ctx.beginPath()
    ctx.moveTo 1, 1
    ctx.lineTo 17, 17
    ctx.moveTo 1, 17
    ctx.lineTo 17, 1
    ctx.stroke()
    ctx = document.getCSSCanvasContext("2d", "updown", 26, 24);
    ctx.fillStyle = "rgb(122, 122, 160)"
    ctx.lineWidth = "2"
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    ctx.strokeStyle = "#333333"
    for i in [0..1]
      ctx.beginPath()
      ctx.moveTo 1, 5
      ctx.lineTo 5, 1
      ctx.lineTo 9, 5
      ctx.moveTo 5, 1
      ctx.lineTo 5, 9
      ctx.stroke()
      ctx.translate 18, 18
      ctx.rotate(180 * Math.PI / 180);
    @collection.comparator = (model) -> model.get "order"
  render: ->
    height = window.innerHeight - 60 #height
    @$(".result_outer").height(height - 35)
    @$el.height(height)
    @setContextMenu()
    @setSortable ".folders", ".title,.menuCaption", @onUpdateFolder
    @setSortable ".ctxMenus", ".menuCaption", @onUpdateMenu
    $.each @$(".editButtons button"), (i, el) =>
      @disableButton _.map(document.querySelectorAll(".editButtons button"), (el) -> el.className.match(/^(\w+)\s/)[1])
    @
  onShowPopup: (name, model, options) ->
    unless super(name, model, options)
      return false
    startEdit()
  hidePopup: ->
    endEdit()
    super()
  onSubmitForm: ->
    false
  setSortable: (selector, handle, fnDoneUpdate) ->
    @$(selector).sortable
      scroll: true
      handle: handle
      connectWith: selector
      placeholder: "ui-placeholder"
      delay: 200
      update: (event, ui) => fnDoneUpdate event, ui, @
      start: (event, ui) => @onStartSort event, ui
      stop: (event, ui)  => @onStopSort event, ui, @
  setFolderDroppable: (target$) ->
    that = this
    target$.droppable
      accept: ".ctxMenuItem.route"
      tolerance: "pointer"
      hoverClass: "drop-folder-hover"
      over: -> $(".folders .ui-placeholder").hide()
      out: -> $(".folders .ui-placeholder").show()
      drop: (event, ui) ->
        ctxMenu$ = $(@).find(".ctxMenus")
        ui.draggable.hide "fast", ->
          that.onUpdateMenu null, item: $(@).appendTo(ctxMenu$).removeClass("route").show().find("span[tabindex='0']").focus(), that
  onUpdateFolder: (event, ui, view) ->
    if ui && _.filter(ui.item.parent().find(".title"), (title) -> title.textContent is ui.item.prevInfo?.text).length > 1
      alert("A folder with the name '#{ui.item.prevInfo.text}' already exists.")
      folders$ = view.$(".folders." + ui.item.prevInfo.contexts)
      ref = folders$.children().eq(ui.item.prevInfo.order).get(0) || null
      folders$[0].insertBefore ui.item[0], ref
      return
    $.each view.$(".folders"), (i, folders) ->
      if (folders$ = $(folders)).find(".folder,.ctxMenuItem").length > 0
        folders$.parents(".contexts").addClass("hasFolder")
      else
        folders$.parents(".contexts").removeClass("hasFolder")
    ui.item.focus() if ui
  onUpdateMenu: (event, ui, view) ->
    $.each view.$(".ctxMenus"), (i, menuItem) ->
      if (menuItem$ = $(menuItem)).find(".ctxMenuItem,.dummy").length is 0
        menuItem$.parents(".folder").removeClass("hasFolder")
    if ui
      ui.item.parents(".folder").addClass("hasFolder")
      ui.item.focus()
  onGetCtxMenuContexts: (container) ->
    container.contexts = @collection.get(container.parentId).get "contexts"
  onClickDone: ->
    newCtxMenu = []
    $.each @$(".ctxMenuItem"), (i, el) =>
      menu$ = $(el)
      message = id: el.id
      message.caption = menu$.find(".menuCaption").text()
      message.order = i + 1
      message.parentId = menu$.parents(".folder").get(0)?.id || "route"
      contexts = menu$.parents(".folders")[0].className.match(/folders\s(\w+)/)[1]
      if message.parentId is "route"
        message.contexts = contexts
      else
        unless @collection.findWhere(id: message.parentId, contexts: contexts)
          @collection.add
            id: message.parentId
            contexts: contexts
            title: @$("#" + message.parentId + " .title").text()
      newCtxMenu.push message
    @trigger "setCtxMenus", newCtxMenu
    @trigger "getCtxMenues", container = {}
    (_.difference @collection.pluck("id"), _.pluck(container.ctxMenus, "parentId")).forEach (id) =>
      @collection.remove @collection.get(id)
    (dfd = $.Deferred()).promise()
    @trigger "remakeCtxMenu", dfd: dfd
    dfd.done =>
      @hidePopup()
    false
  onClickBlank: ->
    #@$(":focus").blur()
    #$.each @$(".editButtons button"), (i, el) =>
    #  @disableButton _.map(document.querySelectorAll(".editButtons button"), (el) -> el.className.match(/^(\w+)\s/)[1])
  onClickClickable: (event) ->
    event.stopPropagation()
    event.preventDefault()
  onClickNew: (event) ->
    unless /contexts|title/.test (target$ = $(document.activeElement)).get(0)?.className
      return
    @activeFolder = {}
    if target$.hasClass("contexts")
      @activeFolder.folder = ""
      contexts$ = target$
      @activeFolder.parentId = "route"
      @activeFolder.contexts = (className = target$.parent()[0].className).match(/droppable\s(\w+)/)[1]
      @activeFolder.selector = "." + className.replace(/\s/g, ".") + " .contexts"
    else
      @activeFolder.folder = " in the folder '<strong>#{target$.text()}</strong>'"
      contexts$ = target$.parents("div.contexts").find("span.contexts")
      @activeFolder.parentId = target$.parent()[0].id
      @activeFolder.selector = "#" + @activeFolder.parentId + " .title"
    @activeFolder.icon = contexts$.find("i")[0].className
    @activeFolder.contextName = contexts$.text()
    @ctxMenuGetterView.render @activeFolder
    entried = _.map(@$(".ctxMenuItem"), (el) -> el.id)
    @trigger "enterCtxMenuSelMode", entried
    @$(".result_outer").getNiceScroll().hide()
    @$el.hide()
    $(".backscreen").hide()
  onAddCtxMenu: (ctxMenu) ->
    @setContextMenuItem _.extend(ctxMenu, @activeFolder)
    @$("#" + ctxMenu.id).hide().show(300)
    @setSortable ".ctxMenus", ".menuCaption", @onUpdateMenu
    @$(".folders").sortable "refresh"
  onAddCtxMenus: (cancel) ->
    @trigger "leaveCtxMenuSelMode", cancel
    @$el.show()
    @$(".result_outer").getNiceScroll().show()
    $(".backscreen").show()
    @$(@activeFolder.selector).focus()
    if cancel
      return
    @trigger "triggerEventSelected"
    @onUpdateMenu null, null, @
    @onUpdateFolder null, null, @
    @$(@activeFolder.selector).focus()
  onClickNewFolder: (event) ->
    unless (target$ = $(document.activeElement)).hasClass("contexts")
      return
    folders$ = target$.parents(".contexts").find ".folders"
    (newFolder$ = $(@tmplFolder id: getUuid(), title: "").appendTo(folders$)).find(".title").focus()
    @setSortable ".ctxMenus", ".menuCaption", @onUpdateMenu
    @$(".folders").sortable "refresh"
    @setFolderDroppable newFolder$
    @enableButton ["rename", "remove", "newmenu"]
    @disableButton ["newfolder"]
    @onClickRen event
  onKeydownCaption: (event) ->
    if event.originalEvent.keyIdentifier is "F2"
      @onClickRen event
  onClickRen: (event) ->
    unless /title|menuCaption/.test (target$ = $(document.activeElement))[0].className
      return
    editer$ = target$.hide().parent().find(".editCaption input:first").show()
    editer$.val(target$.text()).focus()
    event.preventDefault()
  escapeAmp: (text) ->
    text.replace(/&&/g, "^ampersand^").replace(/&/g, "").replace /^ampersand^/g, ""
  doneEditCaption: (event) ->
    if value = $.trim (editer$ = $(event.currentTarget).find("> input")).val()
      if (folder$ = editer$.parent().parent()).hasClass "folder"
        notExists = true
        $.each folder$.parent().find(".title"), (i, title) ->
          if folder$[0] isnt title.parentNode && title.textContent is value
            $("#tiptip_content").text("Folder '#{value}' already exists.")
            editer$.tipTip()
            return notExists = false
        return false if !notExists
    else
      editer$.blur()
      return false
    editer$.hide().parents("div:first").find("> .title,> .menuCaption").show().text(value).focus()
    false
  cancelEditCaption: (event) ->
    unless (target$ = $(event.currentTarget).hide().parents("div:first").find(".title,.menuCaption").show()).text()
      target$.parents(".folder").remove()
  onClickRemove: (event) ->
    unless /title|menuCaption/.test (active$ = $(document.activeElement))[0].className
      return
    active$.parent().remove()
    @onUpdateMenu null, null, @
    @onUpdateFolder null, null, @
  enableButton: (buttonClasses) ->
    buttonClasses.forEach (className) ->
      @$("button." + className).removeClass("disabled").removeAttr("disabled")
  disableButton: (buttonClasses) ->
    buttonClasses.forEach (className) ->
      @$("button." + className).addClass("disabled").attr("disabled", "disabled")
  onClickItem: (event) ->
    switch event.currentTarget.className
      when "contexts"
        @enableButton ["newmenu", "newfolder"]
        @disableButton ["rename", "remove"]
      when "title"
        @enableButton ["rename", "remove", "newmenu"]
        @disableButton ["newfolder"]
      when "menuCaption"
        @enableButton ["rename", "remove"]
        @disableButton ["newmenu", "newfolder"]
    event.currentTarget.focus()
    event.preventDefault()
    event.stopPropagation()
  onHoverMoveItem: (event) ->
    #@$(event.currentTarget).find("> .updown").show()
  onHoverOffMoveItem: ->
    #@$(".updown").hide()
  onMouseoverDroppable: ->
    @$(".ctxMenus .ui-placeholder").hide()
  onStartSort: (event, ui) ->
    ui.item.find("span[tabindex='0']:first").focus()
    if /folder/.test ui.item[0].className
      ui.item.addClass("sorting").find(".ctxMenus").hide()
      ui.item.prevInfo =
        contexts: ui.item.parent()[0].className.match(/folders\s(\w+)/)[1]
        order: ui.item.parent().children().index(ui.item)
        text: ui.item.find(".title").text()
    #ui.find("> .updown").show()
  onStopSort: (event, ui, view) ->
    ui.item.find("span[tabindex='0']:first").focus()
    view.$(".folder").removeClass("sorting")
    view.$(".ctxMenus").show()
    #@$(".updown").hide()
  onClickExpandIcon: (event) ->
    @$(event.currentTarget).parents(".folder").focus()
    expanded = (target$ = $(event.currentTarget).parents(".contexts")).hasClass("expanded")
    if expanded
      target$.removeClass("expanded")
    else
      target$.addClass("expanded")
    windowOnResize()
    event.stopPropagation()
  setContextMenu: () ->
    @$(".result").empty()
    @trigger "getCtxMenues", container = {}
    ctxMenus = container.ctxMenus
    for key of tmplCtxMenus
      @elResult$.append context$ = $(@tmplContexts
        "contexts": key
        "dispname": key.substring(0, 1).toUpperCase() + key.substring(1)
        "icon": tmplCtxMenus[key][1]
        )
      that = this
      context$.find(".droppable").droppable
        accept: ".ctxMenuItem:not(.route)"
        tolerance: "pointer"
        hoverClass: "drop-hover"
        over: -> $(".ctxMenus .ui-placeholder").hide()
        out: -> $(".ctxMenus .ui-placeholder").show()
        drop: (event, ui) ->
          target$ = $(".folders." + this.className.match(/droppable\s(\w+)/)[1])
          ui.draggable.hide "fast", ->
            that.onUpdateMenu null, item: $(this).appendTo(target$).addClass("route").show().find("span[tabindex='0']").focus(), that
    ctxMenus.forEach (ctxMenu) =>
      @setContextMenuItem ctxMenu
    @onUpdateMenu null, null, @
    @onUpdateFolder null, null, @
  setContextMenuItem: (ctxMenu) ->
    if ctxMenu.parentId is "route"
      dest$ = @$(".contexts .folders." + ctxMenu.contexts)
      ctxMenu.route = " route"
    else
      ctxMenu.route = ""
      unless (dest$ = @$("#" + ctxMenu.parentId + " .ctxMenus")).length > 0
        folder = @collection.get ctxMenu.parentId
        @$(".contexts .folders." + folder.get("contexts")).append @tmplFolder id: folder.id, title: folder.get("title")
        dest$ = @$("#" + ctxMenu.parentId + " .ctxMenus")
        @setFolderDroppable @$("#" + ctxMenu.parentId)
    dest$.append @tmplMenuItem ctxMenu
  tmplContexts: _.template """
    <div class="contexts">
      <div class="droppable <%=contexts%>">
        <span class="contexts" tabindex="0"><i class="<%=icon%> contextIcon"></i><%=dispname%></span>
      </div>
      <div class="folders <%=contexts%>"></div>
    </div>
    """
  tmplFolder: _.template """
    <div class="folder hasFolder" id="<%=id%>">
      <span class="title" tabindex="0"><%=title%></span>
      <div class="updown"></div>
      <div class="emptyFolder"></div>
      <form class="editCaption"><input type="text"></form>
      <div class="ctxMenus"></div>
    </div>
    """
  tmplMenuItem: _.template """
    <div class="ctxMenuItem<%=route%>" id="<%=id%>">
      <span class="menuCaption" tabindex="0" title="<%=shortcut%>"><%=caption%></span>
      <div class="updown"></div>
      <form class="editCaption"><input type="text"></form>
    </div>
    """
