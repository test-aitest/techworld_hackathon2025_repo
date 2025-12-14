# OpenAI Realtime API 実装ガイド

このガイドでは、OpenAI Realtime APIを使用したリアルタイム音声会話の実装について説明します。

## 実装済みの機能

### バックエンド (Node.js/TypeScript)

#### 1. WebSocketサーバー (`src/index.ts`)
- ポート3000でWebSocketサーバーを起動
- クライアントからの接続を受け付け
- 環境変数からOpenAI API Keyを読み込み

#### 2. RealtimeService (`src/services/realtimeService.ts`)
OpenAI Realtime APIとの通信を管理するクラス:

**主要メソッド:**
- `connect()`: OpenAI Realtime APIに接続
- `sendAudioToOpenAI()`: クライアントからの音声をAPIに送信
- `handleOpenAIMessage()`: APIからの応答を処理

**処理するイベント:**
- `session.created`: セッション作成完了
- `input_audio_buffer.speech_started`: 発話開始検出
- `input_audio_buffer.speech_stopped`: 発話終了検出
- `response.audio.delta`: AI音声応答（ストリーミング）
- `response.audio_transcript.delta`: 文字起こしテキスト（ストリーミング）
- `response.done`: 応答完了

#### 3. VoiceController (`src/controllers/voiceController.ts`)
クライアントとの接続を管理:
- WebSocket接続の確立
- バイナリデータ（音声）の受信と転送
- テキストメッセージの処理

## セットアップ手順

### 1. 環境変数の設定

`.env` ファイルを作成し、OpenAI API Keyを設定:

```bash
OPENAI_API_KEY=sk-proj-your-actual-api-key
PORT=3000
```

### 2. サーバーの起動

```bash
cd backend
npm install
npm run dev
```

サーバーは `ws://localhost:3000` で起動します。

## クライアント側の実装ガイド (Swift/iOS)

### 必要な変更

#### 1. 音声フォーマットの変更

OpenAI Realtime APIは **PCM16 (24kHz, モノラル)** を使用します。

現在の `MicrophoneManager.swift` を更新:

```swift
private func setupAudioEngine() {
    let inputNode = audioEngine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)
    
    // PCM16 フォーマット (24kHz, モノラル, 16bit)
    guard let recordingFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24000,
        channels: 1,
        interleaved: false
    ) else {
        print("Failed to create recording format")
        return
    }
    
    // フォーマット変換用のコンバーター
    guard let converter = AVAudioConverter(from: inputFormat, to: recordingFormat) else {
        print("Failed to create audio converter")
        return
    }
    
    inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
        guard let self = self else { return }
        
        // 入力フォーマットから24kHz PCM16に変換
        let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: recordingFormat,
            frameCapacity: AVAudioFrameCount(recordingFormat.sampleRate * Double(buffer.frameLength) / inputFormat.sampleRate)
        )!
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("Conversion error: \\(error)")
            return
        }
        
        self.processAudioBuffer(convertedBuffer)
    }
}
```

#### 2. WebSocketManagerの更新

音声データとテキスト両方を受信できるように更新:

```swift
private func receiveMessage() {
    webSocketTask?.receive { [weak self] result in
        guard let self = self else { return }
        
        switch result {
        case .success(let message):
            switch message {
            case .string(let text):
                // ステータスメッセージや文字起こしを処理
                self.handleTextMessage(text)
                
            case .data(let data):
                // AI音声データを受信
                self.handleAudioData(data)
                
            @unknown default:
                break
            }
            
            self.receiveMessage() // 次のメッセージを待つ
            
        case .failure(let error):
            print("Receive error: \\(error)")
        }
    }
}

private func handleTextMessage(_ text: String) {
    if let data = text.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let type = json["type"] as? String {
        
        switch type {
        case "status":
            if let message = json["message"] as? String {
                print("Status: \\(message)")
            }
            
        case "transcript":
            if let text = json["text"] as? String,
               let isDone = json["isDone"] as? Bool {
                print("Transcript: \\(text) (done: \\(isDone))")
                // UIに文字起こしを表示
            }
            
        case "error":
            if let message = json["message"] as? String {
                print("Error: \\(message)")
            }
            
        default:
            print("Unknown message type: \\(type)")
        }
    }
}

private func handleAudioData(_ data: Data) {
    // PCM16データを受信
    // AVAudioPlayerまたはAudioQueueで再生
    print("Received audio: \\(data.count) bytes")
    playAudioData(data)
}
```

