"""
Speech-to-Text Service using OpenAI Whisper API
"""

import os
from openai import AsyncOpenAI

client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))


async def transcribe_audio(audio_bytes: bytes, filename: str) -> str:
    """
    音声データをテキストに変換する
    
    Args:
        audio_bytes: 音声ファイルのバイナリデータ
        filename: ファイル名（拡張子から形式を判定）
    
    Returns:
        str: 文字起こしされたテキスト
    """
    # ファイル拡張子の正規化
    if not filename:
        filename = "audio.m4a"
    
    # OpenAI Whisper APIで文字起こし
    transcript = await client.audio.transcriptions.create(
        model="whisper-1",
        file=(filename, audio_bytes),
        language="ja",  # 日本語を指定（自動検出も可能）
        response_format="text"
    )
    
    return transcript.strip()


async def transcribe_audio_with_details(audio_bytes: bytes, filename: str) -> dict:
    """
    音声データをテキストに変換（詳細情報付き）
    
    Args:
        audio_bytes: 音声ファイルのバイナリデータ
        filename: ファイル名
    
    Returns:
        dict: 文字起こし結果と詳細情報
    """
    transcript = await client.audio.transcriptions.create(
        model="whisper-1",
        file=(filename, audio_bytes),
        language="ja",
        response_format="verbose_json"
    )
    
    return {
        "text": transcript.text,
        "language": transcript.language,
        "duration": transcript.duration,
        "segments": transcript.segments if hasattr(transcript, 'segments') else []
    }
