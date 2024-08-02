import Foundation
import WMFData

final class WKMockURLSessionDataTask: WKURLSessionDataTask {
    func resume() {
        
    }
}

struct WKMockData: Codable {
    let oneInt: Int
    let twoString: String
}

final class WKMockSuccessURLSession: WMFURLSession {
    
    var url: URL?
    
    func wkDataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> WMFData.WKURLSessionDataTask {
        self.url = request.url
        
        let encoder = JSONEncoder()

        let data = try? encoder.encode(WKMockData(oneInt: 1, twoString: "two"))
        let response = HTTPURLResponse(url: URL(string: "http://wikipedia.org")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        completionHandler(data, response, nil)
        return WKMockURLSessionDataTask()
    }
}

final class WKMockServerErrorSession: WMFURLSession {
    func wkDataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> WMFData.WKURLSessionDataTask {

        let response = HTTPURLResponse(url: URL(string: "http://wikipedia.org")!, statusCode: 500, httpVersion: nil, headerFields: nil)
        
        completionHandler(nil, response, nil)
        return WKMockURLSessionDataTask()
    }
}

final class WKMockNoInternetConnectionSession: WMFURLSession {
    func wkDataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> WMFData.WKURLSessionDataTask {

        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        completionHandler(nil, nil, error)
        return WKMockURLSessionDataTask()
    }
}

final class WKMockMissingDataSession: WMFURLSession {
    func wkDataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> WMFData.WKURLSessionDataTask {

        let response = HTTPURLResponse(url: URL(string: "http://wikipedia.org")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        completionHandler(nil, response, nil)
        return WKMockURLSessionDataTask()
    }
}
