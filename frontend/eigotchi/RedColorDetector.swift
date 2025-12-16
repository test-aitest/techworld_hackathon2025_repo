//
//  RedColorDetector.swift
//  eigotchi
//
//  赤色ピクセルを直接検出するユーティリティ
//

import UIKit
import CoreGraphics

class RedColorDetector {

    /// 画像から赤色ピクセルの最小外接矩形を検出
    /// - Parameter image: 検出対象の画像
    /// - Returns: 赤色領域の矩形（正規化座標: 0.0-1.0）、検出できない場合はnil
    static func detectRedArea(in image: UIImage) -> CGRect? {
        // UIImageをRGBA形式のビットマップコンテキストで再描画
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        // RGBAフォーマットでビットマップコンテキストを作成
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // 画像を描画
        context.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))

        // ピクセルデータを取得
        guard let data = context.data else {
            return nil
        }

        let pixelData = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

        var minX = width
        var maxX = 0
        var minY = height
        var maxY = 0
        var redPixelCount = 0

        // すべてのピクセルをスキャン
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel

                // RGBA形式でデータを取得
                let r = CGFloat(pixelData[pixelIndex]) / 255.0
                let g = CGFloat(pixelData[pixelIndex + 1]) / 255.0
                let b = CGFloat(pixelData[pixelIndex + 2]) / 255.0

                // 赤色の判定: R > G AND R > B AND R > 0.5
                if r > g && r > b && r > 0.5 {
                    redPixelCount += 1
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }

        guard redPixelCount > 0 else {
            return nil
        }

        // ピクセル座標から正規化座標に変換
        let normalizedX = CGFloat(minX) / CGFloat(width)
        let normalizedY = CGFloat(minY) / CGFloat(height)
        let normalizedWidth = CGFloat(maxX - minX + 1) / CGFloat(width)
        let normalizedHeight = CGFloat(maxY - minY + 1) / CGFloat(height)

        return CGRect(
            x: normalizedX,
            y: normalizedY,
            width: normalizedWidth,
            height: normalizedHeight
        )
    }
}
