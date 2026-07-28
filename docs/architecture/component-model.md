# Component Model

Wavium uses the WebAssembly Component Model as the stable boundary for application and service packaging.

Components are:
- portable
- isolated
- capability-aware
- language-neutral

Components should not know whether they are running on bare metal, in a simulator, or on a cloud node. That distinction belongs to the runtime and hardware layers.