import UIKit

enum NM7Assets {
    static var mainLogo: UIImage {
        image(named: "nm7_main_logo", ext: "png") ?? UIImage()
    }

    static var launcher: UIImage {
        image(named: "nm7_tv_launcher", ext: "png") ?? UIImage()
    }

    private static func image(named: String, ext: String) -> UIImage? {
        if let url = Bundle.main.url(forResource: named, withExtension: ext) {
            return UIImage(contentsOfFile: url.path)
        }
        if let url = Bundle.main.url(forResource: named, withExtension: ext, subdirectory: "Resources") {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }
}