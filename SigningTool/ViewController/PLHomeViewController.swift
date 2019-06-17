//
//  ViewController.swift
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

class PLHomeViewController: NSViewController {
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var staticLabel: NSTextField!
    @IBOutlet weak var buildButton: NSButton!
    @IBOutlet weak var helpButton: NSButton!
    @IBOutlet weak var dragView: PLDragView!
    @IBOutlet weak var logoView: NSImageView!
    @IBOutlet weak var xcodeStateView: PLBackgroundView!
    @IBOutlet weak var appStateView: PLBackgroundView!
    @IBOutlet weak var provisioningStateView: PLBackgroundView!
    @IBOutlet weak var appStoreRadioButton: NSButton!
    @IBOutlet weak var otherRadioButton: NSButton!
    @IBOutlet weak var versionLabel: NSTextField!
    @IBOutlet weak var outputTextView: NSScrollView!
    @IBOutlet weak var outputTextLabel: NSTextField!
    @IBOutlet weak var stopButton: NSButton!
    @IBOutlet weak var resetButton: NSButton!
    @IBOutlet weak var resetInfoLabel: NSTextField!
    @IBOutlet weak var progressView: NSProgressIndicator!
    
    var isRunning = false
    var outputPipe:Pipe!
    var buildTask:Process!
    
    private var sourceType = ""
    private var isAppStore = true
    private var appFilePath: URL?
    private var provisioningProfilePath: URL?
    private var canProceed = false {
        didSet {
            buildButton.isEnabled = canProceed
        }
    }
    
