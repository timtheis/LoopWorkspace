import Foundation
import LoopKit
import HealthKit
import Combine

public class LibreLinkUpManager: CGMManager {
    public static let pluginIdentifier = "LibreLinkUpManager"
    public static let localizedTitle = "Libre LinkUp Direct"
    public var localizedTitle: String { return LibreLinkUpManager.localizedTitle }

    public var glucoseDisplay: GlucoseDisplayable? { return latestSample }
    public var cgmManagerStatus: CGMManagerStatus { .init(hasValidSensorSession: true, device: nil) }
    
    // --- CREDENTIALS ---
    private let email = "YOUR_EMAIL_HERE"
    private let password = "YOUR_PASSWORD_HERE"
    private var authToken: String?

    public var isOnboarded: Bool { return true }
    public let delegate = WeakSynchronizedDelegate<CGMManagerDelegate>()
    public var delegateQueue: DispatchQueue! { get { delegate.queue } set { delegate.queue = newValue } }
    public var cgmManagerDelegate: CGMManagerDelegate? { get { delegate.delegate } set { delegate.delegate = newValue } }
    public let providesBLEHeartbeat = false

    private var latestSample: NewGlucoseSample?
    private let processQueue = DispatchQueue(label: "com.timtheis.LibreLinkUp.processQueue")
    private var isFetching = false
    private let updateTimer: DispatchTimer

    public init() {
        self.updateTimer = DispatchTimer(timeInterval: 300, queue: processQueue)
        scheduleUpdateTimer()
    }

    public convenience required init?(rawState: CGMManager.RawStateValue) { self.init() }
    public var rawState: CGMManager.RawStateValue { ["isConfigured": true] }

    public func fetchNewDataIfNeeded(_ completion: @escaping (CGMReadingResult) -> Void) {
        guard !isFetching else { return }
        isFetching = true
        
        authenticate { success in
            if success {
                self.getGlucose { result in
                    self.isFetching = false
                    completion(result)
                }
            } else {
                self.isFetching = false
                completion(.noData)
            }
        }
    }

    private func authenticate(completion: @escaping (Bool) -> Void) {
        let url = URL(string: "https://api-us.libreview.io/llu/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("4.16.0", forHTTPHeaderField: "version")
        request.setValue("llu.ios", forHTTPHeaderField: "product")
        let body: [String: String] = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataDict = json["data"] as? [String: Any],
                  let authTicket = dataDict["authTicket"] as? [String: Any],
                  let token = authTicket["token"] as? String else {
                completion(false)
                return
            }
            self.authToken = token
            completion(true)
        }.resume()
    }

    private func getGlucose(completion: @escaping (CGMReadingResult) -> Void) {
        guard let token = authToken else { completion(.noData); return }
        let url = URL(string: "https://api-us.libreview.io/llu/connections")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("4.16.0", forHTTPHeaderField: "version")
        request.setValue("llu.ios", forHTTPHeaderField: "product")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = json["data"] as? [[String: Any]],
                  let connection = dataArray.first,
                  let glucoseData = connection["glucoseMeasurement"] as? [String: Any],
                  let value = glucoseData["Value"] as? Double,
                  let timestampString = glucoseData["Timestamp"] as? String else {
                completion(.noData)
                return
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yyyy h:mm:ss a"
            formatter.timeZone = TimeZone(identifier: "UTC")
            let date = formatter.date(from: timestampString) ?? Date()
            
            let sample = NewGlucoseSample(date: date, quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: value), condition: nil, trend: nil, trendRate: nil, isDisplayOnly: false, wasUserEntered: false, syncIdentifier: "\(date.timeIntervalSince1970)")
            self.latestSample = sample
            completion(.newData([sample]))
        }.resume()
    }

    private func scheduleUpdateTimer() {
        updateTimer.eventHandler = { [weak self] in
            guard let self = self else { return }
            self.fetchNewDataIfNeeded { result in
                if case .newData(let samples) = result {
                    self.delegate.notify { $0?.cgmManager(self, hasNew: .newData(samples)) }
                }
            }
        }
        updateTimer.resume()
    }
}