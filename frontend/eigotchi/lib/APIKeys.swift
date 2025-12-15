//
//  APIKeys.swift
//  eigotchi
//
//  API Keys configuration helper
//

import Foundation

enum APIKeys {
    /// Gemini API Key
    static var gemini: String {
        // Info.plist経由で取得を試みる
        if let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String,
           !key.isEmpty, !key.starts(with: "${") {
            return key
        }

        return ""
    }

    /// OpenAI API Key
    static var openAI: String {
        // Info.plist経由で取得を試みる
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           !key.isEmpty, !key.starts(with: "${") {
            return key
        }
        
        return ""
    }
}
