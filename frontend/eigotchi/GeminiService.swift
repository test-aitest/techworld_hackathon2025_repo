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

// 顔の種類
enum FaceType: String {
    case human = "human"
    case cat = "cat"
}

// 口の位置情報
struct MouthDetection {
    let boundingBox: CGRect  // 正規化された座標 (0.0-1.0)
    let confidence: Float
    let faceType: FaceType  // 人間か猫か
    let redAreaBounds: CGRect  // 赤色領域の範囲
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
    func detectMouth(in image: UIImage) async throws -> MouthDetection? {
        // 画像をBase64エンコード（高品質で赤色の検出精度を向上）
        guard let imageData = image.jpegData(compressionQuality: 0.95) else {
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
                            この画像には顔が描かれています。

                            **あなたのタスク**: 顔の種類を判別してください。

                            顔の種類の判別:
                            - この顔は「人間（human）」ですか、それとも「猫（cat）」ですか？
                            - 判断基準:
                              * 人間: 丸い耳、または耳がない顔
                              * 猫: 三角形や尖った耳がある顔

                            以下のJSON形式で返してください:
                            {
                              "face_type": "human"
                            }

                            または

                            {
                              "face_type": "cat"
                            }
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
                "temperature": 0.0,
                "topK": 1,
                "topP": 1.0,
                "maxOutputTokens": 1024,
                "responseMimeType": "application/json"
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

        // JSONテキストから口の位置情報を抽出
        return try parseMouthDetection(from: text)
    }

    /// レスポンステキストから口の検出情報をパース
    private func parseMouthDetection(from text: String) throws -> MouthDetection? {
        var jsonString = ""
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. まず```json```で囲まれたJSONを探す
        let jsonPattern = "```json\\s*([\\s\\S]*?)\\s*```"
        if let regex = try? NSRegularExpression(pattern: jsonPattern),
           let match = regex.firstMatch(in: trimmedText, range: NSRange(trimmedText.startIndex..., in: trimmedText)),
           let range = Range(match.range(at: 1), in: trimmedText) {
            jsonString = String(trimmedText[range])
        }
        // 2. テキスト全体がJSONの場合（responseMimeType: "application/json"を指定しているため）
        else if trimmedText.hasPrefix("{") && trimmedText.hasSuffix("}") {
            jsonString = trimmedText
        }
        // 3. 手動でJSONブロックを抽出
        else if let startIndex = trimmedText.firstIndex(of: "{"),
                let endIndex = trimmedText.lastIndex(of: "}") {
            jsonString = String(trimmedText[startIndex...endIndex])
        }

        guard !jsonString.isEmpty else {
            return nil
        }

        // JSONをパース
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        // 顔の種類を取得
        guard let faceTypeString = json["face_type"] as? String,
              let faceType = FaceType(rawValue: faceTypeString) else {
            return nil
        }

        // ダミーの矩形を返す（実際の赤色領域はSwift側で検出）
        let dummyRect = CGRect(x: 0.5, y: 0.75, width: 0.1, height: 0.1)

        return MouthDetection(
            boundingBox: dummyRect,
            confidence: 0.9,
            faceType: faceType,
            redAreaBounds: dummyRect
        )
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
