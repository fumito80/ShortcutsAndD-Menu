copy flexkbd.dll extension
:cmd /c coffee -co extension coffee
cmd /c coffee -c coffee

cd coffee

FOR %%j IN (*.js) DO uglifyjs %%j > ..\extension\%%j

pause
