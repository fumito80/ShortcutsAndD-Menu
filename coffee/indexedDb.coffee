WebShareDB = ->
  schema_name = "webshare"
  schema_version = 2
  indexedDB = window.indexedDB or window.webkitIndexedDB or window.mozIndexedDB or window.msIndexedDB
  deferred = $.Deferred()
  @promise = deferred.promise()
  @store_webshare = "webshare"
  @db
  self = this
  open_req = indexedDB.open(schema_name, schema_version)
  open_req.onerror = (evt) ->
    console.log "Database error code: " + evt.target.errorCode
    deferred.reject evt

  open_req.onsuccess = (evt) ->
    self.db = open_req.result  if typeof self.db is "undefined"
    deferred.resolve evt

  open_req.onupgradeneeded = (evt) ->
    self.db = open_req.result  if typeof self.db is "undefined"
    self.db.deleteObjectStore self.store_webshare  if self.db.objectStoreNames.contains(self.store_webshare)
    self.db.createObjectStore self.store_webshare,
      keyPath: "id"
      autoIncrement: true

WebShareDB::put = (items) ->
  d = $.Deferred()
  self = this
  @promise.done ->
    _items = (if (items instanceof Array) then items else [items])
    store = self.db.transaction([self.store_webshare], "readwrite").objectStore(self.store_webshare)
    $.each _items, (i, _item) ->
      req_add = store.put(_item)
      req_add.onsuccess = onSuccess = (evt) ->
        d.resolve()

      req_add.onerror = onError = (evt) ->
        d.reject "Unable to save"


  @promise.fail ->
    d.reject "Unable to open database"

  d.promise()

WebShareDB::get = (id) ->
  d = $.Deferred()
  self = this
  @promise.done ->
    store = self.db.transaction([self.store_webshare], "readonly").objectStore(self.store_webshare)
    cursor_req = store.get(id)
    cursor_req.onsuccess = (e) ->
      d.resolve e.target.result

    cursor_req.onerror = onError = (event) ->
      d.reject "Unable to get record"

    @promise.fail ->
      d.reject "Unable to open database"


  d.promise()

WebShareDB::pop = ->
  @getAll 1

WebShareDB::getAll = (maximum) ->
  d = $.Deferred()
  self = this
  @promise.done ->
    maximum = 10  if maximum is "undefined" or maximum is null or maximum is 0
    web_shares = []
    store = self.db.transaction([self.store_webshare], "readonly").objectStore(self.store_webshare)
    cursor_req = store.openCursor(null, "prev")
    cursor_req.onsuccess = (e) ->
      result = e.target.result
      if result and web_shares.length < maximum
        web_shares.push result.value
        result.continue()
      else
        d.resolve web_shares

    cursor_req.onerror = onError = (event) ->
      d.reject "Unable to get records"

  @promise.fail ->
    d.reject "Unable to open database"

  d.promise()

WebShareDB::delete = (id) ->
  d = $.Deferred()
  self = this
  @promise.done ->
    store = self.db.transaction([self.store_webshare], "readwrite").objectStore(self.store_webshare)
    req_del = store.delete(id)
    req_del.onsuccess = onSuccess = (event) ->
      d.resolve()

    req_del.onerror = onError = (event) ->
      d.reject "Unable to delete record"

    @promise.fail ->
      d.reject "Unable to open database"


  d.promise()

Backbone.sync = (method, model, options) ->
  is_collection = model.hasOwnProperty("length")
  store = (if is_collection then model.model.store else model.constructor.store)
  switch method
    when "read"
      if is_collection
        store.getAll(options["maximum"]).done((records) ->
          options.success records
        ).fail ->
          options.error()

      else
        store.get(model.toJSON()["id"]).done((record) ->
          options.success record
        ).fail ->
          options.error()

    when "create"
      store.put(model.toJSON()).done(->
        options.success()
      ).fail ->
        options.error()

    when "update"
      store.put(model.toJSON()).done(->
        options.success()
      ).fail ->
        options.error()

    when "delete"
      store.delete(model.toJSON()["id"]).done(->
        options.success()
      ).fail ->
        options.error()
