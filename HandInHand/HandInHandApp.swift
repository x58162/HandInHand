//
//  HandInHandApp.swift
//  HandInHand
//
//  Created by user on 2026/10/15.
//

import SwiftUI
import GoogleSignIn

@main
struct HandInHandApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
