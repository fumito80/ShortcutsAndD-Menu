keyCodes = {}
keys = undefined
Config = Backbone.Model.extend({})

KeyConfig = Backbone.Model.extend
  defaults:
    disShortcut: ""
    newShortcut: ""
    option: "sendDom"

KeyConfigSet = Backbone.Collection.extend(model: KeyConfig)

KeyConfigView = Backbone.View.extend
  events:
    "click input[type='radio']": "onClickRadio"
    "click i.icon-remove": "onClickRemove"
    "keydown input.disShortcut": "onKeydownDisSC"

  initialize: (options) ->
    @model.on "remove", @onRemove, this
    @model.collection.on "kbdEvent", @onKbdEvent, this

  onKbdEvent: (value) ->
    input$ = @$("input:text:focus")
    if input$.length > 0
      @setKbdValue input$, value
      @model.set input$[0].className, value

  setKbdValue: (input$, value) ->
    modif = (splited = value.split(","))[0]
    key = undefined
    if key = keys[splited[1]]
      if /Shift/.test(modif) and key[1]
        input$.val modif + " + " + key[1]
      else if key[0]
        input$.val modif + " + " + key[0]
      else
        input$.val ""
    else
      input$.val ""

  render: ->
    @setElement @template(@model.toJSON())
    @$("input[value='" + @model.get("option") + "']").attr "checked", "checked"
    this

  onClickRadio: (event) ->
    @$("input[type='radio']").parent().removeClass "bold"
    target$ = $(event.currentTarget)
    target$.parent().addClass "bold"
    @model.set "option", target$[0].className
    target$.parents("label").find("input.newShortcut").focus()  if target$.val() is "assignOther"

  onClickRemove: ->
    @trigger "removeConfig", @model

  onRemove: ->
    @model.off null, null, this
    @off null, null, null
    @remove()

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
        <div class="radioCaption bold">
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
  el: "div.outerframe"
  
  events:
    "click button.addKeyConfig": "onClickAddKeyConfig"
    "click button.save": "onClickSave"

  initialize: (options) ->
    @collection.on
      add: @onAddRender
      onKeyEvent: @onAddRender
    , this
    keys = keyCodes[@model.get("kbdtype")]

  render: ->
    @collection.set @model.get("keyConfigSet")

  onAddRender: (model) ->
    taskView = undefined
    keyConfigView = new KeyConfigView(model: model)
    @$("div.configSetView").append newChild = keyConfigView.render().$el
    t = (new Date()).getTime()
    newChild.find("input:radio").attr("name", "options" + t).end().find("i.icon-double-angle-right").css "top", newChild.height() / 2 - 12
    keyConfigView.on "removeConfig", @onRemoveConfig, this

  onClickSave: ->
    fireKeyEvent()

  onRemoveConfig: (model) ->
    @collection.remove model

  onClickAddKeyConfig: ->
    @collection.add new KeyConfig({})

bkg = chrome.extension.getBackgroundPage()
config = bkg.getConfig()
keyCodes = bkg.getKeyCodes()

$ = jQuery
$ ->
  keyConfigSetView = new KeyConfigSetView(
    model: new Config(config)
    collection: new KeyConfigSet()
  )
  keyConfigSetView.render()

chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
  if request.key is "kbdEvent"
    keyConfigSetView.collection.trigger "kbdEvent", request.value
