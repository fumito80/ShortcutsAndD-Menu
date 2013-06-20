window.db = {}

class db.IndexedDB
  
  constructor: (options) ->
    {schema_name, schema_version, @keyPath} = options
    indexedDB = window.indexedDB or window.webkitIndexedDB or window.mozIndexedDB or window.msIndexedDB
    @storeName = schema_name
    @db
    open_req = indexedDB.open(schema_name, schema_version)
    open_req.onerror = (evt) ->
      console.log "Database error code: " + evt.target.errorCode
    open_req.onsuccess = (evt) =>
      @db = open_req.result if typeof @db is "undefined"
    open_req.onupgradeneeded = (evt) =>
      @db = open_req.result if typeof @db is "undefined"
      @db.deleteObjectStore @storeName  if @db.objectStoreNames.contains(@storeName)
      store = @db.createObjectStore @storeName,
        keyPath: @keyPath
        autoIncrement: false
      store.createIndex @keyPath, true
  
  put: (items) ->
    dfd = $.Deferred()
    _items = (if (items instanceof Array) then items else [items])
    store = @db.transaction([@storeName], "readwrite").objectStore(@storeName)
    $.each _items, (i, _item) =>
      cursor_req = store.openCursor(_item[@keyPath])
      cursor_req.onsuccess = (evt) ->
        
      
      req_add = store.put(_item)
      req_add.onsuccess = (evt) ->
        dfd.resolve()
      req_add.onerror = (evt) ->
        dfd.reject "Unable to save"
    dfd.promise()

  get: (id) ->
    dfd = $.Deferred()
    store = @db.transaction([@storeName], "readonly").objectStore(@storeName)
    cursor_req = store.get(id)
    cursor_req.onsuccess = (e) ->
      dfd.resolve e.target.result
    cursor_req.onerror = (event) ->
      dfd.reject "Unable to get record"
    dfd.promise()
  
  pop: ->
    @getAll 1

  getAll: (maximum) ->
    dfd = $.Deferred()
    maximum = 10  if maximum is "undefined" or maximum is null or maximum is 0
    result = []
    store = @db.transaction([@storeName], "readonly").objectStore(@storeName)
    cursor_req = store.openCursor(null, "prev")
    cursor_req.onsuccess = (e) ->
      dbResult = e.target.result
      if dbResult and result.length < maximum
        result.push dbResult.value
        dbResult.continue()
      else
        dfd.resolve result
    cursor_req.onerror = (event) ->
      dfd.reject "Unable to get records"
    dfd.promise()

  delete: (id) ->
    dfd = $.Deferred()
    store = @db.transaction([@storeName], "readwrite").objectStore(@storeName)
    req_del = store.delete(id)
    req_del.onsuccess = onSuccess = (event) ->
      dfd.resolve()
    req_del.onerror = onError = (event) ->
      dfd.reject "Unable to delete record"
    dfd.promise()

Backbone?.sync = (method, model, options) ->
  is_collection = model.hasOwnProperty("length")
  store = (if is_collection then model.model.store else model.constructor.store)
  switch method
    when "read"
      if is_collection
        store.getAll(options["maximum"])
          .done (records) ->
            options.success records
          .fail ->
            options.error()
      else
        store.get(model.toJSON()["id"])
          .done (record) ->
            options.success record
          .fail ->
            options.error()
    when "create", "update"
      store.put(model.toJSON())
        .done ->
          options.success()
        .fail ->
          options.error()
    when "delete"
      store.delete(model.toJSON()["id"])
        .done ->
          options.success()
        .fail ->
          options.error()
