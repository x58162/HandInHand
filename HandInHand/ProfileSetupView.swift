import SwiftUI

struct ProfileSetupView: View {
    let pendingProfile: PendingProfile
    let onComplete: (VoiceServerUser) -> Void

    @State private var nickname = ""
    @State private var gender = ""
    @State private var birthDate: Date?
    @State private var draftBirthDate = Calendar.current.date(
        from: DateComponents(year: 2000, month: 1, day: 1)
    ) ?? Date()
    @State private var showingDatePicker = false
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private let accent = Color(red: 0.49, green: 0.30, blue: 0.84)

    var body: some View {
        ZStack {
            Color(red: 0.975, green: 0.965, blue: 0.99).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("歡迎來到牽手")
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.17, green: 0.13, blue: 0.25))
                        Text("先完成基本資料，讓大家認識你。")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                        if !pendingProfile.serverUser.email.isEmpty {
                            Text(pendingProfile.serverUser.email)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.top, 32)

                    VStack(alignment: .leading, spacing: 9) {
                        fieldLabel("暱稱")
                        TextField("輸入 2～20 個字", text: $nickname)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(15)
                            .background(.white, in: RoundedRectangle(cornerRadius: 15))
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.black.opacity(0.07), lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        fieldLabel("性別")
                        HStack(spacing: 10) {
                            genderOption(title: "男", value: "male", symbol: "person.fill")
                            genderOption(title: "女", value: "female", symbol: "person.fill")
                        }
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        fieldLabel("西元出生年月日")
                        Button {
                            draftBirthDate = birthDate ?? draftBirthDate
                            showingDatePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(accent)
                                Text(birthDate.map(formatDate) ?? "選擇出生日期")
                                    .foregroundStyle(birthDate == nil ? Color.secondary : Color.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(15)
                            .background(.white, in: RoundedRectangle(cornerRadius: 15))
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.black.opacity(0.07), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    Text("生日只用於牽手帳號資料。請確認填寫正確。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Button(action: saveProfile) {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView().tint(.white)
                            }
                            Text(isSaving ? "正在儲存…" : "完成，進入牽手")
                                .font(.system(size: 16, weight: .bold))
                            if !isSaving {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13, weight: .bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [accent, Color(red: 0.83, green: 0.34, blue: 0.70)], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isValid || isSaving)
                    .opacity(isValid && !isSaving ? 1 : 0.55)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            nickname = pendingProfile.serverUser.nickname
            gender = pendingProfile.serverUser.gender
            if let existing = parseDate(pendingProfile.serverUser.birthDate) {
                birthDate = existing
                draftBirthDate = existing
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                VStack(spacing: 12) {
                    DatePicker(
                        "出生日期",
                        selection: $draftBirthDate,
                        in: earliestBirthDate...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding(.horizontal, 12)
                    Spacer(minLength: 0)
                }
                .padding(.top, 12)
                .navigationTitle("選擇出生日期")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showingDatePicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") {
                            birthDate = draftBirthDate
                            showingDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert("無法儲存資料", isPresented: $showingError) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private var isValid: Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return (2...20).contains(trimmed.count) && !gender.isEmpty && birthDate != nil
    }

    private var earliestBirthDate: Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 1900, month: 1, day: 1)
        ) ?? Date.distantPast
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color(red: 0.22, green: 0.18, blue: 0.30))
    }

    private func genderOption(title: String, value: String, symbol: String) -> some View {
        Button {
            gender = value
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                Text(title)
                Spacer()
                if gender == value {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(gender == value ? accent : Color.primary)
            .padding(15)
            .background(gender == value ? accent.opacity(0.10) : Color.white, in: RoundedRectangle(cornerRadius: 15))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(gender == value ? accent.opacity(0.55) : Color.black.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func saveProfile() {
        guard isValid, let birthDate else { return }
        let cleanedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true

        Task {
            do {
                let response = try await VoiceServerAPIClient.shared.completeProfile(
                    sessionToken: pendingProfile.sessionToken,
                    nickname: cleanedNickname,
                    gender: gender,
                    birthDate: formatDate(birthDate)
                )
                isSaving = false
                onComplete(response.user)
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}
