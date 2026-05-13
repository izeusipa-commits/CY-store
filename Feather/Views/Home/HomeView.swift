//
//  HomeView.swift
//  SY STORE
//
//  Created by samara on 13.05.2026.
//  Modified for SY STORE - Native Banners.
//

import SwiftUI
import CoreData
import AltSourceKit
import NimbleViews

struct HomeView: View {
    @Environment(\.openURL) var openURL
    @StateObject var viewModel = SourcesViewModel.shared
    
    @State private var _allApps: [(source: ASRepository, app: ASRepository.App)] = []
    @State private var _recentApps: [(source: ASRepository, app: ASRepository.App)] = []
    @State private var _banners: [ASRepository.News] = [] // قراءة البنرات الأصلية للمتجر
    @State private var _selectedRoute: SourceAppRoute?
    @State private var isLoading = true

    @FetchRequest(
        entity: AltSource.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
        animation: .snappy
    ) private var _sources: FetchedResults<AltSource>

    var body: some View {
        NBNavigationView("الرئيسية") {
            ZStack {
                if isLoading && _recentApps.isEmpty && _banners.isEmpty {
                    ProgressView("جاري التحديث...")
                } else if _recentApps.isEmpty && _banners.isEmpty {
                    if #available(iOS 17, *) {
                        ContentUnavailableView {
                            Label("لا توجد تطبيقات", systemImage: "tray.fill")
                        } description: {
                            Text("لم يتم العثور على تطبيقات أو عروض حالياً.")
                        }
                    } else {
                        Text("لا توجد تطبيقات")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        // MARK: - قسم البنرات الإعلانية (Swipeable)
                        if !_banners.isEmpty {
                            Section {
                                TabView {
                                    ForEach(_banners.indices, id: \.self) { index in
                                        let banner = _banners[index]
                                        
                                        Button {
                                            // 1. إذا كان البنر يحتوي على رابط، افتحه
                                            if let url = banner.url {
                                                openURL(url)
                                            } 
                                            // 2. إذا كان البنر يوجه لتطبيق معين داخل المتجر، افتح التطبيق
                                            else if let appID = banner.appID,
                                                    let targetApp = _allApps.first(where: { $0.app.id == appID }) {
                                                _selectedRoute = SourceAppRoute(source: targetApp.source, app: targetApp.app)
                                            }
                                        } label: {
                                            if let imgUrl = banner.imageURL {
                                                AsyncImage(url: imgUrl) { phase in
                                                    if let image = phase.image {
                                                        image
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                    } else if phase.error != nil {
                                                        Rectangle()
                                                            .fill(Color(uiColor: .secondarySystemBackground))
                                                            .overlay(Image(systemName: "photo.fill").foregroundColor(.secondary))
                                                    } else {
                                                        Rectangle()
                                                            .fill(Color(uiColor: .secondarySystemBackground))
                                                            .overlay(ProgressView())
                                                    }
                                                }
                                                .frame(height: 190)
                                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                                .padding(.horizontal, 16)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .frame(height: 230)
                                .tabViewStyle(.page(indexDisplayMode: .always))
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }

                        // MARK: - قسم أحدث التطبيقات
                        if !_recentApps.isEmpty {
                            Section {
                                ForEach(_recentApps, id: \.app.currentUniqueId) { item in
                                    Button {
                                        _selectedRoute = SourceAppRoute(source: item.source, app: item.app)
                                    } label: {
                                        SourceAppsCellView(source: item.source, app: item.app)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                Text("أحدث الإضافات")
                                    .font(.title3.bold())
                                    .foregroundColor(.primary)
                                    .padding(.top, 5)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationDestination(item: $_selectedRoute) { route in
                SourceAppsDetailView(source: route.source, app: route.app)
            }
            .refreshable {
                await viewModel.fetchSources(_sources, refresh: true)
                _loadData()
            }
        }
        .task(id: Array(_sources)) {
            await viewModel.fetchSources(_sources)
            _loadData()
        }
    }

    // MARK: - جلب البيانات (التطبيقات والبنرات) معاً
    private func _loadData() {
        isLoading = true
        Task {
            let loadedSources = _sources.compactMap { viewModel.sources[$0] }
            
            var allApps: [(source: ASRepository, app: ASRepository.App)] = []
            var allBanners: [ASRepository.News] = []

            for source in loadedSources {
                // جلب التطبيقات
                for app in source.apps {
                    allApps.append((source: source, app: app))
                }
                
                // جلب البنرات الأصلية للسورس (News)
                if let news = source.news {
                    allBanners.append(contentsOf: news)
                }
            }

            // ترتيب التطبيقات حسب التاريخ
            allApps.sort {
                ($0.app.currentDate?.date ?? .distantPast) > ($1.app.currentDate?.date ?? .distantPast)
            }

            let topApps = Array(allApps.prefix(25))
            
            // تصفية البنرات التي تحتوي على صور فقط
            let validBanners = allBanners.filter { $0.imageURL != nil }

            DispatchQueue.main.async {
                self._allApps = allApps
                self._recentApps = topApps
                self._banners = validBanners
                self.isLoading = false
            }
        }
    }
}

// MARK: - Supporting Types
struct SourceAppRoute: Identifiable, Hashable {
    let source: ASRepository
    let app: ASRepository.App
    let id: String = UUID().uuidString
}

// MARK: - Extension for Navigation
extension View {
    @ViewBuilder
    func navigationDestination<Item: Identifiable & Hashable, Destination: View>(
        item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        self.navigationDestination(isPresented: Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )) {
            if let selectedItem = item.wrappedValue {
                destination(selectedItem)
            }
        }
    }
}
