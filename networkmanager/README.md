## Wi-Fi (NetworkManager + iwd)

系统的 Wi-Fi 由 **NetworkManager** 负责策略层（选配置、DHCP、路由、DNS），底层扫描/认证交给 **iwd**。

### 依赖

```bash
networkmanager  # 网络管理守护进程
iwd              # Wi-Fi 后端（取代 wpa_supplicant）
```

`iwd.service` 不要手动 enable，NetworkManager 会自己拉起它。

### 配置

后端设置在 [`wifi_backend.conf`](./wifi_backend.conf)，安装到 `/etc/NetworkManager/conf.d/wifi_backend.conf`：

```bash
sudo install -Dm644 networkmanager/wifi_backend.conf /etc/NetworkManager/conf.d/wifi_backend.conf
nmcli general reload
```

内容：

```ini
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=false
```

`wifi.backend=iwd` 指定用 iwd 代替 wpa_supplicant 作为 Wi-Fi 后端。

`wifi.iwd.autoconnect=false` 把**自动连接的决策权交回 NetworkManager**。默认是 `true`，也就是由 iwd 自己挑网络连，而 iwd 那套逻辑失败一次就进 `disconnected` 等下一次扫描触发，没人触发就永远不再试 —— 表现为"开机不自动连接、断了不重连"。
NM 1.58 的 `src/core/devices/wifi/nm-device-iwd.c` 里有两处关键行为：

```c
/* There's no need to scan When using IWD's autoconnect ... */
if (!priv->can_scan || priv->scan_requested || priv->current_ap || priv->iwd_autoconnect)
    interval = -1;
```

iwd 模式下 NM **完全不做周期性扫描**，扫描结果一直是开机那次的缓存 —— 这就是控制中心里 Wi-Fi 列表不刷新、必须手点扫描按钮的原因。

```c
/* IWD will not necessarily retry the same network after a failure ... */
if (priv->iwd_autoconnect)
    nm_manager_devcon_autoconnect_retries_set(..., 0);
```

改成 `false` 后由 NM 用自己的配置列表 + 扫描结果按 `connection.autoconnect-priority` 选连接，并每 10 秒扫描一次。

参考：[NetworkManager#1861919](https://bugzilla.redhat.com/show_bug.cgi?id=1861919)、ArchWiki [Using iwd as the Wi-Fi backend](https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend)。

### 控制中心

Wi-Fi 页在 [`.config/quickshell/modules/controlcenter/WifiSection.qml`](../.config/quickshell/modules/controlcenter/WifiSection.qml)：

- 进入页面时真正触发一次扫描，页面开着时每 30 秒扫一次（`nmcli device wifi list` 只返回后端**缓存**的结果，不触发扫描）
- 已保存配置的网络即使这次没扫到也会列出，并标 `Saved`，可直接用存好的密码连接
- 同一 SSID 有多份配置时，优先选没有绑定 `connection.interface-name` 的那份

配置列表由 [`.config/quickshell/scripts/wifi-networks.sh`](../.config/quickshell/scripts/wifi-networks.sh) 导出（`nmcli connection show` 一次拿不到 SSID / 接口绑定 / 加密方式，只能按 uuid 逐个查）。

### 故障排查

**开机不自动连 / 断了不重连**
确认 `/etc/NetworkManager/conf.d/wifi_backend.conf` 里有 `wifi.iwd.autoconnect=false`，然后 `nmcli general reload`。

以下两条**不会**触发自动重连，属于 NetworkManager 的有意行为，不是故障：

- `nmcli device disconnect wlan0` —— 用户明确要求断开，NM 会锁住该设备的 autoconnect
- `nmcli connection down <某个配置>` —— 停用的是哪一个配置，NM 就不会再自动连它，会退到优先级次高的那个

真正掉线（路由器重启、信号中断、射频重置）走的是另一条路径，会正常自动重连。

**列表里少了某个 AP**
先 `nmcli device wifi rescan`。5GHz 频段在开机后可能要过几十秒才稳定可见。

**同一网络出现多份配置**
`nmcli -f NAME,UUID,AUTOCONNECT-PRIORITY connection show` 看有没有重名的。`connection.interface-name` 指向一个本机不存在的接口（比如从别的机器拷过来的 `wlp3s0`）的配置永远激活不了，删掉重名的那份即可。

**5GHz 扫不到 / 刚开机列表里没有**
路由器的 5GHz 如果跑在 **160MHz** 宽度，在 CN 区域码下会越界（5150–5250 只允许 80MHz，160MHz 的信道 36 横跨 5170–5330 进了 DFS 频段），内核可能在早期扫描里过滤掉它。把 5GHz 带宽改成 **80MHz**、信道改成 149/153/157/161（非 DFS）即可。
