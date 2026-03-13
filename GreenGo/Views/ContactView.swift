import SwiftUI

// MARK: - ContactView

struct ContactView: View {
    @EnvironmentObject private var appState: AppState
    @State private var emailText    = ""
    @State private var subjectText  = ""
    @State private var messageText  = ""
    @State private var showAlert    = false
    @State private var alertMessage = ""
    @State private var alertSuccess = false
    @State private var isSending    = false

    private let green     = Color(red: 0.08, green: 0.52, blue: 0.10)
    private let toAddress = "greengo.customerfeedback@gmail.com"
    private func sanitize(_ raw: String) -> String {
        var s = raw
        if let re = try? NSRegularExpression(pattern: "<[^>]*>", options: []) {
            s = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }
        let sqlPattern = "(?i)(--|;|\\b(DROP|SELECT|INSERT|UPDATE|DELETE|UNION|EXEC|CAST|DECLARE|TRUNCATE)\\b)"
        if let re = try? NSRegularExpression(pattern: sqlPattern, options: []) {
            s = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValidEmail: Bool {
        let t = emailText.trimmingCharacters(in: .whitespacesAndNewlines)
        let re = try? NSRegularExpression(pattern: "^[A-Z0-9a-z._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$")
        let r = NSRange(t.startIndex..., in: t)
        return re?.firstMatch(in: t, range: r) != nil
    }

    private var canSend: Bool {
        isValidEmail &&
        messageText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 &&
        !isSending
    }

    var body: some View {
        ZStack {
            appState.theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    if let img = UIImage(named: "email") {
                        Image(uiImage: img).resizable().scaledToFit()
                            .frame(width: 60, height: 60)
                    }
                    Text("We'd love to hear from you!")
                        .font(.custom("CreativeThoughts-Regular", size: 16))
                        .foregroundStyle(appState.theme.text.opacity(0.85))
                        .multilineTextAlignment(.center)

                    field("Your Email", text: $emailText, keyboard: .emailAddress)

                    if !emailText.isEmpty && !isValidEmail {
                        Text("Please enter a valid email address")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, -8)
                    }

                    field("Subject (optional)", text: $subjectText)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Message")
                            .font(.system(size: 13))
                            .foregroundStyle(appState.theme.mutedText)
                        TextEditor(text: $messageText)
                            .font(.custom("CreativeThoughts-Regular", size: 15))
                            .frame(minHeight: 120)
                            .padding(10)
                            .scrollContentBackground(.hidden)
                            .background(appState.theme.inputBackground,
                                        in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(appState.theme.text)
                            .shadow(color: .black.opacity(0.05), radius: 3)
                    }

                    Button { sendEmail() } label: {
                        Label(isSending ? "Sending…" : "Send Email",
                              systemImage: isSending ? "ellipsis" : "paperplane.fill")
                            .font(.custom("AlumniSans-Bold", size: 18))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(
                                canSend ? green : Color.gray.opacity(0.5),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                    }
                    .disabled(!canSend)

                    HStack(spacing: 4) {
                        Text("You can also reach us at:")
                            .font(.system(size: 12))
                            .foregroundStyle(appState.theme.text.opacity(0.65))
                        if let mailURL = URL(string: "mailto:\(toAddress)") {
                            Link(toAddress, destination: mailURL)
                                .font(.system(size: 12))
                                .foregroundStyle(appState.theme.accent)
                        }
                    }
                    .padding(.bottom, 30)
                }
                .padding(16)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                navBar(title: "Contact Us", back: .home)
            }
        }
        .alert("Message", isPresented: $showAlert) {
            Button("OK", role: .cancel) {
                if alertSuccess { appState.screen = .home }
            }
        } message: { Text(alertMessage) }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func sendEmail() {
        let from    = sanitize(emailText)
        let subject = sanitize(subjectText)
        let message = sanitize(messageText)

        isSending = true
        Task {
            let error = await SupabaseMailer.send(
                replyTo: from,
                subject: subject.isEmpty ? "GreenGo Feedback" : String(subject.prefix(200)),
                message: message
            )
            isSending = false
            if let reason = error {
                alertMessage = "Could not send your message (\(reason)). Please try again or email \(toAddress) directly."
                alertSuccess = false
            } else {
                alertMessage = "Your feedback was sent successfully. Thank you!"
                alertSuccess = true
                emailText = ""; subjectText = ""; messageText = ""
            }
            showAlert = true
        }
    }

    @ViewBuilder
    private func field(_ placeholder: String, text: Binding<String>,
                       keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(placeholder)
                .font(.system(size: 13))
                .foregroundStyle(appState.theme.text.opacity(0.7))
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                .padding(12)
                .background(appState.theme.inputBackground,
                            in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(appState.theme.text)
                .shadow(color: .black.opacity(0.05), radius: 3)
        }
    }
}

// MARK: - SupabaseMailer

enum SupabaseMailer {
    private static let functionURL = "https://sjsjagoqzjvgsiyejial.supabase.co/functions/v1/send-email"
    private static let publishableKey = "https://sjsjagoqzjvgsiyejial.supabase.co" 
    /// Returns nil on success, error string on failure.
    static func send(replyTo: String, subject: String, message: String) async -> String? {
        guard let url = URL(string: functionURL) else { return "Invalid URL" }

        let payload: [String: String] = [
            "replyTo":  replyTo,
            "subject":  subject,
            "message":  message,
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return "Failed to encode request"
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.httpBody   = body
        request.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey,        forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200 { return nil }
            // Parse error message from response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = json["error"] as? String {
                return msg
            }
            return "Server error (\(status))"
        } catch {
            return error.localizedDescription
        }
    }
}