    private var xcodeProvided = false {
        didSet {
            if xcodeProvided == true {
                xcodeStateView.backgroundColor = NSColor.systemGreen
                dragView.isHidden = false
                canProceed = validateRequirements()
            } else {
                xcodeStateView.backgroundColor = NSColor.systemRed
                dragView.isHidden = true
                canProceed = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let alert = NSAlert()
                    alert.messageText = "Missing Xcode Command Line Tools"
                    alert.informativeText = "This tool requires Xcode Command Line Tools, which are not present on your system.\n\nFor more information see the general notes in the manual which you received from Customer Support together with this tool.\n\nYou can also try typing this on command line:\nxcode-select --install"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    if let window = self.view.window {
                        alert.beginSheetModal(for: window, completionHandler: { (modalResponse: NSApplication.ModalResponse) -> Void in
                            if(modalResponse == NSApplication.ModalResponse.alertFirstButtonReturn){
                                //
                            }
                        })
                    }
                }
            }
        }
    }
    
    private var appFileProvided = false {
        didSet {
            if appFileProvided == true {
                appStateView.backgroundColor = NSColor.systemGreen
                canProceed = validateRequirements()
            } else {
                appStateView.backgroundColor = NSColor.systemRed
                canProceed = false
                
                if (appFilePath != nil) {
                    let fileManager = FileManager.default
                    do {
                        try fileManager.removeItem(at: appFilePath!)
                    } catch {
                        return
                    }
                    
                    appFilePath = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let alert = NSAlert()
                        alert.messageText = "Unsupported .ipa/.xcarchive"
                        alert.informativeText = "This file was not provided by plazz AG. Please contact your contact person at plazz AG.\n\nThis tool only works with the Mobile Event App."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.beginSheetModal(for: self.view.window!, completionHandler: { (modalResponse: NSApplication.ModalResponse) -> Void in
                            if(modalResponse == NSApplication.ModalResponse.alertFirstButtonReturn){
                                //
                            }
                        })
                    }
                }
            }
        }
    }
    
    private var provisioningFileProvided = false {
        didSet {
            if provisioningFileProvided == true {
                provisioningStateView.backgroundColor = NSColor.systemGreen
                canProceed = validateRequirements()
            } else {
                provisioningStateView.backgroundColor = NSColor.systemRed
                canProceed = false
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dragView.delegate = self
        dragView.isHidden = true
        outputTextView.isHidden = true
        outputTextLabel.isHidden = true
        stopButton.isEnabled = false
        stopButton.isHidden = true
        resetButton.isEnabled = false
        resetButton.isHidden = true
        resetInfoLabel.isHidden = true
        buildButton.isEnabled = false
        appStoreRadioButton.state = .on
        logoView.image = NSImage(named: "mea_logo")?.imageWithTintColor(tintColor: NSColor.secondaryLabelColor)
        
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            versionLabel.stringValue = "\(version) (\(build))"
        }
        
        if let textView = self.outputTextView.documentView as? NSTextView {
            textView.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        }
        
        self.performReset()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func radioButtonChanged(_ sender: AnyObject) {
        if appStoreRadioButton.state == .on {
            isAppStore = true
        } else {
            isAppStore = false
            
        }
    }
    
    @IBAction func buildButtonTapped(_ sender: AnyObject) {
        buildButton.isEnabled = false
        buildButton.isHidden = true
        dragView.isHidden = true
        appStoreRadioButton.isEnabled = false
        otherRadioButton.isEnabled = false
        outputTextLabel.isHidden = false
        outputTextView.isHidden = false
        if let textView = self.outputTextView.documentView as? NSTextView {
            textView.string = ""
        }
        stopButton.isEnabled = true
        stopButton.isHidden = false
        resetButton.isHidden = false
        resetButton.isEnabled = false
        resetInfoLabel.isHidden = false
        
        isRunning = true
        progressView.startAnimation(nil)
        let taskQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
        taskQueue.async {
            if self.sourceType == "ipa" {
                guard let path = Bundle.main.path(forResource: "resignipa",ofType:"sh") else {
                    print("Unable to locate resignipa.sh")
                    return
                }
                
                var arguments:[String] = []
                arguments.append("-c")
                arguments.append("\"\(path)\" -a \"\((self.appFilePath?.relativePath)!)\" -p \"\((self.provisioningProfilePath?.relativePath)!)\" \(self.isAppStore ? "--store" : "--enterprise")")

                self.buildTask = Process()
                self.buildTask.launchPath = "/bin/sh"
                self.buildTask.arguments = arguments
                
                self.buildTask.terminationHandler = {
                    task in
                    DispatchQueue.main.async(execute: {
                        self.isRunning = false
                        self.progressView.stopAnimation(nil)
                        self.stopButton.isEnabled = false
                        self.resetButton.isEnabled = true
                        
                        if let textView = self.outputTextView.documentView as? NSTextView {
                            var previousOutput = textView.string
                            previousOutput = previousOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                            textView.string = previousOutput
                            let range = NSRange(location:textView.string.count,length:0)
                            textView.scrollRangeToVisible(range)
                        }
                    })
                }
                
                self.captureStandardOutputAndRouteToTextView(self.buildTask)
                self.buildTask.launch()
                self.buildTask.waitUntilExit()
            }
            
            if self.sourceType == "xcarchive" {
                guard let path = Bundle.main.path(forResource: "signarchive",ofType:"sh") else {
                    print("Unable to locate signarchive.sh")
                    return
                }
                
                var arguments:[String] = []
                arguments.append("-c")
                arguments.append("\"\(path)\" -a \"\((self.appFilePath?.relativePath)!)\" -p \"\((self.provisioningProfilePath?.relativePath)!)\" \(self.isAppStore ? "--store" : "--enterprise")")
                
                self.buildTask = Process()
                self.buildTask.launchPath = "/bin/sh"
                self.buildTask.arguments = arguments
                
                self.buildTask.terminationHandler = {
                    task in
                    DispatchQueue.main.async(execute: {
                        self.isRunning = false
                        self.progressView.stopAnimation(nil)
                        self.stopButton.isEnabled = false
                        self.resetButton.isEnabled = true
                        
                        if let textView = self.outputTextView.documentView as? NSTextView {
                            var previousOutput = textView.string
                            previousOutput = previousOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                            textView.string = previousOutput
                            let range = NSRange(location:textView.string.count,length:0)
                            textView.scrollRangeToVisible(range)
                        }
                    })
                }
                
                self.captureStandardOutputAndRouteToTextView(self.buildTask)
                self.buildTask.launch()
                self.buildTask.waitUntilExit()
            }
        }
    }
    
    @IBAction func stopButtonTapped(_ sender: AnyObject) {
        if isRunning {
            buildTask.terminate()
        }
    }
    
    @IBAction func resetButtonTapped(_ sender: AnyObject) {
        if !isRunning {
            self.performReset()
        }
    }
    
    func performReset() {
        buildButton.isEnabled = false
        buildButton.isHidden = false
        dragView.isHidden = true
        appStoreRadioButton.isEnabled = true
        otherRadioButton.isEnabled = true
        outputTextLabel.isHidden = true
        outputTextView.isHidden = true
        if let textView = self.outputTextView.documentView as? NSTextView {
            textView.string = ""
        }
        stopButton.isEnabled = false
        stopButton.isHidden = true
        resetButton.isHidden = true
        resetButton.isEnabled = false
        resetInfoLabel.isHidden = true
        
        // Don't mix the order
        appFilePath = nil
        appFileProvided = false
        provisioningProfilePath = nil
        provisioningFileProvided = false
        imageView.image = nil
        
        //Check xcode command line tools
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "command -v /usr/libexec/PlistBuddy >/dev/null 2>&1 || { exit 1; }"]
        task.launch()
        task.waitUntilExit()
        
        let status = task.terminationStatus
        if status != 0 {
            xcodeProvided = false
        } else {
            xcodeProvided = true
        }
        
        let fileManager = FileManager.default
        guard let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        
        let appFolder = folder.appendingPathComponent(Bundle.main.bundleIdentifier!)
        var isDirectory: ObjCBool = false
        let folderExists = fileManager.fileExists(atPath: appFolder.path, isDirectory: &isDirectory)
        if !folderExists {
            return
        }
        let enumerator = fileManager.enumerator(at: appFolder, includingPropertiesForKeys: nil)
        while let fileUrl = enumerator?.nextObject() {
            do {
                try fileManager.removeItem(at: fileUrl as! URL)
            } catch {
                return
            }
        }
    }
    
    private func validateApp(file: URL?) -> Bool {
        guard file != nil else {
            return false
        }
        
        let fileManager = FileManager.default
        guard let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            appFileProvided = false
            return false
        }
        
        let appFolder = folder.appendingPathComponent(Bundle.main.bundleIdentifier!)
        var isDirectory: ObjCBool = false
        let folderExists = fileManager.fileExists(atPath: appFolder.path, isDirectory: &isDirectory)
        if !folderExists {
            return false
        }
        
        let fileExists = fileManager.fileExists(atPath: (file?.path)!)
        if !fileExists {
            return false
        } else {
            let fileExtension = file?.pathExtension.lowercased()
            if fileExtension == "ipa" {
                let fileExists = fileManager.fileExists(atPath: appFolder.appendingPathComponent("app.zip").path)
                if fileExists {
                    do {
                        try fileManager.removeItem(atPath: appFolder.appendingPathComponent("app.zip").path)
                    } catch {
                        return false
                    }
                }
                do {
                    try fileManager.moveItem(atPath: (file?.absoluteURL)!.path, toPath: appFolder.appendingPathComponent("app.zip").absoluteURL.path)
                } catch {
                    return false
                }
                
                sourceType = fileExtension!
                appFilePath = appFolder.appendingPathComponent("app.zip")
                
                let task = Process()
                task.launchPath = "/bin/sh"
                task.arguments = ["-c", "ipaCheck=$(unzip -l \"\(appFilePath?.relativePath ?? appFolder.appendingPathComponent("app.zip").relativePath)\" | grep Payload/MEA.app | wc -l); if [ $ipaCheck == 0 ]; then exit 1; fi"]
                task.launch()
                task.waitUntilExit()
                
                let status = task.terminationStatus
                
                if status == 0 {
                    var fileExists = fileManager.fileExists(atPath: appFolder.appendingPathComponent("Payload").path, isDirectory: &isDirectory)
                    if fileExists {
                        do {
                            try fileManager.removeItem(atPath: appFolder.appendingPathComponent("Payload").path)
                        } catch {
                            return status == 0
                        }
                    }
                    
                    fileExists = fileManager.fileExists(atPath: appFolder.appendingPathComponent("Symbols").path, isDirectory: &isDirectory)
                    if fileExists {
                        do {
                            try fileManager.removeItem(atPath: appFolder.appendingPathComponent("Symbols").path)
                        } catch {
                            return status == 0
                        }
                    }
                    
                    let unzipProcess = Process.launchedProcess(launchPath: "/usr/bin/unzip", arguments: ["-o", appFilePath?.relativePath ?? appFolder.appendingPathComponent("app.zip").relativePath, "-d", appFolder.relativePath])
                    unzipProcess.waitUntilExit()
                    
                    imageView.image = NSImage(contentsOf: appFolder.appendingPathComponent("Payload/MEA.app/AppIcon83.5x83.5@2x~ipad.png"))
                }
                
                return status == 0
            }
            
            if fileExtension == "xcarchive" {
                let fileExists = fileManager.fileExists(atPath: appFolder.appendingPathComponent("app.xcarchive").path, isDirectory: &isDirectory)
                if fileExists {
                    do {
                        try fileManager.removeItem(atPath: appFolder.appendingPathComponent("app.xcarchive").path)
                    } catch {
                        return false
                    }
                }
                do {
                    try fileManager.moveItem(atPath: (file?.absoluteURL)!.path, toPath: appFolder.appendingPathComponent("app.xcarchive/").absoluteURL.path)
                } catch {
                    return false
                }
                
                sourceType = fileExtension!
                appFilePath = appFolder.appendingPathComponent("app.xcarchive")
                
                let task = Process()
                task.launchPath = "/bin/sh"
                task.arguments = ["-c", "if [ ! -d \"\(appFolder.appendingPathComponent("app.xcarchive/Products/Applications/MEA.app").relativePath)\" ]; then exit 1; fi"]
                task.launch()
                task.waitUntilExit()
                
                let status = task.terminationStatus
                
                if status == 0 {
                    imageView.image = NSImage(contentsOf: appFolder.appendingPathComponent("app.xcarchive/Products/Applications/MEA.app/AppIcon83.5x83.5@2x~ipad.png"))
                }
                
                return status == 0
            }
        }
        return false
    }
    
    private func validateRequirements() -> Bool {
        return xcodeProvided && appFileProvided && provisioningFileProvided
    }
    
    private func captureStandardOutputAndRouteToTextView(_ task:Process) {
        outputPipe = Pipe()
        task.standardOutput = outputPipe
        
        outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: outputPipe.fileHandleForReading , queue: nil) {
            notification in
            let output = self.outputPipe.fileHandleForReading.availableData
            let outputString = String(data: output, encoding: String.Encoding.utf8) ?? ""
            
            DispatchQueue.main.async(execute: {
                if let textView = self.outputTextView.documentView as? NSTextView {
                    let previousOutput = textView.string
                    
                    if previousOutput.count > 0 {
                        let nextOutput = previousOutput + "\n" + outputString
                        textView.string = nextOutput
                    } else {
                        textView.string = outputString
                    }
                    
                    let range = NSRange(location:textView.string.count,length:0)
                    textView.scrollRangeToVisible(range)
                }
            })
            self.outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        }
    }
}

