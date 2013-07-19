set coffee=C:\Users\fumito.Kryten\AppData\Roaming\npm\coffee.cmd

copy flexkbd.dll shortcutsremapper

type coffee\optionsExtends.coffee > coffee\optionsTemp.coffee
type coffee\options.coffee >> coffee\optionsTemp.coffee
cmd /c %coffee% -co shortcutsremapper coffee
rem cmd /c %coffee% -cob shortcutsremapper coffee\indexedDB.coffee
cmd /c %coffee% -bo shortcutsremapper coffee\keyidentifiers.coffee
del shortcutsremapper\options.js
del shortcutsremapper\optionsExtends.js
ren shortcutsremapper\optionsTemp.js options.js
pause
