"""
WebSocket Controller - Handles WebSocket connections and message routing
"""

from fastapi import WebSocket, WebSocketDisconnect
import logging
import base64

from services.voice_chat_service import VoiceChatService

logger = logging.getLogger(__name__)


class WebSocketController:
    """WebSocket接続とメッセージの送受信を管理するコントローラー"""

    def __init__(self):
        self.voice_chat_service = VoiceChatService()

    async def handle_connection(self, websocket: WebSocket):
        """
        WebSocket接続を処理する

        Args:
            websocket: WebSocket接続オブジェクト
        """
        await websocket.accept()
        logger.info("WebSocket connection established")

        try:
            while True:
                # テキストデータを受信（JSON形式）
                data = await websocket.receive_json()
                logger.info(f"Received message: {data}")

                # テキストを抽出
                user_text = data.get("text", "") if isinstance(data, dict) else str(data)

                if not user_text:
                    await self._send_error(websocket, "テキストが空です")
                    continue

                logger.info(f"User text: {user_text}")

                # テキストチャット処理を実行
                await self._process_text_chat(websocket, user_text)

        except WebSocketDisconnect:
            logger.info("WebSocket connection closed")
        except Exception as e:
            logger.error(f"WebSocket error: {str(e)}", exc_info=True)
            await self._send_error(websocket, f"接続エラー: {str(e)}")

    async def _process_text_chat(self, websocket: WebSocket, user_text: str):
        """
        テキストチャットの処理を実行する

        Args:
            websocket: WebSocket接続オブジェクト
            user_text: ユーザーからのテキストメッセージ
        """
        try:
            # ステータス通知: 処理開始
            await self._send_status(websocket, "メッセージを処理中...")

            # テキストチャットサービスで処理を実行
            async def status_callback(message: str):
                """ステータス更新のコールバック関数"""
                try:
                    await self._send_status(websocket, message)
                except Exception as e:
                    # ステータス送信に失敗した場合はログに記録するが、処理は続行
                    logger.warning(f"Failed to send status update: {str(e)}")
                    raise

            result = await self.voice_chat_service.process_text_chat(
                user_text,
                on_status_update=status_callback
            )

            # 応答テキストを送信
            await self._send_reply(websocket, result["reply"])

            # 音声データを送信
            await self._send_audio(websocket, result["audio"])

            # 処理完了を通知
            await self._send_status(websocket, "処理完了")

        except Exception as e:
            logger.error(f"Error processing text: {str(e)}", exc_info=True)
            await self._send_error(websocket, f"処理中にエラーが発生しました: {str(e)}")

    async def _send_status(self, websocket: WebSocket, message: str):
        """ステータスメッセージを送信"""
        try:
            await websocket.send_json({
                "type": "status",
                "message": message
            })
        except Exception as e:
            logger.warning(f"Failed to send status message: {str(e)}")
            raise

    async def _send_reply(self, websocket: WebSocket, reply: str):
        """応答テキストを送信"""
        try:
            await websocket.send_json({
                "type": "reply",
                "data": reply
            })
        except Exception as e:
            logger.warning(f"Failed to send reply: {str(e)}")
            raise

    async def _send_audio(self, websocket: WebSocket, audio_bytes: bytes):
        """音声データをBase64エンコードして送信"""
        try:
            audio_base64 = base64.b64encode(audio_bytes).decode("utf-8")
            await websocket.send_json({
                "type": "audio",
                "data": audio_base64,
                "format": "mp3"
            })
        except Exception as e:
            logger.warning(f"Failed to send audio: {str(e)}")
            raise

    async def _send_error(self, websocket: WebSocket, message: str):
        """エラーメッセージを送信"""
        try:
            await websocket.send_json({
                "type": "error",
                "message": message
            })
        except Exception:
            # 接続が既に閉じられている場合は無視
            pass


# シングルトンインスタンス
_controller = WebSocketController()


async def websocket_endpoint(websocket: WebSocket):
    """
    WebSocketエンドポイント - テキストチャット

    クライアントからテキストデータを受信し、
    LLM → TTSの処理を実行して結果を返す

    メッセージ形式:
    - 受信: JSON形式
      {
        "text": "ユーザーのメッセージ"
      }
      または単純なテキスト文字列

    - 送信: JSON形式
      {
        "type": "status" | "reply" | "audio" | "error",
        "data": string | base64 string,
        "message": string (ステータス/エラー時)
      }
    """
    await _controller.handle_connection(websocket)
