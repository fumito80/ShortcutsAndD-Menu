(function(){window.db={},db.IndexedDB=function(){function e(e){var t,n,r,i,s=this;r=e.schema_name,i=e.schema_version,this.keyPath=e.keyPath,t=window.indexedDB||window.webkitIndexedDB||window.mozIndexedDB||window.msIndexedDB,this.storeName=r,this.db,n=t.open(r,i),n.onerror=function(e){return console.log("Database error code: "+e.target.errorCode)},n.onsuccess=function(e){if(typeof s.db=="undefined")return s.db=n.result},n.onupgradeneeded=function(e){var t;return typeof s.db=="undefined"&&(s.db=n.result),s.db.objectStoreNames.contains(s.storeName)&&s.db.deleteObjectStore(s.storeName),t=s.db.createObjectStore(s.storeName,{keyPath:s.keyPath,autoIncrement:!1}),t.createIndex(s.keyPath,!0)}}return e.prototype.put=function(e){var t,n,r,i=this;return t=$.Deferred(),r=e instanceof Array?e:[e],n=this.db.transaction([this.storeName],"readwrite").objectStore(this.storeName),$.each(r,function(e,r){var s,o;return s=n.openCursor(r[i.keyPath]),s.onsuccess=function(e){},o=n.put(r),o.onsuccess=function(e){return t.resolve()},o.onerror=function(e){return t.reject("Unable to save")}}),t.promise()},e.prototype.get=function(e){var t,n,r;return n=$.Deferred(),r=this.db.transaction([this.storeName],"readonly").objectStore(this.storeName),t=r.get(e),t.onsuccess=function(e){return n.resolve(e.target.result)},t.onerror=function(e){return n.reject("Unable to get record")},n.promise()},e.prototype.pop=function(){return this.getAll(1)},e.prototype.getAll=function(e){var t,n,r,i;n=$.Deferred();if(e==="undefined"||e===null||e===0)e=10;return r=[],i=this.db.transaction([this.storeName],"readonly").objectStore(this.storeName),t=i.openCursor(null,"prev"),t.onsuccess=function(t){var i;return i=t.target.result,i&&r.length<e?(r.push(i.value),i["continue"]()):n.resolve(r)},t.onerror=function(e){return n.reject("Unable to get records")},n.promise()},e.prototype["delete"]=function(e){var t,n,r,i,s;return t=$.Deferred(),s=this.db.transaction([this.storeName],"readwrite").objectStore(this.storeName),i=s["delete"](e),i.onsuccess=r=function(e){return t.resolve()},i.onerror=n=function(e){return t.reject("Unable to delete record")},t.promise()},e}(),typeof Backbone!="undefined"&&Backbone!==null&&(Backbone.sync=function(e,t,n){var r,i;r=t.hasOwnProperty("length"),i=r?t.model.store:t.constructor.store;switch(e){case"read":return r?i.getAll(n.maximum).done(function(e){return n.success(e)}).fail(function(){return n.error()}):i.get(t.toJSON().id).done(function(e){return n.success(e)}).fail(function(){return n.error()});case"create":case"update":return i.put(t.toJSON()).done(function(){return n.success()}).fail(function(){return n.error()});case"delete":return i["delete"](t.toJSON().id).done(function(){return n.success()}).fail(function(){return n.error()})}})}).call(this);