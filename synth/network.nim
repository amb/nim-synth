import std/[tables]

type SynthNetwork* = ref object
    inputs: seq[float32]
    outputs: seq[float32]
    inputBase: seq[float32]
    outputBase: seq[float32]
    inputNames: Table[string, int]
    outputNames: Table[string, int]

    connections: seq[(int, int)]
    isConnected: seq[bool]
    # isActive: seq[bool]

proc synthConnectionsInit*(self: var SynthNetwork) =
    self.inputs = @[]
    self.outputs = @[]
    self.inputBase = @[]
    self.outputBase = @[]
    self.inputNames = initTable[string, int]()
    self.outputNames = initTable[string, int]()
    self.connections = @[]
    self.isConnected = @[]

proc addInput*(self: var SynthNetwork, input: float32, inputName: string) =
    self.inputs.add(input)
    self.inputBase.add(input)
    self.inputNames[inputName] = self.inputs.len - 1
    self.isConnected.add(false)

proc addOutput*(self: var SynthNetwork, output: float32, outputName: string) =
    self.outputs.add(output)
    self.outputBase.add(output)
    self.outputNames[outputName] = self.outputs.len - 1

proc addConnection*(self: var SynthNetwork, inputName: string, outputName: string) =
    self.connections.add((self.inputNames[inputName], self.outputNames[outputName]))
    self.isConnected[self.inputNames[inputName]] = true

proc render*(self: var SynthNetwork): float32 =
    # Set all inputs to their initial values
    for i in 0..<self.inputs.len:
        self.inputs[i] = self.inputBase[i]

    # Sum all connections
    for (inputIndex, outputIndex) in self.connections:
        self.inputs[outputIndex] += self.outputs[inputIndex]

    for i in outputs:
        result += i
