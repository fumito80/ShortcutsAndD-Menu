keyCodes = {}
keys = null

WebFontConfig =
  google: families: ['Noto+Sans::latin']

optionsDisp =
  assignOrg: "None"
  simEvent:  "Simurate key event"
  bookmark:  "Bookmark"
  disabled:  "Disabled"
  through:   "Through"

escape = (html) ->
  entity =
  "&": "&amp;"
  "<": "&lt;"
  ">": "&gt;"
  html.replace /[&<>]/g, (match) ->
    entity[match]
  
HeaderView = Backbone.View.extend

  scHelpUrl: "https://support.google.com/chrome/answer/157179?hl="
  
  # Backbone Buitin Events
  el: "div.header"
  
  events:
    "click button.addKeyConfig": "onClickAddKeyConfig"
    "change select.kbdtype"    : "onChangeSelKbd"
  
  initialize: (options) ->
    # キーボード設定
    keys = keyCodes[kbdtype = @model.get("kbdtype")].keys
    selectKbd$ = @$("select.kbdtype")
    $.each keyCodes, (key, item) =>
      selectKbd$.append """<option value="#{key}">#{item.name}</option>"""
    selectKbd$.val kbdtype
    @setScHelp kbdtype
  
  # DOM Events
  onClickAddKeyConfig: (event) ->
    @trigger "clickAddKeyConfig", (event)

  onChangeSelKbd: (event) ->
    @trigger "changeSelKbd", (event)
    @setScHelp @$("select.kbdtype").val()
  
  # Object method
  setScHelp: (kbdtype) ->
    if kbdtype is "JP"
      @$(".scHelp")
        .text("ショートカットキー一覧")
        .attr "href", @scHelpUrl + "ja"
    else
      @$(".scHelp")
        .text("Keyboard shortcuts")
        .attr "href", @scHelpUrl + "en"
  
Config = Backbone.Model.extend({})

KeyConfig = Backbone.Model.extend
  idAttribute: "proxy"
  defaults:
    mode: "assignOrg"

KeyConfigSet = Backbone.Collection.extend(model: KeyConfig)

