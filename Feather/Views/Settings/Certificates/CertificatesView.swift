//
//  CertificatesView.swift
//  Feather
//
//  Modified for SY STORE - VIP Version
//

import SwiftUI
import NimbleViews

// MARK: - View
struct CertificatesView: View {
    @AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
    @AppStorage("systore.isActivated") private var isActivated: Bool = false
    
    @State private var _isAddingPresenting = false
    @State private var _isRenamingPresenting = false
    @State private var _isSelectedInfoPresenting: CertificatePair?
    @State private var _certToRename: CertificatePair?
    @State private var _newNickname: String = ""

    @FetchRequest(
        entity: CertificatePair.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
        animation: .snappy
    ) private var _certificates: FetchedResults<CertificatePair>
    
    private var _bindingSelectedCert: Binding<Int>?
    private var _selectedCertBinding: Binding<Int> {
        _bindingSelectedCert ?? $_storedSelectedCert
    }
    
    init(selectedCert: Binding<Int>? = nil) {
        self._bindingSelectedCert = selectedCert
    }
    
    var body: some View {
        Group {
            if isActivated {
                mainContentView
            } else {
                ActivationView(isActivated: $isActivated)
            }
        }
        .animation(.easeInOut, value: isActivated)
    }
    
    // MARK: - Main Content
    private var mainContentView: some View {
        NBGrid {
            ForEach(Array(_certificates.enumerated()), id: \.element.uuid) { index, cert in
                _cellButton(for: cert, at: index)
            }
        }
        .navigationTitle(.localized("Certificates"))
        .overlay {
            if _certificates.isEmpty {
                if #available(iOS 17, *) {
                    ContentUnavailableView {
                        Label(.localized("No Certificates"), systemImage: "questionmark.folder.fill")
                    } description: {
                        Text(.localized("Get started signing by importing your first certificate."))
                    } actions: {
                        Button {
                            _isAddingPresenting = true
                        } label: {
                            NBButton(.localized("Import"), style: .text)
                        }
                    }
                }
            }
        }
        .safeToolbar(show: _bindingSelectedCert == nil) { _isAddingPresenting = true }
        .sheet(item: $_isSelectedInfoPresenting) { CertificatesInfoView(cert: $0) }
        .sheet(isPresented: $_isAddingPresenting) { CertificatesAddView().safePresentationDetents() }
        .alert(.localized("Change Nickname"), isPresented: $_isRenamingPresenting, presenting: _certToRename) { cert in
            TextField(.localized("Nickname"), text: $_newNickname)
            Button(.localized("Cancel"), role: .cancel) { }
            Button(.localized("OK")) {
                cert.nickname = _newNickname.isEmpty ? nil : _newNickname
                Storage.shared.saveContext()
            }
        }
    }
}

