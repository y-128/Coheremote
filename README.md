# Coheremote

CoheremoteはVMware Fusion上で動作するWindowsアプリケーションを、macOSのネイティブアプリのようにDockに統合するラッパーアプリ生成ツールです。RemoteApp（RDP）技術を使用して、シームレスな操作体験を提供します。
こちらのXの[ポスト](https://x.com/amania_jp/status/2034160595105403123?s=12)からインスピレーションを受けました。

## 主な機能

- **ネイティブコンパイル**: 生成されるラッパーアプリはSwiftでコンパイルされたネイティブバイナリ
- **ステータスウィンドウ**: VM起動中・接続中・サスペンド中などの状態をリアルタイム表示
- **Dockメニュー**: 右クリックで再接続・Windows再起動・シャットダウンして終了
- **常駐型ラッパー**: Windows App起動後もDockに常駐し、VMのライフサイクルを管理
- **終了時動作の選択**: サスペンド / Windowsシャットダウン / 何もしない を設定可能
- **スマート起動**: VM状態を即座に検出し、既に起動中なら瞬時に接続
- **暗号化VM対応**: 暗号化パスワードをmacOSキーチェーンに安全に保存
- **アプリランチャー**: メニューバーにランチャーパネルを表示。インストール済みWindowsアプリの起動、電源操作、他のラッパーアプリへの切り替えが可能
- **アプリ表示/非表示**: アプリランチャーのアプリ一覧から不要なアプリを非表示にできる（設定は永続化）
- **カスタムアイコン**: PNG、JPG、ICO、ICNS形式に対応
- **日英対応**: Coheremote本体・生成アプリともにシステム言語に応じて日本語/英語を自動切替
- **設定の永続化**: 設定を自動保存し、再生成時に復元

## 前提条件

- **macOS 13.0** (Ventura) 以降
- **VMware Fusion**: `/Applications/VMware Fusion.app` にインストール済み
- **Windows App**（旧Microsoft Remote Desktop）: Mac App Storeからインストール済み
- **RDPファイル**: 以下のいずれかの方法で作成（詳細は「RDPファイルの作成方法」を参照）:
  - **RemoteApp Tool** - [RemoteApp Tool (GitHub)](https://github.com/kimmknight/remoteapptool)
  - **Windows App**（旧Microsoft Remote Desktop）からのエクスポート
- **Xcode Command Line Tools**: 生成アプリのコンパイルに `swiftc` が必要
- **フルディスクアクセス**: 以下のアプリに付与が**必須**:
  - Coheremote.app 本体
  - 生成されたすべてのラッパーアプリ

### フルディスクアクセスの付与方法

1. **システム設定** > **プライバシーとセキュリティ** > **フルディスクアクセス** を開く
2. **+** をクリックして **Coheremote.app** を追加
3. ラッパーアプリ生成後、各 `.app` も同様に追加

フルディスクアクセスがないと `vmrun` がVMware Fusionを制御できません。

## 使い方

### ラッパーアプリの生成

1. **Coheremoteを起動**

2. **設定を入力**:
   - **アプリケーション名**: 生成するラッパーアプリの名前
   - **保存先**: 生成した `.app` の保存場所
   - **アイコン画像**（オプション）: PNG、JPG、ICO、ICNS ファイル
   - **VMパス**: `.vmx` ファイルまたは `.vmwarevm` バンドル
   - **VM暗号化パスワード**（オプション）: 暗号化VMの場合
   - **RDPファイル**: RemoteApp用の `.rdp` ファイル
   - **Windowsユーザー名**: ログイン用
   - **Windowsパスワード**（オプション）: アプリランチャーのアプリ一覧取得に使用（VMware Toolsが必要）

3. **オプション設定**:
   - **RemoteApp変換**（デフォルト: OFF）: RDPファイルにRemoteApp設定を自動注入。RemoteApp Toolを使わずに、通常のRDP接続を個別アプリのRemoteApp接続に変換できる
   - **アプリ終了時にVMをサスペンド**（デフォルト: ON）: ラッパーアプリ終了時にVMをサスペンド
   - **アプリ終了時にWindowsをシャットダウン**（デフォルト: OFF）: ラッパーアプリ終了時にWindowsをシャットダウン（サスペンドより優先）
   - **メニューバーにアプリランチャーを追加**（デフォルト: ON）: メニューバーからWindowsアプリを起動可能
   - **Coheremoteバッジをアイコンに追加**（デフォルト: OFF）: アプリアイコンの右下にCoheremoteのバッジを合成

4. **アプリをビルド** をクリック

5. 生成されたアプリに**フルディスクアクセスを付与**

### ラッパーアプリの使い方

1. **起動**: 生成された `.app` をダブルクリック
2. ステータスウィンドウが表示され、現在の処理が確認できます:
   - *VMware Fusionを起動中...*（未起動の場合）
   - *VMを起動中...*
   - *VMの起動を待機中...*
   - *接続中...*
3. 接続完了後、ステータスウィンドウは自動的に非表示になります
4. ラッパーアプリはDockに常駐し、VMの管理が可能です

### Dockメニュー（右クリック）

ラッパーアプリのDockアイコンを右クリックすると以下が表示されます（日英自動切替）:

| メニュー | 説明 |
|---------|------|
| **再接続** / Reconnect | RDP接続を再確立（Windowsアプリを閉じてしまった場合に使用） |
| **Windowsを再起動** / Restart Windows | VMにソフトリスタートを送信し、起動後にRDPを自動再接続 |
| **シャットダウンして終了** / Shutdown and Quit | Windowsをシャットダウンしてからラッパーアプリを終了 |

### アプリランチャー

メニューバーのアイコンをクリックすると、ランチャーパネルが表示されます:

- **ヘッダー**: アプリ名と接続ステータス（緑: 接続中 / グレー: 未接続）
- **アプリ一覧**: Windows側にインストールされたアプリケーションの一覧（クリックで起動）
- **フッターボタン**:
  - **再接続**: RDP接続を再確立
  - **電源**: 再起動・サスペンド・シャットダウン・アプリだけ終了
  - **表示/非表示**: アプリ一覧の表示/非表示を編集（目のアイコン）
  - **更新**: アプリ一覧を再取得
  - **終了**: アプリを終了

**注意**: アプリランチャーのアプリ一覧を利用するには、Coheremoteの設定で**Windowsパスワード**を入力し、Windows側に**VMware Tools**がインストールされている必要があります。

#### アプリの表示/非表示

フッターの目のアイコンをクリックすると編集モードになり、各アプリの横にトグルボタンが表示されます。非表示にしたアプリは通常のアプリ一覧に表示されなくなります。設定はアプリを再起動しても保持されます。

### 終了

**Cmd+Q** またはDock右クリック > **終了** で、設定に応じて以下の動作を行います:

| 設定 | 終了時の動作 |
|------|------------|
| サスペンドON / シャットダウンOFF | VMをサスペンドして終了 |
| シャットダウンON | Windowsをシャットダウンして終了（サスペンドより優先） |
| 両方OFF | そのまま終了（VMは起動したまま） |

## 仕組み

### ビルドプロセス

Coheremoteは以下の手順でスタンドアロンの `.app` バンドルを生成します:

1. RDPファイルにユーザー名を注入（BOM・改行コードを保持）
2. カスタムアイコンを `sips` + `iconutil` でmacOS `.icns` 形式に変換（Retina対応）
3. VM暗号化パスワードをmacOSキーチェーンに保存
4. Swiftソーステンプレートにパラメータを埋め込み、`swiftc` でネイティブバイナリをコンパイル
5. 標準的な `.app` バンドル構造にパッケージング

### 生成されるアプリの構造

```
MyApp.app/
  Contents/
    Info.plist
    MacOS/
      MyApp          # コンパイル済みSwiftバイナリ
    Resources/
      AppIcon.icns   # アプリアイコン
      app.rdp        # 修正済みRDPファイル
```

### 生成されるアプリの動作

1. **VMware Fusionの起動確認** - 未起動なら自動起動
2. **VMの起動/再開** - `open -a "VMware Fusion"` でVMを起動（コールドブート・サスペンド解除・暗号化VMすべてに対応）
3. **VM状態のポーリング** - 1秒間隔で起動完了を確認（タイムアウト: 120秒）
4. **RDP接続** - Windows App（またはMicrosoft Remote Desktop）で接続
5. **Dockに常駐** - VMライフサイクルを継続管理
6. **終了時処理** - 設定に応じてサスペンドまたはシャットダウン
7. **ログ記録** - すべての操作を `~/Library/Logs/Coheremote/` に記録

## RDPファイルの作成方法

### 方法1: RemoteApp Tool（推奨）

個別のWindowsアプリケーションをRemoteAppとして公開する方法です。

1. Windows側で [RemoteApp Tool](https://github.com/kimmknight/remoteapptool) をダウンロード・実行
2. **+** をクリックしてアプリケーションを追加（例: `notepad.exe`）
3. アプリケーションを選択し、**Create Client Connection** をクリック
4. `.rdp` ファイルを保存
5. この `.rdp` ファイルをmac側にコピーし、Coheremoteで使用

### 方法2: Windows Appからのエクスポート

macOS側のWindows App（旧Microsoft Remote Desktop）から既存の接続設定をエクスポートする方法です。

1. **Windows App** を起動
2. 接続先のPCを追加（まだ追加していない場合）:
   - **+** > **PCの追加** をクリック
   - PC名（VMのIPアドレスまたはホスト名）を入力して保存
3. 追加したPCを右クリック > **RDPファイルにエクスポート** を選択
4. `.rdp` ファイルを保存
5. この `.rdp` ファイルをCoheremoteで使用

**注意**: Windows Appからエクスポートした場合はフルデスクトップ接続になります。個別アプリのRemoteApp接続にするには、方法3（Coheremoteの内蔵機能）を使うか、`.rdp` ファイルをテキストエディタで開いて以下の行を追加してください:

```
remoteapplicationmode:i:1
remoteapplicationname:s:アプリ名
remoteapplicationprogram:s:アプリのパス
```

例（メモ帳の場合）:

```
remoteapplicationmode:i:1
remoteapplicationname:s:Notepad
remoteapplicationprogram:s:C:\Windows\System32\notepad.exe
```

### 方法3: CoheremoteのRemoteApp変換機能

Coheremoteの設定画面で直接RemoteApp変換を行う方法です。RDPファイルの手動編集が不要になります。

1. 方法2で `.rdp` ファイルを作成
2. Coheremoteの設定で **RemoteApp変換** をONにする
3. **アプリ名**（表示名）と **プログラムパス**（Windows側の実行ファイルパス）を入力
4. ビルド時にRDPファイルへRemoteApp設定が自動注入されます

## トラブルシューティング

### 「Operation not permitted」エラー

フルディスクアクセスが付与されていません。システム設定 > プライバシーとセキュリティ > フルディスクアクセスでアプリを追加してください。

### VMが起動しない

- VMware Fusionが `/Applications` にインストールされているか確認
- VMパスが正しいか確認
- 暗号化VMの場合、パスワードが正しいか確認
- ログファイルで詳細を確認: `~/Library/Logs/Coheremote/<アプリ名>.log`

### RemoteAppがIMEしか表示されない（アプリケーション画面が出ない）

これはWindows側の問題です。以下の手順で対処してください:

1. **Windowsを再起動** - Dockメニュー（右クリック > Windowsを再起動）または手動でVMを再起動
2. それでも解決しない場合、Windows側で以下を確認:
   - レジストリエディタで `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\TSAppAllowList` を確認
   - RemoteAppエントリが正しいか確認
   - リモートデスクトップサービス（`TermService`）を再起動
3. RemoteApp Toolで `.rdp` ファイルを再作成し、ラッパーアプリを再ビルド

### Windowsアプリを閉じてしまった

Dockメニューから **再接続** を選択すると、RDP接続を再確立できます。

### 複数のWindowsアプリを同時に使用する場合

2つ以上のラッパーアプリを同時に起動すると、2つ目以降のアプリのウィンドウが表示されないことがあります。その場合は、該当アプリのDockメニュー（右クリック）から**再接続**を選択してください。

**注意**: 複数のラッパーアプリが同じVMを共有している場合、最後のアプリが終了するまでVMのサスペンド/シャットダウンは行われません。

### RDP接続に失敗する

- Windows App（またはMicrosoft Remote Desktop）がインストールされているか確認
- RDPファイルが有効か確認（手動で開いて動作するかテスト）
- Windows認証情報が正しいか確認

### Windowsがハングまたはフリーズした

Dockメニューから **Windowsを再起動** を選択してください。VMにソフトリセットが送信され、Windows起動後に自動的にRDPが再接続されます。

### ログファイルの確認

各ラッパーアプリは `~/Library/Logs/Coheremote/<アプリ名>.log` にログを出力します:

```bash
cat ~/Library/Logs/Coheremote/<アプリ名>.log
```

ログは1MBを超えると自動的にローテーションされます。

## ソースからビルド

CoheremoteはSwift / SwiftUIのmacOSプロジェクトです。Xcodeでプロジェクトを開き、開発チームを設定してビルドしてください。

## セキュリティに関する注意

- **パスワード保存**: VM暗号化パスワードとWindowsパスワードは**macOSキーチェーン**に保存されます（UserDefaultsには保存されません）
- **vmrunの制約**: VMware Fusionの `vmrun` コマンドはパスワードをプロセス引数（`-vp`, `-gp`）でのみ受け付けます。これにより、同一ユーザーの他プロセスから `ps` コマンドでパスワードが閲覧可能です。これは vmrun の既知の制約であり、共有環境での使用時はご注意ください
- **アプリ名サニタイズ**: ビルド時にアプリ名からファイルシステム上の危険な文字（`/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|`）が自動除去されます

## ライセンス

MIT License。詳細は [LICENSE](LICENSE) を参照。

### 注意事項

- 生成されたラッパーアプリは**個人利用**を目的としています
- Microsoft、VMwareのライセンス条項を遵守してください
- パスワードはmacOSキーチェーンに保存されます

## クレジット

Created by y-128 in 2026.
