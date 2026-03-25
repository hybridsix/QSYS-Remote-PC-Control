:: %1 workspaceFolder             C:\qsys_plugins\plugin
:: %2 workspaceFolderBasename     plugin

:: Q-SYS Designer loads user plugins from:
::   %USERPROFILE%\Documents\QSC\Q-Sys Designer\Plugins\<PluginName>\
SET PLUGIN_DIR=%USERPROFILE%\Documents\QSC\Q-Sys Designer\Plugins\%~2

IF NOT EXIST "%PLUGIN_DIR%" MKDIR "%PLUGIN_DIR%"
COPY /Y "%~1\%~2.qplug" "%PLUGIN_DIR%\%~2.qplug"