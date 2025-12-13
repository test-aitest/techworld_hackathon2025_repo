"""
Voice Chat API - FastAPI Backend
音声入力を受け取り、AI応答を音声で返すAPIサーバー
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import logging

load_dotenv()

from controllers.websocket_controller import websocket_endpoint

# ロギング設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Voice Chat API",
    description="音声チャットAPIサーバー - OpenAI STT/LLM + ElevenLabs TTS",
    version="1.0.0"
)

# CORS設定（開発用）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# WebSocketエンドポイントを登録
app.websocket("/ws")(websocket_endpoint)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
