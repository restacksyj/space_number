//
//  ContentView.swift
//  space_number
//
//  Created by Yash Jajoo on 11/15/24.
//


import SwiftUI

@main struct
MainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
    
}
