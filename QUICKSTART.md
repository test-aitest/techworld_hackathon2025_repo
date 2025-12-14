# 🎯 クイックスタートガイド - OpenAI Realtime API 音声会話

このガイドに従って、音声会話機能を起動してください。

## ✅ 前提条件

- OpenAI API Key（[こちらから取得](https://platform.openai.com/api-keys)）
- Node.js（v18以上推奨）
- Xcode（iOS開発用）
- macOS（iOSシミュレーター実行用）

## 🚀 セットアップ手順

### ステップ1: バックエンドのセットアップ

```bash
# 1. バックエンドディレクトリに移動
cd backend

# 2. 依存関係をインストール（既に実行済みの場合はスキップ）
npm install

# 3. 環境変数ファイルを作成
cp .env.example .env

# 4. .envファイルを編集してOpenAI API Keyを設定
# OPENAI_API_KEY=sk-proj-your-actual-api-key-here
nano .env  # または好きなエディタで編集

# 5. サーバーを起動
npm run dev
```

✅ **成功の確認:**
```
🚀 WebSocket server is running on ws://localhost:3000
🔑 OpenAI API Key: sk-proj-xxxxx...
```

### ステップ2: iOSアプリのセットアップ

```bash
# フロントエンドディレクトリに移動
cd ../frontend
```

#### Xcodeでプロジェクトを開く

1. `eigotchi.xcodeproj` をダブルクリック
2. Xcodeが起動します

#### 新しいファイルをプロジェクトに追加

**AudioPlayer.swift を追加:**

1. Xcodeのプロジェクトナビゲーターで `eigotchi` > `lib` フォルダを右クリック
2. "Add Files to eigotchi..." を選択
3. `frontend/eigotchi/lib/AudioPlayer.swift` を選択
4. "Copy items if needed" にチェックを入れる
5. "Add" をクリック

**または、Xcodeのプロジェクトツリーから:**
- 既にファイルシステムに存在するので、Xcodeで「File > Add Files to "eigotchi"...」から追加

### ステップ3: アプリを実行

1. Xcodeで実行デバイスを選択（シミュレーターまたは実機）
2. ▶️ ボタンをクリック（または Cmd + R）
3. アプリが起動します

### ステップ4: 音声会話を開始

1. **画面をタップ** してお絵描き画面に移動
2. **マイク権限を許可**（初回のみ）
3. 自動的にWebSocketサーバーに接続されます
4. **接続完了**のメッセージを確認
5. 🎤 **マイクボタンが赤色**になっていることを確認（録音中）
6. **話しかけてみましょう！** 🗣️

例: 「こんにちは！」と話しかけると、AIが音声で返答します。

## 📱 UI説明

### トップツールバー

| ボタン | 説明 |
|--------|------|
| ← | 元に戻す |
| → | やり直し |
| 🎤 | マイクオン/オフ切り替え |
| ▶ | 口のアニメーション開始 |
| 🗑️ | キャンバスクリア |

### 画面下部

| 要素 | 説明 |
|------|------|
| 🍌 | キャラクター |
| AI会話 | タイトル |
| ●接続完了 | 接続状態（緑=接続中、赤=未接続）|
| 🌊発話中 | AI発話中インジケーター |
| テキストエリア | 文字起こしとAI応答を表示 |

## 🔧 トラブルシューティング

### バックエンドサーバーが起動しない

**エラー: `OPENAI_API_KEY が設定されていません`**
- `.env` ファイルにAPI Keyを設定してください

**エラー: `EPERM`**
```bash
# npmキャッシュをクリア
sudo chown -R $(whoami) ~/.npm
```

### iOSアプリがサーバーに接続できない

1. **サーバーが起動しているか確認**
   ```bash
   # 別のターミナルで確認
   curl http://localhost:3000
   # または
   lsof -i :3000
   ```

2. **シミュレーターの場合、localhostでアクセス可能か確認**
   - シミュレーターは自動的にホストのlocalhostにアクセスできます

3. **実機の場合、ネットワーク設定を確認**
   - 同じWiFiネットワークに接続
   - `WebSocketManager.swift` のURLをホストのIPアドレスに変更:
     ```swift
     init(urlString: String = "ws://192.168.1.XXX:3000/")
     ```

### マイクが動作しない

1. **権限を確認**
   - 設定 > プライバシー > マイク
   - アプリの権限をオンに

2. **アプリを再起動**
   - Xcodeで停止して再実行

3. **ログを確認**
   - Xcodeのコンソールでエラーメッセージを確認

### 音声が聞こえない

1. **音量を確認**
   - デバイスの音量を上げる
   - 消音モードを解除

2. **データが受信されているか確認**
   - Xcodeのコンソールで `🔊 Received audio data` を確認

3. **AudioSessionを確認**
   - 他のアプリが音声セッションを使用していないか確認

## 📊 動作確認のログ

### 正常動作時のログ（バックエンド）

```
🚀 WebSocket server is running on ws://localhost:3000
🔑 OpenAI API Key: sk-proj-xxxxx...
🔌 New WebSocket connection established
🔌 新しいWebSocket接続を受け付けました
✅ OpenAI Realtime API に接続しました
📤 セッション設定を送信しました
🎤 音声データ受信
データサイズ: 8192 bytes (8.00 KB)
📤 音声データ送信: 8192 bytes
📥 OpenAI メッセージ: input_audio_buffer.speech_started
📥 OpenAI メッセージ: response.audio.delta
📤 クライアントに音声送信: 4800 bytes
```

### 正常動作時のログ（iOS）

```
WebSocket connection attempt started
📩 Received message: {"type":"status","message":"OpenAI Realtime API に接続しました 🎉"}
📢 Status: OpenAI Realtime API に接続しました 🎉
✅ Microphone recording started
Sent audio data: 8192 bytes
🔊 Received audio data: 4800 bytes
🔊 Playing audio: 4800 bytes (2400 samples)
📝 Transcript: こんにちは！ (done: true)
```

## 🎉 成功！

すべて正常に動作すれば、AIと音声で会話できるようになります！

### テスト会話例

1. **あなた**: 「こんにちは！」
2. **AI**: 「こんにちは！何かお手伝いできることはありますか？」（音声で返答）
3. **あなた**: 「今日の天気は？」
4. **AI**: 「申し訳ございませんが、私は...」（音声で返答）

## 📚 詳細ドキュメント

- **バックエンド実装**: `backend/README.md`
- **詳細ガイド**: `backend/REALTIME_API_GUIDE.md`
- **フロントエンド実装**: `frontend/VOICE_CHAT_IMPLEMENTATION.md`

## 🐛 問題が解決しない場合

1. ログを確認して、どこで失敗しているか特定
2. エラーメッセージを検索
3. OpenAI APIの残高を確認
4. ネットワーク接続を確認

---

楽しい音声会話をお楽しみください！🎵✨
