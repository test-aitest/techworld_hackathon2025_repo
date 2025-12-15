import type { WebSocket } from 'ws';
import { RealtimeService } from '../services/realtimeService';

// WebSocketごとにRealtimeServiceのインスタンスを保持
const realtimeServices = new WeakMap<WebSocket, RealtimeService>();

/**
 * WebSocket接続を処理
 */
export const handleWebSocketConnection = async (ws: WebSocket, apiKey: string): Promise<void> => {
  console.log('🔌 新しいWebSocket接続を受け付けました');

  try {
    // RealtimeServiceのインスタンスを作成
    const realtimeService = new RealtimeService(ws, apiKey);
    realtimeServices.set(ws, realtimeService);

    // OpenAI Realtime APIに接続
    await realtimeService.connect();

    // 接続確認メッセージを送信
    ws.send(JSON.stringify({
      type: 'status',
      message: 'OpenAI Realtime API に接続しました 🎉'
    }));

    // メッセージ受信時の処理
    ws.on('message', (data: Buffer | string, isBinary: boolean) => {
      if (isBinary || Buffer.isBuffer(data)) {
        // バイナリデータ（音声）の場合
        handleAudioData(ws, data as Buffer);
      } else {
        // テキストメッセージの場合
        try {
          const json = JSON.parse(data as string);
          console.log('📩 テキストメッセージ受信:', json);
          handleTextMessage(ws, json);
        } catch (e) {
          console.log('📩 テキストメッセージ受信:', data);
        }
      }
    });

    // 接続切断時のクリーンアップ
    ws.on('close', () => {
      console.log('🔌 クライアント接続が切断されました');
      const service = realtimeServices.get(ws);
      if (service) {
        service.cleanup();
        realtimeServices.delete(ws);
      }
    });

  } catch (error) {
    console.error('❌ 接続エラー:', error);
    ws.send(JSON.stringify({
      type: 'error',
      message: 'Failed to connect to OpenAI Realtime API'
    }));
    ws.close();
  }
};

/**
 * 音声バイナリデータを処理
 */
const handleAudioData = (ws: WebSocket, audioData: Buffer): void => {
  const audioSize = audioData.length;

  if (audioSize === 0) {
    ws.send(JSON.stringify({
      type: 'error',
      message: 'Audio data is empty'
    }));
    return;
  }

  console.log('====================================');
  console.log(`🎤 音声データ受信`);
  console.log(`時刻: ${new Date().toISOString()}`);
  console.log(`データサイズ: ${audioSize} bytes (${(audioSize / 1024).toFixed(2)} KB)`);

  // PCM 16bit (2 bytes per sample) と仮定
  const sampleCount = audioSize / 2;
  const durationMs = (sampleCount / 24000) * 1000; // 24kHz sampling rate
  console.log(`音声長さ: ${durationMs.toFixed(2)} ms`);
  console.log('====================================\n');

  // OpenAI Realtime APIに音声データを送信
  const realtimeService = realtimeServices.get(ws);
  if (realtimeService) {
    realtimeService.sendAudioToOpenAI(audioData);
  } else {
    console.warn('⚠️ RealtimeServiceが見つかりません');
    ws.send(JSON.stringify({
      type: 'error',
      message: 'Realtime service not initialized'
    }));
  }
};

/**
 * テキストメッセージを処理
 */
const handleTextMessage = (ws: WebSocket, message: any): void => {
  console.log('ℹ️ テキストメッセージ処理:', message);

  // ai_initiateメッセージを処理
  if (message.type === 'ai_initiate') {
    console.log('🤖 AIから話しかけてもらうリクエストを受信しました');
    const realtimeService = realtimeServices.get(ws);
    if (realtimeService) {
      realtimeService.initiateAIConversation();
    } else {
      console.warn('⚠️ RealtimeServiceが見つかりません');
    }
  }
};
