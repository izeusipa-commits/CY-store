//
//  TabbarView.swift
//  SY STORE
//
//  Created by samara on 23.03.2025.
//  Modified for SY STORE.
//

import SwiftUI

struct TabbarView: View {
	@State private var selectedTab: TabEnum = .home // تم التعديل لتصبح الرئيسية هي الافتراضية

	var body: some View {
		TabView(selection: $selectedTab) {
			ForEach(TabEnum.defaultTabs, id: \.self) { tab in // تم تغيير .hashValue إلى .self لحل الخطأ
				TabEnum.view(for: tab)
					.tabItem {
						Label(tab.title, systemImage: tab.icon)
					}
					.tag(tab)
			}
		}
	}
}