KeyConfigView = Backbone.View.extend

  kbdtype: null
  optionKeys: []
  
  # Backbone Buitin Events
  events:
    "click .origin,.proxy"  : "onClickInput"
    "click div.mode"        : "onClickMode"
    "click i.icon-pencil"   : "onClickEditDesc"
    "click .selectMode div" : "onChangeMode"
    "click i.icon-remove"   : "onClickRemove"
    "submit .memo"          : "onSubmitMemo"
    "blur  .selectMode"     : "onBlurSelectMode"
    "blur  input.memo"      : "onBlurInputMemo"
  
  initialize: (options) ->
    @optionKeys = _.keys optionsDisp
    @model.on
      "change:bookmark": @onChangeBookmark
      "setFocus":        @onClickInput
      "remove":          @onRemove
      @
    @model.collection.on
      "kbdEvent":    @onKbdEvent
      "changeKbd":   @onChangeKbd
      "updateOrder": @onUpdateOrder
      @
  
  render: (kbdtype) ->
    @setElement @template({options: optionsDisp})
    mode = @model.get("mode")
    #@$("select.mode").val mode
    @setKbdValue @$(".proxy"), @model.id
    @setKbdValue @$(".origin"), @model.get("origin")
    @kbdtype = kbdtype
    @onChangeMode null, mode
    @
  
  # Model Events
  onChangeBookmark: ->
    @onChangeMode null, "bookmark"
  
  onRemove: ->
    @model.off null, null, @
    @off null, null, null
    @remove()
  
  # Collection Events
  onKbdEvent: (value) ->
    input$ = @$("div:focus")
    if input$.length > 0
      if input$.hasClass "proxy"
        if @model.id isnt value && @model.collection.findWhere(proxy: value)
          @trigger "decodeKbdEvent", value, container = {}
          $("#tiptip_content").text("\"#{container.result}\" is already exists.")
          input$.tipTip()
          return
      else # Origin
        if ~~value.substring(2) > 0x200
          return
      @setKbdValue input$, value
      @model.set input$[0].className.match(/(proxy|origin)/)[0], value
      @setDesc()
      @trigger "resizeInput"
  
  onChangeKbd: (kbdtype) ->
    @kbdtype = kbdtype
    @setKbdValue @$(".proxy"), @model.id
    @setKbdValue @$(".origin"), @model.get("origin")
    @setDesc()
  
  onUpdateOrder: ->
    @model.set "ordernum", @$el.parent().children().index(@$el)
  
  # DOM Events
  onClickEditDesc: ->
    (memo = @$("div.memo")).toggle()
    editing = (input$ = @$("form.memo").toggle().find("input")).is(":visible")
    if editing
      startEditing()
      input$.focus().val(memo.text())
    else
      @onSubmitMemo()
    event.stopPropagation()
  
  onClickMode: ->
    if @$(".selectMode").toggle().is(":visible")
      @$(".selectMode").focus()
      @$(".mode").addClass("selecting")
    else
      @$(".mode").removeClass("selecting")
    event.stopPropagation()
  
  onChangeMode: (event, mode) ->
    if event
      @$(".mode").removeClass("selecting")
      mode = event.currentTarget.className
      @$(".selectMode").hide()
      if mode is "bookmark"
        @trigger "showBookmarks", @model.id
        return
    @model.set "mode", mode
    @$(".mode")
      .removeClass(@optionKeys.join(" "))
      .addClass(mode)
    @setDispMode mode
    @setDesc()
    @trigger "resizeInput"
  
  onBlurSelectMode: ->
    @$(".selectMode").hide()
    @$(".mode").removeClass("selecting")
  
  onClickInput: (event, selector) ->
    if (event)
      $(event.currentTarget).focus()
    else if selector
      @$(selector).focus()
    else
      @$(".origin").focus()
    event?.stopPropagation()
  
  onSubmitMemo: ->
    @$("form.memo").hide()
    @model.set "memo": @$("div.memo").show().html(escape @$("input.memo").val()).text()
    endEditing()
    false
  
  onBlurInputMemo: ->
    @onSubmitMemo()
  
  onClickRemove: ->
    @trigger "removeConfig", @model
  
  # Object Method
  setDispMode: (mode) ->
    @$("div.mode").addClass(mode).find("span").text optionsDisp[mode]
    @$(".proxy,.origin,.icon-arrow-right")
      .removeClass(@optionKeys.join(" "))
      .addClass mode
    if mode is "assignOrg"
      @$(".origin").attr("tabIndex", "0")
      @$("td:first").removeAttr("colspan")
      @$("td:eq(1),td:eq(2)").show()
    else
      @$(".origin").removeAttr("tabIndex")
      @$("td:first").attr("colspan", "3")
      @$("td:eq(1),td:eq(2)").hide()
  
  setKbdValue: (input$, value) ->
    @trigger "decodeKbdEvent", value, container = {}
    if container.result
      input$.html _.map(container.result.split(" + "), (s) -> "<span>#{s}</span>").join("+")
  
  setDesc: ->
    (tdDesc = @$(".desc")).empty()
    switch mode = @model.get "mode"
      #when "simEvent"
      when "bookmark"
        #tdDesc.append """<div><i class="icon-star"></i></div><div class="bookmark" title="#{@model.get("bookmark").url}">#{@model.get("bookmark").title}</div>"""
        url = @model.get("bookmark").url
        tdDesc.append """<div class="bookmark" title="#{url}" style="background-image:-webkit-image-set(url(chrome://favicon/size/16@1x/#{url}) 1x);">#{@model.get("bookmark").title}</div>"""
      when "assignOrg", "through", "disabled"
        lang = if @kbdtype is "JP" then "ja" else "en"
        if mode is "assignOrg"
          keycombo = @$(".origin").text()
        else
          keycombo = @$(".proxy").text()
        keycombo = (keycombo.replace /\s/g, "").toUpperCase()
        unless help = scHelp[keycombo]
          if /^CTRL\+[2-7]$/.test keycombo
            help = scHelp["CTRL+1"]
        if help
          for i in [0...help[lang].length]
            test = help[lang][i].match /(^\w+)\^(.+)/
            key = RegExp.$1
            content = RegExp.$2
            tdDesc
              .append(@tmplHelp
                sectDesc: scHelpSect[key]
                sectKey:  key
                scHelp:   content
              ).find(".sectInit").tooltip {position: {my: "left+10 top-60"}}
    if tdDesc.html() is ""
      tdDesc.append @tmplMemo memo: @model.get("memo")

  tmplMemo: _.template """
    <div>
      <i class="icon-pencil" title="Edit description"></i>
    </div>
    <form class="memo">
      <input type="text" class="memo">
    </form>
    <div class="memo"><%=memo%></div>
    """
  
  tmplHelp: _.template """
    <div class="sectInit" title="<%=sectDesc%>"><%=sectKey%></div><div class="content"><%=scHelp%></div>
    """
  
  template: _.template """
    <tr class="data">
      <td>
        <div class="proxy" tabIndex="0"></div>
      </td>
      <td>
        <i class="icon-arrow-right"></i>
      </td>
      <td class="tdOrigin">
        <div class="origin" tabIndex="0"></div>
      </td>
      <td class="options">
        <div class="mode"><span></span><i class="icon-caret-down"></i></div>
        <div class="selectMode" tabIndex="0">
          <% _.each(options, function(name, key) { %>
          <div class="<%=key%>"><%=name%></div>
          <% }); %>
        </div>
      <td class="desc"></td>
      <td class="remove">
        <i class="icon-remove" title="Delete"></i>
      </td>
      <td class="blank">&nbsp;</td>
    </tr>
    """
  
