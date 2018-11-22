// Created by Julian Dunskus

import Cocoa

class ViewController: NSViewController {
	@IBOutlet var imageView: NSImageView!
	@IBOutlet var progressBar: NSProgressIndicator!
	@IBOutlet var openButton: NSButton!
	
	@IBAction func openTexture(_ sender: Any) {
		if case .decoding(let decoder)? = self.texture?.state {
			decoder.cancel()
			update()
			return
		}
		
		let openPanel = NSOpenPanel()
		openPanel.allowedFileTypes = ["tex"]
		let result = openPanel.runModal()
		guard result == .OK else { return }
		let url = openPanel.urls.first!
		
		do {
			let texture = try Texture(at: url)
			self.texture = texture
			view.window!.title = "\(url.lastPathComponent) (\(texture.width)×\(texture.height))"
			
			updateTimer = .scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in self.update() }
			texture.asyncDecode { image in
				self.updateTimer?.invalidate()
				
				guard let image = image else { return }
				
				DispatchQueue.main.async {
					self.imageView.image = NSImage(cgImage: image, size: .zero)
					self.update()
				}
			}
		} catch {
			NSAlert(error: error).runModal()
		}
	}
	
	var texture: Texture?
	var updateTimer: Timer?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		update()
	}
	
	func update() {
		switch texture?.state {
		case .decoding(let decoder)?:
			openButton.title = "Cancel"
			progressBar.doubleValue = decoder.progress
		default:
			openButton.title = "Open Texture"
			progressBar.doubleValue = 1
		}
	}
}

/// Scales down with anti-aliasing, up without
@IBDesignable
class PixelPerfectImageView: NSImageView {
	override func draw(_ dirtyRect: NSRect) {
		let context = NSGraphicsContext.current!
		let prev = context.imageInterpolation
		let scale = window?.backingScaleFactor ?? 1
		if let image = image, image.size.width < scale * frame.size.width {
			context.imageInterpolation = .none
		}
		super.draw(dirtyRect)
		context.imageInterpolation = prev
	}
}
