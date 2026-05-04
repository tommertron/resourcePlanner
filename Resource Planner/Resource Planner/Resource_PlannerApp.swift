//
//  Resource_PlannerApp.swift
//  Resource Planner
//
//  Created by Tom Robertson on 2026-05-02.
//

import SwiftUI

@main
struct Resource_PlannerApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: Resource_PlannerDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
