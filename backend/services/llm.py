"""
LLM Response Generation Service using OpenAI API
"""

import os
from openai import AsyncOpenAI
from typing import Optional

client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# システムプロンプト
SYSTEM_PROMPT = """あなたは親切で自然な音声アシスタントです。

以下のガイドラインに従って応答してください：
- 簡潔で自然な日本語で応答する
- 音声で聞いて理解しやすい表現を使う
- 長すぎる応答は避け、2-3文程度にまとめる
- 箇条書きやマークダウンは使わない（音声で読み上げるため）
- 親しみやすく、丁寧な口調を維持する
"""


async def generate_response(
    user_message: str,
    conversation_history: Optional[list] = None,
    system_prompt: Optional[str] = None
) -> str:
    """
    ユーザーのメッセージに対する応答を生成する
    
    Args:
        user_message: ユーザーの発話テキスト
        conversation_history: 過去の会話履歴（オプション）
        system_prompt: カスタムシステムプロンプト（オプション）
    
    Returns:
        str: AIの応答テキスト
    """
    messages = [
        {"role": "system", "content": system_prompt or SYSTEM_PROMPT}
    ]
    
    # 会話履歴があれば追加
    if conversation_history:
        messages.extend(conversation_history)
    
    # ユーザーメッセージを追加
    messages.append({"role": "user", "content": user_message})
    
    # OpenAI APIで応答生成
    response = await client.chat.completions.create(
        model="gpt-4o",
        messages=messages,
        max_tokens=300,
        temperature=0.7,
    )
    
    return response.choices[0].message.content.strip()


async def generate_response_streaming(
    user_message: str,
    conversation_history: Optional[list] = None
):
    """
    ストリーミングで応答を生成する（将来の拡張用）
    
    Yields:
        str: 応答テキストのチャンク
    """
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT}
    ]
    
    if conversation_history:
        messages.extend(conversation_history)
    
    messages.append({"role": "user", "content": user_message})
    
    stream = await client.chat.completions.create(
        model="gpt-4o",
        messages=messages,
        max_tokens=300,
        temperature=0.7,
        stream=True
    )
    
    async for chunk in stream:
        if chunk.choices[0].delta.content:
            yield chunk.choices[0].delta.content
