(function(){var e,t,n;n=function(e,t,n,r,i){var s,o;return o={canBubble:!0,cancelable:!1,view:document.defaultView,keyLocation:0,altGraphKey:!1},s=document.createEvent("KeyboardEvent"),s.initKeyboardEvent("keydown",o.canBubble,o.cancelable,o.view,e,o.keyLocation,t,n,r,i,o.altGraphKey),console.log(s),document.dispatchEvent(s)},t='<div class="frame">\n</div>',e=function(e){window!==parent||window!==window.top},chrome.runtime.onMessage.addListener(function(t,r,i){var s,o,u;switch(t.action){case"askAlive":i("hello");break;case"keyEvent":n(t.keyIdentifier,t.ctrl,t.alt,t.shift,t.meta);break;case"copyText":o="",((u=s=window.getSelection())!=null?u.type:void 0)==="Range"&&(o=s.getRangeAt(0).toString(),i(o));break;case"showCopyHistory":e(t.history)}return!0})}).call(this);