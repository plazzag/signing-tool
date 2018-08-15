//
//  PLDragView.swift
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

protocol PLDragViewDelegate {
    func dragView(didDragFileWith URL: NSURL)
}

class PLDragView: NSView {
    enum Appearance {
        static let lineWidth: CGFloat = 10.0
    }
    
    var delegate: PLDragViewDelegate?
    private var acceptedFileType = false
    private var acceptedFileExtensions = ["ipa", "xcarchive", "mobileprovision"]
    private var isReceivingDrag = false {
        didSet {
            needsDisplay = true
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([NSPasteboard.PasteboardType(kUTTypeFileURL as String)])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        acceptedFileType = checkExtension(drag: sender)
        isReceivingDrag = acceptedFileType
        
        let filenames = sender.draggingPasteboard().propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String]
        if (filenames?.count)! > 1 {
            acceptedFileType = false
            isReceivingDrag = acceptedFileType
        }
        
        return []
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return acceptedFileType ? .copy : []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        isReceivingDrag = false
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isReceivingDrag = false
        guard let draggedFileURL = sender.draggedFileURL else {
            return false
        }
        
        if acceptedFileType {
            delegate?.dragView(didDragFileWith: draggedFileURL)
        }
        
        return true
    }
    
    fileprivate func checkExtension(drag: NSDraggingInfo) -> Bool {
        guard let fileExtension = drag.draggedFileURL?.pathExtension?.lowercased() else {
            return false
        }
        
        return acceptedFileExtensions.contains(fileExtension)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
        if isReceivingDrag {
            NSColor.selectedControlColor.set()
            
            let path = NSBezierPath(rect:bounds)
            path.lineWidth = Appearance.lineWidth
            path.stroke()
        }
    }
}

extension NSDraggingInfo {
    var draggedFileURL: NSURL? {
        let filenames = draggingPasteboard().propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String]
        let path = filenames?.first
        
        return path.map(NSURL.init)
    }
}
