gMaxItems = 100
lastFocused = null
keyCodes = {}
keys = null

WebFontConfig =
  google: families: ['Noto+Sans::latin']

modeDisp =
  remap:    ["Remap"      , "icon-random"]
  command:  ["Command..." , "icon-cog"]
  bookmark: ["Bookmark...", "icon-bookmark"]
  #keydown:  ["KeyDown"    , "icon-font"]
  disabled: ["Disabled"   , "icon-ban-circle"]
  through:  ["Pause"      , "icon-pause", "nodisp"]

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
  if keyIdentifier = keys[scanCode]
    keyCombo = []
    #for i in [0...modifierKeys.length]
    #  keyCombo.push modifierKeys[i] if modifiers & Math.pow(2, i)
    keyCombo.push modifierKeys[0] if modifiers & 1
    keyCombo.push modifierKeys[2] if modifiers & 4
    keyCombo.push modifierKeys[1] if modifiers & 2
    keyCombo.push modifierKeys[3] if modifiers & 8
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
    @$(".scHelp")
      .text("ショートカットキー一覧")
      .attr "href", @scHelpUrl + "ja"
  setScHelp0: (kbdtype) ->
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
  idAttribute: "new"
  defaults:
    mode: "remap"

KeyConfigSet = Backbone.Collection.extend(model: KeyConfig)

