
#Note: normally matrix multiplication is used with NNs, however the asymmetricality of NEAT cannot use it

var neurons = {} #dict of all cells
var axons = {} #dict of all axons

var layers = [] #array of arrays of neurons

var disabled = {}

class Cell:
	var id
	var from = [] #array of ids
	var to = []
	var layer = 0
	var value = 0
	var sum = 0
	
	func normalize():
		#value = myRelu(sum)
		value = leakyRelu(sum)
		#value = sum
		
	func leakyRelu(n):
		if n < 0:
			return n/1000
		else:
			return n
			
	func myRelu(n):
		var divisor = 1000
		if n < 0:
			return n/divisor
		elif n > 1:
			return (n-1)/divisor+1
		else:
			return n
			
	func duplicate():
		var n2 = get_script().new()
		n2.id = id
		n2.from = from.duplicate()
		n2.to = to.duplicate()
		n2.layer = layer
		return n2
	
class Axon:
	var id
	var from #id
	var to
	var weight = 0 setget weight
	func weight(w):
		weight = w
		if weight < -1:
			weight = -1
		elif weight > 1:
			weight = 1
		return w
		
	func incWeight(amount):
		weight(amount+weight)
		
	func duplicate():
		var a2 = get_script().new()
		a2.id = id
		a2.from = from
		a2.to = to
		a2.weight = weight
		return a2
		
func setAxonWeight(axon, weight): #note crossovers can still end with sole negative axons
	#TODO: uncertain of this codes efficiency
	if weight < 0: #if the to neuron has no positive in-weights, then make weight positive 
		weight *= -1 #turn positive
		for aid in neurons[axon.to].from:
			if aid == axon.id:
				continue
			var a = axons[aid]
			if a.weight > 0:
				weight *= -1 #stay negative
				break
	axon.weight(weight)

#Creates the neural net
func _init(inputAmount = 0, outputAmount = 0):
	layers = [[],[]]
	for i in range(inputAmount):
		var neuron = createNeuron(i, 0)
	for i in range(outputAmount):
		var neuron = createNeuron(inputAmount+i, 1)
		
	
func createNeuron(id = null, layer = 0):
	var cell = Cell.new()
	if id == null:
		cell.id = neurons.size()
	else:
		cell.id = id
	neurons[cell.id] = cell
	cell.layer = layer
	layers[layer].push_back(cell)
	return cell
	
func createAxon(from, to, weight = 0, id = null):
	var axon = Axon.new()
	if id == null:
		axon.id = axons.size()
	else:
		axon.id = id
	axons[axon.id] = axon
	axon.from = from
	axon.to = to
	neurons[from].to.push_back(axon.id)
	neurons[to].from.push_back(axon.id)
	setAxonWeight(axon, weight)
	return axon
	
func addAxon(axon):
	axons[axon.id] = axon
	neurons[axon.from].to.push_back(axon.id)
	neurons[axon.to].from.push_back(axon.id)
	return axon
	
func addNeuron(neuron):
	neurons[neuron.id] = neuron
	layers[neuron.layer].push_back(neuron)
	return neuron
		
#Feed inputs
func feed(inputValues):
	for i in range( min(inputValues.size(), layers[0].size()) ):
		layers[0][i].value = inputValues[i]
	for i in range(inputValues.size(), layers[0].size()):
		layers[0][i].value = 0
	return propagate()
	
#Propagate the network
func propagate():
	clearCalculated()
	calcForward()
	return outputs()
	
func calcForward():
	for l in layers:
		for n in l:
			if n.layer != 0:
				n.normalize()
			for axonid in n.to:
				var axon = axons[axonid]
				neurons[axon.to].sum += n.value * axon.weight
				
func clearCalculated():
	for i in range(1, layers.size()):
		for n in layers[i]:
			n.sum = 0
	
func outputs():
	var array = []
	for cell in layers[layers.size()-1]:
		array.push_back(cell.value)
	return array

func printValues(array):
	var string = "["
	for a in array:
		string += str(a.value) + " "
	string += "]"
	print(string)
	
func setLayerOfNeuron(neuron, layer):
	layers[neuron.layer].erase(neuron)
	layers[layer].push_back(neuron)
	neuron.layer = layer
		
func deleteAxon(axon):
	if axons.has(axon):
		#remove axon from neurons its connected to
		neurons[axon.from].to.erase(axon.id)
		neurons[axon.to].from.erase(axon.id)
		axons.erase(axon.id)
		disabled[axon.id] = axon

func toggleAxon(axon, b):
	if b == false:
		deleteAxon(axon)
	elif b == true and disabled.has(axon):
		#add axon to the neurons it was connected to
		neurons[axon.from].to.push_back(axon.id)
		neurons[axon.to].from.push_back(axon.id)
		disabled.erase(axon.id)
		axons[axon.id] = axon
	#axon.enabled = b
	
func duplicate():
	var clone = get_script().new()#inputs.size(), outputs.size())
	clone.layers = []
	for l in layers:
		clone.layers.push_back([])
	for n in neurons.values():
		var neuron = n.duplicate()
		clone.neurons[n.id] = neuron
		clone.layers[n.layer].push_back(neuron)
	for a in axons.values():
		clone.axons[a.id] = a.duplicate()
#	for a in disabled:
#		clone.disabled[a.id] = a.duplicate()
	return clone
