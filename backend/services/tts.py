"""
Text-to-Speech Service using ElevenLabs API
"""

import os
import httpx
from typing import Optional

ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY")
DEFAULT_VOICE_ID = os.getenv("ELEVENLABS_VOICE_ID", "21m00Tcm4TlvDq8ikWAM")

# 利用可能な音声ID（参考）
VOICE_IDS = {
    "rachel": "21m00Tcm4TlvDq8ikWAM",      # Rachel - 落ち着いた女性
    "domi": "AZnzlk1XvdvUeBnXmlld",         # Domi - 力強い女性
    "bella": "EXAVITQu4vr4xnSDxMaL",        # Bella - 柔らかい女性
    "antoni": "ErXwobaYiN019PkySvjV",       # Antoni - 落ち着いた男性
    "josh": "TxGEqnHWrfWFTfGW9XjX",         # Josh - 深い男性
    "arnold": "VR6AewLTigWG4xSOukaG",       # Arnold - 力強い男性
    "sam": "yoZ06aMxZJJ28mfd3POQ",          # Sam - 若い男性
}


async def synthesize_speech(
    text: str,
    voice_id: Optional[str] = None,
    model_id: str = "eleven_multilingual_v2",
    stability: float = 0.5,
    similarity_boost: float = 0.75
) -> bytes:
    """
    テキストを音声に変換する
    
    Args:
        text: 読み上げるテキスト
        voice_id: 音声ID（デフォルト: Rachel）
        model_id: モデルID（多言語対応: eleven_multilingual_v2）
        stability: 安定性（0-1、高いほど一貫性のある音声）
        similarity_boost: 類似性（0-1、高いほど元の声に近い）
    
    Returns:
        bytes: MP3音声データ
    """
    if not ELEVENLABS_API_KEY:
        raise ValueError("ELEVENLABS_API_KEY is not set")
    
    voice = voice_id or DEFAULT_VOICE_ID
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice}"
    
    async with httpx.AsyncClient() as client:
        response = await client.post(
            url,
            headers={
                "xi-api-key": ELEVENLABS_API_KEY,
                "Content-Type": "application/json",
                "Accept": "audio/mpeg"
            },
            json={
                "text": text,
                "model_id": model_id,
                "voice_settings": {
                    "stability": stability,
                    "similarity_boost": similarity_boost
                }
            },
            timeout=30.0
        )
        
        if response.status_code != 200:
            error_detail = response.text
            raise Exception(f"ElevenLabs API error: {response.status_code} - {error_detail}")
        
        return response.content


async def synthesize_speech_streaming(
    text: str,
    voice_id: Optional[str] = None
):
    """
    ストリーミングで音声を生成する（リアルタイム応答用）
    
    Yields:
        bytes: 音声データのチャンク
    """
    if not ELEVENLABS_API_KEY:
        raise ValueError("ELEVENLABS_API_KEY is not set")
    
    voice = voice_id or DEFAULT_VOICE_ID
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice}/stream"
    
    async with httpx.AsyncClient() as client:
        async with client.stream(
            "POST",
            url,
            headers={
                "xi-api-key": ELEVENLABS_API_KEY,
                "Content-Type": "application/json",
                "Accept": "audio/mpeg"
            },
            json={
                "text": text,
                "model_id": "eleven_multilingual_v2",
                "voice_settings": {
                    "stability": 0.5,
                    "similarity_boost": 0.75
                }
            },
            timeout=60.0
        ) as response:
            async for chunk in response.aiter_bytes():
                yield chunk


async def get_available_voices() -> list:
    """
    利用可能な音声一覧を取得する
    
    Returns:
        list: 音声情報のリスト
    """
    if not ELEVENLABS_API_KEY:
        raise ValueError("ELEVENLABS_API_KEY is not set")
    
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://api.elevenlabs.io/v1/voices",
            headers={"xi-api-key": ELEVENLABS_API_KEY},
            timeout=10.0
        )
        
        if response.status_code != 200:
            raise Exception(f"Failed to get voices: {response.status_code}")
        
        data = response.json()
        return data.get("voices", [])
