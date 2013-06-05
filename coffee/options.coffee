keyCodes = {}
keys = null

Config = Backbone.Model.extend({})

KeyConfig = Backbone.Model.extend
  defaults:
    disShortcut: ""
    newShortcut: ""
    option: "assignOther"

KeyConfigSet = Backbone.Collection.extend(model: KeyConfig)

KeyConfigView = Backbone.View.extend
  # Backbone Specified
  events:
    "click input[type='radio']": "onClickRadio"
    "click i.icon-remove": "onClickRemove"
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
    @$("input[value='#{@model.get("option")}']")
      .attr("checked", "checked")
      .parent().addClass("hilite")
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
      @model.set input$[0].className, value

  onChangeKbd: (kbdtype) ->
    @setKbdValue @$("input.disShortcut"), @model.get("disShortcut")
    @setKbdValue @$("input.newShortcut"), @model.get("newShortcut")
  
  onUpdateOrder: ->
    @model.set "ordernum", @$el.parent().children().index(@$el)
  
  # DOM Events
  onClickRadio: (event) ->
    @$("input[type='radio']").parent().removeClass "hilite"
    target$ = $(event.currentTarget)
    target$.parent().addClass "hilite"
    @model.set "option", target$.val()
    target$.parents("label").find("input.newShortcut").focus()  if target$.val() is "assignOther"

  onClickRemove: ->
    @trigger "removeConfig", @model
  
  # Object Method
  setKbdValue: (input$, value) ->
    modif = (splited = value.split(","))[0]
    if key = keys[splited[1]]
      if /Shift/.test(modif) and key[1]
        input$.val modif + " + " + key[1]
      else if key[0]
        input$.val modif + " + " + key[0]
      else
        input$.val ""
    else
      input$.val ""
  
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
          <input type="radio" name="options" class="options" value="assignOther">Assign other shortcut key
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
          <input type="radio" name="options" class="options" value="disable">Disabled
        </div>
      </label>
    </div>
    """

KeyConfigSetView = Backbone.View.extend
  # Backbone Specified
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
    @$("button.addKeyConfig").focus()
  
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
  onClickAddKeyConfig: ->
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
