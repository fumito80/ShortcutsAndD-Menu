keyCodes = {}
keys = null

WebFontConfig =
  google: families: ['Noto+Sans::latin']

optionsDisp =
  remap:    "None"
  command:  "Command..."
  bookmark: "Bookmark..."
  simEvent: "Simurate key event"
  disabled: "Disabled"
  through:  "Through"

bmOpenMode =
  current:   "Open in current tab"
  newtab:    "Open in new tab"
  newwin:    "Open in new window"
  incognito: "Open in incognito window"
  
escape = (html) ->
  entity =
  "&": "&amp;"
  "<": "&lt;"
  ">": "&gt;"
  html.replace /[&<>]/g, (match) ->
    entity[match]

modifierKeys  = ["Ctrl", "Alt", "Shift", "Win", "MouseL", "MouseR", "MouseM"]
modifierInits = ["c"   , "a"  , "s"    , "w"]

decodeKbdEvent = (value) ->
  modifiers = parseInt(value.substring(0, 2), 16)
  scanCode = value.substring(2)
  keyIdentifier = keys[scanCode]
  keyCombo = []
  for i in [0...modifierKeys.length]
    keyCombo.push modifierKeys[i] if modifiers & Math.pow(2, i)
  if modifiers & 4
    keyCombo.push keyIdentifier[1] || keyIdentifier[0]
  else
    keyCombo.push keyIdentifier[0]
  keyCombo.join(" + ")

transKbdEvent = (value) ->
  modifiers = parseInt(value.substring(0, 2), 16)
  keyCombo = []
  for i in [0...modifierInits.length]
    keyCombo.push modifierInits[i] if modifiers & Math.pow(2, i)
  scanCode = value.substring(2)
  keyIdenfiers = keys[scanCode]
  "[" + keyCombo.join("") + "]" + keyIdenfiers[0]

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
    mode: "remap"

KeyConfigSet = Backbone.Collection.extend(model: KeyConfig)

