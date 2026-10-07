import StoreKit
import Observation
import WidgetKit

@MainActor @Observable
final class PurchaseService {
    static let productIDs = ["co.haloday.premium.yearly", "co.haloday.premium.monthly", "co.haloday.premium.lifetime"]
    var products: [Product] = []
    var isPremium = false
    var isLoading = false
    var message: String?
    /// When the current entitlement ends (nil for lifetime or no entitlement).
    var premiumUntil: Date?
    /// True when the entitlement came from an offer code (for example the 7-day code).
    var premiumFromCode = false
    /// TestFlight and Xcode builds run against the sandbox; QC diagnostics show only there.
    var isTestEnvironment = false
    private var listener: Task<Void, Never>?

    func start() async {
        if case .verified(let app) = try? await AppTransaction.shared { isTestEnvironment = app.environment != .production }
        #if DEBUG
        isTestEnvironment = true
        #endif
        // Purchases interrupted last time (app killed mid-purchase, Ask to Buy approved later) are settled first.
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result { await transaction.finish() }
        }
        listener?.cancel()
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self, case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
        await refreshEntitlements()
        await loadProducts()
    }

    /// Loads the plans; called again from the paywall when an earlier attempt came back empty.
    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { Self.productIDs.firstIndex(of: $0.id) ?? 0 < Self.productIDs.firstIndex(of: $1.id) ?? 0 }
        } catch {
            message = String(localized: "Plans are unavailable. Try again later.")
        }
    }
    func refreshEntitlements() async {
        var entitled = false
        var until: Date?
        var lifetime = false
        var fromCode = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate {
                guard expiry > .now else { continue }
                if until.map({ expiry > $0 }) ?? true {
                    until = expiry
                    fromCode = transaction.offer?.type == .code
                }
            } else {
                lifetime = true
            }
            entitled = true
        }
        isPremium = entitled
        premiumUntil = lifetime ? nil : until
        premiumFromCode = !lifetime && fromCode
        var settings = AppGroupStorage.shared.settings
        settings.isPremium = entitled
        do { try AppGroupStorage.shared.write(settings, key: "settings") }
        catch { message = String(localized: "Could not save your purchase status. Please reopen Halo Day.") }
        WidgetCenter.shared.reloadAllTimelines()
    }
    func purchase(_ product: Product) async {
        isLoading = true; defer { isLoading = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else { message = String(localized: "The purchase could not be verified."); return }
                await transaction.finish(); await refreshEntitlements()
                message = String(localized: "Welcome to Halo Day Premium.")
            case .pending: message = String(localized: "Your purchase is awaiting approval.")
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = String(localized: "The purchase didn't go through. Please try again.") }
    }
    func restore() async {
        do {
            try await AppStore.sync(); await refreshEntitlements()
            message = isPremium ? String(localized: "Welcome back. Premium is restored.") : String(localized: "We couldn't find a previous purchase for this Apple ID.")
        } catch { message = String(localized: "Restore is unavailable. Please try again.") }
    }
}