KeyConfigSetView = Backbone.View.extend
  placeholder: "Enter new shortcut key"

  # Backbone Buitin Events
  el: "table.keyConfigSetView"
  
  events:
    "blur div.addnew": "onBlurAddnew"
    "click": "onClickBlank"
    
  initialize: (options) ->
    @collection.comparator = (model) ->
      model.get("ordernum")
    @collection.on
      add:      @onAddRender
      kbdEvent: @onKbdEvent
      @
  
  render: (keyConfigSet) ->
    @$el.append @template()
    @collection.set keyConfigSet
    @$("tbody").sortable
      delay: 300
      scroll: true
      cursor: "move"
      update: => @onUpdateSort()
      start: => @onStartSort()
      stop: => @onStopSort()
    $(".fixed-table-container-inner").niceScroll
      cursorwidth: 12
      cursorborderradius: 2
      smoothscroll: true
      cursoropacitymin: .3
      cursoropacitymax: .7
      zindex: 999998
    @niceScroll = $(".fixed-table-container-inner").getNiceScroll()
    @
  
  # Collection Events
  onAddRender: (model) ->
    keyConfigView = new KeyConfigView(model: model)
    keyConfigView.on "decodeKbdEvent", @onChildDecodeKbdEvent, @
    keyConfigView.on "removeConfig"  , @onChildRemoveConfig  , @
    keyConfigView.on "resizeInput"   , @onChildResizeInput   , @
    keyConfigView.on "showBookmarks" , @onShowBookmarks      , @
    @$("tbody")
      .append(newChild = keyConfigView.render(@model.get("kbdtype")).$el)
      .append(@tmplBorder)
  
  onKbdEvent: (value) ->
    if @$(".addnew").length is 0
      if (target = @$(".proxy:focus,.origin:focus")).length is 0
        if model = @collection.get(value)
          model.trigger "setFocus", null, ".proxy"
          return
        else
          unless @onClickAddKeyConfig()
            return
      else
        return
    if @collection.findWhere(proxy: value)
      $("#tiptip_content").text("\"#{@decodeKbdEvent(value)}\" is already exists.")
      @$("div.addnew").tipTip()
      return
    @$("div.addnew").blur()
    if ~~value.substring(2) > 0x200
      originValue = "0130"
    else
      originValue = value
    @collection.add newitem = new KeyConfig
      proxy: value
      origin: originValue
    @$("tbody")
      .sortable("enable")
      .sortable("refresh")
    windowOnResize()
    @onChildResizeInput()
    newitem.trigger "setFocus"
  
  # Child Model Events
  onChildDecodeKbdEvent: (value, container) ->
    container.result = @decodeKbdEvent value
  
  onChildRemoveConfig: (model) ->
    @collection.remove model
    @onStopSort()
    windowOnResize()
    @onChildResizeInput()
  
  onChildResizeInput: ->
    @$(".th_inner").css("left", 0)
    setTimeout((=> @$(".th_inner").css("left", "")), 0)
  
  onShowBookmarks: (modelId) ->
    @trigger "showBookmarks", modelId
  
  onSetBookmark: (modelId, options) ->
    if options
      @collection.get(modelId)
        .set({"bookmark": options}, {silent: true})
        .trigger "change:bookmark"
  
  # DOM Events
  onClickAddKeyConfig: (event) ->
    if @$(".addnew").length > 0
      return
    if @collection.length > 50
      $("#tiptip_content").text("You have reached the maximum number of items. (Max 50 items)")
      $(event.currentTarget).tipTip(defaultPosition: "left")
      return false
    $(@tmplAddNew placeholder: @placeholder).appendTo(@$("tbody")).find(".addnew").focus()[0].scrollIntoView()
    @$("tbody").sortable "disable"
    windowOnResize()
    true
  
  onClickBlank: ->
    @$(":focus").blur()
  
  onBlurAddnew: ->
    @$(".addnew").remove()
    @$("tbody").sortable "enable"
    windowOnResize()
  
  onChangeSelKbd: (event) ->
    keys = keyCodes[newKbd = event.currentTarget.value].keys
    @collection.trigger "changeKbd", newKbd
    @model.set "kbdtype", newKbd
  
  onStartSort: ->
    @$(".ui-sortable-placeholder").next("tr.border").remove()
  
  onStopSort: ->
    $.each @$("tbody tr"), (i, tr) =>
      if tr.className is "data"
        unless $(tr).next("tr")[0]?.className is "border"
          $(tr).after @tmplBorder
      else
        unless (target$ = $(tr).next("tr"))[0]?.className is "data"
          target$.remove()
    if (target$ = @$("tbody tr:first"))[0].className is "border"
      target$.remove()
  
  onUpdateSort: ->
    @collection.trigger "updateOrder"
    @collection.sort()
  
  # Object Method
  decodeKbdEvent: (value) ->
    modifiers = parseInt(value.substring(0, 2), 16)
    scanCode = value.substring(2)
    keyIdenfiers = keys[scanCode]
    keyCombo = []
    keyCombo.push "Ctrl"    if modifiers &  1
    keyCombo.push "Alt"     if modifiers &  2
    keyCombo.push "Win"     if modifiers &  8
    keyCombo.push "MouseL"  if modifiers & 16
    keyCombo.push "MouseR"  if modifiers & 32
    keyCombo.push "MouseM"  if modifiers & 64
    if modifiers & 4
      keyCombo.push "Shift"
      keyCombo.push keyIdenfiers[1] || keyIdenfiers[0]
    else
      keyCombo.push keyIdenfiers[0]
    keyCombo.join(" + ")
  
  getSaveData: ->
    @collection.remove @collection.findWhere proxy: @placeholder
    config: @model.toJSON()
    keyConfigSet: @collection.toJSON()
  
  tmplAddNew: _.template """
    <tr class="addnew">
      <td colspan="3">
        <div class="proxy addnew" tabIndex="0"><%=placeholder%></div>
      </td>
      <td></td><td></td><td></td><td class="blank"></td>
    </tr>
    """
  
  tmplBorder: """
    <tr class="border">
      <td colspan="6"><div class="border"></div></td>
      <td></td>
    </tr>
    """

  template: _.template """
    <thead>
      <tr>
        <th>
          <div class="th_inner">New <i class="icon-arrow-right"></i> Origin shortcut key</div>
        </th>
        <th></th>
        <th></th>
        <th>
          <div class="th_inner options">Options</div>
        </th>
        <th>
          <div class="th_inner desc">Description</div>
        </th>
        <th></th>
        <th><div class="th_inner blank">&nbsp;</div></th>
      </tr>
    </thead>
    <tbody></tbody>
    """

