//
//  HomeView.swift
//  SY STORE
//
//  Created by samara on 13.05.2026.
//

import SwiftUI
import CoreData
import AltSourceKit
import NimbleViews

struct HomeView: View {
    @Environment(\.openURL) var openURL // إضافة بيئة فتح الروابط
    @StateObject var viewModel = SourcesViewModel.shared
    
    @State private var _recentApps: [(source: ASRepository, app: ASRepository.App)] = []
    @State private var _banners: [StoreBanner] = []
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
                                    ForEach(_banners) { banner in
                                        Button {
                                            // فتح الرابط بشكل مباشر وموثوق
                                            if let linkString = banner.link, let url = URL(string: linkString) {
                                                openURL(url)
                                            }
                                        } label: {
                                            // التحقق من وجود رابط الصورة
                                            if let imgUrl = banner.imageURL, let url = URL(string: imgUrl) {
                                                AsyncImage(url: url) { phase in
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
                _loadRecentApps()
                _loadBanners()
            }
        }
        .task(id: Array(_sources)) {
            await viewModel.fetchSources(_sources)
            _loadRecentApps()
            _loadBanners()
        }
    }

    // MARK: - جلب أحدث التطبيقات
    private func _loadRecentApps() {
        isLoading = true
        Task {
            let loadedSources = _sources.compactMap { viewModel.sources[$0] }
            var allApps: [(source: ASRepository, app: ASRepository.App)] = []

            for source in loadedSources {
                for app in source.apps {
                    allApps.append((source: source, app: app))
                }
            }

            allApps.sort {
                ($0.app.currentDate?.date ?? .distantPast) > ($1.app.currentDate?.date ?? .distantPast)
            }

            let topApps = Array(allApps.prefix(25))

            DispatchQueue.main.async {
                self._recentApps = topApps
                self.isLoading = false
            }
        }
    }
    
    // MARK: - جلب البنرات الإعلانية من السورس
    private func _loadBanners() {
        Task {
            guard let url = URL(string: "https://raw.githubusercontent.com/ipa-black/void-repo/refs/heads/main/repo.json") else { return }
            
            // إجبار التطبيق على تجاهل الكاش لجلب أحدث التعديلات
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                let response = try JSONDecoder().decode(RepoBannerResponse.self, from: data)
                
                DispatchQueue.main.async {
                    // تصفية البنرات التي لا تحتوي على صورة وتحديد العدد لـ 2 فقط
                    let validBanners = (response.banners ?? []).filter { $0.imageURL != nil }
                    self._banners = Array(validBanners.prefix(2))
                }
            } catch {
                print("فشل جلب البنرات: \(error)") // ستظهر تفاصيل الخطأ هنا في الـ Console
            }
        }
    }
}

// MARK: - Supporting Types for Banners
struct StoreBanner: Decodable, Identifiable {
    var id: String { imageURL ?? UUID().uuidString }
    let imageURL: String?
    let link: String?
    
    // دعم قراءة المفاتيح بأسماء مختلفة لتجنب أخطاء JSON
    enum CodingKeys: String, CodingKey {
        case imageURL = "imageURL"
        case imageUrl = "imageUrl"
        case image = "image"
        case link = "link"
        case url = "url"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageURL = (try? container.decodeIfPresent(String.self, forKey: .imageURL)) ??
                   (try? container.decodeIfPresent(String.self, forKey: .imageUrl)) ??
                   (try? container.decodeIfPresent(String.self, forKey: .image))
        
        link = (try? container.decodeIfPresent(String.self, forKey: .link)) ??
               (try? container.decodeIfPresent(String.self, forKey: .url))
    }
}

struct RepoBannerResponse: Decodable {
    let banners: [StoreBanner]?
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
