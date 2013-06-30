set coffee=C:\Users\fumito.Kryten\AppData\Roaming\npm\coffee.cmd

copy flexkbd.dll shortcutsremapper

type coffee\optionsExtends.coffee > coffee\optionsTemp.coffee
type coffee\options.coffee >> coffee\optionsTemp.coffee
cmd /c %coffee% -co shortcutsremapper coffee
rem cmd /c %coffee% -cob shortcutsremapper coffee\indexedDB.coffee
del shortcutsremapper\options.js
del shortcutsremapper\optionsExtends.js
ren shortcutsremapper\optionsTemp.js options.js
pause
