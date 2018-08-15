//
//  AppDelegate.swift
//  SigningTool
//
//  Created by Matthias Steinmetz on 11.07.18.
//  Copyright © 2018 plazz AG. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    fileprivate var mainWindowController: NSWindowController!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let mainStoryboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        mainWindowController = mainStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "MainWindowController")) as! NSWindowController
        mainWindowController.window?.makeKeyAndOrderFront(self)
        
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: mainWindowController.window, queue: OperationQueue.main) { _ in
            if let viewcontroller = self.mainWindowController.contentViewController as? PLHomeViewController {
                viewcontroller.performReset()
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if let viewcontroller = self.mainWindowController.contentViewController as? PLHomeViewController {
            viewcontroller.performReset()
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindowController.window?.makeKeyAndOrderFront(self)
        } else {
            mainWindowController.window?.orderFront(self)
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
