import MetalKit

var viewIsDirty:Bool = true

protocol MetalViewDelegate {
    func computeTexture(_ drawable:CAMetalDrawable)
}

class MetalView: MTKView {
    var delegate2:MetalViewDelegate?

    required init(coder: NSCoder) {
        super.init(coder: coder)
        
        self.framebufferOnly = false
        self.device = MTLCreateSystemDefaultDevice()
    }
    
    override func draw() {
        super.draw()
        
        if viewIsDirty {
            if let drawable = currentDrawable {
                delegate2?.computeTexture(drawable)
                viewIsDirty = false
            }
        }
    }
    
    override var acceptsFirstResponder: Bool { return true }
}

