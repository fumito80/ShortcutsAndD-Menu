keyCodes = {}
keys = null
placeholder = "Enter new shortcut key"

WebFontConfig =
  google: families: ['Noto+Sans::latin']

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
    proxy: placeholder
    origin: placeholder
    mode: "assignOrg"

KeyConfigSet = Backbone.Collection.extend(model: KeyConfig)

KeyConfigView = Backbone.View.extend
  # Backbone Buitin Events
  kbdtype: null
  
  events:
    "click div.checkbox"   : "onClickCheck"
    "click .origin,.proxy" : "onClickInput"
    "click i.icon-remove"  : "onClickRemove"
  
  initialize: (options) ->
    @model.on
      setFocus: @onClickInput
      remove:   @onRemove
      @
    @model.collection.on
      kbdEvent:    @onKbdEvent
      changeKbd:   @onChangeKbd
      updateOrder: @onUpdateOrder
      @
  
  render: (kbdtype) ->
    @setElement @template(@model.toJSON())
    mode = @model.get("mode")
    @$("i.#{mode}").addClass("hilite")
    @setDispMode mode
    @onChangeKbd kbdtype
    @setHelp()
    @
  
  # Model Events
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
      @setHelp()
      @trigger "resizeInput"
  
  onChangeKbd: (kbdtype) ->
    @kbdtype = kbdtype
    @setKbdValue @$(".proxy"), @model.id
    @setKbdValue @$(".origin"), @model.get("origin")
    @setHelp()
  
  onUpdateOrder: ->
    @model.set "ordernum", @$el.parent().children().index(@$el)
  
  # DOM Events
  onClickCheck: (event) ->
    @$("i.icon-ok").removeClass "hilite"
    target$ = $(event.currentTarget).find("i")
    target$.addClass "hilite"
    value = target$[0].className.replace /icon-ok\s|\shilite/g, ""
    @model.set "mode", value
    @setDispMode value
    @setHelp()
  
  setDispMode: (mode) ->
    @$(".proxy,.origin,.icon-double-angle-right")
      .removeClass("assignOrg simEvent disabled")
      .addClass mode
    if mode is "assignOrg"
      @$(".origin").attr("tabIndex", "0")
    else
      @$(".origin").removeAttr("tabIndex")
  
  onClickInput: (event) ->
    if (event)
      if (target$ = $(event.currentTarget)).hasClass("proxy") || target$.hasClass("origin assignOrg")
        target$.focus()
    else
      @$(".proxy").focus()
  
  onClickRemove: ->
    @trigger "removeConfig", @model
  
  # Object Method
  setKbdValue: (input$, value) ->
    @trigger "decodeKbdEvent", value, container = {}
    input$.text container.result
  
  setHelp: ->
    @$(".desc").empty()
    if (mode = @model.get "mode") is "simEvent"
      #@$("td.desc").empty()
    else
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
          @$("td.desc").append @templateDesc
            sectDesc: scHelpSect[key]
            sectKey:  key
            scHelp:   RegExp.$2

  templateDesc: _.template """
    <div class="sectInit" title="<%=sectDesc%>"><%=sectKey%></div><div class="content"><%=scHelp%></div>
    """
  
  template: _.template """
    <tr>
      <td>
        <div class="proxy" tabIndex="0"></div>
      </td>
      <td>
        <i class="icon-double-angle-right"></i>
      </td>
      <td class="tdOrigin">
        <div class="origin" tabIndex="0"></div>
      </td>
      <td class=" chkItem">
        <div class="checkbox"><i class="icon-ok assignOrg"></i></div>
      </td>
      <td class=" chkItem">
        <div class="checkbox"><i class="icon-ok simEvent"></i></div>
      </td>
      <td class=" chkItem">
        <div class="checkbox"><i class="icon-ok disabled"></i></div>
      </td>
      <td class="desc">
      </td>
      <td class="remove">
        <i class="icon-remove" title="Remove"></i>
      </td>
      <td class="blank">&nbsp;</td>
    </tr>
    """
  
