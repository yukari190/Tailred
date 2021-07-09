Tailred

<------------------仅支持WINDOWS服务器 ------------------>

免责声明：在其他配置中使用下载所附带的插件的风险自负。

关于：
此配置基于ZoneMod、Gauntlet修改。
https://github.com/SirPlease/L4D2-Competitive-Rework
https://github.com/brxce/Gauntlet
	
	要求：Sourcemod 1.10 以上。
	
	服务器默认隐藏运行，使用connect <ip地址:端口号>命令进服。解除隐藏方法：
		编辑srcds.cmd删除-nomaster启动参数
		编辑cfg/server_preference.cfg删除sv_tags hidden命令
		
	服务器已使用插件锁定在tickrate 60运行，请不要自行添加、修改tickrate值。
		确保启动参数添加了-tickrate 60
		
	默认自动加载配置，删除server.cfg内的autoloadlgofnoc tailredcoop命令可取消自动加载。
		如果需要使用卸载配置时必须取消自动加载。
		
	服务器名称请修改configs/hostname/hostname.txt
	
    在Server.cfg中添加了"mp_maxplayers"来代替sv_maxplayers，这是用来防止它在每次地图更改时被覆盖。
        在配置卸载时，该值将为Server.cfg中使用的值
		
	可在cfg/sharedplugins.cfg内添加自定义插件，请使用lgofnoc_loadplugin命令添加
	注意：请不要在要手动添加的配置中定义插件加载锁定/解锁。
