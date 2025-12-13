"""
Voice Chat Service - Orchestrates LLM and TTS processing
"""

import logging
import asyncio
from typing import Callable, Optional, Awaitable, Union

from services.llm import generate_response
from services.tts import synthesize_speech

logger = logging.getLogger(__name__)


class VoiceChatService:
    """テキストチャットの統合処理を担当するサービス"""

    def __init__(self):
        pass

    async def process_text_chat(
        self,
        user_text: str,
        on_status_update: Optional[Callable[[str], Union[None, Awaitable[None]]]] = None
    ) -> dict:
        """
        テキストチャットの処理を実行する（LLM → TTS）

        Args:
            user_text: ユーザーからのテキストメッセージ
            on_status_update: ステータス更新時のコールバック関数

        Returns:
            dict: {
                "reply": str,        # AI応答テキスト
                "audio": bytes       # 音声データ（MP3）
            }

        Raises:
            Exception: 処理中にエラーが発生した場合
        """
        # 1. LLM: 応答生成
        if on_status_update:
            await self._call_callback(on_status_update, "応答を生成中...")

        logger.info(f"Generating response for text: {user_text}")
        reply = await generate_response(user_text)
        logger.info(f"Reply: {reply}")

        # 2. TTS: テキスト → 音声
        if on_status_update:
            await self._call_callback(on_status_update, "音声を生成中...")

        logger.info("Synthesizing speech...")
        audio_response = await synthesize_speech(reply)
        logger.info(f"Audio response size: {len(audio_response)} bytes")

        return {
            "reply": reply,
            "audio": audio_response
        }

    async def _call_callback(
        self,
        callback: Callable[[str], Union[None, Awaitable[None]]],
        message: str
    ):
        """
        コールバック関数を非同期で実行する

        Args:
            callback: コールバック関数（同期または非同期）
            message: メッセージ
        """
        if callback and callable(callback):
            # コールバックがasync関数かどうかを確認
            if asyncio.iscoroutinefunction(callback):
                await callback(message)
            else:
                callback(message)