#### 3. 音声再生の実装

受信したPCM16音声データを再生:

```swift
class AudioPlayer {
    private var audioQueue: AudioQueueRef?
    private let format: AVAudioFormat
    
    init() {
        // 24kHz, PCM16, モノラル
        format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 24000,
            channels: 1,
            interleaved: false
        )!
        setupAudioQueue()
    }
    
    func play(data: Data) {
        // PCM16データを再生
        // AudioQueueまたはAVAudioEngineを使用
    }
}
```

## 通信フロー

```
1. クライアント → サーバー: WebSocket接続
   ↓
2. サーバー → OpenAI: Realtime API接続
   ↓
3. サーバー → クライアント: {"type": "status", "message": "接続完了"}
   ↓
4. クライアント → サーバー: 音声データ(PCM16, 24kHz)
   ↓
5. サーバー → OpenAI: input_audio_buffer.append
   ↓
6. OpenAI: Voice Activity Detection (自動で発話を検出)
   ↓
7. OpenAI → サーバー: response.audio.delta (AI音声)
   ↓
8. サーバー → クライアント: 音声データ(PCM16, 24kHz)
   ↓
9. クライアント: 音声を再生
```

## テスト方法

### 1. サーバーの動作確認

```bash
cd backend
npm run dev
```

ログに以下が表示されればOK:
```
🚀 WebSocket server is running on ws://localhost:3000
🔑 OpenAI API Key: sk-proj-xxxxx...
```

### 2. クライアント接続テスト

iOSアプリから接続し、ログを確認:

**サーバーログ:**
```
🔌 New WebSocket connection established
🔌 新しいWebSocket接続を受け付けました
✅ OpenAI Realtime API に接続しました
📤 セッション設定を送信しました
```

**クライアントログ:**
```
WebSocket connection attempt started
Status: OpenAI Realtime API に接続しました 🎉
```

### 3. 音声送信テスト

マイクで話しかけると:

**サーバーログ:**
```
🎤 音声データ受信
データサイズ: 8192 bytes (8.00 KB)
音声長さ: 170.67 ms
📤 音声データ送信: 8192 bytes
```

### 4. AI応答テスト

AIが応答すると:

**サーバーログ:**
```
📥 OpenAI メッセージ: response.audio.delta
📤 クライアントに音声送信: 4800 bytes
```

## トラブルシューティング

### OpenAI APIに接続できない

**症状:** `❌ OpenAI WebSocket エラー`

**解決方法:**
1. `.env` の `OPENAI_API_KEY` を確認
2. APIキーが有効か確認: https://platform.openai.com/api-keys
3. アカウント残高を確認

### 音声が送信されない

**症状:** サーバーに音声データが届かない

**解決方法:**
1. クライアントの音声フォーマットがPCM16, 24kHzか確認
2. WebSocket接続が確立されているか確認
3. マイクの権限が許可されているか確認

### 音声が再生されない

**症状:** サーバーから音声が届くが再生されない

**解決方法:**
1. AudioPlayerが正しく実装されているか確認
2. 音声フォーマット(PCM16, 24kHz)が一致しているか確認
3. デバイスの音量を確認

## 次のステップ

1. **UIの改善**
   - リアルタイム文字起こし表示
   - 音声波形の可視化
   - 会話履歴の保存

2. **パフォーマンス最適化**
   - 音声バッファリングの調整
   - レイテンシの削減

3. **機能追加**
   - 会話コンテキストの永続化
   - 複数ユーザー対応
   - カスタムプロンプト設定

## 参考リンク

- [OpenAI Realtime API Documentation](https://platform.openai.com/docs/guides/realtime)
- [WebSocket API (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
- [AVAudioEngine (Apple)](https://developer.apple.com/documentation/avfaudio/avaudioengine)
