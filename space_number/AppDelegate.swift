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
    private var statusBarMenu: NSMenu!
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var application: NSApplication!
    @IBOutlet weak var workspace: NSWorkspace!
    let mainDisplay = "Main"
    let spacesMonitorFile = "~/Library/Preferences/com.apple.spaces.plist"
    let conn = _CGSDefaultConnection()
    private var floatingWindow: NSWindow?
    private var currentSpaceNumber: Int = -1
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureObservers()
        configureSpaceMonitor()
        updateActiveSpaceNumber()
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        // This method will be called when the status bar item is clicked
        statusBarItem?.menu?.popUp(positioning: nil,
                                   at: NSPoint(x: sender.bounds.midX,
                                               y: sender.bounds.minY),
                                   in: sender)
    }
    
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
        let contentView = NSHostingView(rootView: Text(value)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
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
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button {
            button.target = self
            button.title = "?"
        }
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        let quitItem = NSMenuItem()
        quitItem.title = "Quit"
        quitItem.target = NSApplication.shared
        quitItem.action = #selector(NSApplication.terminate(_:))
        quitItem.keyEquivalent = "q"
        menu.addItem(quitItem)
        if let button = statusBarItem?.button {
            button.title = "?"
        }
        statusBarItem?.menu = menu
    }
    
}
