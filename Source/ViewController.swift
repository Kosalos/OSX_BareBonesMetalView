import Cocoa
import MetalKit

class ViewController: NSViewController, NSWindowDelegate, MetalViewDelegate {
    var control = Control()
    var threadGroups = MTLSize()
    var threadGroupCount = MTLSize()
    var device: MTLDevice! = nil
    var uniformBuffer: MTLBuffer! = nil
    var colorBuffer: MTLBuffer! = nil
    var commandQueue: MTLCommandQueue?
    var pipelineState: MTLComputePipelineState! = nil
    var timer = Timer()

    @IBOutlet var instructions: NSTextField!
    
    //MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()

        timer = Timer.scheduledTimer(timeInterval:0.01, target:self, selector: #selector(timerHandler), userInfo: nil, repeats:true)

        instructions.stringValue = """
        Left Mouse Button + Drag : Pan
        Right Mouse Button + Drag : Alter Equation
        Mouse ScrollWheel : Zoom
        1,2 : Alter radial symmetry
        """
    }
    
    override func viewDidAppear() {
        super.viewWillAppear()
        view.window?.delegate = self
        (view as! MetalView).delegate2 = self
        
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        
        let library = device.makeDefaultLibrary()!
        let juliaShader = library.makeFunction(name: "juliaShader")!
        pipelineState = try! device!.makeComputePipelineState(function: juliaShader)
        
        let jbSize = MemoryLayout<float3>.stride * 256
        colorBuffer = device.makeBuffer(length:jbSize, options:MTLResourceOptions.storageModeShared)
        colorBuffer.contents().copyMemory(from:colorMap, byteCount:jbSize)
        
        uniformBuffer = device.makeBuffer(length:MemoryLayout<Control>.stride, options:MTLResourceOptions.storageModeShared)
        
        reset()
        resizeIfNecessary()
    }
    
    //MARK: -
    
    func reset() {
        control.ulCorner.x = -0.1527186040
        control.ulCorner.y = -0.89949572
        control.zoom = 700
        control.realScale = -0.4
        control.imagScale = 0.6
        control.radialAmount = 0
    }
    
    //MARK: -
    
    func calcThreadGroups() {
        let w = pipelineState.threadExecutionWidth
        let h = pipelineState.maxTotalThreadsPerThreadgroup / w
        let wxs = Int(view.bounds.width) * 2     // why * 2 ??
        let wys = Int(view.bounds.height) * 2
        
        control.xSize = Int32(wxs)
        control.ySize = Int32(wys)
        
        threadGroupCount = MTLSizeMake(w, h, 1)
        threadGroups = MTLSizeMake(1 + (wxs / w), 1 + (wys / h), 1)
    }
    
    func computeTexture(_ drawable:CAMetalDrawable) {
        let commandBuffer = commandQueue?.makeCommandBuffer()!
        let renderEncoder = commandBuffer!.makeComputeCommandEncoder()!
        
        control.colorScroll += 1
        if control.colorScroll > 256 { control.colorScroll = 0 }
        
        uniformBuffer.contents().copyMemory(from:&control, byteCount:MemoryLayout<Control>.stride)
        
        renderEncoder.setComputePipelineState(pipelineState)
        renderEncoder.setTexture(drawable.texture, index: 0)
        renderEncoder.setBuffer(uniformBuffer,  offset: 0, index: 0)
        renderEncoder.setBuffer(colorBuffer,    offset: 0, index: 1)
        
        renderEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        renderEncoder.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
    
    //MARK: -

    var eDelta = NSPoint()
    
    @objc func timerHandler() {
        if(eDelta.x != 0 || eDelta.y != 0) {
            let scale:Float = 0.2 / control.zoom
            control.imagScale += Float(eDelta.x) * scale
            control.realScale += Float(eDelta.y) * scale
            viewIsDirty = true
        }
    }
    
    //MARK: -
    
    override func mouseDragged(with event: NSEvent) {
        let scale:Float = 5.0 / control.zoom
        control.ulCorner.x -= Float(event.deltaX) * scale
        control.ulCorner.y -= Float(event.deltaY) * scale
        viewIsDirty = true
    }
    
    //MARK: -

    var rpt = NSPoint()
    
    override func rightMouseDown(with event: NSEvent) {
        rpt = event.locationInWindow;
    }

    override func rightMouseUp(with event: NSEvent) {
        eDelta = NSPoint()
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        let pt = event.locationInWindow;
        eDelta.x = (pt.x - rpt.x) / 100
        eDelta.y = (pt.y - rpt.y) / 100
    }
    
    //MARK: -

    override func scrollWheel(with event: NSEvent) {
        let xs:Float = Float(view.bounds.width)     // why not / 2 ??
        let ys:Float = Float(view.bounds.height)
        let xc:Float = control.ulCorner.x + xs / control.zoom
        let yc:Float = control.ulCorner.y + ys / control.zoom
        
        control.zoom *= Float(1 - event.deltaY / 50.0)
        
        control.ulCorner.x = xc - xs / control.zoom
        control.ulCorner.y = yc - ys / control.zoom
        viewIsDirty = true
    }
    
    func alterRadialSymmetry(_ direction:Float) {
        control.radialAmount += direction * 0.01
        control.radialAmount = max( min(control.radialAmount,1.9) ,0)
        viewIsDirty = true
    }
    
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        
        switch event.keyCode {
        case 18 :   // 1
            alterRadialSymmetry(-1)
        case 19 :   // 2
            alterRadialSymmetry(+1)
        case 53 :   // Esc
            NSApplication.shared.terminate(self)
        default : break
        }
    }
    
    override func keyUp(with event: NSEvent) {}
    
    //MARK: -
    
    func resizeIfNecessary() {
        let minWinSize:CGSize = CGSize(width:500, height:500)
        var r:CGRect = (view.window?.frame)!
        var changed:Bool = false
        
        if r.size.width < minWinSize.width {
            r.size.width = minWinSize.width
            changed = true
        }
        if r.size.height < minWinSize.height {
            r.size.height = minWinSize.height
            changed = true
        }
        
        if changed {  view.window?.setFrame(r, display:true) }
        
        calcThreadGroups()
        viewIsDirty = true
    }
    
    func windowDidResize(_ notification: Notification) { resizeIfNecessary() }
}
