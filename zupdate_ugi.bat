set uglifyjs=C:\dev\express\node_modules\.bin\uglifyjs.cmd
set coffee=C:\Users\fumito.Kryten\AppData\Roaming\npm\coffee.cmd

copy flexkbd.dll shortcutsremapper

type coffee\optionsExtends.coffee > coffee\optionsTemp.coffee
type coffee\options.coffee >> coffee\optionsTemp.coffee
cmd /c %coffee% -c coffee

del coffee\options.js
del coffee\optionsExtends.js
ren coffee\optionsTemp.js options.js

cd coffee

FOR %%j IN (*.js) DO %uglifyjs% -nc %%j > ..\shortcutsremapper\%%j

pause
