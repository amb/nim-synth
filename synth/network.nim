import std/[tables]

type SynthNetwork* = object
    inputs: seq[float32]
    outputs: seq[float32]
    inputNames: Table[string, int]
    outputNames: Table[string, int]
    connections: seq[(int, int)]

proc synthConnectionsInit*(self: var SynthNetwork) =
    self.inputs = @[]
    self.outputs = @[]
    self.inputNames = initTable[string, int]()
    self.outputNames = initTable[string, int]()
    self.connections = @[]

proc addInput*(self: var SynthNetwork, input: float32, inputName: string) =
    self.inputs.add(input)
    self.inputNames[inputName] = self.inputs.len - 1

proc addOutput*(self: var SynthNetwork, output: float32, outputName: string) =
    self.outputs.add(output)
    self.outputNames[outputName] = self.outputs.len - 1

proc addConnection*(self: var SynthNetwork, inputName: string, outputName: string) =
    self.connections.add((self.inputNames[inputName], self.outputNames[outputName]))

proc run*(self: var SynthNetwork) =
    for i in 0..<self.outputs.len:
        self.outputs[i] = 0.0
    for (inputIndex, outputIndex) in self.connections:
        self.outputs[outputIndex] += self.inputs[inputIndex]
