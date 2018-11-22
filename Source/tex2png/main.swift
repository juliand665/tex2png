// Created by Julian Dunskus

import Foundation

let baseURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

if CommandLine.arguments.contains("-help") || CommandLine.arguments.contains("--help") {
	print("Usage: tex2png [file ...]")
	exit(0)
}

let urls = CommandLine.arguments.dropFirst().map {
	$0.hasPrefix("/") ? URL(fileURLWithPath: $0) : baseURL.appendingPathComponent($0)
}

for url in urls {
	let texture: Texture
	do {
		texture = try Texture(at: url)
	} catch {
		print("Could not load texture at", url)
		dump(error)
		continue
	}
	let image = texture.decode()
	
	let outputURL = url.deletingPathExtension().appendingPathExtension("png")
	
	let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, kUTTypePNG, 1, nil)!
	CGImageDestinationAddImage(destination, image, nil)
	if !CGImageDestinationFinalize(destination) {
		print("Could not save texture to", outputURL)
	}
}
