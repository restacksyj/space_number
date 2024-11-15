//
//  AppDelegate.swift
//  space_number
//
//  Created by Yash Jajoo on 11/15/24.
//
import Cocoa
import SwiftUI

import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    fileprivate var statusBarItem: NSStatusItem?
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var application: NSApplication!
    @IBOutlet weak var workspace: NSWorkspace!
    let mainDisplay = "Main"
    let spacesMonitorFile = "~/Library/Preferences/com.apple.spaces.plist"
    let conn = _CGSDefaultConnection()
    private var floatingWindow: NSWindow? // Keep refer
    private var currentSpaceNumber: Int = -1
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        configureObservers()
        configureSpaceMonitor()
        updateActiveSpaceNumber()
    }
    
    //    @objc func showFloatingWindow(value:String) {
    //        if floatingWindow != nil {
    //                    return // Skip creating a new window if it already exists
    //                }
    //        floatingWindow = NSWindow(
    //            contentRect: NSRect(x: 0, y: 0, width: 150, height: 100),
    //            styleMask: [.borderless],
    //            backing: .buffered,
    //            defer: false
    //        )
    //
    //        floatingWindow?.isReleasedWhenClosed = true
    //        floatingWindow?.isOpaque = false
    //        var body: some View {
    //            Text(value)
    //                .foregroundColor(.white)
    //                .font(.system(size: 30))
    //                .frame(maxWidth: .infinity, maxHeight: .infinity)
    //                .background(Color.black)
    //                .cornerRadius(10)
    //                .padding()
    //                .multilineTextAlignment(.center)
    //        }
    //        floatingWindow?.contentView = NSHostingView(rootView: body)
    //        floatingWindow?.backgroundColor = NSColor.black
    //        floatingWindow?.level = .floating
    //        floatingWindow?.alphaValue = 0.8
    //        floatingWindow?.center()
    //        floatingWindow?.makeKeyAndOrderFront(nil)
    //
    //        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
    //            self.floatingWindow?.close()
    //            self.floatingWindow = nil // Release the reference after closing
    //        }
    //
    //    }
    
    @objc func showFloatingWindow(value: String) {
        if let existingWindow = floatingWindow {
            existingWindow.orderOut(nil)
            floatingWindow = nil
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
        window.collectionBehavior = [.transient, .ignoresCycle]
        let contentView = NSHostingView(rootView:
                                            Text(value)
            .foregroundColor(.white)
            .font(.system(size: 30, weight: .bold))
            .frame(width: 100, height: 60)
            .background(Color.black.opacity(0.8))
            .cornerRadius(10)
        )
        
        window.contentView = contentView
        window.center()
        floatingWindow = window
        window.orderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.floatingWindow?.orderOut(nil)
            self?.floatingWindow = nil
        }
    }
    
    fileprivate func configureSpaceMonitor() {
        let fullPath = (spacesMonitorFile as NSString).expandingTildeInPath
        let queue = DispatchQueue.global(qos: .default)
        let fildes = open(fullPath.cString(using: String.Encoding.utf8)!, O_EVTONLY)
        if fildes == -1 {
            NSLog("Failed to open file: \(spacesMonitorFile)")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fildes, eventMask: DispatchSource.FileSystemEvent.delete, queue: queue)
        source.setEventHandler { () -> Void in
            let flags = source.data.rawValue
            if (flags & DispatchSource.FileSystemEvent.delete.rawValue != 0) {
                source.cancel()
                self.updateActiveSpaceNumber()
                self.configureSpaceMonitor()
            }
        }
        source.setCancelHandler { () -> Void in
            close(fildes)
        }
        source.resume()
    }
    
    @objc func updateActiveSpaceNumber() {
        let displays = CGSCopyManagedDisplaySpaces(conn) as! [NSDictionary]
        let activeDisplay = CGSCopyActiveMenuBarDisplayIdentifier(conn) as! String
        let allSpaces: NSMutableArray = []
        var activeSpaceID = -1
        
        for d in displays {
            guard
                let current = d["Current Space"] as? [String: Any],
                let spaces = d["Spaces"] as? [[String: Any]],
                let dispID = d["Display Identifier"] as? String
            else {
                continue
            }
            
            switch dispID {
            case mainDisplay, activeDisplay:
                activeSpaceID = current["ManagedSpaceID"] as! Int
            default:
                break
            }
            
            for s in spaces {
                let isFullscreen = s["TileLayoutManager"] as? [String: Any] != nil
                if isFullscreen {
                    continue
                }
                allSpaces.add(s)
            }
        }
        
        if activeSpaceID == -1 {
            DispatchQueue.main.async {
                if let button = self.statusBarItem?.button{
                    button.title = "?"
                } else {
                    print("Failed to update")
                }
                
            }
            return
        }
        
        for (index, space) in allSpaces.enumerated() {
            let spaceID = (space as! NSDictionary)["ManagedSpaceID"] as! Int
            let spaceNumber = index + 1
            if spaceID == activeSpaceID {
                if spaceNumber != currentSpaceNumber {
                    currentSpaceNumber = spaceNumber
                    DispatchQueue.main.async {
                        guard let statusBarButton = self.statusBarItem?.button else{
                            print("something is nil here")
                            return
                        }
                        statusBarButton.title = String("\(spaceNumber)")
                        self.showFloatingWindow(value:String("\(spaceNumber)"))
                    }
                }
                return
            }
        }
    }
    
    
    fileprivate func configureObservers() {
        workspace = NSWorkspace.shared
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(AppDelegate.updateActiveSpaceNumber),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: workspace
        )
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(AppDelegate.updateActiveSpaceNumber),
//            name: NSApplication.didUpdateNotification,
//            object: nil
//        )
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button {
            button.target = self
            button.title = "?"
        }
    }
    
}