KeyConfigView = Backbone.View.extend

  kbdtype: null
  optionKeys: []
  
  # Backbone Buitin Events
  events:
    "click .origin,.proxy"  : "onClickInput"
    "click div.mode"        : "onClickMode"
    "click .selectMode div" : "onChangeMode"
    "click div.delete"      : "onClickRemove"
    "click div.edit"        : "onClickEdit"
    "click div.copySC"      : "onClickCopySC"
    "click input.memo"      : "onClickInputMemo"
    "click button.cog"      : "onClickCog"
    "submit .memo"          : "onSubmitMemo"
    "blur  .selectMode"     : "onBlurSelectMode"
    "blur  .selectCog"      : "onBlurSelectCog"
    "blur  input.memo"      : "onBlurInputMemo"
  
  initialize: (options) ->
    @optionKeys = _.keys optionsDisp
    @model.on
      "change:bookmark": @onChangeBookmark
      "change:command":  @onChangeCommand
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
  
  onChangeCommand: ->
    @onChangeMode null, "command"
  
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
          $("#tiptip_content").text("\"#{decodeKbdEvent(value)}\" is already exists.")
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
  onClickCopySC: ->
    keycombo = (decodeKbdEvent @model.id).replace /\s/g, ""
    command = @$("td.options .mode").text().replace "None", ""
    command = " " + command + ":" if command
    desc = @$(".desc").find(".content,.command,.bookmark,.memo").text()
    desc = " " + desc if desc
    body = "tsc.send('" + transKbdEvent(@model.id) + "');"
    text = body + " /* " + keycombo + command + desc + " */"
    chrome.runtime.sendMessage
      action: "setClipboard"
      value1: text
  
  onClickInputMemo: ->
    event.stopPropagation()
  
  onSubmitMemo: ->
    @$("form.memo").hide()
    @model.set "memo": @$("div.memo").show().html(escape @$("input.memo").val()).text()
    endEdit()
    false
  
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
      if mode in ["bookmark", "command"]
        @trigger "showPopup", mode, @model, @model.get(mode)
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
  
  onBlurInputMemo: ->
    @onSubmitMemo()
  
  onClickCog: (event) ->
    if @$(".selectCog").toggle().is(":visible")
      @$(".selectCog").focus()
      $(event.currentTarget).addClass("selecting")
    else
      $(event.currentTarget).removeClass("selecting")
    event.stopPropagation()
    
  onBlurSelectCog: ->
    @$(".selectCog").hide()
    @$("button.cog").removeClass("selecting")
  
  onClickEdit: (event) ->
    switch mode = @model.get "mode"
      when "bookmark"
        @trigger "showPopup", "bookmarkOptions", @model, @model.get("bookmark")  
      when "command"
        @trigger "showPopup", "commandOptions", @model, @model.get("command")  
      #when "remap", "through", "disabled"
      else
        (memo = @$("div.memo")).toggle()
        editing = (input$ = @$("form.memo").toggle().find("input.memo")).is(":visible")
        if editing
          input$.focus().val memo.text()
          startEdit()
        else
          @onSubmitMemo()
        event.stopPropagation()
  
  onClickRemove: ->
    shortcut = decodeKbdEvent @model.id
    if confirm "Are you sure you want to delete this shortcut?\n\n '#{shortcut}'"
      @trigger "removeConfig", @model
  
  # Object Method
  setDispMode: (mode) ->
    @$("div.mode").addClass(mode).find("span").text optionsDisp[mode].replace("...", "")
    @$(".proxy,.origin,.icon-arrow-right")
      .removeClass(@optionKeys.join(" "))
      .addClass mode
    if mode is "remap"
      @$(".origin").attr("tabIndex", "0")
      @$("th:first").removeAttr("colspan")
      @$("th:eq(1),th:eq(2)").show()
    else
      @$(".origin").removeAttr("tabIndex")
      @$("th:first").attr("colspan", "3")
      @$("th:eq(1),th:eq(2)").hide()
  
  setKbdValue: (input$, value) ->
    if result = decodeKbdEvent value
      input$.html _.map(result.split(" + "), (s) -> "<span>#{s}</span>").join("+")
  
  setDesc: ->
    (tdDesc = @$(".desc")).empty()
    editOption = iconName: "", command: ""
    switch mode = @model.get "mode"
      #when "simEvent"
      when "bookmark"
        bookmark = @model.get("bookmark")
        tdDesc.append @tmplBookmark
          openmode: bmOpenMode[bookmark.openmode]
          url: bookmark.url
          title: bookmark.title
        editOption = iconName: "icon-cog", command: "Edit bookmark..."
      when "command"
        desc = (commandDisp = commandsDisp[@model.get("command").name])[1]
        if commandDisp[0] is "custom"
          content3row = []
          command = @model.get("command")
          lines = command.content.split("\n")
          for i in [0...lines.length]
            if i > 2
              content3row[i-1] += " ..."
              break
            else
              content3row.push lines[i].replace(/"/g, "'")
          tdDesc.append @tmplCommandCustom desc: desc, content3row: content3row.join("\n"), caption: command.caption
          editOption = iconName: "icon-cog", command: "Edit command..."
        else
          tdDesc.append """<div class="commandIcon">Cmd</div><div class="command">#{desc}</div>"""
      when "remap", "through", "disabled"
        lang = if @kbdtype is "JP" then "ja" else "en"
        if mode is "remap"
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
            tdDesc.append(@tmplHelp
                sectDesc: scHelpSect[key]
                sectKey:  key
                scHelp:   content
              ).find(".sectInit").tooltip {position: {my: "left+10 top-60"}}
    if tdDesc.html() is ""
      tdDesc.append @tmplMemo memo: @model.get("memo")
      editOption = iconName: "icon-pencil", command: "Edit description..."
    tdDesc.append @tmplDesc editOption
    if editOption.iconName is ""
      tdDesc.find(".edit").remove()
  
  tmplDesc: _.template """
    <button class="cog small"><i class="icon-caret-down"></i></button>
    <div class="selectCog" tabIndex="0">
      <div class="edit"><i class="<%=iconName%>"></i> <%=command%></div>
      <div class="copySC"><i class="icon-paper-clip"></i> Copy shortcut command</div>
      <span class="seprater"><hr style="margin:3px 1px" noshade></span>
      <div class="delete"><i class="icon-remove"></i> Delete</div>
    </div>
    """
  
  tmplMemo: _.template """
    <form class="memo">
      <input type="text" class="memo">
    </form>
    <div class="memo"><%=memo%></div>
    """
  
  tmplBookmark: _.template """
    <div class="bookmark" title="<<%=openmode%>>\n<%=url%>" style="background-image:-webkit-image-set(url(chrome://favicon/size/16@1x/<%=url%>) 1x);"><%=title%></div>
    """

  tmplCommandCustom: _.template """
    <div class="customIcon">Cmd</div>
    <div class="command" title="<%=content3row%>"><%=desc%>: <span class="caption"><%=caption%></span></div>
    """
  
  tmplHelp: _.template """
    <div class="sectInit" title="<%=sectDesc%>"><%=sectKey%></div><div class="content"><%=scHelp%></div>
    """
  
  template: _.template """
    <tr class="data">
      <th>
        <div class="proxy" tabIndex="0"></div>
      </th>
      <th>
        <i class="icon-arrow-right"></i>
      </th>
      <th class="tdOrigin">
        <div class="origin" tabIndex="0"></div>
      </th>
      <td class="options">
        <div class="mode"><span></span><i class="icon-caret-down"></i></div>
        <div class="selectMode" tabIndex="0">
          <% _.each(options, function(name, key) { %>
          <div class="<%=key%>"><%=name%></div>
          <% }); %>
        </div>
      <td class="desc"></td>
      <td class="blank">&nbsp;</td>
    </tr>
    """
  
KeyConfigSetView = Backbone.View.extend
  placeholder: "Enter new shortcut key"

  # Backbone Buitin Events
  el: "table.keyConfigSetView"
  
  events:
    "click .addnew": "onClickAddnew"
    "blur  .addnew": "onBlurAddnew"
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
    keyConfigView.on "removeConfig"  , @onChildRemoveConfig  , @
    keyConfigView.on "resizeInput"   , @onChildResizeInput   , @
    keyConfigView.on "showPopup"     , @onShowPopup          , @
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
      $("#tiptip_content").text("\"#{decodeKbdEvent(value)}\" is already exists.")
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
  onChildRemoveConfig: (model) ->
    @collection.remove model
    @onStopSort()
    windowOnResize()
    @onChildResizeInput()
  
  onChildResizeInput: ->
    @$(".th_inner").css("left", 0)
    setTimeout((=> @$(".th_inner").css("left", "")), 0)
  
  onShowPopup: (name, model, options) ->
    @trigger "showPopup", name, model, options
  
  onSetBookmark: (modelId, options) ->
    @collection.get(modelId)
      .set({"bookmark": options}, {silent: true})
      .trigger "change:bookmark"
  
  onSetCommand: (modelId, options) ->
    @collection.get(modelId)
      .set({"command": options}, {silent: true})
      .trigger "change:command"
  
  # DOM Events
  onClickAddKeyConfig: (event) ->
    if @$(".addnew").length > 0
      return
    if @collection.length > 50
      $("#tiptip_content").text("You have reached the maximum number of items. (Max 50 items)")
      $(event.currentTarget).tipTip defaultPosition: "left"
      return false
    $(@tmplAddNew placeholder: @placeholder).appendTo(@$("tbody")).find(".addnew").focus()[0].scrollIntoView()
    @$("tbody").sortable "disable"
    windowOnResize()
    true
  
  onClickBlank: ->
    @$(":focus").blur()
  
  onClickAddnew: (event) ->
    event.stopPropagation()
  
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
  getSaveData: ->
    @collection.remove @collection.findWhere proxy: @placeholder
    config: @model.toJSON()
    keyConfigSet: @collection.toJSON()
  
  tmplAddNew: _.template """
    <tr class="addnew">
      <th colspan="3">
        <div class="proxy addnew" tabIndex="0"><%=placeholder%></div>
      </th>
      <td></td><td></td><td class="blank"></td>
    </tr>
    """
  
  tmplBorder: """
    <tr class="border">
      <td colspan="5"><div class="border"></div></td>
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
        <th><div class="th_inner blank">&nbsp;</div></th>
      </tr>
    </thead>
    <tbody></tbody>
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

startEdit = ->
  fk.startEdit()

endEdit = ->
  fk.endEdit()

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
  bookmarkOptionsView = new BookmarkOptionsView {}
  commandsView = new CommandsView {}
  commandOptionsView = new CommandOptionsView {}
  
  headerView.on       "clickAddKeyConfig", keyConfigSetView.onClickAddKeyConfig, keyConfigSetView
  headerView.on       "changeSelKbd"     , keyConfigSetView.onChangeSelKbd     , keyConfigSetView
  #keyConfigSetView.on "showPopup"        , bookmarksView.onShowPopup           , bookmarksView
  #keyConfigSetView.on "showPopup"        , commandsView.onShowPopup            , commandsView
  #keyConfigSetView.on "showPopup"        , commandInputView.onShowPopup        , commandInputView
  #keyConfigSetView.on "showPopup"        , commandFreeInputView.onShowPopup    , commandFreeInputView
  #commandsView.on     "showPopup"        , commandInputView.onShowPopup        , commandInputView
  #commandsView.on     "showPopup"        , commandFreeInputView.onShowPopup    , commandFreeInputView
  #bookmarksView.on    "setBookmark"      , keyConfigSetView.onSetBookmark      , keyConfigSetView
  commandsView.on     "setCommand"       , keyConfigSetView.onSetCommand       , keyConfigSetView
  commandOptionsView.on "setCommand"     , keyConfigSetView.onSetCommand       , keyConfigSetView
  bookmarkOptionsView.on "setBookmark"   , keyConfigSetView.onSetBookmark      , keyConfigSetView
  
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
