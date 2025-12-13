import type { WebSocket } from 'ws';

export const handleWebSocketConnection = (ws: WebSocket): void => {
  // 接続確認メッセージを送信
  ws.send(JSON.stringify({
    type: 'status',
    message: 'テスト接続できました🎉'
  }));

  // メッセージ受信時の処理（バイナリデータとして受け取る）
  ws.on('message', (data: Buffer | string, isBinary: boolean) => {
    // バイナリデータとして処理
    if (isBinary || Buffer.isBuffer(data)) {
      handleAudioData(ws, data as Buffer);
    } else {
      // テキストメッセージの場合
      try {
        const json = JSON.parse(data as string);
        console.log('Received text message:', json);
      } catch (e) {
        console.log('Received text message:', data);
      }
    }
  });
};

/**
 * 音声バイナリデータを処理する
 */
const handleAudioData = (ws: WebSocket, audioData: Buffer): void => {
  const audioSize = audioData.length;
  
  if (audioSize === 0) {
    ws.send(JSON.stringify({
      type: 'error',
      message: 'Audio data is empty'
    }));
    return;
  }
  
  // 詳細なログを出力
  console.log('====================================');
  console.log(`🎤 音声データ受信`);
  console.log(`時刻: ${new Date().toISOString()}`);
  console.log(`データサイズ: ${audioSize} bytes (${(audioSize / 1024).toFixed(2)} KB)`);
  
  // PCM 16bit (2 bytes per sample) と仮定してサンプル数を計算
  const sampleCount = audioSize / 2;
  console.log(`サンプル数: ${sampleCount} samples`);
  
  // 16kHzと仮定して録音時間を計算
  const durationMs = (sampleCount / 16000) * 1000;
  console.log(`音声長さ: ${durationMs.toFixed(2)} ms`);
  
  // 最初と最後のバイトを16進数で表示
  const previewBytes = Math.min(16, audioSize);
  const hexPreviewStart = audioData.slice(0, previewBytes).toString('hex');
  console.log(`先頭 ${previewBytes} bytes (hex): ${hexPreviewStart}`);
  
  if (audioSize > previewBytes) {
    const hexPreviewEnd = audioData.slice(-previewBytes).toString('hex');
    console.log(`末尾 ${previewBytes} bytes (hex): ${hexPreviewEnd}`);
  }
  
  // 音声データの統計情報を計算（Int16として解釈）
  let sum = 0;
  let min = 32767;
  let max = -32768;
  let nonZeroCount = 0;
  
  for (let i = 0; i < audioSize - 1; i += 2) {
    const sample = audioData.readInt16LE(i);
    sum += Math.abs(sample);
    min = Math.min(min, sample);
    max = Math.max(max, sample);
    if (sample !== 0) nonZeroCount++;
  }
  
  const average = sum / sampleCount;
  console.log(`音声レベル - 平均: ${average.toFixed(2)}, 最小: ${min}, 最大: ${max}`);
  console.log(`非ゼロサンプル: ${nonZeroCount}/${sampleCount} (${((nonZeroCount / sampleCount) * 100).toFixed(2)}%)`);
  console.log('====================================\n');

  // 確認メッセージを送信（オプション）
  // ws.send(JSON.stringify({
  //   type: 'status',
  //   message: `Audio data received (${audioSize} bytes)`
  // }));

  // ここに実際の音声処理を追加
  // 例: 音声認識、音声合成など
};
