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
    
    @IBOutlet var instructions: NSTextField!
    
    //MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        instructions.stringValue =
            "Left Mouse Button + Drag : Pan\n" +
            "Right Mouse Button + Drag : Alter Equation\n" +
        "Mouse ScrollWheel : Zoom\n"
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
    
    override func mouseDragged(with event: NSEvent) {
        let scale:Float = 5.0 / control.zoom
        control.ulCorner.x -= Float(event.deltaX) * scale
        control.ulCorner.y -= Float(event.deltaY) * scale
        viewIsDirty = true
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        let scale:Float = 0.2 / control.zoom
        control.imagScale += Float(event.deltaX) * scale
        control.realScale += Float(event.deltaY) * scale
        viewIsDirty = true
    }
    
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
    
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        
        switch event.keyCode {
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
