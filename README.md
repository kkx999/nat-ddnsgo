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


# 第4步
### 安装ddns-go

⚠️ 请修改 :10005 改为你的NAT没被占用的端口
```
wget https://github.com/jeessy2/ddns-go/releases/download/v6.15.0/ddns-go_6.15.0_linux_x86_64.tar.gz
tar -zxvf ddns-go_6.15.0_linux_x86_64.tar.gz
sudo ./ddns-go -s install -l :10005
```

安装完后IPv4地址加刚才安装的端口访问网页(首次登录直接自己随意填写 以后就是按自己填写的登录）

<img width="1265" height="547" alt="屏幕快照 2026-01-23 的 05 45 16 上午" src="https://github.com/user-attachments/assets/990ecd93-3413-466a-9dc0-33fdcd3d0e03" />

进入后台后先选Cloudflare提供商 填写Cloudflare生成的密钥

<img width="912" height="471" alt="屏幕快照 2026-01-23 的 05 47 41 上午" src="https://github.com/user-attachments/assets/65444d4c-5e72-470b-baea-4dffd1e2da20" />

接着看IPv4一栏 选通过接口获取 Domains自己自定义Cloudflare名下域名

<img width="925" height="411" alt="屏幕快照 2026-01-23 的 05 50 07 上午" src="https://github.com/user-attachments/assets/7153d810-638d-4aa0-b620-cb1369037120" />

⚠️如后后续想修改访问端口可以使用以下指令

卸载服务
```
sudo ./ddns-go -s uninstall
```
删除配置文件（可操作可不操作）
```
rm ~/.ddns_go_config.yaml
```
重新安装 改为你新的映射端口
```
sudo ./ddns-go -s install -l :10005
```

# 第5步 安装acme.sh
```
curl https://get.acme.sh | sh
source ~/.bashrc
```
⚠️ 记得把邮箱改成你自己的（当然也可以不改）
```
~/.acme.sh/acme.sh --register-account -m my@example.com
```
导入你Cloudflare生成Token和填你的Cloudflare登录邮箱
```
export CF_Token="这里填你的Token"
export CF_Email="你的CF登录邮箱"
```
申请证书xxxxxxxx.com改完你ddns-go绑定的域名
```
~/.acme.sh/acme.sh --issue --dns dns_cf -d xxxxxxxx.com --server letsencrypt
```
创建存放证书的文件夹
```
mkdir -p /root/cert
```
把证书和密钥移动到指定文件夹
```
~/.acme.sh/acme.sh --install-cert -d xxxxxxx.com --key-file /root/cert/private.key --fullchain-file /root/cert/cert.crt
```
赋予读取权限 (防止面板没权限读取)
```
chmod 755 /root/cert
```
# 第6步 安装3X-UI面板
```
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```
记得选自定义端口 选自己映射的端口或者vps商提供的端口

安装完成后通过ddns-go绑定域名加3x-ui自定义的端口访问

登录成功后 修改密钥路径和公钥路径 然后重启使用https访问

公钥路径
```
/root/cert/cert.crt
```
密钥路径
```
/root/cert/private.key
```
# 大功告成