// MARK: - View extension
extension CertificatesView {
    @ViewBuilder
    private func _cellButton(for cert: CertificatePair, at index: Int) -> some View {
        let cornerRadius = { if #available(iOS 26.0, *) { 28.0 } else { 10.5 } }()
        
        Button {
            _selectedCertBinding.wrappedValue = index
        } label: {
            CertificatesCellView(cert: cert)
            .padding()
            .background(RoundedRectangle(cornerRadius: cornerRadius).fill(Color(uiColor: .quaternarySystemFill)))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(_selectedCertBinding.wrappedValue == index ? Color.accentColor : Color.clear, lineWidth: 2))
            .contextMenu {
                _contextActions(for: cert)
                if cert.isDefault != true { Divider(); _actions(for: cert) }
            }
            .transaction { $0.animation = nil }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder private func _actions(for cert: CertificatePair) -> some View {
        Button(.localized("Delete"), systemImage: "trash", role: .destructive) { Storage.shared.deleteCertificate(for: cert) }
    }
    
    @ViewBuilder private func _contextActions(for cert: CertificatePair) -> some View {
        Button(.localized("Get Info"), systemImage: "info.circle") { _isSelectedInfoPresenting = cert }
        Button(.localized("Change Nickname"), systemImage: "pencil") { _newNickname = cert.nickname ?? ""; _certToRename = cert; _isRenamingPresenting = true }
        Divider()
        Button(.localized("Check Revokage"), systemImage: "person.text.rectangle") { Storage.shared.revokagedCertificate(for: cert) }
    }
}

// MARK: - 🔥 Activation View (UI Morden & Smart Logic)
struct ActivationView: View {
    @Binding var isActivated: Bool
    @State private var code: String = ""
    @State private var isLoading: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    
    let firebaseURL = "https://systore-b04e9-default-rtdb.firebaseio.com"

    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            // أيقونة المتجر بتأثير عصري
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                .padding(.bottom, 5)
            
            Text("مرحباً بك في SY STORE")
                .font(.title2.bold())
            
            Text("الرجاء إدخال كود التفعيل للوصول إلى الشهادات وتوقيع التطبيقات بحرية.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 30)
                .font(.subheadline)

            // حقل إدخال عصري
            TextField("مثال: CY-XXXXXX", text: $code)
                .font(.headline)
                .multilineTextAlignment(.center)
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 30)

            if isLoading {
                ProgressView("جاري التحقق من السيرفر...")
                    .padding(.top, 10)
            } else {
                // زر تفعيل عصري
                Button(action: verifyCode) {
                    Text("تفعيل الآن")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(15)
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 30)
                }
                .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(code.isEmpty ? 0.6 : 1.0)
            }
            
            Spacer()
        }
        .alert("تنبيه", isPresented: $showAlert) {
            Button("حسناً", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Smart Verification Logic
    private func verifyCode() {
        guard !code.isEmpty else { return }
        isLoading = true
        
        // 1. تنظيف وتجهيز الكود (الذكاء الاصطناعي في الفلترة)
        var rawCode = code.trimmingCharacters(in: .whitespaces).uppercased()
        
        // إزالة CY- أو CY لو كتبها المستخدم لتجنب التكرار
        if rawCode.hasPrefix("CY-") {
            rawCode = String(rawCode.dropFirst(3))
        } else if rawCode.hasPrefix("CY") {
            rawCode = String(rawCode.dropFirst(2))
        }
        
        // إعادة التجميع بالشكل الصحيح الذي يفهمه فايربيس: cy-XXXXXX
        let finalCode = "cy-" + rawCode
        
        let requestURL = "\(firebaseURL)/codes/\(finalCode).json"
        guard let url = URL(string: requestURL) else {
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    alertMessage = "خطأ في الاتصال: \(error.localizedDescription)"
                    showAlert = true; return
                }
                
                guard let data = data, let jsonString = String(data: data, encoding: .utf8) else {
                    alertMessage = "حدث خطأ غير معروف."; showAlert = true; return
                }
                
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
                    alertMessage = "الكود غير صحيح أو غير موجود."
                    showAlert = true; return
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let status = json["status"] as? String {
                    
                    if status == "valid" {
                        markCodeAsUsed(finalCode)
                        withAnimation { isActivated = true }
                    } else if status == "used" {
                        alertMessage = "هذا الكود مستخدم من قبل! يرجى الحصول على كود جديد."
                        showAlert = true
                    } else if status == "suspended" {
                        alertMessage = "هذا الكود تم إيقافه من قبل الإدارة."
                        showAlert = true
                    } else {
                        alertMessage = "الكود غير صالح للاستخدام."
                        showAlert = true
                    }
                }
            }
        }.resume()
    }
    
    private func markCodeAsUsed(_ finalCode: String) {
        let requestURL = "\(firebaseURL)/codes/\(finalCode).json"
        guard let url = URL(string: requestURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // إضافة تاريخ التفعيل
        let formatter = ISO8601DateFormatter()
        let currentDate = formatter.string(from: Date())
        
        let body = [
            "status": "used",
            "usedDate": currentDate
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        URLSession.shared.dataTask(with: request).resume()
    }
}

// MARK: - Compatibility Extensions
private extension View {
    @ViewBuilder func safePresentationDetents() -> some View {
        if #available(iOS 16.0, *) { self.presentationDetents([.medium]) } else { self }
    }
    
    @ViewBuilder func safeToolbar(show: Bool, action: @escaping () -> Void) -> some View {
        if show {
            self.toolbar { NBToolbarButton(systemImage: "plus", style: .icon, placement: .topBarTrailing) { action() } }
        } else { self }
    }
}
