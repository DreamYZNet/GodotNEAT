var fitness = 0
var neuralNet 

var lastMutation = 0#keep track of what kind of mutations are successful (1:all 2:one 3:axon 4:neuron 5:crossover)

var neat #sacrifices must be made

func _init(neat, inputs = 0, outputs = 0):
	neuralNet = preload("NeuralNet.gd").new(inputs, outputs)
	self.neat = neat
	if self.neat == null:
		print("init neat: " + str(neat))

func lastMutationStr():
	match(lastMutation):
		0:
			return "None"
		1:
			return "1-All"
		2:
			return "2-One"
		3:
			return "3-Many"
		4:
			return "4-Axon"
		5:
			return "5-Neuron"
		6:
			return "6-InWgh"
		7:
			return "7-InAll"
		8:
			return "8-OutWgh"
		9:
			return "9-OutAll"
			
func calcWeight(weight = 1, exponent = 1, value = 1):
	return weight * pow(rand_range(0,value), exponent) * (randi()%2*2-1) #this last bit randomizes if its negative
	
func mutateAllWeights(weight = 1, exponent = 1, value = 1):
	for axon in neuralNet.axons.values():
#		axon.incWeight( calcWeight(weight,exponent,value) ) #dont delete im unsure of this. instead we could norm it afterwards
		neuralNet.setAxonWeight(axon, axon.weight + calcWeight(weight,exponent,value))
	lastMutation = 1
		
func mutateWeight(set = true, weight = 1, axon = null):
	if axon == null:
		#pick random axon
		axon = neuralNet.axons.values()[randi()%neuralNet.axons.size()]
	if set:
		neuralNet.setAxonWeight(axon, weight)
	else:
		neuralNet.setAxonWeight(axon, axon.weight + weight)
	lastMutation = 2
			
func mutateManyWeights(set = true, percentage = 0.1, weight = 1, exponent = 1, value = 1):
	var count = 0
	for axon in neuralNet.axons.values():
		if randf() <= percentage:
			count += 1
			mutateWeight(set, calcWeight(weight,exponent,value), axon)
	#if we failed to change any weights
	if count == 0:
		mutateWeight(set, calcWeight(weight,exponent,value))
	lastMutation = 3
		
#Creates a new axon between 2 random neurons
func mutateAxon(axonDB, weight = 1, n1 = null):
	#if n1 wasn't given, we enable refinding n1
	var refind = n1 == null
	var size = neuralNet.neurons.size()
	#Determine the second neuron
	for i in range(1000):#allows timeout
	#allow the starting neuron to be chosen
		if n1 == null or refind:
			n1 = neuralNet.neurons.values()[randi()%size]
		var n2 = neuralNet.neurons.values()[randi()%size]
		var axon = createAxon(n1, n2, weight, axonDB)
		if axon != null:
			lastMutation = 4
			return axon
	#print("MUTATE AXON TIMEOUT refind:" + str(refind))
	return null
			
#Split a random axon with a new neuron
func mutateNeuron(axonDB, neuronDB, weight = 1):
	for i in range(100):#allows timeout
		#pick random axon
		var axon = neuralNet.axons.values()[randi()%neuralNet.axons.size()]
		#create neuron
		var from = neuralNet.neurons[axon.from]
		var to = neuralNet.neurons[axon.to]
		var neuron = createNeuron(axon.id, neuronDB, from.layer)
		if neuron != null:
			#add axon first so it will push the layers
			var a2 = createAxon(neuron, to, axon.weight, axonDB)
			#Push the layer forward and any others if needed
			pushLayersFrom(neuron)
			#add from axon
			var a1 = createAxon(from, neuron, 1, axonDB)
			#Delete the split axon
			neuralNet.deleteAxon(axon)
			#The new neuron by itself is meaningless so we give it the complexity it deserves (WIP consider adding bias instead)
			mutateAxon(axonDB, weight, neuron)
			lastMutation = 5
			return neuron
	print("MUTATE NEURON TIMEOUT")
	return null
	
func createAxon(n1, n2, weight, axonDB):
	#ensure the layers are different
	if n1.layer != n2.layer:
		#make a vector in the correct direction
		var vector = Vector2(n1.id, n2.id)
		if n1.layer > n2.layer:
			vector = Vector2(vector.y, vector.x)
		var id = null
		if axonDB.has(vector):
			#fetch id from database
			id = axonDB[vector]
			#ensure network doesn't already contain the axon
			if neuralNet.axons.has(id):
				return null
			#disallow disabled axons from reappearing (disable this code if desired)
				if neuralNet.disabled.has(id):
					return null
		else:
			#add new id to database
			id = axonDB.size()
			axonDB[vector] = id
		return neuralNet.createAxon(int(vector.x), int(vector.y), weight, id)
	
func createNeuron(axonid, neuronDB, layer = 0):
	var id = null
	if neuronDB.has(axonid):
		#fetch id from database
		id = neuronDB[axonid]
		#ensure network doesn't already contain the neuron
		if neuralNet.neurons.has(id):
			return null #you could replace this with a way to generate a new id instead
	else:
		#add new id to database
		id = neat.totalNeurons()#neuronDB.size() + neuralNet.layers[0].size() + neuralNet.layers[neuralNet.layers.size()-1].size() 
		neuronDB[axonid] = id
	return neuralNet.createNeuron(id, layer)
	
func pushLayersFrom(neuron, keepGoing = false):
	if neuron.to.size() != 0: #if we are dealing with outputs
		for axonid in neuron.to:
			var next = neuralNet.neurons[neuralNet.axons[axonid].to]
			if neuron.layer+1 == next.layer:
				pushLayersFrom(next)
			elif keepGoing:
				pushLayersFrom(next)
		neuralNet.setLayerOfNeuron(neuron, neuron.layer+1)
	else:
		pushOutputs()
		
func pushOutputs():
	var size = neuralNet.layers.size()
	var outputLayer = neuralNet.layers[size-1]
	neuralNet.layers.push_back(outputLayer)
	neuralNet.layers[size-1] = []
	for n in neuralNet.layers[size]:
		n.layer = size
			
func correctLayers():
	for input in neuralNet.inputs:
		pushLayerR(neuralNet.neurons[input], true)
	neuralNet.updateLayerCount()
	
func duplicate():
	var clone = get_script().new(neat)
	clone.fitness = fitness
	clone.neuralNet = neuralNet.duplicate()
	clone.lastMutation = lastMutation
	if clone.neat == null:
		print("clone neat: " + str(clone.neat))
	return clone