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
      // isBinaryフラグを優先的にチェック
      if (isBinary) {
        // バイナリデータ（音声）の場合
        handleAudioData(ws, data as Buffer);
      } else {
        // テキストメッセージの場合（BufferをStringに変換）
        const textData = Buffer.isBuffer(data) ? data.toString('utf-8') : data;
        try {
          const json = JSON.parse(textData);
          handleTextMessage(ws, json);
        } catch (e) {
          console.error('❌ JSONパースエラー:', e);
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

  // 小さすぎるデータ（ノイズ/初期化データ）は無視
  if (audioSize < 100) {
    return;
  }

  if (audioSize === 0) {
    ws.send(JSON.stringify({
      type: 'error',
      message: 'Audio data is empty'
    }));
    return;
  }

  // OpenAI Realtime APIに音声データを送信
  const realtimeService = realtimeServices.get(ws);
  if (realtimeService) {
    realtimeService.sendAudioToOpenAI(audioData);
  }
};

/**
 * テキストメッセージを処理
 */
const handleTextMessage = (ws: WebSocket, message: any): void => {
  // ai_initiateメッセージを処理
  if (message.type === 'ai_initiate') {
    const realtimeService = realtimeServices.get(ws);
    if (realtimeService) {
      realtimeService.initiateAIConversation();
    }
  }
};
