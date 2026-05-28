# Windows セットアップガイド

ROS1 Noetic Docker ワークスペースを Windows で動かすための手順書です．

---

## 目次

1. [システム要件](#1-システム要件)
2. [WSL2 の有効化](#2-wsl2-の有効化)
3. [Git for Windows のインストール・設定](#3-git-for-windows-のインストール設定)
4. [Docker Desktop のインストール・設定](#4-docker-desktop-のインストール設定)
5. [VcXsrv のインストール・設定（GUI使用時）](#5-vcxsrv-のインストール設定gui使用時)
6. [リポジトリのクローン](#6-リポジトリのクローン)
7. [初回セットアップ](#7-初回セットアップ)
8. [基本的な使い方](#8-基本的な使い方)
9. [USB デバイスのパススルー（usbipd-win）](#9-usb-デバイスのパススルーusbipd-win)
10. [ジョイスティックの使い方](#10-ジョイスティックの使い方)
11. [シリアル通信の設定](#11-シリアル通信の設定)
12. [トラブルシューティング](#12-トラブルシューティング)

> **CAN 通信について**: SocketCAN は Linux カーネルの機能であり，WSL2 のデフォルトカーネルには CAN モジュールが含まれていないため，**Windows 環境では CAN 通信は非対応**です．CAN を使用する場合は Linux 環境（`make` コマンド）を利用してください．

---

## コマンドの実行場所について

このガイドでは，コマンドを実行する場所を以下の表記で統一しています．

| 表記 | 実行場所 |
|---|---|
| **PowerShell** | Windows PowerShell（通常権限）|
| **PowerShell（管理者）** | Windows PowerShell（管理者として実行）|
| **コンテナ内** | `.\run.ps1 shell` でコンテナに入った後の bash |

各コードブロックの先頭行にコメントで実行場所を明記しています．

---

## 1. システム要件

| 項目 | 要件 |
|---|---|
| OS | Windows 10 バージョン 2004 以降（Build 19041+）または Windows 11 |
| RAM | 8 GB 以上（16 GB 推奨） |
| ストレージ | 空き 20 GB 以上 |
| CPU | 仮想化対応（Intel VT-x / AMD-V が BIOS で有効） |

> **仮想化の確認**: タスクマネージャー → パフォーマンス → CPU →「仮想化: 有効」になっていること．

---

## 2. WSL2 の有効化

Docker Desktop の動作に WSL2 が必要です．管理者権限の PowerShell を開いて実行します．

```powershell
# 実行場所: PowerShell（管理者）

# WSL と仮想マシンプラットフォームを有効化
wsl --install

# 再起動後，WSL2 をデフォルトに設定
wsl --set-default-version 2
```

> `wsl --install` 実行後に再起動を求められたら再起動してください．  
> Ubuntu が自動インストールされますが，Docker Desktop さえあれば直接使わなくて構いません．

---

## 3. Git for Windows のインストール・設定

### インストール

[公式サイト](https://git-scm.com/download/win)から最新版をダウンロードしてインストールします．

インストール時の推奨オプション:

| 設定項目 | 推奨値 |
|---|---|
| デフォルトエディタ | Visual Studio Code（または好みのもの） |
| PATH 環境 | **Git from the command line and also from 3rd-party software** |
| 改行コード変換 | **Checkout as-is, commit as-is** |
| ターミナル | Windows の標準ターミナル または Git Bash |

### Git の初期設定

インストール後，**PowerShell** または **Git Bash** で以下を実行します．

```powershell
# 実行場所: PowerShell

# ユーザー情報（必須）
git config --global user.name  "Your Name"
git config --global user.email "your@email.com"

# 改行コード変換を無効化（シェルスクリプトの LF を保持するために必須）
git config --global core.autocrlf false

# デフォルトブランチ名（任意）
git config --global init.defaultBranch main
```

> **重要**: `core.autocrlf false` を設定しないと `.sh` ファイルが CRLF になり，  
> Docker コンテナ内で実行エラーが発生します．  
> リポジトリ内の `.gitattributes` でも `.sh` の LF を強制していますが，  
> global 設定もあわせて行うことを推奨します．

---

## 4. Docker Desktop のインストール・設定

### インストール

[公式サイト](https://www.docker.com/products/docker-desktop/)から「Docker Desktop for Windows」をダウンロードしてインストールします．

### セットアップ

1. インストール後，Docker Desktop を起動
2. 初回起動時に利用規約への同意画面が表示されたら **「Accept」** をクリック
3. WSL 2 ベースエンジンが有効になっているか確認:  
   Settings → General → **「Use the WSL 2 based engine」** にチェックが入っていること

> **補足**: 古いバージョンでは初回ウィザードに「Use WSL 2 instead of Hyper-V」という選択肢が表示されていましたが，  
> 新しいバージョン（Docker Desktop 4.x 以降）ではウィザードが簡略化され，WSL 2 が自動的に選択されるようになっています．


> **Gazebo など重い GUI ツールを使用する場合**: WSL 2 はデフォルトでホスト RAM の最大 50% を使用するため，Windows 側が重くなることがあります．  
> その場合は `%USERPROFILE%\.wslconfig` でリソース制限を行うことを検討してください．  
> 例: `memory=4GB` / `processors=4` / `swap=2GB`

### 動作確認

```powershell
# 実行場所: PowerShell

docker version
docker compose version
```

エラーなく表示されれば OK です．

---

## 5. VcXsrv のインストール・設定（GUI使用時）

RViz・Gazebo などの GUI を使うには，Windows 側で X サーバーを動かす必要があります．

> **WSLg について**: Windows 11 の WSLg は WSL2 ターミナル内から直接起動するアプリには使えますが，  
> **PowerShell から起動した Docker コンテナからは WSLg にアクセスできません**．VcXsrv が必要です．

### インストール

[SourceForge](https://sourceforge.net/projects/vcxsrv/)から最新版をダウンロードしてインストールします．  
インストールすると **XLaunch**（VcXsrv の設定・起動ツール）がスタートメニューに追加されます．

### 起動設定

スタートメニューから **XLaunch** を開き，以下の順に設定します．

1. **Display settings**: `Multiple windows`，Display number: `0`
2. **Session type**: `Start no client`
3. **Extra settings**:
   - `Clipboard` にチェック
   - `Primary Selection` にチェック
   - **`Disable access control` にチェック** ← 重要
4. **Finish** をクリックして起動

> **自動起動設定（任意）**: 設定後「Save configuration」で `config.xlaunch` を保存し，  
> スタートアップフォルダ（`shell:startup`）に配置すると起動時に自動で立ち上がります．

### Windows ファイアウォールの設定

VcXsrv 初回起動時にファイアウォールの許可ダイアログが出た場合，**「プライベートネットワーク」と「パブリックネットワーク」の両方を許可**してください．

---

## 6. リポジトリのクローン

PowerShell を開いて，任意のディレクトリでクローンします．

```powershell
# 実行場所: PowerShell

# 例: C:\Users\username\Projects に配置する場合
cd C:\Users\$env:USERNAME\Projects

git clone <リポジトリURL>
cd ros1_docker_ws
```

---

## 7. 初回セットアップ

### PowerShell の実行ポリシー設定

スクリプト実行を許可します（管理者権限は不要）．

```powershell
# 実行場所: PowerShell

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Docker イメージのビルド

```powershell
# 実行場所: PowerShell（リポジトリのルートディレクトリで実行）

.\run.ps1 build
```

初回は数分かかります．

### catkin ワークスペースの初期化

```powershell
# 実行場所: PowerShell（リポジトリのルートディレクトリで実行）

.\run.ps1 catkin-init
```

---

## 8. 基本的な使い方

すべてのコマンドはリポジトリのルートで `.\run.ps1 <コマンド>` の形式で実行します．

### コンテナの起動・停止

```powershell
# 実行場所: PowerShell（リポジトリのルートディレクトリで実行）

.\run.ps1 up        # コンテナをバックグラウンドで起動
.\run.ps1 shell     # 実行中コンテナの bash に入る
.\run.ps1 down      # コンテナを停止
```

### catkin ビルド

```powershell
# 実行場所: PowerShell（リポジトリのルートディレクトリで実行）

# src/ にパッケージを配置後
.\run.ps1 rosdep-install   # 依存パッケージをインストール
.\run.ps1 catkin-build     # ビルド

# 特定パッケージのみ
.\run.ps1 catkin-build-pkg -PKG my_package
```

### GUI ツール（RViz / Gazebo）

XLaunch が起動している状態で実行します．

```powershell
# 実行場所: PowerShell（リポジトリのルートディレクトリで実行）

.\run.ps1 rviz    # RViz を起動
.\run.ps1 gazebo  # Gazebo を起動
```

### ジョイスティック

ジョイスティックを使う場合は先に [セクション 10](#10-ジョイスティックの使い方) の usbipd-win アタッチを完了してください．

```powershell
# 実行場所: PowerShell（リポジトリのルートディレクトリで実行）

# デフォルト（/dev/input/js0）
.\run.ps1 joy

# デバイスを指定する場合
.\run.ps1 joy -JsDev /dev/input/js1
```

### rosbag

```powershell
# 実行場所: PowerShell（リポジトリのルートディレクトリで実行）

# 全トピックを録画
.\run.ps1 bag-record

# 特定トピックを録画
.\run.ps1 bag-record -TOPICS "/cmd_vel /odom /scan"

# 再生（通常速度）
.\run.ps1 bag-play -BAG 2024-01-01-12-00-00.bag

# 0.5倍速で再生
.\run.ps1 bag-play -BAG 2024-01-01-12-00-00.bag -RATE 0.5

# メタ情報確認
.\run.ps1 bag-info -BAG 2024-01-01-12-00-00.bag

# 一覧表示
.\run.ps1 bag-list
```

### コマンド一覧

```powershell
# 実行場所: PowerShell（リポジトリのルートディレクトリで実行）

.\run.ps1 help
```

---

## 9. USB デバイスのパススルー（usbipd-win）

Windows では Docker コンテナに USB デバイスを直接渡せないため，**usbipd-win** を使用して WSL2 経由でコンテナにパススルーします．USB シリアルアダプタ（CH340，FTDI 等）はこの手順で接続します．

### 9-1. usbipd-win のインストール

**管理者権限の PowerShell** で以下を実行します（winget を使用）．

```powershell
# 実行場所: PowerShell（管理者）

winget install usbipd
```

または [GitHub](https://github.com/dorssel/usbipd-win) から最新のインストーラーをダウンロードしてインストールします．

インストール後，PowerShell を再起動してください．

### 9-2. Docker Desktop の WSL integration 確認

Docker Desktop の Settings → Resources → **WSL Integration** で，使用する WSL2 ディストリビューション（通常は Ubuntu）が有効になっていることを確認します．

### 9-3. USB デバイスのアタッチ手順（毎回必要）

USB デバイスを PC に接続した後，**管理者権限の PowerShell** で以下を実行します．

**ステップ 1: 接続されている USB デバイスを確認**

```powershell
# 実行場所: PowerShell（管理者）

usbipd list
```

出力例:
```
BUSID  VID:PID    DEVICE                              STATE
2-1    0403:6001  USB Serial Converter (CH340)        Not shared
2-3    046d:c52b  USB Receiver                        Not shared
```

**ステップ 2: デバイスをバインド（初回のみ）**

`BUSID` はデバイスを PC の別の USB ポートに差し替えると変わる場合があります．  
初回または BUSID が変わったときに実行します．

```powershell
# 実行場所: PowerShell（管理者）

usbipd bind --busid 2-1
```

再度 `usbipd list` を実行すると `STATE` が `Shared` に変わります．

**ステップ 3: WSL2 にアタッチ**

Docker コンテナを起動する**前**に実行します．

```powershell
# 実行場所: PowerShell（管理者）

usbipd attach --wsl --busid 2-1
```

`STATE` が `Attached` になれば成功です．

### 9-4. docker-compose.windows.yml のデバイス設定を有効化

`docker/docker-compose.windows.yml` を開き，`devices` セクションのコメントを外します．

```yaml
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0    # CH340，FTDI 等の USB シリアル
      # - /dev/ttyACM0:/dev/ttyACM0  # Arduino 等の CDC ACM デバイス
```

デバイスノード名はコンテナ内で `ls /dev/ttyUSB* /dev/ttyACM*` で確認できます．

### 9-5. コンテナを再起動して反映

```powershell
# 実行場所: PowerShell（リポジトリのルートディレクトリで実行）

.\run.ps1 down
.\run.ps1 up
```

### 9-6. アタッチの解除

PC からデバイスを取り外す前，またはセッション終了時に実行します．

```powershell
# 実行場所: PowerShell（管理者）

usbipd detach --busid 2-1
```

> **注意**: コンテナを再起動した場合や PC を再起動した場合は，ステップ 3（`usbipd attach`）を再度実行する必要があります．バインド（ステップ 2）は再実行不要です．

---

## 10. ジョイスティックの使い方

ゲームパッドやジョイスティックも usbipd-win 経由でコンテナに渡せます．

### 10-1. usbipd-win でジョイスティックをアタッチ

[セクション 9-1〜9-3](#9-usb-デバイスのパススルーusbipd-win) と同じ手順で，ジョイスティックの BUSID を WSL2 にアタッチします．

```powershell
# 実行場所: PowerShell（管理者）

# デバイス一覧を確認（ジョイスティックの BUSID を探す）
usbipd list

# バインド（初回のみ）
usbipd bind --busid <BUSID>

# WSL2 にアタッチ
usbipd attach --wsl --busid <BUSID>
```

アタッチ後，WSL2 内に `/dev/input/js0`（または `js1`）が作成されます．

### 10-2. docker-compose.windows.yml の確認

`docker/docker-compose.windows.yml` に以下のボリュームマウントが含まれていることを確認します（デフォルトで有効）．

```yaml
volumes:
  - /dev/input:/dev/input    # ジョイスティック (usbipd-win アタッチ後)
```

> `/dev/input` が WSL2 上に存在しない場合（ジョイスティック未接続時）はこの行をコメントアウトしてコンテナを起動してください．

### 10-3. joy ノードの起動

```powershell
# 実行場所: PowerShell（リポジトリのルートディレクトリで実行）

# デフォルト（/dev/input/js0）
.\run.ps1 joy

# デバイスを指定する場合
.\run.ps1 joy -JsDev /dev/input/js1
```

コマンド実行時に `Test-UsbIpdJoystick` が自動チェックを行い，デバイスが見つからない場合は警告を表示します．

### 10-4. トピックの確認

別の PowerShell ウィンドウを開いてコンテナに入り，`/joy` トピックを確認します．

```powershell
.\run.ps1 shell
```

```bash
# 実行場所: コンテナ内
source /opt/ros/noetic/setup.bash
rostopic echo /joy
```

---

## 11. シリアル通信の設定

[セクション 9](#9-usb-デバイスのパススルーusbipd-win) の USB パススルー（`usbipd attach`）が完了していることが前提です．

### デバイスの確認

```powershell
# 実行場所: PowerShell（リポジトリのルートディレクトリで実行）

.\run.ps1 serial-list
```

または，コンテナ内で直接確認する場合:

```powershell
# 実行場所: PowerShell → コンテナ内に入る
.\run.ps1 shell
```

```bash
# 実行場所: コンテナ内
ls -l /dev/ttyUSB* /dev/ttyACM*
```

### シリアルモニタ（minicom）

```powershell
# 実行場所: PowerShell（リポジトリのルートディレクトリで実行）

.\run.ps1 serial-monitor -PORT /dev/ttyUSB0 -BAUD 115200
```

minicom 操作:
- `Ctrl+A` → `Z` : ヘルプ
- `Ctrl+A` → `X` : 終了

### Python でのアクセス

```powershell
# 実行場所: PowerShell → コンテナ内に入る
.\run.ps1 shell
```

```bash
# 実行場所: コンテナ内
python3 -c "
import serial
ser = serial.Serial('/dev/ttyUSB0', 115200, timeout=1)
ser.write(b'hello\n')
print(ser.readline())
"
```

### 接続デバイスのノード名が変わる場合

USB ポートを差し替えるたびに `/dev/ttyUSB0` → `/dev/ttyUSB1` のようにノード名が変わることがあります．  
ホスト（WSL2）側で udev ルールを設定するとシリアル番号でデバイス名を固定できます．

```bash
# 実行場所: WSL2 または Linux ホスト

udevadm info -a -n /dev/ttyUSB0 | grep -i serial
```

取得したシリアル番号を `/etc/udev/rules.d/99-usb-serial.rules` に登録します．

```
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="YOUR_SERIAL", SYMLINK+="ttyMYDEVICE"
```

---

## 12. トラブルシューティング

### Docker が起動しない

- Docker Desktop が起動しているか確認（タスクバーの Docker アイコン）
- WSL2 が正しく設定されているか確認:
  ```powershell
  # 実行場所: PowerShell
  wsl --status
  ```

### GUI（RViz/Gazebo）が表示されない

1. XLaunch が起動しているか確認（タスクバーに X のアイコン）
2. XLaunch 起動時の「Disable access control」が有効か確認
3. Windows ファイアウォールで VcXsrv が許可されているか確認  
   設定 → Windows セキュリティ → ファイアウォール → アプリ許可
4. コンテナ内で DISPLAY を確認:
   ```powershell
   # 実行場所: PowerShell → コンテナ内に入る
   .\run.ps1 shell
   ```

   ```bash
   # 実行場所: コンテナ内
   echo $DISPLAY          # → host.docker.internal:0.0
   xeyes                  # テスト用 GUI アプリ
   ```

### `.\run.ps1` がスクリプト実行エラーになる

PowerShell の実行ポリシーを確認・設定します．

```powershell
# 実行場所: PowerShell

Get-ExecutionPolicy -List
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### catkin build がパーミッションエラーになる

Windows 上の `catkin_ws/` に対して Docker がアクセスできない場合，Docker Desktop の Settings → Resources → File sharing でドライブが共有されているか確認してください．

### USB デバイスが認識されない（usbipd-win）

```powershell
# 実行場所: PowerShell（管理者）

# アタッチ状態の確認
usbipd list

# 再アタッチ
usbipd detach --busid <BUSID>
usbipd attach --wsl --busid <BUSID>
```

Docker コンテナを再起動後にアタッチすると認識されることがあります．

コンテナ起動後に usbipd attach した場合は，`docker/docker-compose.windows.yml` の `devices` をアンコメントしてコンテナを再起動してください．

### ポート 11311 が使用中

```powershell
# 実行場所: PowerShell

# 使用しているプロセスを確認
netstat -ano | findstr :11311

# 必要に応じてコンテナを停止
.\run.ps1 down
```

### roscore プロファイル使用時の ROS_MASTER_URI

roscore を別コンテナで動かす場合（`.\run.ps1 roscore`），`ros` サービスの `ROS_MASTER_URI` を `docker/docker-compose.windows.yml` で変更する必要があります．

```yaml
environment:
  - ROS_MASTER_URI=http://roscore:11311   # roscore コンテナ名に変更
  - ROS_HOSTNAME=ros1_ws
```
