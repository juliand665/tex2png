// Created by Julian Dunskus

import Foundation
import CoreGraphics

let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

final class Texture {
	let name: String
	let width: Int
	let height: Int
	var state: State
	
	init(at url: URL) throws {
		let data = try Data(contentsOf: url)
		
		name = url.lastPathComponent.components(separatedBy: ".tex").first!
		width = Int(data.read(UInt32.self, at: 4))
		height = Int(data.read(UInt32.self, at: 8))
		state = .decoding(LZ4Decoder(for: data[60...]))
	}
	
	func decode() -> CGImage {
		switch state {
		case .decoding(let decoder):
			let contents = decoder.runSync()
			let image = generateImage(from: contents)
			state = .decoded(image)
			return image
		case .decoded(let image):
			return image
		}
	}
	
	func asyncDecode(completion: @escaping (CGImage?) -> Void) {
		switch state {
		case .decoding(let decoder):
			decoder.runAsync { contents in
				if let contents = contents {
					let image = self.generateImage(from: contents)
					self.state = .decoded(image)
					completion(image)
				} else {
					completion(nil)
				}
			}
		case .decoded(let image):
			completion(image)
		}
	}
	
	private func generateImage(from imageData: Data) -> CGImage {
		let context = CGContext(
			data: nil,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: 4 * width,
			space: rgbColorSpace,
			bitmapInfo: bitmapInfo
		)!
		imageData.withUnsafeBytes {
			context.data!.copyMemory(from: $0, byteCount: 4 * width * height)
		}
		
		// flip vertically
		let image = context.makeImage()!
		context.clear(CGRect(x: 0, y: 0, width: width, height: height))
		context.translateBy(x: 0, y: CGFloat(height))
		context.scaleBy(x: 1, y: -1)
		context.draw(image, in: CGRect(origin: .zero, size: CGSize(width: width, height: height)))
		
		return context.makeImage()!
	}
	
	enum State {
		case decoding(LZ4Decoder)
		case decoded(CGImage)
	}
}
