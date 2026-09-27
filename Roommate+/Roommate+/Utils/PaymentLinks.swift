import UIKit

enum PaymentLinks {
    static func normalizedVenmoUsername(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if value.hasPrefix("@") {
            value = String(value.dropFirst())
        }
        return value.isEmpty ? nil : value
    }

    static func normalizedZellePhone(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    static func venmoURL(username: String, amountCents: Int, note: String, webFallback: Bool) -> URL? {
        let amount = String(format: "%.2f", Double(amountCents) / 100.0)
        let cleanUser = normalizedVenmoUsername(username) ?? username

        if webFallback {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "venmo.com"
            components.path = "/\(cleanUser)"
            components.queryItems = venmoQueryItems(amount: amount, note: note)
            return components.url
        }

        var components = URLComponents()
        components.scheme = "venmo"
        components.host = "paycharge"
        components.queryItems = venmoQueryItems(amount: amount, note: note, recipients: cleanUser)
        return components.url
    }

    static func openVenmo(username: String, amountCents: Int, note: String) {
        if let appURL = venmoURL(username: username, amountCents: amountCents, note: note, webFallback: false),
           let schemeURL = URL(string: "venmo://"),
           UIApplication.shared.canOpenURL(schemeURL) {
            UIApplication.shared.open(appURL)
            return
        }

        if let webURL = venmoURL(username: username, amountCents: amountCents, note: note, webFallback: true) {
            UIApplication.shared.open(webURL)
        }
    }

    static func zelleClipboardText(phone: String, amountCents: Int, note: String) -> String {
        let amount = SplitMoney.format(cents: amountCents)
        let cleanPhone = normalizedZellePhone(phone) ?? phone
        return "Send \(amount) via Zelle to \(cleanPhone) — \(note)"
    }

    static func copyZelleInfo(phone: String, amountCents: Int, note: String) {
        UIPasteboard.general.string = zelleClipboardText(phone: phone, amountCents: amountCents, note: note)
    }

    private static func venmoQueryItems(amount: String, note: String, recipients: String? = nil) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "txn", value: "pay"),
            URLQueryItem(name: "amount", value: amount),
            URLQueryItem(name: "note", value: note)
        ]
        if let recipients {
            items.insert(URLQueryItem(name: "recipients", value: recipients), at: 1)
        }
        return items
    }
}
