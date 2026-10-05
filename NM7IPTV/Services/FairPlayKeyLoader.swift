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
                let configuredContentType = self.header(named: "Content-Type")
                licenseRequest.setValue(
                    configuredContentType?.isEmpty == false ? configuredContentType! : "application/octet-stream",
                    forHTTPHeaderField: "Content-Type"
                )
                if self.header(named: "Accept") == nil {
                    licenseRequest.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
                }

                for (key, value) in self.headers {
                    licenseRequest.setValue(value, forHTTPHeaderField: key)
                }

                self.session.dataTask(with: licenseRequest) { data, response, error in
                    guard error == nil,
                          let http = response as? HTTPURLResponse,
                          200..<300 ~= http.statusCode,
                          let data,
                          !data.isEmpty else {
                        let status = (response as? HTTPURLResponse)?.statusCode
                        request.finishLoading(
                            with: error ?? self.error(
                                status.map { "FairPlay license HTTP \($0)." }
                                    ?? "FairPlay license trả về dữ liệu rỗng."
                            )
                        )
                        return
                    }

                    let ckc = self.normalizeCKC(data, response: response)
                    guard !ckc.isEmpty else {
                        request.finishLoading(with: self.error("FairPlay license không chứa CKC hợp lệ."))
                        return
                    }
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

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else {
                completion(nil, NSError(
                    domain: "NM7FairPlay",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "FairPlay loader đã bị huỷ."]
                ))
                return
            }
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  200..<300 ~= http.statusCode,
                  let data, !data.isEmpty else {
                let status = (response as? HTTPURLResponse)?.statusCode
                completion(
                    nil,
                    error ?? self.error(
                        status.map { "FairPlay certificate HTTP \($0)." }
                            ?? "FairPlay certificate HTTP error."
                    )
                )
                return
            }
            completion(self.normalizeCertificate(data, response: response), nil)
        }.resume()
    }

    private func contentIdentifier(for request: AVAssetResourceLoadingRequest) -> Data {
        let raw = request.request.url?.absoluteString ?? ""
        let identifier = raw.lowercased().hasPrefix("skd://")
            ? String(raw.dropFirst(6))
            : raw
        if let decoded = identifier.removingPercentEncoding, decoded != identifier {
            return Data(decoded.utf8)
        }
        return Data(identifier.utf8)
    }

    private func normalizeCertificate(_ data: Data, response: URLResponse?) -> Data {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["certificate", "cert", "data"] {
                if let value = object[key] as? String,
                   let decoded = Data(base64Encoded: value, options: [.ignoreUnknownCharacters]),
                   !decoded.isEmpty {
                    return decoded
                }
            }
        }
        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let decoded = Data(base64Encoded: text, options: [.ignoreUnknownCharacters]),
           !decoded.isEmpty {
            return decoded
        }
        _ = response
        return data
    }

    private func normalizeCKC(_ data: Data, response: URLResponse?) -> Data {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["ckc", "CKC", "license", "data", "response"] {
                if let value = object[key] as? String,
                   let decoded = Data(base64Encoded: value, options: [.ignoreUnknownCharacters]),
                   !decoded.isEmpty {
                    return decoded
                }
            }
        }

        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let decoded = Data(base64Encoded: text, options: [.ignoreUnknownCharacters]),
           !decoded.isEmpty {
            return decoded
        }

        _ = response
        return data
    }

    private func header(named name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    private func error(_ description: String) -> NSError {
        NSError(domain: "NM7FairPlay", code: 1, userInfo: [NSLocalizedDescriptionKey: description])
    }
}