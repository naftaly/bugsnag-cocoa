//
//  NetworkSoakScenario.swift
//  iOSTestApp
//
//  Created by Steve Kirkland-Walton on 07/10/2021.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

import Foundation

class NetworkSoakScenario: Scenario {
    
    let url = URL(string: "http://bs-local.com:9339/logs")!
    var requestNumber = 1
    var totalElapsed = 0
    var maxElapsed = 0

    override func startBugsnag() {
        config.autoTrackSessions = false
        super.startBugsnag()
    }
    
    override func run() {
        self.requestNumber = 1

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            var request = URLRequest(url: self.url)
            request.httpMethod = "POST"
            request.httpBody = #"{"message":"hello"}"#.data(using: .utf8)

            let startTime = CFAbsoluteTimeGetCurrent()

            URLSession.shared.dataTask(with: request) { _, response, error in
                let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                if (response as? HTTPURLResponse) != nil {
                    NSLog("$$$$ [\(self.requestNumber)] Responded in \(elapsed)")
                } else if let error = error {
                    NSLog("$$$$ [\(self.requestNumber)] Errored with \(error)")
                } else {
                    fatalError("URLSession data task completed without response or error")
                }

                // Update stats
                self.totalElapsed += elapsed
                if (elapsed > self.maxElapsed) {
                    self.maxElapsed = elapsed
                }
            }.resume()

            // Break out of the loop after sending all requests
            if self.requestNumber == 60 {
                timer.invalidate()
                sleep(5)
                self.reportStats()
            } else {
                self.requestNumber += 1
            }
        }

    }
    
    func reportStats() {
        var request = URLRequest(url: self.url)
        request.httpMethod = "POST"
        let average = self.totalElapsed / self.requestNumber
        request.httpBody = "{\"averageElapsed\":\(average), \"maxElapsed\":\(self.maxElapsed)}".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { _, response, error in
            if (response as? HTTPURLResponse) != nil {
                NSLog("$$$$ Response to stats request: \(String(describing: response))")
            } else if let error = error {
                NSLog("$$$$ Stats request error: \(error)")
            } else {
                fatalError("Stats request completed without response or error")
            }
        }.resume()
    }
}
