# Eigotchi Backend - OpenAI Realtime API WebSocket Server

音声チャットアプリのバックエンドサーバー。OpenAI Realtime APIを使用して、リアルタイムの音声会話を実現します。

## 機能

- **リアルタイム音声会話**: OpenAI Realtime APIを使用した双方向の音声会話
- **WebSocket通信**: クライアントとサーバー間の低遅延通信
- **自動音声認識**: Voice Activity Detection (VAD) による自動的な発話検出
- **音声合成**: AIの応答を音声として配信

## OpenAI Realtime API について

OpenAI Realtime APIは、リアルタイムの音声会話を実現するためのWebSocketベースのAPIです。

- **ドキュメント**: https://platform.openai.com/docs/guides/realtime
- **モデル**: `gpt-4o-realtime-preview-2024-12-17`
- **サポート形式**: PCM16 audio (16-bit PCM, モノラル)
- **サンプリングレート**: 24kHz

## セットアップ

### 1. 依存関係のインストール

```bash
cd backend
npm install
```

### 2. 環境変数の設定

```bash
# サンプルファイルをコピー
cp .env.example .env

# .env を編集してAPIキーを設定
```

`.env` ファイル:
```bash
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
PORT=3000
```

必要なAPIキー:
- **OpenAI API Key**: https://platform.openai.com/api-keys から取得

### 3. サーバーの起動

```bash
# 開発モード（ホットリロード有効）
npm run dev

# または本番モード
npm run build
npm start
```

サーバーは `ws://localhost:3000` で起動します。

## アーキテクチャ

### WebSocket通信フロー

```
クライアント (iOS/Swift)
    ↕ WebSocket (音声データ + 制御メッセージ)
バックエンドサーバー (Node.js/TypeScript)
    ↕ WebSocket
OpenAI Realtime API
```

### メッセージタイプ

#### クライアント → サーバー

1. **バイナリデータ (音声)**
   - PCM16形式の音声データ
   - サーバーがOpenAI APIに中継

2. **テキストメッセージ (制御)**
   ```json
   {
     "type": "control",
     "action": "start" | "stop" | "reset"
   }
   ```

#### サーバー → クライアント

1. **ステータスメッセージ**
   ```json
   {
     "type": "status",
     "message": "Session created"
   }
   ```

2. **文字起こしテキスト**
   ```json
   {
     "type": "transcript",
     "text": "こんにちは",
     "isDone": true
   }
   ```

3. **音声データ (バイナリ)**
   - PCM16形式のAI音声応答

4. **エラーメッセージ**
   ```json
   {
     "type": "error",
     "message": "Error description"
   }
   ```

## プロジェクト構成

```
backend/
├── src/
│   ├── index.ts                 # エントリーポイント
│   ├── controllers/
│   │   └── voiceController.ts   # WebSocket接続処理
│   └── services/
│       └── realtimeService.ts   # OpenAI Realtime API通信
├── package.json
├── tsconfig.json
├── .env.example
└── README.md
```

## カスタマイズ

### AIの音声の変更

`src/services/realtimeService.ts` の `sendSessionUpdate()` メソッド内で音声を変更できます:

```typescript
voice: 'alloy', // 'alloy', 'echo', 'shimmer' から選択
```

### システムプロンプトの変更

`src/services/realtimeService.ts` の `instructions` を編集:

```typescript
instructions: 'あなたは親しみやすく、フレンドリーなAIアシスタントです。',
```

### Voice Activity Detection の設定

VADのパラメータを調整して、発話検出の感度を変更できます:

```typescript
turn_detection: {
  type: 'server_vad',
  threshold: 0.5,              // 0.0-1.0 (高いほど感度が低い)
  prefix_padding_ms: 300,      // 発話開始前のパディング
  silence_duration_ms: 500,    // この長さの沈黙で発話終了と判定
},
```

## 開発

### デバッグモード

```bash
npm run debug
```

### 型チェック

```bash
npm run type-check
```

## トラブルシューティング

### OpenAI APIに接続できない

1. API Keyが正しく設定されているか確認
2. OpenAI アカウントに十分な残高があるか確認
3. ネットワーク接続を確認

### 音声が途切れる

1. ネットワーク接続の品質を確認
2. `turn_detection` の `silence_duration_ms` を調整
3. クライアント側のバッファサイズを確認

### レイテンシが高い

1. サーバーとクライアントの地理的距離を確認
2. OpenAI APIのレスポンス時間をログで確認
3. ネットワーク帯域幅を確認

## 注意事項

- **課金**: OpenAI Realtime APIは有料です。使用量に応じた課金が発生します
- **レート制限**: APIのレート制限に注意してください
- **セキュリティ**: 本番環境では適切な認証・認可の実装が必要です
- **音声形式**: クライアントは PCM16 (24kHz, モノラル) 形式で音声を送信する必要があります

## 参考リンク

- [OpenAI Realtime API Documentation](https://platform.openai.com/docs/guides/realtime)
- [OpenAI Realtime API Reference](https://platform.openai.com/docs/api-reference/realtime)
- [WebSocket Protocol](https://datatracker.ietf.org/doc/html/rfc6455)
