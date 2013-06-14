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
    "click i.icon-remove"   : "onClickRemove"
    "click div.mode"        : "onClickMode"
    "click .selectMode div" : "onChangeMode"
    "blur  .selectMode"     : "onBlurSelectMode"
    "click i.icon-pencil"   : "onClickEditDesc"
    "submit .memo"          : "onSubmitMemo"
    "blur  input.memo"      : "onBlurInputMemo"
  
  initialize: (options) ->
    @optionKeys = _.keys optionsDisp
    @model.on
      "change:bookmark": @onChangeBookmark
      setFocus: @onClickInput
      remove:   @onRemove
      @
    @model.collection.on
      kbdEvent:    @onKbdEvent
      changeKbd:   @onChangeKbd
      updateOrder: @onUpdateOrder
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
  
  onClickMode: ->
    if @$(".selectMode").toggle().is(":visible")
      @$(".selectMode").focus()
      @$(".mode").addClass("selecting")
    else
      @$(".mode").removeClass("selecting")
  
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
  
  onClickInput: (event) ->
    if (event)
      if (target$ = $(event.currentTarget)).hasClass("proxy") || target$.hasClass("origin assignOrg")
        target$.focus()
    else
      @$(".origin").focus()
  
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
    else
      @$(".origin").removeAttr("tabIndex")
  
  setKbdValue: (input$, value) ->
    @trigger "decodeKbdEvent", value, container = {}
    input$.html _.map(container.result.split(" + "), (s) -> "<span>#{s}</span>").join("+")
  
  setDesc: ->
    (tdDesc = @$(".desc")).empty()
    switch mode = @model.get "mode"
      #when "simEvent"
      when "bookmark"
        tdDesc.append """<div><i class="icon-star"></i></div><div class="bookmark" title="#{@model.get("bookmark").url}">#{@model.get("bookmark").title}</div>"""
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
              .append(@templateHelp
                sectDesc: scHelpSect[key]
                sectKey:  key
                scHelp:   content
              ).find(".sectInit").tooltip {position: {my: "left+10 top-60"}}
    if tdDesc.html() is ""
      tdDesc.append @templateMemo memo: @model.get("memo")

  templateMemo: _.template """
    <div>
      <i class="icon-pencil" title="Edit description"></i>
    </div>
    <form class="memo">
      <input type="text" class="memo">
    </form>
    <div class="memo"><%=memo%></div>
    """
  
  templateHelp: _.template """
    <div class="sectInit" title="<%=sectDesc%>"><%=sectKey%></div><div class="content"><%=scHelp%></div>
    """
  
  template: _.template """
    <tr>
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
      <td class="desc">
      </td>
      <td class="remove">
        <i class="icon-remove" title="Remove"></i>
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
      update: => @userSorted()
    #@setTableVisible()
    #$("button").focus().blur()
    @
  
  # Collection Events
  onAddRender: (model) ->
    keyConfigView = new KeyConfigView(model: model)
    keyConfigView.on "decodeKbdEvent", @onChildDecodeKbdEvent, @
    keyConfigView.on "removeConfig"  , @onChildRemoveConfig  , @
    keyConfigView.on "resizeInput"   , @onChildResizeInput   , @
    keyConfigView.on "showBookmarks" , @onShowBookmarks      , @
    @$("tbody").append newChild = keyConfigView.render(@model.get("kbdtype")).$el
    #@setTableVisible()
    #newChild.find(".proxy").focus()
  
  onKbdEvent: (value) ->
    if @$(".addnew").length is 0
      return
    if @collection.findWhere(proxy: value)
      $("#tiptip_content").text("\"#{@decodeKbdEvent(value)}\" is already exists.")
      @$("div.addnew").tipTip()
      return
    @$("div.addnew").blur()
    @collection.add newitem = new KeyConfig
      proxy: value
      origin: value
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
    #@setTableVisible()
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
    if @collection.length >= 20
      $("#tiptip_content").text("You have reached the maximum number of items. (Max 20 items)")
      $(event.currentTarget).tipTip(defaultPosition: "right")
      return
    $(@templateAddNew placeholder: @placeholder).appendTo(@$("tbody")).find(".addnew").focus()[0].scrollIntoView()
    @$("tbody").sortable "disable"
    windowOnResize()
  
  onBlurAddnew: ->
    @$(".addnew").remove()
    @$("tbody").sortable "enable"
    windowOnResize()
  
  onChangeSelKbd: (event) ->
    keys = keyCodes[newKbd = event.currentTarget.value].keys
    @collection.trigger "changeKbd", newKbd
    @model.set "kbdtype", newKbd
  
  # Object Method
  decodeKbdEvent: (value) ->
    modifiers = parseInt(value.substring(0, 2), 16)
    scanCode = value.substring(2)
    keyIdenfiers = keys[scanCode]
    keyCombo = []
    keyCombo.push "Ctrl" if modifiers & 1
    keyCombo.push "Alt"  if modifiers & 2
    keyCombo.push "Win"  if modifiers & 8
    if modifiers & 4
      keyCombo.push "Shift"
      keyCombo.push keyIdenfiers[1] || keyIdenfiers[0]
    else
      keyCombo.push keyIdenfiers[0]
    keyCombo.join(" + ")
  
  setTableVisible: ->
    if @collection.length is 0 then @$el.hide() else @$el.show()
  
  userSorted: ->
    @collection.trigger "updateOrder"
    @collection.sort()
  
  getSaveData: ->
    @collection.remove @collection.findWhere proxy: @placeholder
    config: @model.toJSON()
    keyConfigSet: @collection.toJSON()
  
  templateAddNew: _.template """
    <tr class="addnew">
      <td colspan="3">
        <div class="proxy addnew" tabIndex="0"><%=placeholder%></div>
      </td>
      <td></td><td></td><td></td><td class="blank"></td>
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
    "submit form"       : "onSubmitForm"
    "click a"           : "setBookmark"
    "click .icon-remove": "onClickIconRemove"
  initialize: ->
    @elBookmark$ = @$(".result")
    @$(".result_outer").niceScroll
      cursorwidth: 12
      cursorborderradius: 6
      smoothscroll: true
      cursoropacitymin: .1
      cursoropacitymax: .6
  onClickIconRemove: ->
    @trigger "setBookmark", @modelId, null
    @hideBookmarks()
  onShowBookmarks: (id) ->
    @modelId = id
    height = window.innerHeight - 80
    left = (window.innerWidth - 600) / 2
    @el.style.pixelTop = 20
    @el.style.pixelLeft = left
    @$(".result_outer").height(height - 30)
    @$el.height(height)
      .show()
      .find("input.query").focus()
    @$(".result_outer").getNiceScroll().show()
    $(".backscreen").show()
    startEditing()
  onSubmitForm: ->
    @$(".result").empty()
    query = @$("input.query").val()
    chrome.bookmarks.getTree (treeNode) =>
      treeNode.forEach (node) =>
        #console.log "title: " + node.title
        @digBookmarks node, query, 1
        #console.log node
    windowOnResize()
    false
  digBookmarks: (node, query, indent) ->
    if node.title
      if node.children
        #console.log Array(indent).join("  ") + "folder: " + node.title
        @elBookmark$.append """<div class="folder" style="text-indent:#{indent-1}em"><i class="icon-folder-open"></i>#{node.title}</div>"""
      else
        #console.log Array(indent).join("  ") + "title: " + node.title
        if !query || (node.title + " " + node.url).toUpperCase().indexOf(query.toUpperCase()) > -1
          @elBookmark$.append """<div style="text-indent:#{indent}em"><a href="#" title="#{node.url}" data-id="#{node.id}">#{node.title}</a></div>"""
    else
      indent--
    if node.children
      node.children.forEach (child) =>
        @digBookmarks child, query, indent + 1
  hideBookmarks: ->
    endEditing()
    @$(".result_outer").getNiceScroll().hide()
    $(".backscreen").hide()
    @$el.hide()
  setBookmark: (event) ->
    target = $(event.currentTarget)
    @trigger "setBookmark", @modelId, {title: target.text(), url: target.attr("title"), bmId: target.attr("data-id")}
    @hideBookmarks()

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
  
  windowOnResize()
  
  $(".fixed-table-container-inner").niceScroll
    cursorwidth: 12
    cursorborderradius: 2
    smoothscroll: true
    cursoropacitymin: .1
    cursoropacitymax: .6
  
  $(".beta").text("\u03B2")
