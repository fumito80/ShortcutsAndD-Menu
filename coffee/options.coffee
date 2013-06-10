keyCodes = {}
keys = null

WebFontConfig =
  google: families: ['Noto+Sans::latin']

HeaderView = Backbone.View.extend
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
  
  # DOM Events
  onClickAddKeyConfig: (event) ->
    @trigger "clickAddKeyConfig", (event)

  onChangeSelKbd: (event) ->
    @trigger "changeSelKbd", (event)

Config = Backbone.Model.extend({})

KeyConfig = Backbone.Model.extend
  idAttribute: "proxy"
  defaults:
    proxy: ""
    origin: ""
    mode: "assignOrg"

KeyConfigSet = Backbone.Collection.extend(model: KeyConfig)

KeyConfigView = Backbone.View.extend
  # Backbone Buitin Events
  kbdtype: null
  
  events:
    "click div.checkbox"  : "onClickCheck"
    "click input.origin"  : "onClickInputOrigin"
    "click i.icon-remove" : "onClickRemove"
  
  initialize: (options) ->
    @model.on
      setFocus: @onSetFocus
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
    unless mode is "assignOrg"
      @$("input.origin").attr("disabled", "disabled")
    @onChangeKbd kbdtype
    @setHelp()
    @
  
  # Model Events
  onSetFocus: ->
    @$("input.proxy").focus()
  
  onRemove: ->
    @model.off null, null, @
    @off null, null, null
    @remove()
  
  # Collection Events
  onKbdEvent: (value) ->
    input$ = @$("input:text:focus")
    if input$.length > 0
      @setKbdValue input$, value
      if input$[0].className is "proxy"
        if @model.id isnt value && @model.collection.findWhere(proxy: value)
          $("#tiptip_content").text("\"#{input$.val()}\" is already exists.")
          if @model.id
            @setKbdValue input$, @model.id
          else
            input$.val("").removeAttr("data-entry")
          input$.tipTip()
          return
        else if (origin$ = @$("input.origin")).val() is ""
          @setKbdValue origin$, value
          @model.set "origin", value
      @model.set input$[0].className, value
      @setHelp()
  
  onChangeKbd: (kbdtype) ->
    @kbdtype = kbdtype
    @setKbdValue @$("input.proxy"), @model.id
    @setKbdValue @$("input.origin"), @model.get("origin")
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
    if value is "assignOrg"
      @$("input.origin").removeAttr("disabled")
    else
      @$("input.origin").attr("disabled", "disabled").blur()
    @setHelp()
  
  onClickInputOrigin: (event) ->
    unless /assignOrg/.test @$("i.hilite")[0].className
      $(event.currentTarget).blur()
  
  onClickRemove: ->
    @trigger "removeConfig", @model
  
  # Object Method
  setKbdValue: (input$, value) ->
    if !value
      input$.val ""
      return
    modifiers = parseInt(value.substring(0, 2), 16)
    scanCode = value.substring(2)
    keyIdenfiers = keys[scanCode]
    chars = []
    chars.push "Ctrl" if modifiers & 1
    chars.push "Alt"  if modifiers & 2
    chars.push "Meta" if modifiers & 8
    if modifiers & 4
      chars.push "Shift"
      chars.push keyIdenfiers[1] || keyIdenfiers[0]
    else
      chars.push keyIdenfiers[0]
    input$
      .val(chars.join(" + "))
      .attr("data-entry", "true")
  
  setHelp: ->
    @$("td.desc").empty()
    if (mode = @model.get "mode") is "simEvent"
      #@$("td.desc").empty()
    else
      lang = if @kbdtype is "JP" then "ja" else "en"
      if mode is "assignOrg"
        keycombo = @$("input.origin").val()
      else
        keycombo = @$("input.proxy").val()
      keycombo = (keycombo.replace /\s/g, "").toUpperCase()
      unless help = scHelp[keycombo]
        if /^CTRL\+[2-7]$/.test keycombo
          help = scHelp["CTRL+1"]
      if help
        #ol = @$("td.desc")[0].appendChild document.createElement "ol"
        for i in [0...help[lang].length]
          test = help[lang][i].match /(^\w+)\^(.+)/
          @$("td.desc").append $("""<div class="sectInit" title="#{scHelpSect[RegExp.$1]}">#{RegExp.$1}</div><div class="content">#{RegExp.$2}</div>""")
          #ol.appendChild(document.createElement "li").textContent = RegExp.$2
  
  template: _.template """
    <tr>
      <td>
        <input type="text" class="proxy" placeholder="Enter new shortcut key" readonly>
      </td>
      <td>
        <i class="icon-double-angle-right"></i>
      </td>
      <td>
        <input type="text" class="origin" placeholder="Enter orgin shortcut key" readonly>
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
  
  initialize: (options) ->
    @collection.comparator = (model) ->
      model.get("ordernum")
    @collection.on
      add: @onAddRender
      onKeyEvent: @onAddRender
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
  
  onAddRender: (model) ->
    taskView = undefined
    keyConfigView = new KeyConfigView(model: model)
    @$("tbody").append newChild = keyConfigView.render(@model.get("kbdtype")).$el
    newChild.find("input.proxy").focus().end()
    window.scrollTo 0, document.body.scrollHeight
    keyConfigView.on "removeConfig", @onRemoveConfig, @
    @setTableVisible()
  
  # Child Model Events
  onRemoveConfig: (model) ->
    @collection.remove model
    @setTableVisible()
    windowOnResize()
  
  # DOM Events
  onClickAddKeyConfig: (event) ->
    if emptyModel = @collection.get("")
      emptyModel.trigger "setFocus"
      return
    if @collection.length >= 20
      $("#tiptip_content").text("You have reached the maximum number of items. (Max 20 items)")
      $(event.currentTarget).tipTip(defaultPosition: "right")
      return
    @collection.add new KeyConfig({})
    @$("tbody").sortable "refresh"
    windowOnResize()
  
  onChangeSelKbd: (event) ->
    keys = keyCodes[newKbd = event.currentTarget.value].keys
    @collection.trigger "changeKbd", newKbd
    @model.set "kbdtype", newKbd
  
  # Object Method
  setTableVisible: ->
    if @collection.length is 0 then @$el.hide() else @$el.show()
  
  userSorted: ->
    @collection.trigger "updateOrder"
    @collection.sort()
  
  getSaveData: ->
    config: @model.toJSON()
    keyConfigSet: @collection.toJSON()
  
  setCanvasHeader: ->
    #fx = -76
    #fy = 120
    fx = 0
    lx = 9.5
    fillText = (ctx, text, fy) ->
      ctx.moveTo lx, fy + 6
      ctx.lineTo lx, 150
      ctx.lineWidth = 1
      ctx.fillStyle = "#999999"
      ctx.stroke()
      #ctx.font = "14px 'Noto Sans'"
      #ctx.rotate(325 * Math.PI / 180)
      #ctx.fillStyle = "#000000"
      #ctx.fillText(text, fx, fy)
    strokeLine = (ctx, fy) ->
      ctx.moveTo lx, fy + 7
      ctx.lineTo lx, 150
      ctx.lineWidth = 1
      ctx.strokeStyle = "#666666"
      ctx.stroke()
    ctx = @$("canvas.check1")[0].getContext("2d")
    strokeLine ctx, 90
    #fillText ctx, "Assign orgin shortcut key", 90
    ctx = @$("canvas.check2")[0].getContext("2d")
    strokeLine ctx, 110
    #fillText ctx, "Simurate key event", 110
    ctx = @$("canvas.check3")[0].getContext("2d")
    strokeLine ctx, 130
    #fillText ctx, "Disabled", 130
  
  template: _.template """
    <thead>
      <tr>
        <th><div class="th_inner">New shortcut key <i class="icon-double-angle-right"></i> Origin shortcut key</div></th>
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
  
marginBottom = 10
resizeTimer = false
windowOnResize = ->
  if resizeTimer
    clearTimeout resizeTimer
  resizeTimer = setTimeout((->
    tableHeight = window.innerHeight - document.querySelector("div.header").offsetHeight - marginBottom;
    document.querySelector("div.fixed-table-container").style.pixelHeight = tableHeight;
    $("div.fixed-table-container-inner").getNiceScroll().resize()
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
  
  $("div.fixed-table-container-inner").niceScroll
    cursorwidth: 12
    cursorborderradius: 2
    smoothscroll: false
    cursoropacitymin: .1
    cursoropacitymax: .6
  
  $("span.beta").text("\u03B2")
