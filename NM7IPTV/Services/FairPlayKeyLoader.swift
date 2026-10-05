import Foundation
import AVFoundation

final class FairPlayKeyLoader: NSObject, AVAssetResourceLoaderDelegate {
    private let certificateURL: URL
    private let licenseURL: URL
    private let headers: [String: String]
    private let queue = DispatchQueue(label: "vn.phuongnm7.nm7iptv.fairplay")
    private let session: URLSession

    init(certificateURL: URL, licenseURL: URL, headers: [String: String]) {
        self.certificateURL = certificateURL
        self.licenseURL = licenseURL
        self.headers = headers

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
        super.init()
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard loadingRequest.request.url?.scheme?.lowercased() == "skd" else { return false }
        queue.async { [weak self] in self?.process(loadingRequest) }
        return true
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest
    ) -> Bool {
        queue.async { [weak self] in self?.process(renewalRequest) }
        return true
    }

    private func process(_ request: AVAssetResourceLoadingRequest) {
        fetchCertificate { [weak self] certificate, certError in
            guard let self else { return }
            guard let certificate else {
                request.finishLoading(with: certError ?? self.error("Không tải được FairPlay certificate."))
                return
            }

            do {
                let identifier = self.contentIdentifier(for: request)
                let spc = try request.streamingContentKeyRequestData(
                    forApp: certificate,
                    contentIdentifier: identifier,
                    options: nil
                )

                var licenseRequest = URLRequest(url: self.licenseURL)
                licenseRequest.httpMethod = "POST"
                licenseRequest.httpBody = spc
                licenseRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                licenseRequest.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

                for (key, value) in self.headers {
                    licenseRequest.setValue(value, forHTTPHeaderField: key)
                }

                self.session.dataTask(with: licenseRequest) { data, response, error in
                    guard error == nil, let data, !data.isEmpty else {
                        request.finishLoading(with: error ?? self.error("FairPlay license trả về dữ liệu rỗng."))
                        return
                    }

                    let ckc = self.normalizeCKC(data, response: response)
                    request.dataRequest?.respond(with: ckc)
                    request.finishLoading()
                }.resume()
            } catch {
                request.finishLoading(with: error)
            }
        }
    }

    private func fetchCertificate(completion: @escaping (Data?, Error?) -> Void) {
        var request = URLRequest(url: certificateURL)
        request.httpMethod = "GET"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        session.dataTask(with: request) { data, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  200..<300 ~= http.statusCode,
                  let data, !data.isEmpty else {
                completion(nil, error ?? self.error("FairPlay certificate HTTP error."))
                return
            }
            completion(data, nil)
        }.resume()
    }

    private func contentIdentifier(for request: AVAssetResourceLoadingRequest) -> Data {
        let raw = request.request.url?.absoluteString ?? ""
        let identifier = raw.lowercased().hasPrefix("skd://")
            ? String(raw.dropFirst(6))
            : raw
        return identifier.data(using: .utf8) ?? Data()
    }

    private func normalizeCKC(_ data: Data, response: URLResponse?) -> Data {
        guard let http = response as? HTTPURLResponse else { return data }
        let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        guard contentType.contains("text") || contentType.contains("json") else { return data }

        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let decoded = Data(base64Encoded: text), !decoded.isEmpty {
            return decoded
        }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["ckc", "CKC"] {
                if let value = object[key] as? String,
                   let decoded = Data(base64Encoded: value),
                   !decoded.isEmpty {
                    return decoded
                }
            }
        }
        return data
    }

    private func error(_ description: String) -> NSError {
        NSError(domain: "NM7FairPlay", code: 1, userInfo: [NSLocalizedDescriptionKey: description])
    }
}