BookmarksView = Backbone.View.extend
  el: ".bookmarks"
  events:
    "submit form"        : "onSubmitForm"
    "click  a"           : "setBookmark"
    "click  .title"      : "onClickFolder"
    "click  .expand-icon": "onClickExpandIcon"
    "click  .expand"     : "onClickExpand"
    "click  .icon-remove": "onClickIconRemove"
  
  initialize: ->
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
  
  onClickIconRemove: ->
    @trigger "setBookmark", @modelId, null
    @hideBookmarks()
  
  onShowBookmarks: (id) ->
    if @$(".result").children().length is 0
      @onSubmitForm()
    @modelId = id
    height = window.innerHeight - 60
    left = (window.innerWidth - 600) / 2
    @el.style.pixelTop = 20
    @el.style.pixelLeft = left
    @$(".result_outer").height(height - 30)
    @$el.height(height).show()
    if (target = @$("input.query")).val()
      target.focus()
    @$(".result_outer").getNiceScroll().show()
    $(".backscreen").show()
    startEditing()
  
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
  
  hideBookmarks: ->
    endEditing()
    @$(".result_outer").getNiceScroll().hide()
    $(".backscreen").hide()
    @$el.hide()
  
  setBookmark: (event) ->
    target = $(event.currentTarget)
    @trigger "setBookmark", @modelId, {title: target.text(), url: target.attr("title"), bmId: target.attr("data-id")}
    @hideBookmarks()
  
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

