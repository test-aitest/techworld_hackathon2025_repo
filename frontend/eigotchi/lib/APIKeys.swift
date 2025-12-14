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
           !key.isEmpty, !key.starts(with: "$(") {
            return key
        }

        // フォールバック: 環境変数から取得（開発時のみ）
        #if DEBUG
        print("⚠️ GEMINI_API_KEY not found in Info.plist, using fallback")
        return "AIzaSyCFEjaPsldMJPhkuvKvtAKD9hGV8dyoL7g"
        #else
        fatalError("GEMINI_API_KEY not found in Info.plist")
        #endif
    }

    /// OpenAI API Key
    static var openAI: String {
        // Info.plist経由で取得を試みる
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           !key.isEmpty, !key.starts(with: "$(") {
            return key
        }

        // フォールバック: 環境変数から取得（開発時のみ）
        #if DEBUG
        print("⚠️ OPENAI_API_KEY not found in Info.plist, using fallback")
        return "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"
        #else
        fatalError("OPENAI_API_KEY not found in Info.plist")
        #endif
    }
}
