Tailred - L4D2 Entertainment Config

Tailred 是一个基于LGOFNOC建立的的战役配置，使战役模式变得更有趣。

Developer：趴趴酱
Customfogl：趴趴酱
Plugins：趴趴酱、Janus、闲月疏云、Promod、hardcoop、def075、Google
VScripts：Promod
Stripper：Promod
Testing：趴趴酱

感谢大佬们的帮助。

================================================================================
安装说明 （必须按顺序进行）
================================================================================
预安装注意：本指南和相关方案仅供WINDOWS服务器。该指南还假定您拥有一个干净的香草服务器。
目前Linux并不完全支持。设置一个windows服务器上的更多信息请访问：http://www.l4dnation.com/confogl-and-other-configs/does-promod-work-on-windows-server/
本配置已经包含Metamod、Sourcemod等所需文件，您不需要额外的安装步骤。

步骤1 -停止服务器
步骤2 -安装Tailred
步骤3 -启动服务器
================================================================================


-----------------[步骤 1 - 停止服务器]-----------------------------------------
停止你的服务器控制面板的GSP。不做这一步有时导致安装问题。
--------------------------------------------------------------------------------


-----------------[步骤 2 - 安装Tailred]------------------
下载 Tailred http://pan.baidu.com/s/1c1ET8Ko
提取并上传到服务器/ left4dead2 /文件夹,覆盖任何要求。
Tailred现在安装。如果你安装其他配置，确保Tailred插件没有被他们覆盖，否则可能不会按预期工作。
--------------------------------------------------------------------------------


-----------------[步骤 3 - 启动服务器]---------------------------------------
重新启动服务器并连接到它。
一旦在控制台游戏类型“sm version”和“meta version”,以检查是否都安装了。
试着开始一项配置!forcematch Tailred。
检查加载插件类型“sm plugins”控制台,然后输入!resetmatch在聊天,看它是否正确卸载然后尝试另一个配置。
你的服务器现在安装,gg。
-------------------------------------------------------------------------------


===============================================================================
额外的 Q/A
===============================================================================

  ["Commands like !forcestart and !forcematch aren't working."]

  If everything else works, you probably need to set admins in sourcemod.
  See here: http://wiki.alliedmods.net/Adding_Admins_%28SourceMod%29

====================================================================================
LICENSE
====================================================================================

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, either version 3 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program.  If not, see <http://www.gnu.org/licenses/>.

END OF LICENSE
