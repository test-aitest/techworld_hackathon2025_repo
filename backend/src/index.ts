import { WebSocketServer } from 'ws';
import type { WebSocket } from 'ws';
import { handleWebSocketConnection } from './controllers/voiceController';

const PORT = process.env.PORT ? Number(process.env.PORT) : 3000;

// WebSocketサーバーを作成
const wss = new WebSocketServer({ port: PORT });

console.log(`WebSocket server is running on ws://localhost:${PORT}`);

// クライアント接続時の処理
wss.on('connection', (ws: WebSocket) => {
  console.log('New WebSocket connection established');

  // コントローラーで接続を処理
  handleWebSocketConnection(ws);

  // 接続切断時の処理
  ws.on('close', () => {
    console.log('WebSocket connection closed');
  });

  // エラー処理
  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

export default wss;