KeyConfigView = Backbone.View.extend

  kbdtype: null
  optionKeys: []
  
  # Backbone Buitin Events
  events:
    "click .origin,.new"   : "onClickInput"
    "click div.mode"       : "onClickMode"
    "click .selectMode div": "onChangeMode"
    "click div.edit"       : "onClickEdit"
    "click div.copySC"     : "onClickCopySC"
    "click div.pause"      : "onClickPause"
    "click div.resume"     : "onClickResume"
    "click div.delete"     : "onClickRemove"
    "click input.memo"     : "onClickInputMemo"
    "click button.cog"     : "onClickCog"
    "focus .new,.origin"   : "onFocusKeyInput"
    "keydown .origin"      : "onKeydownOrigin"
    "submit  .memo"        : "onSubmitMemo"
    "blur  .selectMode"    : "onBlurSelectMode"
    "blur  .selectCog"     : "onBlurSelectCog"
    "blur  input.memo"     : "onBlurInputMemo"
  
  initialize: (options) ->
    @optionKeys = _.keys modeDisp
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
    @setElement @template options: modeDisp
    mode = @model.get("mode")
    unless @setKbdValue @$(".new"), @model.id
      @state = "invalid"
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
      if input$.hasClass "new"
        if @model.id isnt value && @model.collection.findWhere(new: value)
          $("#tiptip_content").text("\"#{decodeKbdEvent(value)}\" is already exists.")
          input$.tipTip()
          return
      else # Origin
        if ~~value.substring(2) > 0x200
          return
      @setKbdValue input$, value
      @model.set input$[0].className.match(/(new|origin)/)[0], value
      @setDesc()
      @trigger "resizeInput"
  
  onChangeKbd: (kbdtype) ->
    @kbdtype = kbdtype
    @setKbdValue @$(".new"), @model.id
    @setKbdValue @$(".origin"), @model.get("origin")
    @setDesc()
  
  onUpdateOrder: ->
    @model.set "ordernum", @$el.parent().children().index(@$el)
  
  # DOM Events
  onKeydownOrigin: (event) ->
    if keynames = keyIdentifiers[@kbdtype][event.originalEvent.keyIdentifier]
      if event.originalEvent.shiftKey
        unless keyname = keynames[1]
          return
        scCode = "04"
      else
        keyname = keynames[0]
        scCode = "00"
      for i in [0...keys.length]
        if keys[i] && (keyname is keys[i][0] || keyname is keys[i][1])
          scanCode = i
          break
      if scanCode
        scCode += i
        if event.originalEvent.shiftKey
          @$(".origin").html "<span>Shift</span>+<span>#{keyname}</span>"
        else
          @$(".origin").html "<span>#{keyname}</span>"
        @model.set "origin", scCode
        @setDesc()
        @trigger "resizeInput"
  
  onClickCopySC: (event) ->
    if @model.get("mode") is "remap"
      method = "keydown"
      scCode = @model.get("origin")
      desc = @$(".desc").find(".content,.memo").text()
    else
      method = "send"
      scCode = @model.id
      desc = @$(".desc").find(".content,.command,.commandCaption,.bookmark,.memo").text()
    command = @$("td.options .mode").text().replace "Remap", ""
    command = " " + command + ":" if command
    keyCombo = (decodeKbdEvent scCode).replace /\s/g, ""
    desc = " " + desc if desc
    body = "tsc.#{method}('#{transKbdEvent(scCode)}');"
    text = body + " /* " + keyCombo + command + desc + " */"
    chrome.runtime.sendMessage
      action: "setClipboard"
      value1: text
      (msg) ->
  
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
    @setDispMode mode
    @setDesc()
    @trigger "resizeInput"
  
  onBlurSelectMode: ->
    @$(".selectMode").hide()
    @$(".mode").removeClass("selecting")
  
  onFocusKeyInput: ->
    lastFocused = @el
  
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
    if (mode = @model.get("mode")) is "through"
      pause = true
      mode = @model.get("lastMode")
    switch mode
      when "bookmark"
        @trigger "showPopup", "bookmarkOptions", @model, @model.get("bookmark")  
      when "command"
        @trigger "showPopup", "commandOptions", @model, @model.get("command")
      else #when "remap", "through", "disabled"
        (memo = @$("div.memo")).toggle()
        editing = (input$ = @$("form.memo").toggle().find("input.memo")).is(":visible")
        if editing
          input$.focus().val memo.text()
          startEdit()
        else
          @onSubmitMemo()
        event.stopPropagation()
  
  onClickPause: ->
    @model.set("lastMode", @model.get("mode"))
    @onChangeMode(null, "through")
  
  onClickResume: ->
    @onChangeMode(null, @model.get("lastMode"))
  
  onClickRemove: ->
    shortcut = decodeKbdEvent @model.id
    if confirm "Are you sure you want to delete this shortcut?\n\n '#{shortcut}'"
      @trigger "removeConfig", @model
  
  # Object Method
  setDispMode: (mode) ->
    @$(".mode")
      .attr("title", modeDisp[mode][0].replace("...", ""))
      .find(".icon")[0].className = "icon " + modeDisp[mode][1]
    if mode is "through"
      mode = @model.get("lastMode") + " through"
    @$(".new,.origin,.icon-arrow-right")
      .removeClass(@optionKeys.join(" "))
      .addClass mode
    if /remap/.test mode
      @$("th:first").removeAttr("colspan")
      @$("th:eq(1),th:eq(2)").show()
    else
      @$("th:first").attr("colspan", "3")
      @$("th:eq(1),th:eq(2)").hide()
  
  setKbdValue: (input$, value) ->
    if result = decodeKbdEvent value
      input$.html _.map(result.split(" + "), (s) -> "<span>#{s}</span>").join("+")
      true
    else
      false
  
  setDesc: ->
    (tdDesc = @$(".desc")).empty()
    editOption = iconName: "", command: ""
    if (mode = @model.get("mode")) is "through"
      pause = true
      mode = @model.get("lastMode")
    switch mode
      when "bookmark"
        bookmark = @model.get("bookmark")
        tdDesc.append @tmplBookmark
          openmode: bmOpenMode[bookmark.openmode]
          url: bookmark.url
          title: bookmark.title
        editOption = iconName: "icon-cog", command: "Edit bookmark..."
      when "command"
        desc = (commandDisp = commandsDisp[@model.get("command").name])[1]
        if commandDisp[2]
          content3row = []
          command = @model.get("command")
          lines = command.content.split("\n")
          for i in [0...lines.length]
            if i > 2
              content3row[i-1] += " ..."
              break
            else
              content3row.push lines[i].replace(/"/g, "'")
          tdDesc.append @tmplCommandCustom
            ctg: commandDisp[3]
            desc: desc
            content3row: content3row.join("\n")
            caption: command.caption
          editOption = iconName: "icon-cog", command: "Edit command..."
        else
          tdDesc.append @tmplCommand desc: desc, ctg: commandDisp[0].substring(0,1).toUpperCase() + commandDisp[0].substring(1)
      when "remap", "disabled"
        lang = if @kbdtype is "JP" then "ja" else "en"
        if mode is "remap"
          keycombo = @$(".origin").text()
        else
          keycombo = @$(".new").text()
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
    if mode is "disabled"
      @$(".addKey,.copySC,.seprater.1st").remove()
    if editOption.iconName is ""
      tdDesc.find(".edit").remove()
    if pause
      tdDesc.find(".pause").remove()
    else
      tdDesc.find(".resume").remove()
  
  tmplDesc: _.template """
    <button class="cog small"><i class="icon-caret-down"></i></button>
    <div class="selectCog" tabIndex="0">
      <div class="edit"><i class="<%=iconName%>"></i> <%=command%></div>
      <div class="addKey"><i class="icon-plus"></i> Add KeyEvent</div>
      <div class="copySC"><i class="icon-paper-clip"></i> Copy script</div>
      <span class="seprater 1st"><hr style="margin:3px 1px" noshade></span>
      <div class="pause"><i class="icon-pause"></i> Pause</div>
      <div class="resume"><i class="icon-play"></i> Resume</div>
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

  tmplCommand: _.template """<div class="ctgIcon <%=ctg%>"><%=ctg%></div><div class="command"><%=desc%></div>"""

  tmplCommandCustom: _.template """
    <div class="ctgIcon <%=ctg%>"><%=ctg%></div>
    <div class="command"><%=desc%>:</div><div class="commandCaption" title="<%=content3row%>"><%=caption%></div>
    """
  
  tmplHelp: _.template """
    <div class="sectInit" title="<%=sectDesc%>"><%=sectKey%></div><div class="content"><%=scHelp%></div>
    """
  
  template: _.template """
    <tr class="data">
      <th>
        <div class="new" tabIndex="0"></div>
      </th>
      <th>
        <i class="icon-arrow-right"></i>
      </th>
      <th class="tdOrigin">
        <div class="origin" tabIndex="-1"></div>
      </th>
      <td class="options">
        <div class="mode"><i class="icon"></i><span></span><i class="icon-caret-down"></i></div>
        <div class="selectMode" tabIndex="0">
          <% _.each(options, function(option, key) { if (option[2] != "nodisp") { %>
          <div class="<%=key%>"><i class="icon <%=option[1]%>"></i> <%=option[0]%></div>
          <% }}); %>
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
      #cursorcolor: "#1E90FF"
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
    keyConfigView.on "removeConfig", @onChildRemoveConfig, @
    keyConfigView.on "resizeInput" , @onChildResizeInput , @
    keyConfigView.on "showPopup"   , @onShowPopup        , @
    divAddNew = @$("tr.addnew")[0] || null
    tbody = @$("tbody")[0]
    tbody.insertBefore keyConfigView.render(@model.get("kbdtype")).el, divAddNew
    tbody.insertBefore $(@tmplBorder)[0], divAddNew
    if divAddNew
      @$("div.addnew").blur()
      @onUpdateSort()
    if keyConfigView.state is "invalid"
      @onChildRemoveConfig model
  
  onKbdEvent: (value) ->
    if @$(".addnew").length is 0
      if (target = @$(".new:focus,.origin:focus")).length is 0
        if model = @collection.get(value)
          model.trigger "setFocus", null, ".new"
          return
        else
          unless @onClickAddKeyConfig()
            return
      else
        return
    if @collection.findWhere(new: value)
      $("#tiptip_content").text("\"#{decodeKbdEvent(value)}\" is already exists.")
      @$("div.addnew").tipTip()
      return
    if ~~value.substring(2) > 0x200
      originValue = "0130"
    else
      originValue = value
    @collection.add newitem = new KeyConfig
      new: value
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
    if @collection.length > gMaxItems
      $("#tiptip_content").text("You have reached the maximum number of items. (Max #{gMaxItems} items)")
      $(event.currentTarget).tipTip defaultPosition: "left"
      return false
    newItem$ = $(@tmplAddNew placeholder: @placeholder)
    @$("tbody")[0].insertBefore newItem$[0], lastFocused
    newItem$.find(".addnew").focus()[0].scrollIntoViewIfNeeded()
    #$(@tmplAddNew placeholder: @placeholder).appendTo(@$("tbody")).find(".addnew").focus()[0].scrollIntoView()
    @$("tbody").sortable "disable"
    windowOnResize()
  
  onClickBlank: ->
    @$(":focus").blur()
    lastFocused = null
  
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
    @collection.remove @collection.findWhere new: @placeholder
    config: @model.toJSON()
    keyConfigSet: @collection.toJSON()
  
  tmplAddNew: _.template """
    <tr class="addnew">
      <th colspan="3">
        <div class="new addnew" tabIndex="0"><%=placeholder%></div>
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
          <div class="th_inner options">Mode</div>
        </th>
        <th>
          <div class="th_inner desc">Description</div>
        </th>
        <th><div class="th_inner blank">&nbsp;</div></th>
      </tr>
    </thead>
    <tbody></tbody>
    """

#document.addEventListener "contextmenu",
#  (event) ->
#    event.preventDefault()
#    event.stopPropagation()
#  true

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
  
  headerView.on          "clickAddKeyConfig", keyConfigSetView.onClickAddKeyConfig, keyConfigSetView
  headerView.on          "changeSelKbd"     , keyConfigSetView.onChangeSelKbd     , keyConfigSetView
  commandsView.on        "setCommand"       , keyConfigSetView.onSetCommand       , keyConfigSetView
  commandOptionsView.on  "setCommand"       , keyConfigSetView.onSetCommand       , keyConfigSetView
  bookmarkOptionsView.on "setBookmark"      , keyConfigSetView.onSetBookmark      , keyConfigSetView
  
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
    .on "click", ->
      lastFocused = null
  
  $(".beta").text("\u03B2")

  windowOnResize()
