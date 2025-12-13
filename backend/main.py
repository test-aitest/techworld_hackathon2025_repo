"""
Voice Chat API - FastAPI Backend
音声入力を受け取り、AI応答を音声で返すAPIサーバー
"""

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from urllib.parse import quote
import logging

load_dotenv()

from services.stt import transcribe_audio
from services.llm import generate_response
from services.tts import synthesize_speech

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


@app.post("/chat")
async def chat(audio: UploadFile = File(...)):
    """
    音声ファイルを受け取り、AI応答の音声を返す
    
    - **audio**: 音声ファイル（m4a推奨）
    
    Returns:
        - audio/mpeg: MP3音声データ
        - X-Transcript: ユーザーの発話テキスト（URLエンコード済み）
        - X-Reply: AIの応答テキスト（URLエンコード済み）
    """
    try:
        logger.info(f"Received audio file: {audio.filename}")
        
        # 1. 音声ファイル読み込み
        audio_bytes = await audio.read()
        logger.info(f"Audio size: {len(audio_bytes)} bytes")
        
        # 2. STT: 音声 → テキスト
        logger.info("Starting transcription...")
        transcript = await transcribe_audio(audio_bytes, audio.filename or "audio.m4a")
        logger.info(f"Transcript: {transcript}")
        
        # 3. LLM: 応答生成
        logger.info("Generating response...")
        reply = await generate_response(transcript)
        logger.info(f"Reply: {reply}")
        
        # 4. TTS: テキスト → 音声
        logger.info("Synthesizing speech...")
        audio_response = await synthesize_speech(reply)
        logger.info(f"Audio response size: {len(audio_response)} bytes")
        
        # 5. レスポンス返却
        return Response(
            content=audio_response,
            media_type="audio/mpeg",
            headers={
                "X-Transcript": quote(transcript, safe=""),
                "X-Reply": quote(reply, safe=""),
                "Access-Control-Expose-Headers": "X-Transcript, X-Reply"
            }
        )
        
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/chat/json")
async def chat_json(audio: UploadFile = File(...)):
    """
    音声ファイルを受け取り、JSON形式で応答を返す（デバッグ用）
    
    音声データはBase64エンコードされて返される
    """
    import base64
    
    try:
        audio_bytes = await audio.read()
        
        transcript = await transcribe_audio(audio_bytes, audio.filename or "audio.m4a")
        reply = await generate_response(transcript)
        audio_response = await synthesize_speech(reply)
        
        return {
            "transcript": transcript,
            "reply": reply,
            "audio_base64": base64.b64encode(audio_response).decode("utf-8")
        }
        
    except Exception as e:
        logger.error(f"Error: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
async def health_check():
    """ヘルスチェックエンドポイント"""
    return {"status": "healthy", "service": "voice-chat-api"}


@app.get("/")
async def root():
    """ルートエンドポイント"""
    return {
        "message": "Voice Chat API",
        "docs": "/docs",
        "endpoints": {
            "chat": "POST /chat - 音声チャット（MP3応答）",
            "chat_json": "POST /chat/json - 音声チャット（JSON応答）",
            "health": "GET /health - ヘルスチェック"
        }
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