KeyConfigSetView = Backbone.View.extend
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
    @setTableVisible()
    $("button").focus().blur()
    @
  
  # Collection Events
  onAddRender: (model) ->
    keyConfigView = new KeyConfigView(model: model)
    keyConfigView.on "decodeKbdEvent", @onChildDecodeKbdEvent, @
    keyConfigView.on "removeConfig"  , @onChildRemoveConfig  , @
    keyConfigView.on "resizeInput"   , @onChildResizeInput   , @
    @$("tbody").append newChild = keyConfigView.render(@model.get("kbdtype")).$el
    #newChild[0].scrollIntoView true
    @setTableVisible()
    newChild.find(".proxy").focus()
  
  onKbdEvent: (value) ->
    if @$(".addnew").length is 0
      return
    if @collection.findWhere(proxy: value)
      $("#tiptip_content").text("\"#{@decodeKbdEvent(value)}\" is already exists.")
      @$("div.addnew").tipTip()
      return
    #@$(".addnew").remove()
    @collection.add new KeyConfig
      proxy: value
      origin: value
    @$("tbody")
      .sortable("enable")
      .sortable("refresh")
    windowOnResize()
    @onChildResizeInput()
  
  # Child Model Events
  onChildDecodeKbdEvent: (value, container) ->
    container.result = @decodeKbdEvent value
  
  onChildRemoveConfig: (model) ->
    @collection.remove model
    @setTableVisible()
    windowOnResize()
    @onChildResizeInput()
  
  onChildResizeInput: ->
    @$("canvas,.th_inner").css("left", 0)
    setTimeout((=> @$("canvas,.th_inner").css("left", "")), 0)
  
  # DOM Events
  onClickAddKeyConfig: (event) ->
    if @$(".addnew").length > 0
      return
    if @collection.length >= 20
      $("#tiptip_content").text("You have reached the maximum number of items. (Max 20 items)")
      $(event.currentTarget).tipTip(defaultPosition: "right")
      return
    $(@templateAddNew).appendTo(@$("tbody")).find(".proxy").focus()[0].scrollIntoView()
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
    keyCombo.push "Meta" if modifiers & 8
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
    @collection.remove @collection.findWhere proxy: placeholder
    config: @model.toJSON()
    keyConfigSet: @collection.toJSON()
  
  setCanvasHeader: ->
    #fx = -76
    #fy = 120
    fx = 0
    lx = 6.5
    fillText = (ctx, text, fy) ->
      ctx.font = "14px 'Noto Sans'"
      ctx.rotate(325 * Math.PI / 180)
      ctx.fillStyle = "#000000"
      ctx.fillText(text, fx, fy)
    strokeLine = (ctx, fy) ->
      ctx.moveTo lx, fy + 7
      ctx.lineTo lx, 150
      ctx.lineWidth = 1
      ctx.strokeStyle = "#666666"
      ctx.stroke()
    ctx = @$(".check1")[0].getContext("2d")
    strokeLine ctx, 90
    #fillText ctx, "Assign orgin shortcut key", 90
    ctx = @$(".check2")[0].getContext("2d")
    strokeLine ctx, 110
    #fillText ctx, "Simurate key event", 110
    ctx = @$(".check3")[0].getContext("2d")
    strokeLine ctx, 130
    #fillText ctx, "Disabled", 130
  
  templateAddNew: """
    <tr class="addnew">
      <td colspan="3">
        <div class="proxy addnew" tabIndex="0">#{placeholder}</div>
      </td>
      <td></td><td></td><td></td><td></td><td></td>
    </tr>
    """

  template: _.template """
    <thead>
      <tr>
        <th><div class="th_inner">New <i class="icon-double-angle-right"></i> Origin shortcut key</div></th>
        <th></th>
        <th></th>
        <th>
          <div class="th_inner assignOrg">Assign orgin shortcut key</div>
          <canvas class="check1" width="200"></canvas>
        </th>
        <th>
          <div class="th_inner simEvent">Simurate key event</div>
          <canvas class="check2" width="200"></canvas>
        </th>
        <th>
          <div class="th_inner disable">Disabled</div>
          <canvas class="check3" width="200"></canvas>
        </th>
        <th></th>
        <th></th>
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
  ), 200)

fk = chrome.extension.getBackgroundPage().fk
saveData = fk.getConfig()
keyCodes = fk.getKeyCodes()
scHelp   = fk.getScHelp()
scHelpSect = fk.getScHelpSect()

$ = jQuery
$ ->
  headerView = new HeaderView
    model: new Config(saveData.config)
  headerView.render()
  
  keyConfigSetView = new KeyConfigSetView
    model: new Config(saveData.config)
    collection: new KeyConfigSet()
  keyConfigSetView.render(saveData.keyConfigSet)
  
  headerView.on "clickAddKeyConfig", keyConfigSetView.onClickAddKeyConfig, keyConfigSetView
  headerView.on "changeSelKbd"     , keyConfigSetView.onChangeSelKbd     , keyConfigSetView
  
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
    .on "load", ->
      keyConfigSetView.setCanvasHeader()
  
  windowOnResize()
  
  $(".fixed-table-container-inner").niceScroll
    cursorwidth: 12
    cursorborderradius: 2
    smoothscroll: false
    cursoropacitymin: .1
    cursoropacitymax: .6
  
  $(".beta").text("\u03B2")
