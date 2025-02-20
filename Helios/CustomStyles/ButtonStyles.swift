import SwiftUI

enum TabButtonAlignment {
	case leading, center, trailing
	
	var textAlignment: HorizontalAlignment {
		switch self {
		case .leading: return .leading
		case .center: return .center
		case .trailing: return .trailing
		}
	}
}

struct TabButtonStyle: ButtonStyle {
	@Environment(\.colorScheme) private var colorScheme
	@State private var isHovered = false
	let alignment: TabButtonAlignment
	let expandWidth: Bool
	
	init(alignment: TabButtonAlignment = .leading, expandWidth: Bool = true) {
		self.alignment = alignment
		self.expandWidth = expandWidth
	}
	
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.frame(
				maxWidth: expandWidth ? .infinity : nil,
				alignment: alignment == .leading ? .leading :
						  alignment == .center ? .center : .trailing
			)
			.padding(.vertical, 6)
			.padding(.horizontal, 8)
			.background(
				RoundedRectangle(cornerRadius: 4)
					.fill(Color.primary)
					.opacity(
						configuration.isPressed ? 0.1 :
						isHovered ? 0.05 : 0
					)
			)
			.foregroundStyle(Color.primary)
			.font(.system(size: 13))
			.contentShape(Rectangle())
			.onHover { hovering in
				withAnimation(.easeOut(duration: 0.15)) {
					isHovered = hovering
				}
			}
	}
}

// Preview provider for the button style
struct TabButtonStyle_Previews: PreviewProvider {
	static var previews: some View {
		Group {
			VStack(alignment: .leading, spacing: 20) {
				// Expanded width examples
				Text("Expanded Width Buttons")
					.font(.headline)
				
				Button(action: {}) {
					Label("Leading Aligned (Expanded)", systemImage: "plus")
				}
				.buttonStyle(TabButtonStyle(alignment: .leading, expandWidth: true))
				
				Button(action: {}) {
					Label("Center Aligned (Expanded)", systemImage: "arrow.clockwise")
				}
				.buttonStyle(TabButtonStyle(alignment: .center, expandWidth: true))
				
				Button(action: {}) {
					Label("Trailing Aligned (Expanded)", systemImage: "chevron.left")
				}
				.buttonStyle(TabButtonStyle(alignment: .trailing, expandWidth: true))
				
				// Compact width examples
				Text("Compact Width Buttons")
					.font(.headline)
					.padding(.top)
				
				Button(action: {}) {
					Label("Leading (Compact)", systemImage: "plus")
				}
				.buttonStyle(TabButtonStyle(alignment: .leading, expandWidth: false))
				
				Button(action: {}) {
					Label("Center (Compact)", systemImage: "arrow.clockwise")
				}
				.buttonStyle(TabButtonStyle(alignment: .center, expandWidth: false))
				
				Button(action: {}) {
					Label("Trailing (Compact)", systemImage: "chevron.left")
				}
				.buttonStyle(TabButtonStyle(alignment: .trailing, expandWidth: false))
			}
			.padding()
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.background(Color(.windowBackgroundColor))
			
			// Dark mode preview
			VStack(alignment: .leading, spacing: 20) {
				Text("Dark Mode Examples")
					.font(.headline)
				
				Button(action: {}) {
					Label("Expanded", systemImage: "plus")
				}
				.buttonStyle(TabButtonStyle(alignment: .leading, expandWidth: true))
				
				Button(action: {}) {
					Label("Compact", systemImage: "plus")
				}
				.buttonStyle(TabButtonStyle(alignment: .leading, expandWidth: false))
			}
			.padding()
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.background(Color(.windowBackgroundColor))
			.preferredColorScheme(.dark)
		}
	}
}
