//
//  CertificatesView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//  Modified for SY STORE with Firebase Activation System.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct CertificatesView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
    @AppStorage("systore.isActivated") private var isActivated: Bool = false // 🔥 مفتاح الحماية
	
	@State private var _isAddingPresenting = false
	@State private var _isRenamingPresenting = false
	@State private var _isSelectedInfoPresenting: CertificatePair?
	@State private var _certToRename: CertificatePair?
	@State private var _newNickname: String = ""

	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>
	
	//
	private var _bindingSelectedCert: Binding<Int>?
	private var _selectedCertBinding: Binding<Int> {
		_bindingSelectedCert ?? $_storedSelectedCert
	}
	
	init(selectedCert: Binding<Int>? = nil) {
		self._bindingSelectedCert = selectedCert
	}
	
	// MARK: Body
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
    
    // MARK: - Main Content (Protected)
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
        .safeToolbar(show: _bindingSelectedCert == nil) {
            _isAddingPresenting = true
        }
        .sheet(item: $_isSelectedInfoPresenting) { cert in
            CertificatesInfoView(cert: cert)
        }
        .sheet(isPresented: $_isAddingPresenting) {
            CertificatesAddView()
                .safePresentationDetents()
        }
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
		let cornerRadius = {
			if #available(iOS 26.0, *) {
				28.0
			} else {
				10.5
			}
		}()
		
		Button {
			_selectedCertBinding.wrappedValue = index
		} label: {
			CertificatesCellView(
				cert: cert
			)
			.padding()
			.background(
				RoundedRectangle(cornerRadius: cornerRadius)
					.fill(Color(uiColor: .quaternarySystemFill))
			)
			.overlay(
				RoundedRectangle(cornerRadius: cornerRadius)
					.strokeBorder(
						_selectedCertBinding.wrappedValue == index ? Color.accentColor : Color.clear,
						lineWidth: 2
					)
			)
			.contextMenu {
				_contextActions(for: cert)
				if cert.isDefault != true {
					Divider()
					_actions(for: cert)
				}
			}
			.transaction {
				$0.animation = nil
			}
		}
		.buttonStyle(.plain)
	}
	
	@ViewBuilder
	private func _actions(for cert: CertificatePair) -> some View {
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteCertificate(for: cert)
		}
	}
	
	@ViewBuilder
	private func _contextActions(for cert: CertificatePair) -> some View {
		Button(.localized("Get Info"), systemImage: "info.circle") {
			_isSelectedInfoPresenting = cert
		}
		Button(.localized("Change Nickname"), systemImage: "pencil") {
			_newNickname = cert.nickname ?? ""
			_certToRename = cert
			_isRenamingPresenting = true
		}
		Divider()
		Button(.localized("Check Revokage"), systemImage: "person.text.rectangle") {
			Storage.shared.revokagedCertificate(for: cert)
		}
	}
}

// MARK: - 🔥 Activation View (بوابة الحماية)
struct ActivationView: View {
    @Binding var isActivated: Bool
    @State private var code: String = ""
    @State private var isLoading: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    
    // رابط سيرفرك في فايربيس
    let firebaseURL = "https://systore-b04e9-default-rtdb.firebaseio.com"

    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 70))
                .foregroundColor(.accentColor)
                .padding(.bottom, 10)
            
            Text("حماية المتجر")
                .font(.title.bold())
            
            Text("يرجى إدخال كود التفعيل الخاص بك لتتمكن من إضافة الشهادات وتوقيع التطبيقات.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)

            TextField("كود التفعيل (مثال: SY-XXXXXX)", text: $code)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .font(.headline)
                .autocapitalization(.allCharacters) // إجبار الأحرف الكبيرة
                .disableAutocorrection(true)
                .padding(.horizontal, 40)

            if isLoading {
                ProgressView("جاري التحقق...")
                    .padding(.top, 10)
            } else {
                Button(action: verifyCode) {
                    Text("تفعيل الآن")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
                .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            Spacer()
        }
        .padding(.top, 50)
        .alert("تنبيه", isPresented: $showAlert) {
            Button("حسناً", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func verifyCode() {
        guard !code.isEmpty else { return }
        isLoading = true
        
        let cleanedCode = code.trimmingCharacters(in: .whitespaces).uppercased()
        let requestURL = "\(firebaseURL)/codes/\(cleanedCode).json"
        
        guard let url = URL(string: requestURL) else {
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    alertMessage = "فشل الاتصال بالسيرفر: \(error.localizedDescription)"
                    showAlert = true
                    return
                }
                
                guard let data = data,
                      let jsonString = String(data: data, encoding: .utf8) else {
                    alertMessage = "حدث خطأ غير معروف."
                    showAlert = true
                    return
                }
                
                // إذا رد فايربيس بـ null فهذا يعني أن الكود غير موجود نهائياً
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
                    alertMessage = "الكود الذي أدخلته غير صحيح أو غير موجود."
                    showAlert = true
                    return
                }
                
                // إذا وجدنا بيانات، نفك تشفيرها
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let status = json["status"] as? String {
                    
                    if status == "valid" {
                        // الكود صحيح وجديد -> نقوم بحرقه (جعله مستخدم)
                        markCodeAsUsed(cleanedCode)
                        
                        // تفعيل المتجر
                        withAnimation {
                            isActivated = true
                        }
                    } else if status == "used" {
                        alertMessage = "هذا الكود مستخدم من قبل! يرجى شراء كود جديد."
                        showAlert = true
                    } else {
                        alertMessage = "الكود غير صالح للاستخدام."
                        showAlert = true
                    }
                } else {
                    alertMessage = "خطأ في قراءة بيانات الكود."
                    showAlert = true
                }
            }
        }.resume()
    }
    
    // دالة لحرق الكود بعد استخدامه
    private func markCodeAsUsed(_ cleanedCode: String) {
        let requestURL = "\(firebaseURL)/codes/\(cleanedCode).json"
        guard let url = URL(string: requestURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["status": "used"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        URLSession.shared.dataTask(with: request).resume()
    }
}

// MARK: - Compatibility Extensions
private extension View {
    @ViewBuilder
    func safePresentationDetents() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.medium])
        } else {
            self
        }
    }
    
    @ViewBuilder
    func safeToolbar(show: Bool, action: @escaping () -> Void) -> some View {
        if show {
            self.toolbar {
                NBToolbarButton(
                    systemImage: "plus",
                    style: .icon,
                    placement: .topBarTrailing
                ) {
                    action()
                }
            }
        } else {
            self
        }
    }
}
