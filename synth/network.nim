import std/[tables]

type SynthNetwork* = ref object
    inputs: seq[float32]
    outputs: seq[float32]
    inputDefault: seq[float32]
    outputDefault: seq[float32]
    inputNames: Table[string, int]
    outputNames: Table[string, int]

    connections: seq[(int, int)]
    isConnected: seq[bool]

proc synthConnectionsInit*(self: var SynthNetwork) =
    self.inputs = @[]
    self.outputs = @[]
    self.inputDefault = @[]
    self.outputDefault = @[]
    self.inputNames = initTable[string, int]()
    self.outputNames = initTable[string, int]()
    self.connections = @[]
    self.isConnected = @[]

proc addInput*(self: var SynthNetwork, input: float32, inputName: string) =
    self.inputs.add(input)
    self.inputDefault.add(input)
    self.inputNames[inputName] = self.inputs.len - 1
    self.isConnected.add(false)

proc addOutput*(self: var SynthNetwork, output: float32, outputName: string) =
    self.outputs.add(output)
    self.outputDefault.add(output)
    self.outputNames[outputName] = self.outputs.len - 1

proc addConnection*(self: var SynthNetwork, inputName: string, outputName: string) =
    self.connections.add((self.inputNames[inputName], self.outputNames[outputName]))
    self.isConnected[self.inputNames[inputName]] = true

proc run*(self: var SynthNetwork) =
    # Clear all inputs that are connected so they can be summed into
    for i in 0..<self.inputs.len:
        if self.isConnected[i]:
            self.inputs[i] = 0.0

    # Sum all connections
    for (inputIndex, outputIndex) in self.connections:
        self.inputs[outputIndex] += self.outputs[inputIndex]
