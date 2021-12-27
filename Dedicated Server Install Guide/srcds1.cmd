@echo off
title srcds
echo.
echo # 游戏路径, 仅当您的安装路径与指南中的路径不同时才更改此路径.
set DIR=../..
set DAEMON="%DIR%/srcds.exe"
echo.
echo # 根据您的需要更改所有参数.
echo.
echo ############################################## TICKRATE INFO ########################################################
echo #
echo # 只有128 Tickrate及以上需要修改frametime和frametime_override, 100 tick及以下不需要这些参数.
echo # 128 Tickrate 需要添加以下参数: -frametime 0.037 -frametime_override 0.037
echo #
echo #####################################################################################################################
echo.
echo.
echo ############################################# PARAMETERS & SERVER.CFG ###############################################
echo #
echo # 当您在同一台专用机器上托管多个服务器时, SVNUM 会派上用场.
echo # 将 "0.0.0.0" 替换为您的专用服务器 IP.
echo # 将 27020 替换为将托管此 L4D2 服务器的端口.
echo #
echo # 相应地重命名您的 Server.cfg 文件, 如果您只托管一台服务器, 则只需要 server1.cfg
echo # 如果您托管多个服务器, 只需复制 server1.cfg, 更改其中的主机名并将其重命名为 server2.cfg 等等.
echo # 不要忘记复制和编辑文件, SVNUM 必须匹配 server#.cfg 并且端口必须可用.
echo #
echo #####################################################################################################################
echo.
echo # 当前设置将在 Dead Center 1 的 60 Tick 上启动服务器.
set SVNUM=1
set IP=0.0.0.0
set PORT=27020
set NAME=L4D2_Server%SVNUM%
set PARAMS=-console -game left4dead2 -ip %IP% -port %PORT% -noipx -nomaster +sv_clockcorrection_msecs 25 -timeout 10 -tickrate 60 +map c1m1_hotel -maxplayers 32 +servercfgfile server%SVNUM%.cfg
set DESC="L4D2 Dedicated Server #%SVNUM% on port %PORT%"
echo.
echo.
echo ###########################################
echo #                                         #
echo #           DON'T TOUCH THESE             #
echo #                                         #
echo ###########################################
echo.
echo "Starting %DESC%: %NAME%"
start "" %DAEMON% %PARAMS%
ping 127.0.0.1 /n 10 > nul
exit
