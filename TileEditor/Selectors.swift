//
//  PaletteOptions.swift
//  TileEditor
//
//  Created by iury bessa on 11/5/16.
//  Copyright © 2016 yellokrow. All rights reserved.
//

import Foundation
import Cocoa

class Selector: NSView {
    var boxSelectorProtocol: BoxSelectorProtocol? = nil
    var boxSelectorDelegate: BoxSelectorDelegate? = nil
    
    var palette: (number: Int, box: Int) = (0,0)
    var _boxSelected: (x: Int, y: Int) = (0,0)
    var boxSelected: (x: Int, y: Int) {
        get {
            return _boxSelected
        }set {
            guard let boxSelectorProtocol = boxSelectorProtocol,
                  let paletteCurrentlySelected = boxSelectorProtocol.paletteSelected else {
                NSLog("")
                return
            }
            let selectedPalette = paletteSelected(boxSelected: newValue,
                                                  palettesPerRow: boxSelectorProtocol.palettesPerRow,
                                                  paletteSize: paletteCurrentlySelected.count)
            palette = selectedPalette
            _boxSelected = newValue
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard var boxSelectorProtocol = boxSelectorProtocol,
              let boxSelectorDelegate = boxSelectorDelegate else {
            NSLog("BoxSelectorProtocol not set")
            return
        }
        
        if let ctx = NSGraphicsContext.current()?.cgContext {
            // swap coordinate so that 0,0 is top left corner
            ctx.translateBy(x: 0, y: frame.size.height)
            ctx.scaleBy(x: 1, y: -1)
            ctx.setLineWidth(CGFloat(0.01))
            
            var numberOfTimesAcross = boxSelectorProtocol.palettesPerRow
            let numberOfPalettes = boxSelectorProtocol.palettes.count
            let numberOfBoxesPerPalette = boxSelectorProtocol.palettes[0].count
            let dimensionForBox = boxSelectorProtocol.boxDimension
            
            if numberOfPalettes < numberOfTimesAcross {
                numberOfTimesAcross = numberOfPalettes
            }
            
            // Every time a palette is drawn, a new starting position will be set. This starting position will also account for the case if wrapping occurs.
            var startingPosition: (CGFloat, CGFloat) = (0.0,0.0)
            // Ever time the counter reaches the numberOfPalettesHorizontally, we will move the drawing cursor down the y-axis down the height of the color box
            var numberOfPalettesHorizontallyCounter: CGFloat = 0
            var counter: Int = 0
            for palette in boxSelectorProtocol.palettes {
                startingPosition = draw(palette: palette,
                                        ctx: ctx,
                                        dimension: boxSelectorProtocol.boxDimension,
                                        startingPosition: startingPosition)
                counter = counter + 1
                
                // We have reached the end of the line of the allowed number of palettes horizontally
                if counter == boxSelectorProtocol.palettesPerRow {
                    counter = 0
                    numberOfPalettesHorizontallyCounter = numberOfPalettesHorizontallyCounter + 1
                }
                startingPosition = (dimensionForBox.width*CGFloat(counter*numberOfBoxesPerPalette),
                                    dimensionForBox.height*numberOfPalettesHorizontallyCounter)
            }
            
            if boxSelectorProtocol.boxHighlighter {
                drawCursor(ctx: ctx, position: boxSelected, width: dimensionForBox.width, height: dimensionForBox.height)
            }
            
            
            let selectedPalette = paletteSelected(boxSelected: boxSelected,
                                                  palettesPerRow: boxSelectorProtocol.palettesPerRow,
                                                  paletteSize: numberOfBoxesPerPalette)
            
            if boxSelectorProtocol.paletteHighlighter {
                drawPaletteHighlighter(ctx: ctx,
                                       palette: selectedPalette.number,
                                       boxesHorizontally: boxSelectorProtocol.maximumBoxesPerRow,
                                       paletteSize: numberOfBoxesPerPalette,
                                       width: dimensionForBox.width,
                                       height: dimensionForBox.height)
            }
            
            palette = selectedPalette
            
            boxSelectorDelegate.selected(boxSelector: self, palette: selectedPalette, boxSelected: boxSelected)
        }
        
    }
    override func mouseDown(with event: NSEvent) {
        guard let boxSelectorProtocol = boxSelectorProtocol,
              let paletteCurrentlySelected = boxSelectorProtocol.paletteSelected else {
            NSLog("BoxSelectorProtocol not set")
            return
        }
        let numberOfBoxesPerPalette = paletteCurrentlySelected.count
        let p = event.locationInWindow
        let rawMouseCursor = convert(p, from: nil)
        let mouseCursor = CGPoint(x: rawMouseCursor.x, y: self.frame.size.height-rawMouseCursor.y)
        
        let boxCoordinatePosition = boxPosition(cursorPosition: mouseCursor,
                                                dimension: self.frame.size,
                                                numberOfHorizontalBoxes: boxSelectorProtocol.maximumBoxesPerRow,
                                                rows: boxSelectorProtocol.numberOfRows)
        boxSelected = boxCoordinatePosition
        let selectedPalette = paletteSelected(boxSelected: boxSelected,
                                              palettesPerRow: boxSelectorProtocol.palettesPerRow,
                                              paletteSize: numberOfBoxesPerPalette)
        palette = selectedPalette
        
        needsDisplay = true
        
    }
    func boxPosition(cursorPosition: CGPoint, dimension: CGSize, numberOfHorizontalBoxes: Int, rows: Int) -> (Int, Int) {
        func positionOnALine(position: CGFloat, width: CGFloat) -> Int {
            /**
             This is a three step process
             * Step 1 - Dividing the position/width this us what were the previous section that were past.
             * Step 2 - Get the remainder of diving position/width. If it is 0, then we are on the last section selected. If we are anything other than 0, then we have started moving toward a new section.
             * Step 3 - If the first section of the line is selected, then we will have started at 1 because the remainder will have been some value. Being that computer scientists start counting from 0 we then subtract one.
             */
            let previousSections = position/width
            let remainder = position.truncatingRemainder(dividingBy:width)
            return Int( previousSections + (remainder == 0 ? 0 : 1 )) - 1
        }
        
        // TODO: must find out a mathematical formula for finding the box position within a size given the number of boxes horizontally and vertically
        let widthPerBox = dimension.width/CGFloat(numberOfHorizontalBoxes)
        let heightPerBox = dimension.height/CGFloat(rows)
        
        let horizontalCounter = positionOnALine(position: cursorPosition.x, width: widthPerBox)
        let verticalCounter = positionOnALine(position: cursorPosition.y, width: heightPerBox)
        
        return (horizontalCounter, verticalCounter)
    }
    
    func paletteSelected(boxSelected: (x: Int,y: Int),
                         palettesPerRow: Int,
                         paletteSize: Int) -> (number: Int, box: Int) {
        let numberOfPalettsAcross = palettesPerRow
        // Get the palette in question
        let numberOfPalettesBeforeRow = (boxSelected.y*numberOfPalettsAcross)
        let currentPaletteSelected = (boxSelected.x/paletteSize)+numberOfPalettesBeforeRow
        
        // Get the box selected of the palette
        // This equation will get the number of palettes across and subtract from which palette that is currently selected.
        // This value is the number of palettes left of the currently selected palette.
        let palettesToTheLeftOfSelectedPalette = (currentPaletteSelected-(boxSelected.y*numberOfPalettsAcross))
        // Then subtract palettesToTheLeftOfSelectedPalette*palette size to exclude the palette boxes left of the selected palette so to subtract from the boxSelected.x which is the selected box
        let currentBoxSelected = boxSelected.x - palettesToTheLeftOfSelectedPalette*paletteSize
        
        return (currentPaletteSelected, currentBoxSelected)
    }
    
    func drawCursor(ctx: CGContext, position: (x: Int, y: Int), width: CGFloat, height: CGFloat) {
        ctx.setStrokeColor(NSColor.red.cgColor)
        ctx.setLineWidth(CGFloat(2.0))
        ctx.addRect(CGRect(x: width*CGFloat(position.x),
                           y: height*CGFloat(position.y),
                           width: width,
                           height: height))
        ctx.drawPath(using: .stroke)
    }
    func drawPaletteHighlighter(ctx: CGContext,
                                palette: Int,
                                boxesHorizontally: Int,
                                paletteSize: Int,
                                width: CGFloat,
                                height: CGFloat) {
        let numberOfPalettesAcross = boxesHorizontally/paletteSize
        
        let rowPosition: CGFloat = CGFloat(palette/numberOfPalettesAcross)
        let columnPosition: CGFloat = (CGFloat(palette) - rowPosition*CGFloat(numberOfPalettesAcross))*CGFloat(paletteSize)
        let paletteWidth: CGFloat  = width*CGFloat(paletteSize)
        
        ctx.setStrokeColor(NSColor.red.cgColor)
        ctx.setLineWidth(CGFloat(2.0))
        ctx.addRect(CGRect(x: columnPosition*width,
                           y: rowPosition*height,
                           width: paletteWidth,
                           height: height))
        ctx.drawPath(using: .stroke)
    }
    func draw(palette: Palette,
              ctx: CGContext,
              dimension: (width: CGFloat, height: CGFloat),
              startingPosition: (x: CGFloat, y: CGFloat)) -> (x: CGFloat, y: CGFloat) {
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(CGFloat(1))
        
        var startingXPosition = startingPosition.x
        var startingYPosition = startingPosition.y
        for color in palette.colors {
            if self.frame.size.width < dimension.width + startingXPosition {
                startingXPosition = 0
                startingYPosition = startingYPosition+dimension.height
            }
            
            ctx.addRect(CGRect(x: startingXPosition,
                               y: startingYPosition,
                               width: dimension.width,
                               height: dimension.height))
            ctx.setFillColor(color)
            ctx.drawPath(using: .fillStroke)
            startingXPosition = startingXPosition + dimension.width
        }
        return (0,0)
    }
}

class ColorSelector: Selector, BoxSelectorProtocol {
    var palettes: [Palette] = []
    var boxHighlighter: Bool = true
    var paletteHighlighter: Bool = false
    var palettesPerRow: Int = 1
    var maximumBoxesPerRow = 4
    
    var currentPaletteSelected = 0
    var currentBoxSelected: Int = 0
    var numberOfRows: Int = 1
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.boxSelectorProtocol = self
    }
}

class PaletteSelector: Selector, BoxSelectorProtocol {
    var palettes: [Palette] = []
    var boxHighlighter: Bool = false
    var paletteHighlighter: Bool = true
    var palettesPerRow: Int = 4
    var maximumBoxesPerRow = 16
    
    var currentPaletteSelected = 0
    var currentBoxSelected: Int = 0
    var numberOfRows: Int = 2
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.boxSelectorProtocol = self
    }
}

class GeneralColorSelector: Selector, BoxSelectorProtocol {
    var palettes: [Palette] = []
    var boxHighlighter: Bool = true
    var paletteHighlighter: Bool = false
    var palettesPerRow: Int = 1
    var maximumBoxesPerRow = 4
    var numberOfRows: Int = 16
    var currentPaletteSelected = 0
    var currentBoxSelected: Int = 0
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.boxSelectorProtocol = self
    }
}