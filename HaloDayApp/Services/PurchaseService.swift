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
    private var listener: Task<Void, Never>?
    func start() async {
        listener?.cancel()
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self, case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
        await refreshEntitlements()
        do { products = try await Product.products(for: Self.productIDs) }
        catch { message = String(localized: "Plans are unavailable. Try again later.") }
    }
    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID), transaction.revocationDate == nil,
               transaction.expirationDate == nil || transaction.expirationDate! > .now { entitled = true }
        }
        isPremium = entitled
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
