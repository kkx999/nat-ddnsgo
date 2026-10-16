# NAT动态IP 配合ddns-go 实现自动更换IP
## 项目来源及需要用到的平台
[ddns-go](https://github.com/jeessy2/ddns-go)

[3X-UI](https://github.com/MHSanaei/3x-ui)

[cloudflare](https://cloudflare.com)

[Web SSH](https://ssh.hax.co.id)

#第1步 更新相关源和依赖
```
apt update -y
```
```
apt install -y curl wget sudo unzip git
```
```
apt install -y socat
```

# 第2步 
### 访问cloudflare创建api令牌

<img width="1108" height="264" alt="屏幕快照 2026-01-23 的 05 19 48 上午" src="https://github.com/user-attachments/assets/8b1a5324-a795-4379-a052-711f6fc61dc0" />

### 点击创建令牌 编辑区域DNS点击使用模版改成图中所示 然后点继续以显示摘要 再点创建令牌 

<img width="997" height="833" alt="屏幕快照 2026-01-23 的 05 22 21 上午" src="https://github.com/user-attachments/assets/2333368f-6a07-453c-a526-11a8890e97fd" />

### 复制用户API令牌

<img width="435" height="229" alt="屏幕快照 2026-01-23 的 05 25 07 上午" src="https://github.com/user-attachments/assets/ea85eb5b-563e-42a6-9e0f-448180dedd36" />

# 第3步
根据你买的vps提供商提供的IPv6 连接ssh（有IPv6环境可以直接使用ssh工具连接没有则使用Web SSH临时连接）

连上之后输入以下指令 查看IPv4地址
```
curl 4.ipw.cn
```
查询出IPv4后可以重新用IPv4连接ssh （根据你买的vps提供商提供的映射好的22连接端口或自己映射端口）也可以继续使用IPv6操作具体自己随意


# 第4步 自动安装最新版 DDNS-GO

本仓库提供 [install-ddns-go.sh](./install-ddns-go.sh)，**每次全新安装时自动查询 [DDNS-GO 官方最新正式版](https://github.com/jeessy2/ddns-go/releases/latest)**，根据 Linux CPU 架构下载安装包、校验官方 SHA256，并注册系统服务；无需手动填写固定版本号。

**使用 root 用户运行**（第 1 步已安装 curl）。以下示例监听端口为 `10005`，可以将末尾端口号改为 NAT VPS 实际需要监听的内部端口：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kkx999/nat-ddnsgo/main/install-ddns-go.sh) 10005
```

脚本支持常见 Linux x86_64、ARM 等架构；不支持的架构或缺少上游安装包时会停止，不会盲目安装。首次安装后程序位于 `/usr/local/bin/ddns-go`。

> **注意：** 这里的“最新版”指**执行全新安装命令时自动选择最新版**，并非让 DDNS-GO 以后后台自动升级。为避免影响原有服务，脚本检测到已安装的 DDNS-GO 时会停止，不会覆盖配置或正在运行的版本。监听 `:10005` 可能暴露管理后台，务必做好公网访问限制和账号初始化。

安装完成后通过 VPS 服务商提供的公网映射 IP 和端口访问网页，并尽快完成首次账号初始化。**公网映射端口不一定等于 VPS 内部监听端口**。

<img width="1265" height="547" alt="屏幕快照 2026-01-23 的 05 45 16 上午" src="https://github.com/user-attachments/assets/990ecd93-3413-466a-9dc0-33fdcd3d0e03" />

进入后台后先选 Cloudflare 提供商，填写 Cloudflare 生成的 API Token。

<img width="912" height="471" alt="屏幕快照 2026-01-23 的 05 47 41 上午" src="https://github.com/user-attachments/assets/65444d4c-5e72-470b-baea-4dffd1e2da20" />

接着在 IPv4 一栏选择“通过接口获取”，Domains 填写 Cloudflare 名下需要更新的域名。

<img width="925" height="411" alt="屏幕快照 2026-01-23 的 05 50 07 上午" src="https://github.com/user-attachments/assets/7153d810-638d-4aa0-b620-cb1369037120" />

### 可选：修改 DDNS-GO 监听端口

以下操作仅用于需要改变**已有服务**的监听端口，不属于日常安装步骤。先卸载服务（不会主动删除 DDNS-GO 配置），再用原来的二进制文件安装到新端口：

```bash
sudo /usr/local/bin/ddns-go -s uninstall
sudo /usr/local/bin/ddns-go -s install -l :10005
```

将 `10005` 改为实际需要的内部监听端口。**不要删除 `~/.ddns_go_config.yaml`：删除配置文件可能导致域名和 API Token 设置丢失。**

# 第5步 一键申请 SSL 证书

本仓库提供独立的 [nat-cert.sh](./nat-cert.sh) 脚本，用于 NAT VPS 通过 **Cloudflare DNS-01** 申请 Let's Encrypt 证书并配置自动续签；不需要开放公网 80 / 443 端口。

**适用系统：Debian / Ubuntu，使用 root 用户在交互式 SSH 终端运行。**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kkx999/nat-ddnsgo/main/nat-cert.sh)
```

按提示输入：邮箱、要申请证书的域名（如 `nat.example.com`）、Cloudflare API Token（输入时不显示）。Token 应仅授权所需 DNS 区域及 DNS 编辑权限；不要将 Token 写到公开文件中。

脚本自动完成依赖与 acme.sh 安装、cron 自动续签任务配置、DNS 验证、ECC 证书部署，并保存续签后重启 3X-UI 的回调。

> **顺序说明：** 第 5 步运行时尚未安装 3X-UI，首次部署证书会正常跳过重启；第 6 步安装面板并设置证书路径后，后续成功续签会自动重启 `x-ui`。如果已经装好 3X-UI，脚本也可以单独使用。

证书默认放在与域名对应的目录中（将 `nat.example.com` 替换为实际域名）：

```text
/root/cert/nat.example.com/fullchain.pem
/root/cert/nat.example.com/privkey.pem
```

检查自动续签与证书信息（非强制续签）：

```bash
crontab -l | grep acme.sh
/root/.acme.sh/acme.sh --list
openssl x509 -in /root/cert/nat.example.com/fullchain.pem -noout -dates
```

如果脚本提示签发失败，首先检查 Cloudflare Token 的权限与证书域名是否属于授权的 DNS 区域。脚本不会删除原有的 DDNS-GO 配置，也不修改系统的 apt 配置文件。

# 第6步 安装3X-UI面板

```bash
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```

安装时设置为 NAT VPS 已映射的可用服务端口，注意区分公网映射端口与 VPS 内部监听端口。

面板安装完成后，在面板设置中填写第 5 步输出的**实际证书路径**和**私钥路径**，不要再使用旧教程的 `/root/cert/cert.crt`、`/root/cert/private.key`：

证书路径：

```text
/root/cert/nat.example.com/fullchain.pem
```

私钥路径：

```text
/root/cert/nat.example.com/privkey.pem
```

保存设置后，重启面板使 HTTPS 配置生效：

```bash
systemctl restart x-ui
```

随后使用已配置的域名和对应公网映射端口通过 HTTPS 访问面板。后续证书成功续签时，`nat-cert.sh` 注册的 acme.sh 回调会自动重启已安装的 3X-UI。

# 大功告成
### Telegram机器人通知模版
```
https://api.telegram.org/bot机器人密钥/sendMessage
```
```
{
    "chat_id": "账户数字id",
    "text": "🚨 IPv4 变动通知\n\n🌏 新 IP: #{ipv4Addr}\n🏠 域名: #{ipv4Domains}\n✅ 状态: #{ipv4Result}",
    "parse_mode": "Markdown"
}
```
```
Content-Type: application/json
```
