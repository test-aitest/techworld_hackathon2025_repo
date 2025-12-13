# Voice Chat API - Backend

音声チャットアプリのバックエンドAPI。OpenAI (STT/LLM) と ElevenLabs (TTS) を使用して、音声入力に対してAI応答の音声を返します。

## 機能

- **Speech-to-Text**: OpenAI Whisper API で音声をテキストに変換
- **LLM Response**: OpenAI GPT-4o で自然な応答を生成
- **Text-to-Speech**: ElevenLabs API でテキストを音声に変換

## セットアップ

### 1. 依存関係のインストール

```bash
# 仮想環境の作成（推奨）
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# パッケージのインストール
pip install -r requirements.txt
```

### 2. 環境変数の設定

```bash
# サンプルファイルをコピー
cp .env.example .env

# .env を編集してAPIキーを設定
```

必要なAPIキー:
- **OpenAI API Key**: https://platform.openai.com/api-keys
- **ElevenLabs API Key**: https://elevenlabs.io/app/settings/api-keys

### 3. サーバーの起動

```bash
# 開発モード（ホットリロード有効）
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# または
python main.py
```

## API エンドポイント

### `POST /chat`

音声ファイルを受け取り、AI応答の音声を返します。

**Request:**
- Content-Type: `multipart/form-data`
- Body: `audio` - 音声ファイル（m4a推奨）

**Response:**
- Content-Type: `audio/mpeg`
- Headers:
  - `X-Transcript`: ユーザーの発話テキスト（URLエンコード済み）
  - `X-Reply`: AIの応答テキスト（URLエンコード済み）

**cURL Example:**
```bash
curl -X POST http://localhost:8000/chat \
  -F "audio=@recording.m4a" \
  --output response.mp3
```

### `POST /chat/json`

音声ファイルを受け取り、JSON形式で応答を返します（デバッグ用）。

**Response:**
```json
{
  "transcript": "こんにちは",
  "reply": "こんにちは！何かお手伝いできることはありますか？",
  "audio_base64": "//uQxAAAAAANIAAAAAExBTUUzLjEwMFVV..."
}
```

### `GET /health`

ヘルスチェック用エンドポイント。

### `GET /docs`

Swagger UI（APIドキュメント）

## プロジェクト構成

```
voice-chat-backend/
├── main.py              # FastAPIアプリケーション
├── services/
│   ├── __init__.py
│   ├── stt.py           # Speech-to-Text (OpenAI Whisper)
│   ├── llm.py           # LLM応答生成 (OpenAI GPT-4o)
│   └── tts.py           # Text-to-Speech (ElevenLabs)
├── requirements.txt     # 依存関係
├── .env.example         # 環境変数サンプル
└── README.md
```

## カスタマイズ

### 音声の変更

`.env` の `ELEVENLABS_VOICE_ID` を変更することで、異なる音声を使用できます。

利用可能な音声:
- Rachel (デフォルト): `21m00Tcm4TlvDq8ikWAM`
- Domi: `AZnzlk1XvdvUeBnXmlld`
- Bella: `EXAVITQu4vr4xnSDxMaL`
- Antoni: `ErXwobaYiN019PkySvjV`
- Josh: `TxGEqnHWrfWFTfGW9XjX`

### システムプロンプトの変更

`services/llm.py` の `SYSTEM_PROMPT` を編集することで、AIの応答スタイルをカスタマイズできます。

## 注意事項

- OpenAI と ElevenLabs の API は有料です。使用量に応じた課金が発生します。
- 本番環境では、適切なセキュリティ設定（CORS、認証など）を行ってください。
