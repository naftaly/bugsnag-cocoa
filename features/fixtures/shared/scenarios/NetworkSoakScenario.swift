//
//  NetworkSoakScenario.swift
//  iOSTestApp
//
//  Created by Steve Kirkland-Walton on 07/10/2021.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

import Foundation
//import Timer

class NetworkSoakScenario: Scenario {
    
    let url = URL(string: "http://localhost:9339/log")!
//    let url = URL(string: "http://bs-local.com:9339/logs")!
    var requestNumber = 1

    override func startBugsnag() {
        config.autoTrackSessions = false
        super.startBugsnag()
    }
    
    override func run() {
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            var request = URLRequest(url: self.url)
            request.httpMethod = "POST"
            request.httpBody = #"{"message":"hello"}"#.data(using: .utf8)
            
            let requestNumber = self.requestNumber

            let startTime = CFAbsoluteTimeGetCurrent()

            URLSession.shared.dataTask(with: request) { _, response, error in
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                if (response as? HTTPURLResponse) != nil {
                    NSLog("$$$$ [\(requestNumber)] Responded in \(elapsed)")
                } else if let error = error {
                    NSLog("$$$$ [\(requestNumber)] \(error)")
                } else {
                    fatalError("URLSession data task completed without response or error")
                }
            }.resume()
            
            if self.requestNumber == 1000 {
                timer.invalidate()
            } else {
                self.requestNumber += 1
            }
        }
    }
}
