//
//  SourcesView.swift
//  SY STORE
//
//  Created by samara on 10.04.2025.
//  Modified for SY STORE.
//

import CoreData
import AltSourceKit
import SwiftUI
import NimbleViews

// MARK: - View
struct SourcesView: View {
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@StateObject var viewModel = SourcesViewModel.shared
	@State private var _searchText = ""
	
	private var _filteredSources: [AltSource] {
		_sources.filter { _searchText.isEmpty || ($0.name?.localizedCaseInsensitiveContains(_searchText) ?? false) }
	}
	
	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>
	
	// MARK: Body
	var body: some View {
		NBNavigationView("المصادر") {
			NBListAdaptable {
				if !_filteredSources.isEmpty {
					Section {
						NavigationLink {
							SourceAppsView(object: Array(_sources), viewModel: viewModel)
						} label: {
							let isRegular = horizontalSizeClass != .compact
							HStack(spacing: 18) {
								Image("Repositories").appIconStyle()
								NBTitleWithSubtitleView(
									title: "جميع التطبيقات",
									subtitle: "عرض جميع التطبيقات المتاحة في المتجر"
								)
							}
							.padding(isRegular ? 12 : 0)
							.background(
								isRegular
									? RoundedRectangle(cornerRadius: 18, style: .continuous)
									.fill(Color(.quaternarySystemFill))
									: nil
							)
						}
						.buttonStyle(.plain)
					}
					
					NBSection(
						"المكتبات",
						secondary: _filteredSources.count.description
					) {
						ForEach(_filteredSources) { source in
							NavigationLink {
								SourceAppsView(object: [source], viewModel: viewModel)
							} label: {
								SourcesCellView(source: source)
							}
							.buttonStyle(.plain)
						}
					}
				}
			}
			.searchable(text: $_searchText, placement: .platform(), prompt: "ابحث في المتجر...")
			.overlay {
				if _filteredSources.isEmpty {
					if #available(iOS 17, *) {
						ContentUnavailableView {
							Label("جاري تجهيز المتجر...", systemImage: "arrow.down.app.fill")
						} description: {
							Text("يرجى الانتظار بينما يتم تحميل التطبيقات الأساسية.")
						} actions: {
							ProgressView()
						}
					}
				}
			}
			.refreshable {
				await viewModel.fetchSources(_sources, refresh: true)
			}
		}
		.task(id: Array(_sources)) {
			await viewModel.fetchSources(_sources)
            _importDefaultSources() // جلب المصادر الخاصة بالمتجر
		}
	}
    
    // MARK: - دالة استيراد المصادر الحصرية
    private func _importDefaultSources() {
        let myStoreSources = [
            "https://fastsign.dev/repo.json",
            "https://repository.apptesters.org",
            "https://raw.githubusercontent.com/ipa-black/void-repo/refs/heads/main/repo.json"
        ]
        
        for source in myStoreSources {
            let exists = _sources.contains { $0.sourceURL?.absoluteString.lowercased() == source.lowercased() }
            if !exists {
                FR.handleSource(source) { }
            }
        }
    }
}
