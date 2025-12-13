import type { WebSocket } from 'ws';

// 受信データの型定義
interface AudioMessagePayload {
  userName: string;
  audioMessage: string;
}

export const handleWebSocketConnection = (ws: WebSocket): void => {
  // 接続確認メッセージを送信
  ws.send(JSON.stringify({
    type: 'status',
    message: 'Connected to WebSocket server'
  }));

  // メッセージ受信時の処理（バイナリデータとして受け取る）
  ws.on('message', (data: Buffer | string, isBinary: boolean) => {
    // バイナリデータとして処理
    // if (isBinary || Buffer.isBuffer(data)) {
    //   handleAudioData(ws, data as Buffer);
    // } else {
    //   ws.send(JSON.stringify({
    //     type: 'error',
    //     message: 'Expected binary audio data'
    //   }));
    // }
    return "hackathon!!"
  });
};

/**
 * 音声バイナリデータを処理する
 */
const handleAudioData = (ws: WebSocket, audioData: Buffer): void => {
  const audioSize = audioData.length;
  console.log(`Received audio data: ${audioSize} bytes`);

  if (audioSize === 0) {
    ws.send(JSON.stringify({
      type: 'error',
      message: 'Audio data is empty'
    }));
    return;
  }

  ws.send(JSON.stringify({
    type: 'status',
    message: `Audio data received (${audioSize} bytes)`
  }));

  // ここに実際の音声処理を追加
  ws.send(JSON.stringify({
    type: 'status',
    message: 'Processing audio data...'
  }));
};
