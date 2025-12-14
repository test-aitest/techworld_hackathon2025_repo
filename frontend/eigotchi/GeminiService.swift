//
//  GeminiService.swift
//  eigotchi
//
//  Created for mouth detection and animation
//

import Foundation
import UIKit

// Gemini APIのレスポンス構造
struct GeminiResponse: Codable {
    let candidates: [Candidate]?

    struct Candidate: Codable {
        let content: Content

        struct Content: Codable {
            let parts: [Part]

            struct Part: Codable {
                let text: String?
            }
        }
    }
}

// 口の位置情報
struct MouthDetection {
    let boundingBox: CGRect  // 正規化された座標 (0.0-1.0)
    let confidence: Float
}

class GeminiService {
    // APIキーは環境変数または設定ファイルから取得してください
    // 本番環境では絶対にコード内にハードコードしないでください
    private let apiKey: String
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// 画像から口の位置を検出
    func    detectMouth(in image: UIImage) async throws -> MouthDetection? {
        // 画像をBase64エンコード
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "GeminiService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
        }

        let base64Image = imageData.base64EncodedString()

        // リクエストボディを構築
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": """
                            この画像には顔が描かれています。画像内の「口（mouth）」の位置を検出してください。

                            【超重要】口の特徴:
                            1. **色**: 口は「赤色（red）」で描かれています。赤い部分を探してください。
                            2. **位置**: 口は顔の「下半分」にあります（Y座標が0.6〜0.9の範囲）
                            3. **形状**: 横長の形状です（幅 > 高さ）。半円形、弧、横長の楕円形、または笑顔の形をしています。
                            4. **口の構成**: 口は「上の線」と「下の半円」の2つのパーツで構成されています。両方を含む領域を検出してください。

                            【絶対に避けること】:
                            - 目は黒色で、顔の上半分（Y座標0.2〜0.5）にあります。黒い物体は無視してください。
                            - 赤色以外の部分を口として検出しないでください。

                            画像の座標系:
                            - 左上が (0, 0)
                            - 右下が (1, 1)
                            - Y軸: 上が0、下が1

                            検出する領域:
                            - 赤色で描かれた「上の横線」と「下の半円」の両方を含む、最小の矩形領域
                            - heightは口全体（上の線〜下の半円の最下部）の高さ

                            以下のJSON形式で返してください:
                            {
                              "mouth_detected": true,
                              "center_x": 0.5,
                              "center_y": 0.75,
                              "width": 0.4,
                              "height": 0.15
                            }

