import Foundation
import UIKit

enum NM7DeviceKind: Equatable {
    case iPhone
    case iPad
}

struct NM7DeviceProfile {
    static var kind: NM7DeviceKind {
        UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
    }

    static var isPad: Bool { kind == .iPad }
    static var isPhone: Bool { kind == .iPhone }
}