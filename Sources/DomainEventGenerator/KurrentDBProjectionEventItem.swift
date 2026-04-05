import Foundation

package enum KurrentDBProjectionEventItem {
    case plain(String)
    case custom(name: String, body: String)

    package var name: String {
        switch self {
        case .plain(let n): n
        case .custom(let n, _): n
        }
    }
}