marginBottom = 0
resizeTimer = false
windowOnResize = ->
  if resizeTimer
    clearTimeout resizeTimer
  resizeTimer = setTimeout((->
    tableHeight = window.innerHeight - document.querySelector(".header").offsetHeight - marginBottom;
    document.querySelector(".fixed-table-container").style.pixelHeight = tableHeight;
    $(".fixed-table-container-inner").getNiceScroll().resize()
    $(".result_outer").getNiceScroll().resize()
  ), 200)

fk = chrome.extension.getBackgroundPage().fk
saveData = fk.getConfig()
keyCodes = fk.getKeyCodes()
scHelp   = fk.getScHelp()
scHelpSect = fk.getScHelpSect()

startEditing = ->
  fk.startEditing()

endEditing = ->
  fk.endEditing()

$ = jQuery
$ ->
  headerView = new HeaderView
    model: new Config(saveData.config)
  headerView.render()
  
  keyConfigSetView = new KeyConfigSetView
    model: new Config(saveData.config)
    collection: new KeyConfigSet()
  keyConfigSetView.render(saveData.keyConfigSet)

  bookmarksView = new BookmarksView {}
  
  headerView.on "clickAddKeyConfig", keyConfigSetView.onClickAddKeyConfig, keyConfigSetView
  headerView.on "changeSelKbd"     , keyConfigSetView.onChangeSelKbd     , keyConfigSetView
  keyConfigSetView.on "showBookmarks", bookmarksView.onShowBookmarks     , bookmarksView
  bookmarksView.on    "setBookmark"  , keyConfigSetView.onSetBookmark    , keyConfigSetView
  
  chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
    switch request.action
      when "kbdEvent"
        keyConfigSetView.collection.trigger "kbdEvent", request.value
      when "saveConfig"
        fk.saveConfig keyConfigSetView.getSaveData()
  
  $(window)
    .on "unload", ->
      fk.saveConfig keyConfigSetView.getSaveData()
    .on "resize", ->
      windowOnResize()
  
  $(".beta").text("\u03B2")

  windowOnResize()
