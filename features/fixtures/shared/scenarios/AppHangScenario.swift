//
//  AppHangScenario.swift
//  macOSTestApp
//
//  Created by Nick Dowell on 05/03/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

class AppHangScenario: Scenario {
    
    override func startBugsnag() {
        super.startBugsnag()
    }
    
    override func run() {
        logInfo("eventMde is o\(eventMode!)")
    }
}
