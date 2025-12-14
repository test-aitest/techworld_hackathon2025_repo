import WebSocket from 'ws';

/**
 * OpenAI Realtime APIとの通信を管理するサービスクラス
 * クライアントからの音声データをOpenAI Realtime APIに中継し、
 * AIの音声応答をクライアントに返します
 */
export class RealtimeService {
  private openaiWs: WebSocket | null = null;
  private clientWs: WebSocket;
  private apiKey: string;
  private isConnected = false;

  constructor(clientWs: WebSocket, apiKey: string) {
    this.clientWs = clientWs;
    this.apiKey = apiKey;
  }

  /**
   * OpenAI Realtime APIに接続
   */
  async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        // OpenAI Realtime API エンドポイント
        const url = 'wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-12-17';

        this.openaiWs = new WebSocket(url, {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'OpenAI-Beta': 'realtime=v1',
          },
        });

        this.openaiWs.on('open', () => {
          console.log('✅ OpenAI Realtime API に接続しました');
          this.isConnected = true;

          // セッション設定を送信
          this.sendSessionUpdate();
          resolve();
        });

        this.openaiWs.on('message', (data: WebSocket.Data) => {
          this.handleOpenAIMessage(data);
        });

        this.openaiWs.on('error', (error) => {
          console.error('❌ OpenAI WebSocket エラー:', error);
          this.sendErrorToClient('OpenAI connection error');
          reject(error);
        });

        this.openaiWs.on('close', () => {
          console.log('🔌 OpenAI WebSocket 接続が切断されました');
          this.isConnected = false;
        });
      } catch (error) {
        console.error('❌ OpenAI接続エラー:', error);
        reject(error);
      }
    });
  }

  /**
   * セッション設定を送信
   */
  private sendSessionUpdate(): void {
    if (!this.openaiWs || !this.isConnected) return;

    const sessionConfig = {
      type: 'session.update',
      session: {
        modalities: ['text', 'audio'],
        instructions: 'あなたは親しみやすく、フレンドリーなAIアシスタントです。英語で会話してください。',
        voice: 'alloy', // alloy, echo, shimmer から選択
        input_audio_format: 'pcm16',
        output_audio_format: 'pcm16',
        input_audio_transcription: {
          model: 'whisper-1',
        },
        turn_detection: {
          type: 'server_vad', // Voice Activity Detection を有効化
          threshold: 0.5,
          prefix_padding_ms: 300,
          silence_duration_ms: 500,
        },
        temperature: 0.8,
        max_response_output_tokens: 4096,
      },
    };

    this.openaiWs.send(JSON.stringify(sessionConfig));
    console.log('📤 セッション設定を送信しました');
  }

  /**
   * クライアントから受信した音声データをOpenAI APIに送信
   */
  sendAudioToOpenAI(audioData: Buffer): void {
    if (!this.openaiWs || !this.isConnected) {
      console.warn('⚠️ OpenAI APIに未接続です');
      return;
    }

    try {
      // PCM16フォーマットの音声データをBase64エンコード
      const base64Audio = audioData.toString('base64');

      const audioMessage = {
        type: 'input_audio_buffer.append',
        audio: base64Audio,
      };

      this.openaiWs.send(JSON.stringify(audioMessage));
      console.log(`📤 音声データ送信: ${audioData.length} bytes`);
    } catch (error) {
      console.error('❌ 音声送信エラー:', error);
      this.sendErrorToClient('Failed to send audio to OpenAI');
    }
  }

  /**
   * OpenAI APIからのメッセージを処理
   */
  private handleOpenAIMessage(data: WebSocket.Data): void {
    try {
      const message = JSON.parse(data.toString());
      console.log(`📥 OpenAI メッセージ: ${message.type}`);

      switch (message.type) {
        case 'session.created':
          this.sendStatusToClient('Session created');
          break;

        case 'session.updated':
          this.sendStatusToClient('Session updated');
          break;

        case 'input_audio_buffer.speech_started':
          this.sendStatusToClient('Speech detected');
          break;

        case 'input_audio_buffer.speech_stopped':
          this.sendStatusToClient('Speech ended');
          break;

        case 'input_audio_buffer.committed':
          console.log('🎤 音声バッファがコミットされました');
          break;

        case 'conversation.item.created':
          console.log('💬 会話アイテムが作成されました');
          break;

        case 'response.audio_transcript.delta':
          // AIの発話テキスト（部分）
          if (message.delta) {
            this.sendTranscriptToClient(message.delta, false);
          }
          break;

        case 'response.audio_transcript.done':
          // AIの発話テキスト（完了）
          if (message.transcript) {
            this.sendTranscriptToClient(message.transcript, true);
          }
          break;

        case 'response.audio.delta':
          // AIの音声応答（部分）
          if (message.delta) {
            const audioBuffer = Buffer.from(message.delta, 'base64');
            this.sendAudioToClient(audioBuffer);
          }
          break;

        case 'response.audio.done':
          console.log('🔊 音声応答が完了しました');
          this.sendStatusToClient('Response completed');
          break;

        case 'response.done':
          console.log('✅ 応答処理が完了しました');
          break;

        case 'error':
          console.error('❌ OpenAI エラー:', message.error);
          this.sendErrorToClient(message.error.message || 'OpenAI API error');
          break;

        default:
          console.log(`ℹ️ その他のメッセージ: ${message.type}`);
      }
    } catch (error) {
      console.error('❌ メッセージ処理エラー:', error);
    }
  }

  /**
   * クライアントに音声データを送信
   */
  private sendAudioToClient(audioData: Buffer): void {
    if (this.clientWs.readyState === WebSocket.OPEN) {
      // バイナリデータとして送信
      this.clientWs.send(audioData);
      console.log(`📤 クライアントに音声送信: ${audioData.length} bytes`);
    }
  }

  /**
   * クライアントに文字起こしテキストを送信
   */
  private sendTranscriptToClient(text: string, isDone: boolean): void {
    if (this.clientWs.readyState === WebSocket.OPEN) {
      this.clientWs.send(JSON.stringify({
        type: 'transcript',
        text: text,
        isDone: isDone,
      }));
    }
  }

  /**
   * クライアントにステータスメッセージを送信
   */
  private sendStatusToClient(message: string): void {
    if (this.clientWs.readyState === WebSocket.OPEN) {
      this.clientWs.send(JSON.stringify({
        type: 'status',
        message: message,
      }));
    }
  }

  /**
   * クライアントにエラーメッセージを送信
   */
  private sendErrorToClient(message: string): void {
    if (this.clientWs.readyState === WebSocket.OPEN) {
      this.clientWs.send(JSON.stringify({
        type: 'error',
        message: message,
      }));
    }
  }

  /**
   * 接続をクリーンアップ
   */
  cleanup(): void {
    if (this.openaiWs) {
      this.openaiWs.close();
      this.openaiWs = null;
    }
    this.isConnected = false;
    console.log('🧹 Realtime サービスをクリーンアップしました');
  }
}
