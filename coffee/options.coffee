gMaxItems = 100
defaultSleep = 100
lastFocused = null
loading = true

WebFontConfig =
  google: families: ['Noto+Sans::latin']

modeDisp =
  remap:    ["Remap"      , "icon-random"]
  command:  ["Command..." , "icon-cog"]
  bookmark: ["Bookmark...", "icon-bookmark"]
  #keydown:  ["KeyDown"    , "icon-font"]
  disabled: ["Disabled"   , "icon-ban-circle"]
  sleep:    ["Sleep"      , "icon-eye-close"]
  comment:  ["Comment"    , "icon-comment-alt"]
  through:  ["Pause"      , "icon-pause", "nodisp"]

bmOpenMode =
  current:   "Open in current tab"
  newtab:    "Open in new tab"
  newwin:    "Open in new window"
  incognito: "Open in incognito window"
  left:      "Open in new tab to left of the current tab"
  right:     "Open in new tab to right of the current tab"
  first:     "Open in new tab to first position"
  last:      "Open in new tab to last position"

escape = (html) ->
  entity =
  "&": "&amp;"
  "<": "&lt;"
  ">": "&gt;"
  html.replace /[&<>]/g, (match) ->
    entity[match]

modifierKeys  = ["Ctrl", "Alt", "Shift", "Win", "MouseL", "MouseR", "MouseM"]
modifierInits = ["c"   , "a"  , "s"    , "w"]

decodeKbdEvent = (kbdCode) ->
  unless kbdCode
    return null
  modifiers = parseInt(kbdCode.substring(0, 2), 16)
  scanCode = kbdCode.substring(2)
  if keyIdentifier = keys[scanCode]
    keyCombo = []
    ###
    for i in [0...modifierKeys.length]
      keyCombo.push modifierKeys[i] if modifiers & Math.pow(2, i)
    ###
    keyCombo.push modifierKeys[0] if modifiers & 1
    keyCombo.push modifierKeys[2] if modifiers & 4
    keyCombo.push modifierKeys[1] if modifiers & 2
    keyCombo.push modifierKeys[3] if modifiers & 8
    keyCombo.push modifierKeys[4] if modifiers & 16
    keyCombo.push modifierKeys[5] if modifiers & 32
    keyCombo.push modifierKeys[6] if modifiers & 64
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
    "click .addKeyConfig": "onClickAddKeyConfig"
    "click .ctxmgr"      : "onClickCtxmgr"
    "click .settings"    : "onClickSettings"
  initialize: (options) ->
    @$(".addKeyConfig,.ctxmgr,.scHelp,.helpview,.settings").show()
    @model.on "change:lang", @onChangeLang, @
  # DOM Events
  onClickAddKeyConfig: (event) ->
    @trigger "clickAddKeyConfig", (event)
  onClickCtxmgr: ->
    @trigger "showPopup", "ctxMenuManager"
  onClickSettings: ->
    @trigger "showPopup", "settings"
  onEnterCtxMenuSelMode: ->
    @$("button").attr("disabled", "disabled").addClass("disabled")
  onLeaveCtxMenuSelMode: ->
    @$("button").removeAttr("disabled").removeClass("disabled")
  onChangeLang0: (kbdtype) ->
    @$(".scHelp")
      .text("ショートカットキー一覧")
      .attr "href", @scHelpUrl + "ja"
  onChangeLang: ->
    @$(".scHelp")
      .text("Keyboard shortcuts")
      .attr "href", @scHelpUrl + @model.get("lang")

Config = Backbone.Model.extend {}

KeyConfig = Backbone.Model.extend
  idAttribute: "new"
  defaults:
    mode: "remap"

KeyConfigSet = Backbone.Collection.extend model: KeyConfig

