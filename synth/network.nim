import std/[tables]

type NetworkDevice* = ref object
    id: int

type SynthNetwork* = ref object
    inputs: seq[float32]
    outputs: seq[float32]
    inputBase: seq[float32]
    inputNames: Table[string, int]
    outputNames: Table[string, int]

    connections: seq[(int, int)]
    isConnected: seq[bool]

    devices: seq[NetworkDevice]

# Interface for a device that can be added to a SynthNetwork
proc publish*(self: SynthNetwork, device: NetworkDevice) =
    echo "New empty device"

proc process*(osc: NetworkDevice, step: float32, inputs: openArray[float32]): float32 =
    result = 0.0

proc getInputPtr*(self: SynthNetwork, inputId: int): ptr float32 =
    result = addr self.inputs[inputId]

# Rest of the SynthNetwork implementation
proc synthConnectionsInit*(self: var SynthNetwork) =
    self.inputs = @[]
    self.outputs = @[]
    self.inputBase = @[]
    self.inputNames = initTable[string, int]()
    self.outputNames = initTable[string, int]()
    self.connections = @[]
    self.isConnected = @[]

proc addInput*(self: var SynthNetwork, input: float32, inputName: string): ptr float32 =
    self.inputs.add(input)
    self.inputBase.add(input)
    self.inputNames[inputName] = self.inputs.len - 1
    self.isConnected.add(false)
    result = addr self.inputs[self.inputs.len - 1]

proc addOutput*(self: var SynthNetwork, output: float32, outputName: string) =
    self.outputs.add(output)
    self.outputNames[outputName] = self.outputs.len - 1

proc addConnection*(self: var SynthNetwork, inputName: string, outputName: string) =
    self.connections.add((self.inputNames[inputName], self.outputNames[outputName]))
    self.isConnected[self.inputNames[inputName]] = true

proc addDevice*(self: var SynthNetwork, device: NetworkDevice) =
    self.publish(device)
    self.devices.add(device)
    self.devices[^1].id = self.devices.len - 1
    # self.devices[^1].nw = self

proc render*(self: var SynthNetwork): float32 =
    # Set all inputs to their initial values
    for i in 0..<self.inputs.len:
        self.inputs[i] = self.inputBase[i]

    # Sum all connections
    for (inputIndex, outputIndex) in self.connections:
        self.inputs[outputIndex] += self.outputs[inputIndex]

    for i in self.outputs:
        result += i
