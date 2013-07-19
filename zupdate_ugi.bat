set uglifyjs=C:\dev\express\node_modules\.bin\uglifyjs.cmd
set coffee=C:\Users\fumito.Kryten\AppData\Roaming\npm\coffee.cmd

copy flexkbd.dll shortcutsremapper

type coffee\optionsExtends.coffee > coffee\optionsTemp.coffee
type coffee\options.coffee >> coffee\optionsTemp.coffee
cmd /c %coffee% -c coffee

cmd /c %coffee% -bo shortcutsremapper coffee\keyidentifiers.coffee

del coffee\options.js
del coffee\optionsExtends.js
ren coffee\optionsTemp.js options.js

pushd coffee

rem call ../ugi.bat

FOR %%j IN (*.js) DO cmd /c %uglifyjs% -nc %%j > ..\shortcutsremapper\%%j

popd

cmd /c %coffee% -bo shortcutsremapper coffee\keyidentifiers.coffee

pause
