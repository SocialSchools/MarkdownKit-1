import UIKit

public protocol TextStorageCustomDelegate: AnyObject {
	func textStorage(_ textStorage: TextStorage, didParseDocument document: Document)
	func textStorage(_ textStorage: TextStorage, didChangeTheme theme: Theme)

	func textStorage(_ textStorage: TextStorage, shouldChangeTextIn range: NSRange, with string: String,
					 actionName: String) -> Bool
	func textStorage(_ textStorage: TextStorage, didUpdateSelectedRange range: NSRange)
}

public final class TextStorage: BaseTextStorage {

	// MARK: - Properties

	public weak var customDelegate: TextStorageCustomDelegate?

	public private(set) var document: Document?

	public var fontSize: CGFloat = 0 {
		didSet {
			guard theme.fontSize != fontSize else {
				return
			}

			theme.fontSize = fontSize

			if needsParse {
				return
			}

			parse()
		}
	}

	public private(set) var theme: Theme = DefaultTheme() {
		didSet {
			customDelegate?.textStorage(self, didChangeTheme: theme)
		}
	}

	public var typingAttributes: [NSAttributedString.Key: Any] {
		return theme.baseAttributes
	}

	public var bounds: NSRange {
		return NSRange(location: 0, length: string.length)
	}

	private var needsParse = false

	// MARK: - NSTextStorage

	public override func replaceCharacters(in range: NSRange, with string: String) {
		needsParse = true
		super.replaceCharacters(in: range, with: string)
	}

	// MARK: - Parsing

    /// Reparse `string` and updated the attributes based on `theme`.
    ///
    /// This should be called from `textViewDidChange` or in `UITextView.text`’s `didSet`.
	public func parseIfNeeded() {
		guard needsParse else {
			return
		}

		parse()
	}

    /// Force parsing now. You should probably use `parseIfNeeded` instead.
	public func parse() {
		needsParse = false

		beginEditing()
		resetAttributes()

		if let document = Parser.parse(string) {
			self.document = document
			customDelegate?.textStorage(self, didParseDocument: document)
			addAttributes(for: document, currentFont: theme.font)
		} else {
			self.document = nil
		}

		endEditing()
	}

	// MARK: - Private

	/// Reset all attributes. Down the road, we could detect the maximum affect area and only reset those.
	private func resetAttributes() {
		setAttributes(typingAttributes, range: bounds)
	}

	private func addAttributes(for node: Node, currentFont: UIFont) {
		var currentFont = currentFont
		let attributes = theme.attributes(for: node)

		if var attributes = attributes, let range = node.range {
			if let traits = attributes[.fontTraits] as? UIFontDescriptor.SymbolicTraits {
				currentFont = currentFont.addingTraits(traits)
				attributes[.font] = currentFont
				attributes.removeValue(forKey: .fontTraits)
			}

			addAttributes(attributes, range: range)
		}

		for child in node.children {
			addAttributes(for: child, currentFont: currentFont)
		}
	}
}

extension NSAttributedString.Key {
    /// `UIFontDescriptor.SymbolicTraits` to use for the given range. Prefer this over customizing the font so sizes
    /// and font traits can cascade.
	public static let fontTraits = NSAttributedString.Key("FontTraits")
}
