keyCodes = {}
keys = null

Config = Backbone.Model.extend({})

KeyConfig = Backbone.Model.extend
  idAttribute: "disShortcut"
  defaults:
    disShortcut: ""
    newShortcut: ""
    option: "assignOther"

KeyConfigSet = Backbone.Collection.extend(model: KeyConfig)

KeyConfigView = Backbone.View.extend
  # Backbone Buitin Events
  events:
    "click input[type='radio']": "onClickRadio"
    "click i.icon-remove"      : "onClickRemove"
    "keydown input.disShortcut": "onKeydownDisSC"
  
  initialize: (options) ->
    @model.on "remove", @onRemove, @
    @model.collection.on
      kbdEvent:    @onKbdEvent
      changeKbd:   @onChangeKbd
      updateOrder: @onUpdateOrder
      @

  render: (kbdtype) ->
    @setElement @template(@model.toJSON())
    option = @model.get("option")
    @$("input[value='#{option}']")
      .attr("checked", "checked")
      .parent().addClass("hilite")
    unless option is "assignOther"
      @$("input.newShortcut").addClass("disabled")
    @onChangeKbd kbdtype
    @
  
  # Model Events
  onRemove: ->
    @model.off null, null, @
    @off null, null, null
    @remove()
  
  # Collection Events
  onKbdEvent: (value) ->
    input$ = @$("input:text:focus")
    if input$.length > 0
      @setKbdValue input$, value
      if input$[0].className is "disShortcut"
        if @model.id isnt value && @model.collection.findWhere(disShortcut: value)
          $("#tiptip_content").text("\"#{input$.val()}\" is a already exists.")
          @setKbdValue input$, @model.id
          input$.tipTip()
          return
        else if (newShortcut$ = @$("input.newShortcut")).val() is ""
          @setKbdValue newShortcut$, value
          @model.set "newShortcut", value
      @model.set input$[0].className, value

  onChangeKbd: (kbdtype) ->
    @setKbdValue @$("input.disShortcut"), @model.id
    @setKbdValue @$("input.newShortcut"), @model.get("newShortcut")
  
  onUpdateOrder: ->
    @model.set "ordernum", @$el.parent().children().index(@$el)
  
  # DOM Events
  onClickRadio: (event) ->
    @$("input[type='radio']").parent().removeClass "hilite"
    target$ = $(event.currentTarget)
    target$.parent().addClass "hilite"
    @model.set "option", target$.val()
    if target$.val() is "assignOther"
      @$("input.newShortcut").removeClass("disabled").focus()
    else
      @$("input.newShortcut").addClass("disabled").blur()

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
    input$.val chars.join(" + ")
    
  template: _.template """
    <div class="innerframe">
      <i class="icon-remove" title="Remove"></i>
      <label>
        <div class="targetCaption">Target shortcut key:</div>
        <input type="text" class="disShortcut" readonly>
      </label>
      <i class="icon-double-angle-right"></i>
      <label>
        <div class="radioCaption">
          <input type="radio" name="options" class="options" value="assignOther">Assign another shortcut key
        </div>
        <input type="text" class="newShortcut" readonly>
      </label>
      <label>
        <div class="radioCaption">
          <input type="radio" name="options" class="options" value="sendDom">Simulate keydown event
        </div>
      </label>
      <label>
        <div class="radioCaption">
          <input type="radio" name="options" class="options" value="disabled">Disabled
        </div>
      </label>
    </div>
    """

KeyConfigSetView = Backbone.View.extend
  # Backbone Buitin Events
  el: "div.outerframe"
  
  events:
    "click button.addKeyConfig": "onClickAddKeyConfig"
    "click button.save"        : "onClickSave"
    "change select.kbdtype"    : "onChangeSelKbd"

  initialize: (options) ->
    @collection.comparator = (model) ->
      model.get("ordernum")
    @collection.on
      add: @onAddRender
      onKeyEvent: @onAddRender
      @
    # キーボード設定
    keys = keyCodes[kbdtype = @model.get("kbdtype")].keys
    selectKbd$ = @$("select.kbdtype")
    $.each keyCodes, (key, item) =>
      selectKbd$.append """<option value="#{key}">#{item.name}</option>"""
    selectKbd$.val kbdtype
  
  render: (keyConfigSet) ->
    @collection.set keyConfigSet
    @$el.focus()
  
  onAddRender: (model) ->
    taskView = undefined
    keyConfigView = new KeyConfigView(model: model)
    @$("div.configSetView").append newChild = keyConfigView.render(@model.get("kbdtype")).$el
    t = (new Date()).getTime()
    newChild
      .find("input.disShortcut").focus().end()
      .find("input:radio").attr("name", "options" + t).end().find("i.icon-double-angle-right").css "top", newChild.height() / 2 - 12
    keyConfigView.on "removeConfig", @onRemoveConfig, @
  
  # Child Model Events
  onRemoveConfig: (model) ->
    @collection.remove model
  
  # DOM Events
  onClickAddKeyConfig: (event) ->
    if @collection.length >= 20
      $("#tiptip_content").text("Registration up to a maximum of 20.")
      $(event.currentTarget).tipTip(defaultPosition: "right")
      return
    @collection.add new KeyConfig({})
    @$("div.configSetView").sortable "refresh"
  
  onChangeSelKbd: (event) ->
    keys = keyCodes[newKbd = event.currentTarget.value].keys
    @collection.trigger "changeKbd", newKbd
    @model.set "kbdtype", newKbd
  
  # Object Method
  userSorted: ->
    @collection.trigger "updateOrder"
    @collection.sort()
  
  getSaveData: ->
    config: @model.toJSON()
    keyConfigSet: @collection.toJSON()

fk = chrome.extension.getBackgroundPage().fk
saveData = fk.getConfig()
keyCodes = fk.getKeyCodes()

$ = jQuery
$ ->
  keyConfigSetView = new KeyConfigSetView
    model: new Config(saveData.config)
    collection: new KeyConfigSet()
  keyConfigSetView.render(saveData.keyConfigSet)
  
  $("div.configSetView").sortable
    delay: 300
    cursor: "move"
    update: -> keyConfigSetView.userSorted()
  
  chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
    switch request.action
      when "kbdEvent"
        keyConfigSetView.collection.trigger "kbdEvent", request.value
      when "saveConfig"
        fk.saveConfig keyConfigSetView.getSaveData()
  
  $(window).on "unload", ->
    fk.saveConfig keyConfigSetView.getSaveData()
  
  $("span.beta").text("\u03B2")
