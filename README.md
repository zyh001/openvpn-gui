# 荆楚理工学院 VPN 客户端 · 打包

把本仓库这些文件放到你 fork 的 `openvpn-gui` 仓库根目录,推送或打 tag 即可由 GitHub Actions 全自动出包。

## 文件结构

```
installer/
  installer.iss          安装脚本
  JCUT-教育网.ovpn        校园 VPN 配置(文件名 = 托盘里显示的连接名)
  app.ico                学校图标(可选,放了就用,不放也能编译)
build-local.ps1          本地调试打包(可选)
.github/workflows/build-installer.yml   CI 工作流
.gitignore
```

## 怎么用(零本地操作)

```bash
git add installer .github build-local.ps1 .gitignore
git commit -m "添加校园 VPN 客户端打包"
git push
# 出正式版:
git tag v1.0.0
git push origin v1.0.0
```

- 普通 push / 手动触发:在 **Actions** 页跑完后,产物在 run 的 **Artifacts** 里下载。
- 打 `v*` tag:安装包会自动附加到对应 **Release**,学生直接去 Release 页下载。

## CI 自动做了什么

1. 编译你 fork 的定制 GUI(失败会自动退回官方 GUI,保证第一次也能出包)
2. 取出 OpenVPN 运行时(openvpn.exe / openvpnserv.exe / 各 DLL / wintun.dll)
3. **自动探测交互服务启动参数**(不用你手动 `sc qc`)
4. 组装 payload、用 Inno Setup 编译安装包
5. 静默装/卸一轮冒烟测试,确认安装包本身没问题

装好后用户体验:桌面图标 → 打开 GUI → 托盘里点"JCUT-教育网" → 输统一身份账号密码即可。

## 仍需人工的 3 件事

1. **真机连通性测试(必须)**:CI 只验证"能装能卸、文件到位"。真正连上学校 VPN(要输学号密码、要能到达服务器)无法在 CI 里做,务必拿一台干净的 Win10/11(最好快照)装一次、连一次、再用普通账户连一次。
2. **图标(可选)**:把学校 logo 转成 `installer/app.ico` 放进去,安装包和快捷方式就会用它。没有也能编译。
3. **代码签名(建议)**:未签名安装包会触发 SmartScreen 蓝色拦截,学生需点"仍要运行"。学校若有 EV/OV 证书,可在 workflow 里加 signtool 步骤消除警告。

## 注意

- 目标机器**不要同时装官方 OpenVPN**,否则注册表 `HKLM\Software\OpenVPN` 和交互服务可能互相覆盖/冲突。
- 配置用的是 `auth-user-pass`,**不内嵌任何账号密码**,每个学生用自己的统一身份登录。
- openvpn-gui 与 OpenVPN 均为 GPL-2.0,品牌化分发请保留许可与源码可得性(你 fork 已公开,满足要求)。
