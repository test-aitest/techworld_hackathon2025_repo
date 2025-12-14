import { WebSocketServer } from 'ws';
import type { WebSocket } from 'ws';
import { handleWebSocketConnection } from './controllers/voiceController';
import dotenv from 'dotenv';

// 環境変数を読み込み
dotenv.config();

const PORT = process.env.PORT ? Number(process.env.PORT) : 3000;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

if (!OPENAI_API_KEY) {
  console.error('❌ エラー: OPENAI_API_KEY が設定されていません');
  console.error('📝 .env ファイルを作成し、OPENAI_API_KEY を設定してください');
  process.exit(1);
}

// WebSocketサーバーを作成
const wss = new WebSocketServer({ port: PORT });

console.log(`🚀 WebSocket server is running on ws://localhost:${PORT}`);
console.log(`🔑 OpenAI API Key: ${OPENAI_API_KEY.substring(0, 20)}...`);

// クライアント接続時の処理
wss.on('connection', (ws: WebSocket) => {
  console.log('🔌 New WebSocket connection established');

  // コントローラーで接続を処理
  handleWebSocketConnection(ws, OPENAI_API_KEY);

  // 接続切断時の処理
  ws.on('close', () => {
    console.log('🔌 WebSocket connection closed');
  });

  // エラー処理
  ws.on('error', (error) => {
    console.error('❌ WebSocket error:', error);
  });
});

export default wss;
