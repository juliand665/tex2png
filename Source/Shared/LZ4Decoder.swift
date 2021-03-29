// Created by Julian Dunskus

import Foundation

final class LZ4Decoder {
	private let input: Data
	private(set) var position: Data.Index
	private(set) var output = Data()
	
	var progress: Double {
		return Double(position - input.startIndex) / Double(input.count)
	}
	
	private(set) var isRunning = true
	private(set) var isFinished = false
	
	init(for input: Data) {
		self.input = input
		self.position = input.startIndex
		
		output.reserveCapacity(input.count)
	}
	
	func cancel() {
		isRunning = false
	}
	
	func runAsync(completion: @escaping (Data?) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			var output = Data()
			output.reserveCapacity(self.input.count)
			
			while self.isRunning {
				self.readBlock(into: &output)
			}
			
			completion(self.isFinished ? output : nil)
		}
	}
	
	func runSync() -> Data {
		while !isFinished {
			readBlock(into: &output)
		}
		
		return output
	}
	
	private func readBlock(into output: inout Data) {
		//print("position:", position)
		
		var literalLength = peekByte() >> 4 & 0xF
		var matchLength = popByte() & 0xF
		
		decodeLSICInteger(into: &literalLength)
		//print("reading \(literalLength) literal bytes")
		output.append(pop(byteCount: literalLength))
		
		guard position < input.endIndex else {
			isRunning = false
			isFinished = true
			return
		}
		
		let offset = Int(pop(byteCount: 2).read(UInt16.self))
		
		decodeLSICInteger(into: &matchLength)
		matchLength += 4
		//print("copying \(matchLength) literal bytes")
		
		let startPos = output.endIndex - offset
		
		if abs(offset) >= matchLength {
			var match = output[startPos..<startPos + matchLength]
			match.withUnsafeMutableBytes { _ in } // ensure unique reference
			output.append(match)
		} else {
			for position in startPos..<startPos + matchLength {
				output.append(output[position])
			}
		}
	}
	
	private func decodeLSICInteger(into value: inout Int) {
		guard value == 15 else { return }
		
		while true {
			let next = popByte()
			value += next
			guard next == 255 else { return }
		}
	}
	
	private func peekByte() -> Int {
		return Int(input[position])
	}
	
	private func popByte() -> Int {
		defer { position += 1 }
		return peekByte()
	}
	
	private func pop(byteCount: Int) -> Data {
		defer { position += byteCount }
		return input[position..<position + byteCount]
	}
}

extension Data {
	func read<T>(_ type: T.Type, at offset: Int = 0) -> T {
		return self.dropFirst(offset).withUnsafeBytes { $0.pointee }
	}
}
