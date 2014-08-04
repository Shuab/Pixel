//
//  PixelEditorView.swift
//  PixelApp
//
//  Created by Tom Hancocks on 02/08/2014.
//  Copyright (c) 2014 Tom Hancocks. All rights reserved.
//

import Cocoa

class PixelEditorView: NSView {
    
    // Brush Settings
    var brushColor: NSColor = NSColor.blackColor()
    var brushSize: Int = 1
    
    
    // Canvas Settings
    var actualSize: CGSize = CGSize(width: 32, height: 32)
    private var scaledSize: CGSize {
        return CGSize(width: actualSize.width * currentScaleFactor,
            height: actualSize.height * currentScaleFactor)
    }
    
    var wantsPixelGrid: Bool = true {
        didSet {
            setNeedsDisplayInRect(bounds)
        }
    }
    
    var currentScaleFactor: CGFloat = 5 {
        didSet {
            frame = NSRect(origin: CGPointZero, size: scaledSize)
            
            for layer in pixelLayers {
                layer.scaleFactor = currentScaleFactor
            }
            
            setNeedsDisplayInRect(bounds)
        }
    }
    
    
    // Layer Settings
    var pixelLayers = [PixelLayer]()
    var activePixelLayer: Int = 0
    var layersTableView: NSTableView? {
        didSet {
            self.layersTableView?.setDataSource(self)
            self.layersTableView?.setDelegate(self)
            self.layersTableView?.reloadData()
        }
    }
    
    
    /// Instantiate a new editor view with the specified frame size and the actual pixel grid size
    init(frame frameRect: NSRect, withSize size: CGSize) {
        pixelLayers = [PixelLayer]()
        actualSize = size
        super.init(frame: frameRect)
        addPixelLayer()
    }
    
    
    /// Provides the actual on screen dimensions of a pixel as they are displayed within the canvas
    var cellSize: CGSize {
        return CGSize(width: frame.size.width / actualSize.width, height: frame.size.height / actualSize.height)
    }
    

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        // Draw the edge and background color for the canvas
        NSColor.gridColor().setFill()
        NSBezierPath(rect: bounds).fill()
        
        NSColor.whiteColor().setFill()
        NSBezierPath(rect: NSInsetRect(bounds, 1, 1)).fill()
        
        // Draw each of the layers, starting with the backmost layer and working to the front most
        for pixelLayer in pixelLayers {
            if let rep = pixelLayer.cachedRepresentation? {
                rep.drawAtPoint(NSZeroPoint, fromRect:
                    pixelLayer.rect,
                    operation: .CompositeSourceOver,
                    fraction: 1.0)
            }
        }
        
        // Draw the pixel grid lines if they are wanted
        if wantsPixelGrid {
            drawPixelGrid()
        }
    }
    
    override func mouseDown(theEvent: NSEvent!) {
        drawPixel(locationInView: convertPoint(theEvent.locationInWindow, fromView: nil))
    }
    
    override func mouseDragged(theEvent: NSEvent!) {
        drawPixel(locationInView: convertPoint(theEvent.locationInWindow, fromView: nil))
    }
    
    
    /// Draw a single point of color at the specified location. It takes an actual point in
    /// the view itself and then converts it to the actual that actual pixel space of the 
    /// final image.
    /// It will use the current brush settings.
    func drawPixel(locationInView point: CGPoint) {
        // Convert the point to the actual pixel grid
        let x = Int(floor(point.x / currentScaleFactor))
        let y = Int(floor(point.y / currentScaleFactor))
        
        // Get the active layer
        let activeLayer = pixelLayers[activePixelLayer]
        activeLayer.setPixel(atPoint: PixelPoint(x: x, y: y), toColor: brushColor)
        
        // Update the view
        setNeedsDisplayInRect(bounds)
    }
    
    
    /// Add a new layer to the canvas, using the actual final pixel size and current scale
    /// factor.
    func addPixelLayer() {
        var pixelLayer = PixelLayer(size: actualSize)
        pixelLayer.scaleFactor = currentScaleFactor
        pixelLayers += [pixelLayer]
        layersTableView?.reloadData()
    }
    
    /// Remove the specified pixel layer. This will destroy any pixel information contained
    /// on that layer, and trigger a redraw of the canvas.
    func removePixelLayer(atIndex index: Int) {
        pixelLayers.removeAtIndex(index)
        setNeedsDisplayInRect(bounds)
        layersTableView?.reloadData()
    }
    
    /// Rename a specific pixel layer to the given name
    func setName(#name: String, ofLayerAtIndex index: Int) {
        let pixelLayer = pixelLayers[index]
        pixelLayer.name = name
        layersTableView?.reloadData()
    }
    
    /// Load base image for layer using a given URL
    func setBaseImage(url: NSURL?, ofLayerAtIndex index: Int) {
        if let actualURL = url? {
            let pixelLayer = pixelLayers[index]
            pixelLayer.importPixelsFromImage(atURL: actualURL)
            setNeedsDisplayInRect(bounds)
        }
    }
    
    
    /// Draw grid lines representing the layout of pixels on the canvas. The grid lines are
    /// a standard grid line color. 
    /// This may need to be changed in future!
    func drawPixelGrid() {
        for y in 1..<Int(actualSize.height) {
            NSColor.gridColor().setFill()
            
            var origin = CGPoint(x: 0, y: CGFloat(y) * cellSize.height)
            var size = CGSize(width: CGRectGetWidth(frame), height: 1)
            
            NSBezierPath(rect: NSRect(origin: origin, size: size)).fill()
        }
        
        for x in 1..<Int(actualSize.width) {
            NSColor.gridColor().setFill()
            
            var origin = CGPoint(x: CGFloat(x) * cellSize.width, y: 0)
            var size = CGSize(width: 1, height: CGRectGetHeight(frame))
            
            NSBezierPath(rect: NSRect(origin: origin, size: size)).fill()
        }
    }
}


/// This extension handles everything to do with the tableview displaying
/// layers, as well as any actions for creating, removing or selecting active
/// layers.
extension PixelEditorView: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRowsInTableView(tableView: NSTableView!) -> Int {
        return countElements(pixelLayers)
    }
    
    func tableView(tableView: NSTableView!, objectValueForTableColumn tableColumn: NSTableColumn!, row: Int) -> AnyObject! {
        let layer = pixelLayers[row]
        
        if tableColumn.identifier == "name" {
            return layer.name
        }
        
        return nil
    }
    
    func tableView(tableView: NSTableView!, setObjectValue object: AnyObject!, forTableColumn tableColumn: NSTableColumn!, row: Int) {
        
        let layer = pixelLayers[row]
        
        if tableColumn.identifier == "name" {
            layer.name = object as String
        }
    }
    
    
    
    func tableViewSelectionDidChange(notification: NSNotification!) {
        let tableView = notification.object as NSTableView
        if tableView == layersTableView {
            activePixelLayer = tableView.selectedRow
        }
    }
    
}