extension PLHomeViewController: PLDragViewDelegate {
    func dragView(didDragFileWith URL: NSURL) {
        let fileExtension = URL.pathExtension?.lowercased()
        if fileExtension == "ipa" || fileExtension == "xcarchive" {
            let fileManager = FileManager.default
            guard let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                appFileProvided = false
                self.showDragErrorAlert(forFile: URL.lastPathComponent ?? "")
                return
            }
            let appFolder = folder.appendingPathComponent(Bundle.main.bundleIdentifier!)
            var isDirectory: ObjCBool = false
            let folderExists = fileManager.fileExists(atPath: appFolder.path, isDirectory: &isDirectory)
            if !folderExists || !isDirectory.boolValue {
                do {
                    try fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    appFileProvided = false
                    self.showDragErrorAlert(forFile: URL.lastPathComponent ?? "")
                    return
                }
            }
            
            let fileExists = fileManager.fileExists(atPath: appFolder.appendingPathComponent("MEA.\(fileExtension ?? "ipa")").path)
            if fileExists {
                do {
                    try fileManager.removeItem(atPath: appFolder.appendingPathComponent("MEA.\(fileExtension ?? "ipa")").path)
                } catch {
                    appFileProvided = false
                    self.showDragErrorAlert(forFile: URL.lastPathComponent ?? "")
                    return
                }
            }
            
            do {
                try fileManager.copyItem(atPath: URL.absoluteURL!.path, toPath: appFolder.appendingPathComponent("MEA.\(fileExtension ?? "ipa")").absoluteURL.path)
            }
            catch _ as NSError {
                self.showDragErrorAlert(forFile: URL.lastPathComponent ?? "")
                return
            }
            
            appFilePath = appFolder.appendingPathComponent("MEA.\(fileExtension ?? "ipa")")
            appFileProvided = validateApp(file: appFilePath)
        }
        
