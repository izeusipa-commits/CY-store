//
//  AboutView.swift
//  SY STORE
//
//  Created by samara on 30.04.2025.
//  Modified for SY STORE.
//

import SwiftUI
import NimbleViews
import NimbleJSON

// MARK: - Extension: Model
extension AboutView {
	struct CreditsModel: Codable, Hashable {
		let name: String
		let desc: String
		let link: String
		let imageUrl: String
	}
}

// MARK: - View
struct AboutView: View {
	@State private var _credits: [CreditsModel] = [
		.init(
			name: "IPA BLACK",
			desc: "مطور ios",
			link: "https://t.me/ipa_black",
			imageUrl: "https://up6.cc/2026/05/177867480259152.jpeg"
		),
		.init(
			name: "حور",
			desc: "مساعد مطور ومصمم",
			link: "https://t.me/lh0ss",
			imageUrl: "https://up6.cc/2026/05/177867480261513.jpeg"
		)
	]
	
	// MARK: Body
	var body: some View {
		NBList(.localized("About")) {
			Section {
				VStack {
					// App Image
					AsyncImage(url: URL(string: "https://up6.cc/2026/05/17786748025561.jpeg")) { phase in
						if let image = phase.image {
							image
								.resizable()
								.scaledToFill()
						} else {
							ProgressView()
						}
					}
					.frame(width: 85, height: 85)
					.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
					.padding(.bottom, 8)
					
					Text(Bundle.main.exec)
						.font(.largeTitle)
						.bold()
						.foregroundStyle(Color.accentColor)
					
					HStack(spacing: 4) {
						Text(.localized("Version"))
						Text(Bundle.main.version)
					}
					.font(.footnote)
					.foregroundStyle(.secondary)
				}
			}
			.frame(maxWidth: .infinity)
			.listRowBackground(EmptyView())
			
			NBSection(.localized("Credits")) {
				ForEach(_credits, id: \.link) { credit in
					_credit(
						name: credit.name,
						desc: credit.desc,
						link: credit.link,
						imageUrl: credit.imageUrl
					)
				}
				.transition(.slide)
			}
		}
	}
}

// MARK: - Extension: view
extension AboutView {
	@ViewBuilder
	private func _credit(
		name: String,
		desc: String,
		link: String,
		imageUrl: String
	) -> some View {
		Button {
			UIApplication.open(link)
		} label: {
			HStack {
				FRIconCellView(
					title: name,
					subtitle: desc,
					iconUrl: URL(string: imageUrl)!,
					size: 45,
					isCircle: true
				)
				
				Image(systemName: "arrow.up.right")
					.foregroundColor(.secondary.opacity(0.65))
			}
		}
	}
}
