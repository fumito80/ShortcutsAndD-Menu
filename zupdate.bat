set coffee=C:\Users\fumito.Kryten\AppData\Roaming\npm\coffee.cmd

copy flexkbd.dll shortcutsandy

type coffee\optionsExtends.coffee > coffee\optionsTemp.coffee
type coffee\options.coffee >> coffee\optionsTemp.coffee
cmd /c %coffee% -co shortcutsandy coffee
rem cmd /c %coffee% -cob shortcutsandy coffee\indexedDB.coffee
cmd /c %coffee% -bo shortcutsandy coffee\keyidentifiers.coffee
del shortcutsandy\options.js
del shortcutsandy\optionsExtends.js
ren shortcutsandy\optionsTemp.js options.js
pause