        if fileExtension == "mobileprovision" {
            let fileManager = FileManager.default
            guard let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                provisioningFileProvided = false
                self.showDragErrorAlert(forFile: URL.lastPathComponent ?? "")
                return
            }
            let appFolder = folder.appendingPathComponent(Bundle.main.bundleIdentifier!)
            var isDirectory: ObjCBool = false
            let folderExists = fileManager.fileExists(atPath: appFolder.path, isDirectory: &isDirectory)
            if !folderExists || !isDirectory.boolValue {
                do {
                    try fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    provisioningFileProvided = false
                    self.showDragErrorAlert(forFile: URL.lastPathComponent ?? "")
                    return
                }
            }
            
            let fileExists = fileManager.fileExists(atPath: appFolder.appendingPathComponent("app.\(fileExtension ?? "mobileprovision")").path)
            if fileExists {
                do {
                    try fileManager.removeItem(atPath: appFolder.appendingPathComponent("app.\(fileExtension ?? "mobileprovision")").path)
                } catch {
                    provisioningFileProvided = false
                    self.showDragErrorAlert(forFile: URL.lastPathComponent ?? "")
                    return
                }
            }
            
            do {
                try fileManager.copyItem(atPath: URL.absoluteURL!.path, toPath: appFolder.appendingPathComponent("app.\(fileExtension ?? "mobileprovision")").absoluteURL.path)
            }
            catch _ as NSError {
                self.showDragErrorAlert(forFile: URL.lastPathComponent ?? "")
                return
            }
            
            provisioningProfilePath = appFolder.appendingPathComponent("app.\(fileExtension ?? "mobileprovision")")
            provisioningFileProvided = true
        }
    }
    
    private func showDragErrorAlert(forFile: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let alert = NSAlert()
            alert.messageText = "Processing Error"
            alert.informativeText = "\(Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String) could not process the file \"\(forFile)\". The file may be damaged or you do not have the required permissions."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.beginSheetModal(for: self.view.window!, completionHandler: { (modalResponse: NSApplication.ModalResponse) -> Void in
                if(modalResponse == NSApplication.ModalResponse.alertFirstButtonReturn){
                    //
                }
            })
        }
    }
}