                            注意:
                            - center_yは0.6〜0.9の範囲
                            - 赤色の領域全体を含むheightを返してください
                            """
                        ],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "topK": 1,
                "topP": 0.95,
                "maxOutputTokens": 1024
            ]
        ]

        // HTTPリクエストを作成
        var request = URLRequest(url: URL(string: "\(endpoint)?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // リクエスト送信
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GeminiService", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "GeminiService", code: httpResponse.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorMessage)"])
        }

        // レスポンスをパース
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let text = geminiResponse.candidates?.first?.content.parts.first?.text else {
            throw NSError(domain: "GeminiService", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "No text in response"])
        }

        // デバッグ: Gemini APIからの生のレスポンスを出力（詳細確認時のみ有効化）
        // print("📡 Gemini APIレスポンス:")
        // print("=== START ===")
        // print(text)
        // print("=== END ===")

        // JSONテキストから口の位置情報を抽出
        return try parseMouthDetection(from: text)
    }

    /// レスポンステキストから口の検出情報をパース
    private func parseMouthDetection(from text: String) throws -> MouthDetection? {
        // JSONブロックを抽出（```json ... ```の中身を取得）
        let jsonPattern = "```json\\s*([\\s\\S]*?)\\s*```"
        let plainJsonPattern = "\\{[\\s\\S]*?\\}"

        var jsonString = ""

        // まず```json```で囲まれたJSONを探す
        if let regex = try? NSRegularExpression(pattern: jsonPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            jsonString = String(text[range])
        }
        // 見つからない場合は、{}で囲まれたJSONを探す
        else if let regex = try? NSRegularExpression(pattern: plainJsonPattern),
                let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                let range = Range(match.range, in: text) {
            jsonString = String(text[range])
        }

        guard !jsonString.isEmpty else {
            print("❌ No JSON found in response: \(text)")
            return nil
        }

        // デバッグ: 抽出したJSONを出力（詳細確認時のみ有効化）
        // print("🔍 抽出されたJSON:")
        // print(jsonString)

        // JSONをパース
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            print("❌ Failed to parse JSON: \(jsonString)")
            return nil
        }

        // デバッグ: パース結果を出力（詳細確認時のみ有効化）
        // print("✅ JSONパース成功:")
        // print("  - mouth_detected: \(json["mouth_detected"] ?? "なし")")
        // print("  - center_x: \(json["center_x"] ?? "なし")")
        // print("  - center_y: \(json["center_y"] ?? "なし")")
        // print("  - width: \(json["width"] ?? "なし")")
        // print("  - height: \(json["height"] ?? "なし")")

        // 口が検出されたかチェック
        guard let mouthDetected = json["mouth_detected"] as? Bool,
              mouthDetected,
              let centerX = json["center_x"] as? Double,
              let centerY = json["center_y"] as? Double,
              let width = json["width"] as? Double,
              let height = json["height"] as? Double else {
            print("⚠️ Mouth not detected or invalid JSON structure")
            return nil
        }

        // 検証: center_yが0.6未満の場合は目を検出している可能性が高い
        if centerY < 0.6 {
            print("⚠️ 警告: 検出されたY座標(\(centerY))が顔の上部です")
            print("⚠️ これは口ではなく、目を検出している可能性があります")
            print("⚠️ 検出をスキップします")
            return nil
        }

        // 検証: 幅が高さより小さい場合は口ではない可能性が高い
        if width <= height {
            print("⚠️ 警告: 検出された形状が横長ではありません (幅:\(width) ≤ 高さ:\(height))")
            print("⚠️ 口は通常、横長の形状です")
            print("⚠️ 検出をスキップします")
            return nil
        }

        // バウンディングボックスを計算と調整
        // 赤色検出により精度が向上したため、調整を控えめに
        // 高さを2.5倍に調整（上の線＋下の半円を確実に覆うため）
        let adjustedHeight = height * 2.5
        // Y座標を下にシフト（半円の中心に合わせる）
        let adjustedCenterY = centerY + height * 0.5

        let x = centerX - width / 2
        let y = adjustedCenterY - adjustedHeight / 2
        let boundingBox = CGRect(x: x, y: y, width: width, height: adjustedHeight)

        print("📐 バウンディングボックス計算:")
        print("  - 元の高さ: \(height) → 調整後: \(adjustedHeight)")
        print("  - 元のY中心: \(centerY) → 調整後: \(adjustedCenterY)")
        print("  - Y範囲: \(y) ~ \(y + adjustedHeight)")
        print("  - 最終BoundingBox: \(boundingBox)")
        print("✅ 検証OK: 口として認識します")

        return MouthDetection(boundingBox: boundingBox, confidence: 0.9)
    }

    /// 画像に描かれているものを認識して説明を取得
    func recognizeDrawing(in image: UIImage) async throws -> String {
        // 画像をBase64エンコード
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "GeminiService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
        }

        let base64Image = imageData.base64EncodedString()

        // リクエストボディを構築
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": """
                            この画像に描かれているものは何ですか？
                            簡潔に日本語で1〜2文で説明してください。
                            """
                        ],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 200
            ]
        ]

        // HTTPリクエストを作成
        var request = URLRequest(url: URL(string: "\(endpoint)?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // リクエスト送信
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GeminiService", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "GeminiService", code: httpResponse.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorMessage)"])
        }

        // レスポンスをパース
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let text = geminiResponse.candidates?.first?.content.parts.first?.text else {
            throw NSError(domain: "GeminiService", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "No text in response"])
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