KeyConfigView = Backbone.View.extend

  kbdtype: null
  optionKeys: []
  
  # Backbone Buitin Events
  events:
    "click .origin,.new"   : "onClickInput"
    "click div.mode"       : "onClickMode"
    "click .selectMode div": "onChangeMode"
    "click .edit"          : "onClickEdit"
    "click .addCommand"    : "onClickAddCommand"
    "click .copySC"        : "onClickCopySC"
    "click div.ctxmenu"    : "onClickCtxMenu"
    "click .pause"         : "onClickPause"
    "click .resume"        : "onClickResume"
    "click .delete"        : "onClickDelete"
    "click .editSleep"     : "onClickEditSleep"
    "click input.memo,.inputSleep": "onClickInputMemo"
    "click button.cog"     : "onClickCog"
    "click .updown a"      : "onClickUpDownChild"
    "focus .new,.origin"   : "onFocusKeyInput"
    "focus .inputSleep"    : "onClickInputMemo"
    "keydown"              : "onKeydown"
    "submit  .memo"        : "onSubmitMemo"
    "submit  .formSleep"   : "onSubmitSleep"
    "blur  .selectMode"    : "onBlurSelectMode"
    "blur  .selectCog"     : "onBlurSelectCog"
    "blur  input.memo"     : "onBlurInputMemo"
    "blur  .inputSleep"    : "onBlurInputSleep"
    "mouseover"            : "onMouseOverChild"
    "mouseout"             : "onMouseOutChild"
  
  initialize: (options) ->
    @optionKeys = _.keys modeDisp
    @model.on
      "change:new":      @onChangeNew
      "change:bookmark": @onChangeBookmark
      "change:command":  @onChangeCommand
      "change:ctxMenu":  @onChangeCtxmenu
      "setFocus":        @onClickInput
      "remove":          @onRemove
      "setUnselectable": @onSetUnselectable
      "setRowspan":      @onSetRowspan
      "updatePosition" : @onUpdatePosition
      "setSelected":     @onSetSelected
      "getDescription":  @onGetDescription
      "triggerEventCtxMenuSelected": @onTriggerCtxMenuSelected
      @
    @model.collection.on
      "kbdEvent":        @onKbdEvent
      "changeKbd":       @onChangeKbd
      "changeLang":      @onChangeLang
      "updateOrderByEl": @onUpdateOrderByEl
      "mouseoverchild" : @onMouseOverChild
      "mouseoutchild" :  @onMouseOutChild
      @
  
  render: (kbdtype, lang) ->
    @kbdtype = kbdtype
    @lang = lang
    @setElement @template options: modeDisp
    mode = @model.get("mode")
    if /^C/.test @model.id
      @$el
        .addClass("child").find("th:first-child").remove().end()
        .find(".disabled").hide()
    else if !@setKbdValue(@$(".new"), @model.id)
      @state = "invalid"
    else
      @$el.find(".sleep").hide()
      @onSetRowspan()
    unless @$el.hasClass("parent") || @$el.hasClass("child")
      @$el.find(".comment").hide()
    @setKbdValue @$(".origin"), @model.get("origin")
    @onChangeMode null, mode
    @
  
  # Model Events
  onChangeBookmark: ->
    @onChangeMode null, "bookmark"
  
  onChangeCommand: ->
    @onChangeMode null, "command"
  
  onChangeCtxmenu: ->
    if (ctxMenu = @model.get("ctxMenu")) && !@$el.hasClass("child")
      unless ctxMenu.parentId is "route"
        @model.collection.trigger "getCtxMenuContexts", container = parentId: ctxMenu.parentId
        ctxMenu.contexts = container.contexts
      @$("td.ctxmenu").html """<div class="ctxmenu-icon" title="Context menu for #{ctxMenu.contexts}\n Title: #{ctxMenu.caption}"><i class="#{tmplCtxMenus[ctxMenu.contexts][1]}"></i></div>"""
      @$("div.ctxmenu")[0].childNodes[1].nodeValue = " Edit context menu..."
    else if @model.get("mode") isnt "disabled" && !@$el.hasClass("child")
      @$("td.ctxmenu").empty()
      @$("div.ctxmenu")[0].childNodes[1].nodeValue = " Create context menu..."
    @trigger "resizeInput"
  
  onRemove: ->
    if parentId = @model.get "parentId"
      @model.collection.trigger "mouseoutchild", parentId
    @model.collection.off null, null, @ 
    @model.off null, null, @
    @off null, null, null
    @remove()
  
  onSetUnselectable: (unSelectable) ->
    if unSelectable
      @$el.addClass "unselectable"
    else
      @$el.removeClass "unselectable"
  
  onTriggerCtxMenuSelected: ->
    if @$el.hasClass("unselectable")
      @$el.removeClass "ui-selected unselectable"
    else if @$el.hasClass("ui-selected")
      @$el.removeClass "ui-selected"
      shortcut = decodeKbdEvent @model.id
      @trigger "addCtxMenu",
        id: @model.id
        caption: @getDescription() || shortcut
        shortcut: shortcut
  
  onSetRowspan: ->
    if (models = @model.collection.where(parentId: @model.id)).length > 0
      @$el.addClass("parent").find(".selectMode .comment").show().end().find(".disabled").hide()
      @$("th:first-child").attr "rowspan", models.length + 1
      @model.set "batch", true
    else
      @$el.removeClass("parent")
      @$("th:first-child").removeAttr "rowspan"
      @model.unset "batch"
      unless @$el.hasClass "child"
        @$(".selectMode .comment").hide().end().find(".disabled").show()
        @$("ul.updown").remove()
  
  onSetSelected: (selected) ->
    if selected
      @$el.addClass "ui-selected"
    else
      @$el.removeClass "ui-selected"
  
  onGetDescription: (container) ->
    container.desc = @getDescription()
  
  onChangeNew: (model) ->
    andy.changePK @model.id, model.previous("new")
  
  # Collection Events
  onKbdEvent: (value) ->
    input$ = @$("div:focus")
    if input$.length > 0
      if input$.hasClass "new"
        if @model.id isnt value && @model.collection.findWhere(new: value)
          $("#tiptip_content").text("\"#{decodeKbdEvent(value)}\" already exists.")
          input$.tipTip()
          return
        @model.collection.where(parentId: @model.id).forEach (child) ->
          child.set "parentId", value
      else # Origin
        scanCode = ~~value.substring(2)
        if scanCode >= 0x200 || scanCode is 0x15D
          return
      @setKbdValue input$, value
      @model.set input$[0].className.match(/(new|origin)/)[0], value
      @setDesc()
      @trigger "resizeInput"
      if input$.hasClass("new") && @model.has("ctxMenu")
        @trigger "remakeCtxMenu", dfd: $.Deferred()
  
  onChangeKbd: (kbdtype) ->
    @kbdtype = kbdtype
    @setKbdValue @$(".new"), @model.id
    @setKbdValue @$(".origin"), @model.get("origin")

  onChangeLang: (lang) ->
    @lang = lang
    @setDesc()
  
  onUpdateOrderByEl: ->
    @model.set "order", @$el.parent().children().index(@$el)

  onUpdatePosition: ->
    @$el.parent()[0].insertBefore @el, (@$el.parent().children().eq(@model.get("order")).get(0) || null)

  # DOM Events
  onKeydown: (event) ->
    if event.target.tagName in ["TEXTAREA", "INPUT", "SELECT"]
      return
    if @$("div:focus").hasClass("new")
      @trigger "getConfigValue", "singleKey", container = {}
      unless container.result
        return
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
        @onKbdEvent(scCode + i)
  
  onClickCopySC: (event) ->
    if (mode = @model.get("mode")) is "through"
      mode = @model.get "lastMode"
    if (children = @model.collection.where parentId: @model.id).length > 0
      mode = "batch"
    if mode is "remap"
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
    body = "scd.#{method}('#{transKbdEvent(scCode)}');"
    text = body + " /* " + keyCombo + command + desc + " */"
    chrome.runtime.sendMessage
      action: "setClipboard"
      value1: text
      (msg) ->
  
  getDescription: ->
    if @model.get("mode") is "remap"
      desc = @$(".desc").find(".content,.memo").text()
    else
      desc = @$(".desc").find(".content,.command,.commandCaption,.bookmark,.memo").text()
    $.trim(desc)
  
  onClickCtxMenu: ->
    @trigger "showPopup", "ctxMenuOptions", @model.id
  
  onClickInputMemo: (event) ->
    event.stopPropagation()
    #event.preventDefault()
  
  onSubmitMemo: ->
    @$("form.memo").hide()
    @model.set "memo": @$("div.memo").show().html(escape @$("input.memo").val()).text()
    endEdit()
    false
  
  onClickMode: (event) ->
    if event.currentTarget.getAttribute("title") is "Pause"
      return
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
        @trigger "showPopup", mode, @model.id
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
    if (mode = @model.get "mode") is "through"
      mode = @model.get "lastMode"
    switch mode
      when "bookmark"
        @trigger "showPopup", "bookmarkOptions", @model.id
      when "command"
        if @model.get("command").name is "openExtProg"
          @trigger "showPopup", "optionExtProg", @model.id
        else
          @trigger "showPopup", "commandOptions", @model.id
      else #when "remap", "through", "disabled"
        (memo = @$("div.memo")).toggle()
        editing = (input$ = @$("form.memo").toggle().find("input.memo")).is(":visible")
        if editing
          input$.focus().val memo.text()
          startEdit()
        else
          @onSubmitMemo()
        event.stopPropagation()
  
  onClickAddCommand: ->
    if /^C/.test(parentId = @model.get("new"))
      parentId = @model.get "parentId"
    lastFocused = @el
    @model.collection.add
      "new": getUuid("C")
      "origin": if ~~parentId.substring(2) >= 0x200 then "0130" else parentId
      "parentId": parentId
    if @$el.hasClass "parent"
      @setDispMode @model.get "mode"
      unless @$("ul.updown").length > 0
        @$(".desc").append @tmplUpDown
  
  onMouseOverChild: (event, id) ->
    if id is @model.id
      @$el.addClass "hover"
    if event && (parentId = @model.get "parentId")
      @model.collection.trigger "mouseoverchild", null, parentId
  
  onMouseOutChild: (event, id) ->
    if id is @model.id
      @$el.removeClass "hover"
    if event && (parentId = @model.get "parentId")
      @model.collection.trigger "mouseoutchild", null, parentId
  
  onClickPause: ->
    @model.set("lastMode", @model.get("mode"))
    @onChangeMode(null, "through")
    if ctxMenu = @model.get "ctxMenu"
      andy.updateCtxMenu @model.id, ctxMenu, true
  
  onClickResume: ->
    @onChangeMode(null, @model.get("lastMode"))
    if ctxMenu = @model.get "ctxMenu"
      andy.updateCtxMenu @model.id, ctxMenu, false
  
  onClickDelete: ->
    if parentId = @model.get "parentId"
      switch @model.get("mode")
        when "remap"
          desc = "Shortcut key: " + decodeKbdEvent(@model.get "origin") + "\n Description: \"#{@getDescription()}\""
        when "sleep"
          desc = "Sleep " + @model.get("sleep") + " msec"
        else
          desc = "Description: \"#{@getDescription()}\""
      children = []
      msg = "Are you sure you want to delete this child command?\n\n " + desc
    else
      if (children = @model.collection.where(parentId: @model.id)).length > 0
        msg = "Are you sure you want to delete this shortcut and all child commands?"
      else
        msg = "Are you sure you want to delete this shortcut?"
      shortcut = decodeKbdEvent @model.id
      msg += "\n\n Shortcut key: #{shortcut}\n Description: \"#{@getDescription()}\""
    if confirm msg
      children.forEach (child) =>
        @trigger "removeConfig", child
      collection = @model.collection
      @trigger "removeConfig", @model
      if parentId
        collection.get(parentId).trigger "setRowspan"
    else
      @$(".selectCog").blur()
  
  onClickUpDownChild: (event) ->
    changeParent = ->
      childId = childModel.id
      childModel.set "new", "temp"
      childModel.unset "parentId"
      parentModel.set "new", childId
      parentModel.set "parentId", parentId
      childModel.set "new", parentId
      newParent$.removeClass("child").find(".disabled").show().end()
        .prepend(newChild$.find("th:first-child"))
        .find("td.ctxmenu").append(newChild$.find("div.ctxmenu-icon")).end()
        .find(".desc").find(".ctxmenu,.copySC").show()
      newChild$
        .removeClass("parent hover").addClass("child").find(".disabled").hide().end()
        .find(".desc").find(".ctxmenu,.copySC").hide()
      if ctxMenu = parentModel.get("ctxMenu")
        childModel.set "ctxMenu", ctxMenu
        parentModel.unset "ctxMenu"
      if childModel.get("mode") is "through"
        newParent$.find(".new").addClass "through"
      else
        newParent$.find(".new").removeClass "through"
    order = -1
    parentId = @model.get("parentId") || @model.id
    models = [parentModel = @model.collection.get(parentId)].concat @model.collection.where(parentId: parentId)
    $.each models, (i, model) =>
      if model.id is @model.id
        order = i
        false
    if event.currentTarget.title is "up" && order > 0
      (newChild$ = @$el.prev()).before newParent$ = @$el
      if order is 1
        childModel = @model
        changeParent()
      @trigger "updateChildPos"
    else if event.currentTarget.title is "down" && models.length > (order + 1)
      (newChild$ = @$el).before (newParent$ = @$el.next())
      if order is 0
        childModel = models[1]
        changeParent()
      @trigger "updateChildPos"
  
  onClickEditSleep: ->
    @$(".dispSleep").hide()
    @$(".inputSleep").show().val(@model.get "sleep")
    setTimeout((=> @$(".inputSleep").focus()), 0)

  onSubmitSleep: ->
    value = @$(".inputSleep").val()
    if !value
      value = 100
    else
      value = 0 if value < 0
      value = 60000 if value > 60000
    value = Math.round value
    @model.set "sleep": value
    @$(".dispSleep").show().html(value).attr "title", "Sleep #{value} msec"
    @$(".inputSleep").hide()
    false

  onBlurInputSleep: ->
    @onSubmitSleep()
  
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
      @$("th:first,th:eq(1)").removeAttr("colspan").css("padding", "").find("i").show()
      @$("th:eq(1),th:eq(2),th .origin").show().find("i").show()
    else
      if @$el.hasClass "child"
        @$("th:first").css("padding", "16px 0").find("i").hide()
        @$("th .origin").hide()
      else if @$el.hasClass "parent"
        @$("th:first").removeAttr("colspan")
        @$("th:eq(1),th:eq(2)").show()
        @$("th:eq(1)").css("padding", "18px 0").find("i").hide()
        @$("th .origin").hide()
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
      mode = @model.get "lastMode"
    switch mode
      when "sleep"
        unless sleep = @model.get("sleep")
          @model.set "sleep", sleep = 100
        tdDesc.append @tmplSleep sleep: sleep
      when "bookmark"
        bookmark = @model.get("bookmark")
        tdDesc.append @tmplBookmark
          openmode: bmOpenMode[bookmark.openmode]
          url: bookmark.url
          title: bookmark.title
        editOption = iconName: "icon-pencil", command: "Edit bookmark..."
      when "command"
        desc = (commandDisp = commandsDisp[@model.get("command").name])[1]
        if commandDisp[2]
          content3row = []
          command = @model.get("command")
          lines = command.content?.split("\n") || []
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
          editOption = iconName: "icon-pencil", command: "Edit command..."
        else
          tdDesc.append @tmplCommand desc: desc, ctg: commandDisp[0].substring(0,1).toUpperCase() + commandDisp[0].substring(1)
      when "remap", "disabled"
        if mode is "remap"
          keycombo = @$(".origin").text()
        else
          keycombo = @$(".new").text()
        keycombo = (keycombo.replace /\s/g, "").toUpperCase()
        unless help = scHelp[keycombo]
          if /^CTRL\+[2-7]$/.test keycombo
            help = scHelp["CTRL+1"]
        if help　&& help[@lang]
          for i in [0...help[@lang].length]
            test = help[@lang][i].match /(^\w+)\^(.+)/
            key = RegExp.$1
            content = RegExp.$2
            tdDesc.append(@tmplHelp
                sectDesc: scHelpSect[key]
                sectKey:  key
                scHelp:   content
              ).find(".sectInit").tooltip position: {my: "left+10 top-60"}, tooltipClass: "tooltipClass"
    if tdDesc.html() is ""
      tdDesc.append @tmplMemo memo: @model.get("memo")
      editOption = iconName: "icon-pencil", command: "Edit description"
    tdDesc.append @tmplDesc editOption
    if mode is "disabled"
      @$(".addKey,.copySC,.seprater.1st,div.ctxmenu,.addCommand").hide()
    if editOption.iconName is ""
      tdDesc.find(".edit").hide()
    if pause
      tdDesc.find(".pause").hide()
    else
      tdDesc.find(".resume").hide()
    if @$el.hasClass "child"
      tdDesc.find(".ctxmenu,.copySC").hide()
    if @$el.hasClass("child") || @$el.hasClass("parent")
      tdDesc.append @tmplUpDown
    @onChangeCtxmenu()
  
  tmplDesc: _.template """
    <button class="cog small" title="menu"><i class="icon-caret-down"></i></button>
    <div class="selectCog" tabIndex="0">
      <div class="edit"><i class="<%=iconName%>"></i> <%=command%></div>
      <div class="addCommand"><i class="icon-plus"></i> Add command</div>
      <div class="ctxmenu"><i class="icon-reorder"></i> Create context menu...</div>
      <div class="copySC"><i class="icon-copy"></i> Copy script</div>
      <span class="seprater 1st"><hr style="margin:3px 1px" noshade></span>
      <div class="pause"><i class="icon-pause"></i> Pause</div>
      <div class="resume"><i class="icon-play"></i> Resume</div>
      <span class="seprater"><hr style="margin:3px 1px" noshade></span>
      <div class="delete"><i class="icon-trash"></i> Delete</div>
    </div>
    """
  
  tmplUpDown: """
    <ul class="button-bar updown">
      <li class="first"><a href="#" title="up"><i class="icon-chevron-up"></i></a></li>
  	  <li class="last"><a href="#" title="down"><i class="icon-chevron-down"></i></a></li>
  	</ul>
    """
  
  tmplMemo: _.template """
    <form class="memo">
      <input type="text" class="memo">
    </form>
    <div class="memo"><%=memo%></div>
    """
  
  tmplSleep: _.template """
    <form class="formSleep">
      <input type="number" class="inputSleep" min="0" max="60000" step="10" required>
      <span class="dispSleep" title="Sleep <%=sleep%> msec"><%=sleep%></span>
      <i class="icon-pencil editSleep" title="Edit sleep msec(0-60000)"></i>
    </form>
    """
  
  tmplBookmark: _.template """
    <div class="bookmark" title="<%=url%>\n[<%=openmode%>]" style="background-image:-webkit-image-set(url(chrome://favicon/size/16@1x/<%=url%>) 1x);"><%=title%></div>
    """

  tmplCommand: _.template """<div class="ctgIcon <%=ctg%>"><%=ctg%></div><div class="command"><%=desc%></div>"""

  tmplCommandCustom: _.template """
    <div class="ctgIcon <%=ctg%>" title="<%=desc%>"><%=ctg%></div><div class="commandCaption" title="<%=content3row%>"><%=caption%></div>
    """
  
  tmplHelp: _.template """
    <div class="sectInit" title="<%=sectDesc%>"><%=sectKey%></div><div class="content"><%=scHelp%></div>
    """
  
  template: _.template """
    <tr class="data">
      <th>
        <div class="new" tabIndex="0"></div>
        <div class="grpbartop"></div>
        <div class="grpbarbtm"></div>
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
      <td class="ctxmenu"></td>
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
    "click"        : "onClickBlank"
    "click .scrollEnd i": "onClickScrollEnd"
  
  initialize: (options) ->
    @model.on "change:lang"   , @onChangeLang   , @
    @model.on "change:kbdtype", @onChangeKbdtype, @
    @collection.comparator = (model) ->
      model.get "order"
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
      cancel: "tr.border,tr.child,input"
      placeholder: "ui-placeholder"
      forceHelperSize: true
      forcePlaceholderSize: true
      cursor: "move"
      start: =>
        @onStartSort()
      stop: (event, ui) =>
        @redrawTable()
        ui.item.effect("highlight", 1500)[0].scrollIntoViewIfNeeded true
    $(".fixed-table-container-inner")
      .on "scroll", (event) ->
        #console.log @scrollTop + ": " + (@scrollHeight - @offsetHeight)
        if @scrollTop < 10
          $(".header-background").removeClass("scrolling")
        else
          $(".header-background").addClass("scrolling")
          $(".scrollEnd").show()
        if @scrollTop + 120 > @scrollHeight - @offsetHeight
          $(".footer").removeClass("scrolling")
        else
          $(".footer").addClass("scrolling")
          $(".scrollEnd").show()
      .niceScroll
        #cursorcolor: "#1E90FF"
        cursorwidth: 13
        cursorborderradius: 2
        smoothscroll: true
        cursoropacitymin: .3
        cursoropacitymax: .7
        zindex: 999998
    @niceScroll = $(".fixed-table-container-inner").getNiceScroll()
    loading = false
    @redrawTable()
    @
  
  # Collection Events
  onAddRender: (model) ->
    keyConfigView = new KeyConfigView(model: model)
    keyConfigView.on "removeConfig", @onChildRemoveConfig, @
    keyConfigView.on "resizeInput" , @onChildResizeInput , @
    keyConfigView.on "showPopup"   , @onShowPopup        , @
    keyConfigView.on "addCtxMenu"  , @onAddCtxMenu       , @
    keyConfigView.on "updateChildPos", @redrawTable      , @
    keyConfigView.on "remakeCtxMenu" , @onRemakeCtxMenu  , @
    keyConfigView.on "getConfigValue", @onGetConfigValue , @
    divAddNew = @$("tr.addnew")[0] || null
    tbody = @$("tbody")[0]
    if /^C/.test(model.id) && lastFocused
      divAddNew = lastFocused.nextSibling || null
    tbody.insertBefore keyConfigView.render(@model.get("kbdtype"), @model.get("lang")).el, divAddNew
    tbody.insertBefore $(@tmplBorder)[0], divAddNew
    if keyConfigView.state is "invalid"
      @onChildRemoveConfig model
    if divAddNew || /^C/.test(model.id) && !loading
      @$("div.addnew").blur()
      @redrawTable()
    if /^C/.test(model.id) && lastFocused
      lastFocused = null
      @collection.get(model.get "parentId").trigger "setRowspan"
      setTimeout((-> model.trigger "setFocus"), 0)
  
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
      $("#tiptip_content").text("\"#{decodeKbdEvent(value)}\" already exists.")
      @$("div.addnew").tipTip()
      return
    @collection.add newitem = new KeyConfig
      new: value
      origin: if ~~value.substring(2) >= 0x200 then "0130" else value
    @$("tbody")
      .sortable("enable")
      .sortable("refresh")
    windowOnResize()
    @onChildResizeInput()
    newitem.trigger "setFocus"
  
  # Child Model Events
  onChildRemoveConfig: (model) ->
    @collection.remove model
    @redrawTable()
    windowOnResize()
    @onChildResizeInput()
  
  onChildResizeInput: ->
    @$(".th_inner").css("left", 0)
    setTimeout((=> @$(".th_inner").css("left", "")), 0)
  
  onShowPopup: (name, id) ->
    @trigger "showPopup", name, id
  
  onRemakeCtxMenu: (container) ->
    andy.remakeCtxMenu(@getSaveData()).done ->
      container.dfd.resolve()
  
  onAddCtxMenu: (ctxMenu) ->
    @trigger "addCtxMenu", ctxMenu
  
  onTriggerEventSelected: ->
    @collection.models.forEach (model) ->
      model.trigger "triggerEventCtxMenuSelected"
    @redrawTable()
  
  onSetCtxMenus: (ctxMenus) ->
    @collection.models.forEach (model) ->
      model.unset("ctxMenu")
    ctxMenus.forEach (ctxMenu) =>
      model = @collection.get ctxMenu.id
      model.set "ctxMenu", ctxMenu
  
  onGetCtxMenues: (container) ->
    container.ctxMenus = []
    @collection.models.forEach (model) ->
      if ctxMenu = model.get "ctxMenu"
        container.ctxMenus.push
          id: model.id
          caption: ctxMenu.caption
          contexts: ctxMenu.contexts
          parentId: ctxMenu.parentId
          shortcut: decodeKbdEvent model.id
          order: ctxMenu.order || 999
    container.ctxMenus.sort (a, b) -> a.order - b.order

  onEnterCtxMenuSelMode: (entried) ->
    @$("button").attr("disabled", "disabled").addClass("disabled")
    @collection.models.forEach (model) ->
      model.trigger "setUnselectable", if model.id in entried then true else false
    @$("tbody")
      .sortable("disable")
      .selectable
        cancel: "tr:has(div.ctxmenu-icon)"
        filter: "tr"
      .find("tr:has(div.mode[title='Disabled'])").addClass("unselectable").end()
      .find("tr:has(div.ctxmenu-icon)").addClass("unselectable").end()
      .find("div.mode,div.new,div.origin").addClass("unselectable").end()
    @onStartSort()
  
  onLeaveCtxMenuSelMode: (cancel) ->
    @$("button").removeAttr("disabled").removeClass("disabled")
    @$("tbody")
      .selectable("destroy")
      .sortable("enable")
      .find("div.unselectable").removeClass("unselectable").end()
    if cancel
      @$("tr").removeClass("ui-selected unselectable")
      @redrawTable()

  onGetEditerSize: (container) ->
    if editerSize = @model.get "editerSize"
      container.width = editerSize.width
      container.height = editerSize.height
  
  onSetEditerSize: (width, height) ->
    @model.set "editerSize",
      width:  width
      height: height
  
  onGetSaveData: (container) ->
    container.data = @getSaveData()
  
  onSetSaveData: (newData) ->
    @collection.remove @collection.findWhere new: @placeholder
    @model.set newData.config
    ctxMenuManagerView.collection.reset newData.ctxMenuFolderSet
    while model = @collection.at(0)
      @collection.remove(model)
    loading = true
    @collection.set newData.keyConfigSet
    @redrawTable()
    @collection.models.forEach (model) ->
      if model.get("mode") is "command"
        command = model.get("command")
        if command.name is "execJS" && command.coffee
          andy.coffee2JS model.get("new"), command.content
    andy.remakeCtxMenu @getSaveData()
    loading = false
    windowOnResize()
  
  onGetConfigValue: (key, container) ->
    container.result = @model.get(key)
  
  # DOM Events
  onClickScrollEnd: (event) ->
    scrollable = $(".fixed-table-container-inner")
    if /icon-double-angle-up/.test event.target.className
      scrollTop = 0
    else
      scrollTop = scrollable[0].scrollHeight
    scrollable.animate {scrollTop: scrollTop}, 200
  
  onKeyDown: (event) ->
    unless @model.get "singleKey"
      return
    if (elActive = document.activeElement) && (elActive.tagName in ["TEXTAREA", "INPUT", "SELECT"])
      return
    if keynames = keyIdentifiers[@model.get "kbdtype"][event.originalEvent.keyIdentifier]
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
        @onKbdEvent(scCode + i)
  
  onClickAddKeyConfig: (event) ->
    if @$(".addnew").length > 0
      return
    if @collection.length > gMaxItems
      $("#tiptip_content").text("You have reached the maximum number of items. (Max #{gMaxItems} items)")
      $(event.currentTarget).tipTip defaultPosition: "bottom"
      return false
    newItem$ = $(@tmplAddNew placeholder: @placeholder)
    if /child/.test lastFocused?.className
      lastFocused = $(lastFocused).prevAll(".parent:first")[0]
    @$("tbody")[0].insertBefore newItem$[0], lastFocused
    newItem$.find(".addnew").focus()[0].scrollIntoViewIfNeeded()
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
  
  onChangeLang: ->
    @collection.trigger "changeLang", @model.get("lang")
  
  onChangeKbdtype: ->
    @collection.trigger "changeKbd", @model.get("kbdtype")
  
  onStartSort: ->
    @$("tr.child").hide()
    @$(".ui-placeholder").nextAll("tr.border:first,tr.border:last").remove()
    @$(".parent th:first-child").removeAttr "rowspan"
  
  # Object Method
  redrawTable: ->
    @$("tr.child").show()
    @$("tr.border").remove()
    @collection.models.forEach (model) =>
      model.trigger "setRowspan"
    $("#sortarea").append @$("tr.data")
    @collection.trigger "updateOrderByEl"
    @collection.sort()
    @collection.models.forEach (model) =>
      if parentId = model.get "parentId"
        model.set "order", 999
    @collection.sort()
    @collection.models.forEach (model) =>
      if parentId = model.get "parentId"
        model.set "order", @collection.get(parentId).get("order")
    @collection.sort()
    $.each @collection.models, (i, model) =>
      model.set "order", i
      model.trigger "updatePosition"
    $.each $("#sortarea tr"), (i, tr) =>
      @$("tbody").append tr
    @$("tr.last").removeClass "last"
    $.each @$("tbody > tr"), (i, tr) =>
      unless /child/.test tr.nextSibling?.className
        (tr$ = $(tr)).after @tmplBorder
        if /child/.test tr.className
          tr$.addClass "last"
  
  getSaveData: ->
    @collection.remove @collection.findWhere new: @placeholder
    config: @model.toJSON()
    ctxMenuFolderSet: ctxMenuManagerView.collection.sort().toJSON()
    keyConfigSet: @collection.toJSON()
  
  tmplAddNew: _.template """
    <tr class="addnew">
      <th colspan="3">
        <div class="new addnew" tabIndex="0"><%=placeholder%></div>
      </th>
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
          <div class="th_inner options">Mode</div>
        </th>
        <th class="ctxmenu"></th>
        <th>
          <div class="th_inner desc">Description</div>
          <div class="scrollEnd top"><i class="icon-double-angle-up" title="Scroll to Top"></i></div>
          <div class="scrollEnd bottom"><i class="icon-double-angle-down" title="Scroll to Bottom"></i></div>
        </th>
      </tr>
    </thead>
    <tbody></tbody>
    """

Router = Backbone.Router.extend
  initialize: (options) ->
    {@collection} = options
    @popupType =
      "bookmark"       : "popup"
      "command"        : "popup"
      "bookmarkOptions": "editable"
      "commandOptions" : "editable"
      "optionExtProg"  : "editable"
      "ctxMenuOptions" : "editable"
      "ctxMenuManager" : "editable"
      "settings"       : "editable"
  routes:
    "popup/:name(/:id)(/:option1)(/:option2)"   : "showPopup"
    "editable/:name(/:id)(/:option1)(/:option2)": "showPopup"
    "(:any)": "onNavigateRootPage"
  showPopup: (name, id, option1, option2) ->
    if id
      model = @collection.get id
    @trigger "showPopup", name, model, option1, option2
  onNavigateRootPage: ->
    @navigate "/"
    @trigger "hidePopup"
  onNavigatePopup: (name, id) ->
    params = ""
    Array.prototype.slice.call(arguments, 1).forEach (param) ->
      params += "/" + param if param
    @navigate @popupType[name] + "/" + name + params, {trigger: true}

marginBottom = 0
resizeTimer = false
windowOnResize = ->
  if resizeTimer
    clearTimeout resizeTimer
  resizeTimer = setTimeout((->
    tableHeight = window.innerHeight - document.querySelector(".header").offsetHeight - marginBottom
    document.querySelector(".fixed-table-container").style.height = tableHeight + "px"
    $(".fixed-table-container-inner").getNiceScroll().resize()
    $(".result_outer").getNiceScroll().resize()
  ), 200)

startEdit = ->
  andy.startEdit()
  return
  
endEdit = ->
  andy.endEdit()
  return

andy = chrome.extension.getBackgroundPage().andy

$ = jQuery
$ ->
  keyCodes = andy.getKeyCodes()
  scHelp   = andy.getScHelp()
  scHelpSect = andy.getScHelpSect()
  saveData = andy.local
  
  config = new Config saveData.config
  keyConfigSet = new KeyConfigSet()
  
  router = new Router
    collection: keyConfigSet
  
  headerView = new HeaderView
    model: config
  
  settingsView = new SettingsView
    model: config
  
  keyConfigSetView = new KeyConfigSetView
    model: config
    collection: keyConfigSet
  
  new BookmarksView {}
  new BookmarkOptionsView {}
  new CommandsView {}
  commandOptionsView = new CommandOptionsView {}
  new OptionExtProgView {}
  ctxMenuFolderSet = new CtxMenuFolderSet()
  ctxMenuOptionsView = new CtxMenuOptionsView
    collection: ctxMenuFolderSet
  ctxMenuManagerView = new CtxMenuManagerView
    collection: ctxMenuFolderSet
  
  headerView.on       "showPopup"      , router.onNavigatePopup, router
  keyConfigSetView.on "showPopup"      , router.onNavigatePopup, router
  headerView.on "clickAddKeyConfig"    , keyConfigSetView.onClickAddKeyConfig, keyConfigSetView
  ctxMenuOptionsView.on "getCtxMenues" , keyConfigSetView.onGetCtxMenues , keyConfigSetView
  ctxMenuOptionsView.on "remakeCtxMenu", keyConfigSetView.onRemakeCtxMenu, keyConfigSetView
  ctxMenuManagerView.on "getCtxMenues" , keyConfigSetView.onGetCtxMenues , keyConfigSetView
  ctxMenuManagerView.on "remakeCtxMenu", keyConfigSetView.onRemakeCtxMenu, keyConfigSetView
  keyConfigSet.on "getCtxMenuContexts" , ctxMenuManagerView.onGetCtxMenuContexts, ctxMenuManagerView
  ctxMenuManagerView.on "enterCtxMenuSelMode", keyConfigSetView.onEnterCtxMenuSelMode, keyConfigSetView
  ctxMenuManagerView.on "enterCtxMenuSelMode", headerView.onEnterCtxMenuSelMode, headerView
  ctxMenuManagerView.on "leaveCtxMenuSelMode", keyConfigSetView.onLeaveCtxMenuSelMode, keyConfigSetView
  ctxMenuManagerView.on "leaveCtxMenuSelMode", headerView.onLeaveCtxMenuSelMode, headerView
  ctxMenuManagerView.on "triggerEventSelected", keyConfigSetView.onTriggerEventSelected, keyConfigSetView
  ctxMenuManagerView.on "setCtxMenus", keyConfigSetView.onSetCtxMenus, keyConfigSetView
  commandOptionsView.on "getEditerSize", keyConfigSetView.onGetEditerSize, keyConfigSetView
  commandOptionsView.on "setEditerSize", keyConfigSetView.onSetEditerSize, keyConfigSetView
  settingsView.on "getSaveData", keyConfigSetView.onGetSaveData, keyConfigSetView
  settingsView.on "setSaveData", keyConfigSetView.onSetSaveData, keyConfigSetView
  
  ctxMenuFolderSet.reset saveData.ctxMenuFolderSet
  keyConfigSetView.render(saveData.keyConfigSet)
  
  chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
    switch request.action
      when "kbdEvent"
        keyConfigSetView.collection.trigger "kbdEvent", request.value
      when "saveConfig"
        andy.saveConfig keyConfigSetView.getSaveData()
  
  $(window)
    .on "unload", ->
      andy.saveConfig keyConfigSetView.getSaveData()
    .on "resize", ->
      windowOnResize()
    .on "click", ->
      lastFocused = null
    .on "keydown", (event) ->
      keyConfigSetView.onKeyDown event
  
  windowOnResize()
  
  scrollContainer = $(".fixed-table-container-inner")[0]
  if (scrollContainer.scrollHeight - scrollContainer.offsetHeight) > 40
    $(".footer").addClass("scrolling")
    $(".scrollEnd").show()
  
  Backbone.history.start pushState: false
