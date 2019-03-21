#Important adjustments
var population = 100 #100
var initialWeight = 1.2 #1.5#2 #mutate a weight in random between 0 - initialWeight
var weightAdjust = 0.05 #for mutateAllWeights
var manyWeightsPercentage = .05
var maxSpeciesDifference = 1.0 #smaller = more species
var geneDifMult = .83 #%genes that are different, 0-1
var weightDifMult = .83 #average weight dif, 0-2
#NEW STUFF TEST THIS
var disallowOffspringPercent = 0.5 #0.6= 60% cant reproduce. currently rank based
var minSpeciesSize = population / 10 #refuse to delete species if at/under this size
var transferStalenessToOffspring = false
var transferRecordFitnessToOffspring = false
var fitnessIsGenomesAverage = true #the fitness of a species will be the average, not the top genome
var fitnessIsRecord = false #false = fitness changes every gen, true = fitness is always the maximum
#Exponents
var speciesSizeExponent = 1#3
var weightExponent = 1 #allows for finer changes in weights, big = medium, small = very very tiny
var rankSelectionExponent = 1 #of genomes
var genomeSelectionExponent = 1 #too large means no variety
#Important toggles
var bestForgetsQueenWhenStale = true
var genomeRankSelection = true
var rankedSpecieSize = true
var speciesElitism = true #false = queen gets replaced every gen, true = queen only replaced when defeated
#Chance
var mutateAllWeightsChance = 65
var mutateWeightChance = 0
var mutateManyWeightsChance = 30
var mutateAxonChance = 4
var mutateNeuronChance = 1
var crossoverChance = 99*3
var copyAllCrossoverChance = 1*3
var crossoverWithinSpeciesChance = 99
var crossoverOutsideSpeciesChance = 1

#Useful sometimes
var minGenomeAmount = 1
var maxGenomeAmount = 0 #0 = off
#Somewhat important
var targetSpecieSize = 0.1 #percent
var targetShiftMult = 0 #subtle is good
#Less important
var checkHostFirst = false #false because we prefer to find the most similar without bias
var copyAxonsCrossover = true
var copyNeuronsCrossover = true
var adjustNeuronsCrossover = true
var sortToAnySpecies = true
#var speciesAveraging = false 
#Staleness
#var speciesEliminationPercent = 0.1 #currently depracated
var maxStaleness = 25 #*(1000/population*1)
#var dyingStaleness = maxStaleness/5 #5

#Necessary variables
var Genome = preload("Genome.gd")
var species = {}
var speciesCount = 0 #tracking ids
var axonDB = {} #Vector2(fromid,toid):axonid
var neuronDB = {} #axonid:neuronid
var inputDB = []
var outputDB = []
var startingFitness = 0
var bestSpecies
#Fancy variables
var generation = 1
var bestSpeciesAllTime
var bestSpeciesLastGen
var recordMutations = [0,0,0,0,0,0,0,0,0,0]
var recordMutationsFitness = [0,0,0,0,0,0,0,0,0,0]
var records = 0
var recordsGen = 0
var startingTime
var staledQueens = 0

class Specie:
	var id
	var fitness = 0 #determines choosing chance and genome size
	var recordFitness = 0 #for no elitism staleness
	var queen #checkpoint genome
	var lastGenQueen = 0
	var genomes = []
	var history = []
	var parent #species id
	var children = [] #species id
	var staleness = 0
	var fitnessHistory = [0,0,0,0]
	var fitnessAllTime = 0
	var fitnessLastGen = 0
	
	func selectQueen(fitnessIsRecord = true, elitism = true, fitnessIsGenomesAverage = false):
		#Find best genome
		var highFitness = -1000000
		var highGenome = queen
		if genomes.size() > 0:
			highGenome = genomes[0]
		for g in genomes: #bimp
			if g.fitness > highFitness:
				highFitness = g.fitness
				highGenome = g
		
		#Set the new queens
		lastGenQueen = highGenome
		if !elitism or highGenome.fitness > queen.fitness:
			queen = highGenome	
#		if average:
#			fitnessHistory.push_front(highFitness)
#			highFitness = averageFitness()
#			fitnessHistory.pop_back()
		#by default fitness is the top genome
		fitness = highGenome.fitness
		if fitnessIsGenomesAverage:
			fitness = genomesFitnessAverage()
		fitnessLastGen = fitness
		#see if a record was made
		if fitness > recordFitness: #mainly for !elitism
			recordFitness = fitness
			staleness = 0
			if recordFitness > fitnessAllTime: #debugging purposes
				fitnessAllTime = recordFitness
		#toggle if fitness is its own thing or the same as record
		if fitnessIsRecord:
			fitness = recordFitness
		return queen
		
	func genomesFitnessAverage():
		if genomes.size() == 0:
			return 0
		var totalFitness = 0
		for g in genomes:
			totalFitness += g.fitness
		return float(totalFitness)/genomes.size()
		
		
#	func averageFitness(extra = null):
#		var total = 0
#		for f in fitnessHistory:
#			total += f
#		if extra == null:
#			return total / fitnessHistory.size()
#		else:
#			return (total+extra) / (fitnessHistory.size()+1)
		
func _init():
	randomize()
	
#Creates 1 species with the entire genome population, each with a random axon with a weight of 1
func create(inputs, outputs):
	print("Creating NEAT...")
	#Creates a new species with a queen, then adds the queen to genomes
	var s = createSpecies(newGenome(inputs, outputs))
	s.genomes.push_back(s.queen)
	s.queen.fitness = startingFitness
	for i in range(population):
		var genome = newGenome(inputs, outputs)
		genome.fitness = startingFitness
		sortGenomeToSpecies(genome, s)
	bestSpecies = s
	bestSpeciesAllTime = s
	bestSpeciesLastGen = s
	#update inputdb and outputdb
	var nn = s.queen.neuralNet
	for i in range(nn.layers[0].size()):
		inputDB.append(nn.layers[0][i].id)
	for i in range(nn.layers[1].size()):
		outputDB.append(nn.layers[1][i].id)
	startingTime = OS.get_datetime()
	
func addInputAmount(amount):
	for i in range(amount):
		inputDB.append(totalNeurons())
func totalNeurons():
	return inputDB.size() + outputDB.size() + neuronDB.size()
	
func newGenome(inputs, outputs):
	var genome = Genome.new(self, inputs, outputs)
	while genome.mutateAxon(axonDB, genome.calcWeight(1,weightExponent,initialWeight)) == null:
		pass
	genome.lastMutation = 0
	return genome
	
func endGeneration():
	var recordFitness = bestSpeciesAllTime.recordFitness
	var bestFitness = bestSpecies.fitness
	#Select queens
	for s in species.values():
		s.staleness += 1
		s.selectQueen(fitnessIsRecord, speciesElitism, fitnessIsGenomesAverage)
	selectBestSpecies()
	print(" ")
	#If we made a new record
	if !checkRecord(bestSpeciesAllTime.recordFitness-recordFitness, bestSpeciesAllTime.queen.lastMutation, "NEW! RECORD +"):
		checkRecord(bestSpecies.fitness-bestFitness, bestSpecies.queen.lastMutation, "Sub RECORD +")
	printCurrentResults()
	
func checkRecord(fitnessDifference, mutation, string = null):
	if fitnessDifference > 0:
		if string != null:
			print(string + str(fitnessDifference)) #bugged
		recordMutations[mutation-1] += 1
		recordMutationsFitness[mutation-1] += fitnessDifference
		records += 1
		recordsGen = generation
		return true
	return false
	
	
func printCurrentResults():
	#Find total genome count (for results)
	var averageFitness = 0
	var averageQueenFitness = 0
	var actualPopulation = 0
	for s in species.values():
		actualPopulation += s.genomes.size()
		averageQueenFitness += s.queen.fitness
		for g in s.genomes:
			averageFitness += g.fitness
	averageFitness /= actualPopulation
	averageQueenFitness /= species.size()	
	var mutationStrings = []
	for i in range(recordMutations.size()):
		mutationStrings.append(mutationString(i))
	mutationStrings.pop_back()
			
	print("GEN:" + str(generation)+ " Species:" + str(species.size())+" Pop:"+str(actualPopulation)+"/"+str(population)+" AvgSize:" + str(population/species.size())+" R:"+str(records)+":"+str(recordsGen)+"                     MaxDif:"+str(maxSpeciesDifference)+" Unique-axons:" + str(axonDB.size())+ " Unique-neurons:" + str(neuronDB.size()))
	print("Average-fitness: Genomes:%s Queens:%s"%[round(averageFitness), round(averageQueenFitness)] + "  Staled-queens:%s"%[staledQueens])
	printSpeciesResults(bestSpeciesLastGen, bestSpeciesLastGen.lastGenQueen, "Last Gen:", bestSpeciesLastGen.fitnessLastGen)
	printSpeciesResults(bestSpecies, bestSpecies.queen, "Cur Best:", bestSpecies.recordFitness)
	printSpeciesResults(bestSpeciesAllTime, bestSpeciesAllTime.queen, "All Time:", bestSpeciesAllTime.fitnessAllTime)
	print("M: All:%s One:%s Many:%s Axon:%s Neuron:%s InWgt:%s InAll:%s OutWgt:%s OutAll:%s"%mutationStrings)
	print(timeToString(timePassed(startingTime)))
func printSpeciesResults(specie, queen, startStr, fitness):
	print(startStr+" S#:" + str(specie.id)+" Size:" + str(specie.genomes.size())+" Fitness:" + str(fitness)+" Stale:" + str(specie.staleness)+"/"+str(maxStaleness)+"     M:"+queen.lastMutationStr()+" Axons:" + str(queen.neuralNet.axons.size())+" Neurons:" + str(queen.neuralNet.neurons.size()-(queen.neuralNet.layers[0].size()+queen.neuralNet.layers[queen.neuralNet.layers.size()-1].size()))+" Depth:" + str(queen.neuralNet.layers.size()-2)+" Children:" + str(specie.children.size())+" Parent#:" + str(specie.parent))
func mutationString(mutation):
	var one = recordMutationsFitness[mutation]
	var two = recordMutations[mutation]
	return "%s/%s=%s" % [round(one), two, round(one/(two+0.0001))]
	
func selectBestSpecies():
	#Record best species (based on fitnesses)
	bestSpecies = species.values()[0] #bestSpecies.queen
	for s in species.values():
		if s.recordFitness > bestSpecies.recordFitness:
			bestSpecies = s
	#Record best species (based on record fitnesses)
	if bestSpecies.recordFitness > bestSpeciesAllTime.fitnessAllTime:
		bestSpeciesAllTime = bestSpecies
	#Record best species (based on last gens fitnesses)
	bestSpeciesLastGen = species.values()[0] #WIPPPPPPPPPPPP
	for s in species.values():
		if s.fitnessLastGen > bestSpeciesLastGen.fitnessLastGen:
			bestSpeciesLastGen = s
	return bestSpecies
#
#func setInputAmount(amount):
#
	
func nextGeneration():
	generation += 1
	deleteStaleSpecies()
	#return null if all species have been eliminated
	if species.size() == 0:
		return -1
	#swap genomes to history
	makeHistory()
	#create new genomes
	generateNextGeneration()
	#Try to keep species' size constant
	var dif = (float(species.size())/population -targetSpecieSize)
	#only decrease if negative
	if dif < 0:
		#maxSpeciesDifference += dif*targetShiftMult
		maxSpeciesDifference *= dif/10*targetShiftMult+1
		
func deleteStaleSpecies():
	var speciesValues = species.values()
	#if we care about keeping a min size, then we need to only delete the worst species, and so we sort them
	if minSpeciesSize != 0 and minSpeciesSize != 1: 
		quickSort(speciesValues, funcref(self,"sortByFitness"))
	#if we have more than one species
	if maxSpeciesDifference != 0:
		for s in speciesValues:#.duplicate(): #IMP kinda hacky dont you think
			if s.staleness >= maxStaleness: #or (s.staleness == dyingStaleness and s.fitness / totalFitness <= speciesEliminationPercent):
				#if !(species.size() != 1 and s == bestSpecies):
				if s != bestSpecies:
					if species.size() > minSpeciesSize: #if we dont care about the size####################WIPWIP############WIPWIP#######WIPWIP
						species.erase(s.id)
							
							
				elif bestForgetsQueenWhenStale: #if best species
					bestSpecies.queen = bestSpecies.lastGenQueen
					bestSpecies.fitness = bestSpecies.queen.fitness
					bestSpecies.recordFitness = bestSpecies.queen.fitness
					bestSpecies.staleness = 0
					selectBestSpecies()
					staledQueens += 1

func makeHistory():
	for s in species.values():
		s.history = s.genomes
		s.history.push_back(s.queen) #imp theres a possibility that push_front is better. small but leaving this here anyway
		s.genomes = []
		#Sort for ranked selection
		if genomeRankSelection:
			quickSort(s.history, funcref(self,"sortByFitness"))

func generateNextGeneration():
	var speciesValues = species.values()
	quickSort(speciesValues, funcref(self,"sortByFitness"))
	#Determine the total culmination of values for the size
	var totalSizingValue = 0
	if rankedSpecieSize:
		for i in range(speciesValues.size()):
			totalSizingValue += pow(i+1, speciesSizeExponent)
#		quickSort(speciesValues, funcref(self,"sortByFitness")) WHY WAS THIS HERE??
	else:
		totalSizingValue = totalFitness(speciesValues, speciesSizeExponent) #used for size
	#Create new genomes for every specie
	for s in speciesValues.duplicate(): 
		var totalGenomeFitness = totalFitness(s.history) #used for genome selection
		#How many new genomes
		var sizingValue
		if rankedSpecieSize:
			sizingValue = speciesValues.find(s)+1 #THIS MIGHT BE TOO SLOW WIP
		else:
			sizingValue = s.fitness+1
			
		var newGenomeAmount = population * pow(sizingValue,speciesSizeExponent)/totalSizingValue
		if newGenomeAmount < minGenomeAmount:
			newGenomeAmount = minGenomeAmount
		elif maxGenomeAmount != 0 and newGenomeAmount > maxGenomeAmount:
			newGenomeAmount = maxGenomeAmount
		#Create new genomes
		for i in range(newGenomeAmount):
			#Pick random genome
			var g = pickSemiRandomGenome(s.history, totalGenomeFitness)
			var newGenome = g.duplicate()
			#increase input amount
			for i in range(g.neuralNet.layers[0].size(), inputDB.size()):
				g.neuralNet.createNeuron(inputDB[i],0)
			#Reset fitness
			newGenome.fitness = startingFitness
			
			alterGenome(newGenome, s, speciesValues)
			sortGenomeToSpecies(newGenome, s, speciesValues, checkHostFirst)
func alterGenome(newGenome, s, speciesValues):
	#Mutate or crossover
	var rand = randi()%totalChance()
	if rand < mutateChance():
		mutate(newGenome)
	else:
		var success = false
		for j in range(3):
			var s2 = s
			#Determine if crossing within or outside species
			if randi()%(crossoverWithinSpeciesChance+crossoverOutsideSpeciesChance) < crossoverOutsideSpeciesChance:
				s2 = pickSemiRandomGenome(speciesValues, totalFitness(speciesValues, genomeSelectionExponent), genomeSelectionExponent)
			var g2 = pickSemiRandomGenome(s2.history, null, genomeSelectionExponent)
			if newGenome != g2:
				var crossover
				#Regular crossover
				if rand < mutateChance()+crossoverChance:
					crossover = crossover(newGenome, g2)
				#Copyall crossover
				else:
					crossover = crossover(newGenome, g2, copyAxonsCrossover, copyNeuronsCrossover, adjustNeuronsCrossover)
				if crossover != null:
					success = true
					if s2 != s:
						newGenome.lastMutation += 2
					break
		#Mutate genomes whose crossover was unsuccessful
		if not success:
			mutate(newGenome)
			#print("Failed to find crossover")
func sortGenomeToSpecies(newGenome, s, speciesValues = species.values(), checkHostFirst = false):
	var hostSpecie = s
	if maxSpeciesDifference == 0:
		hostSpecie = species.values()[0]
	#Determine if genome belongs with it's host species
	elif !checkHostFirst or compare(newGenome, s.queen) > maxSpeciesDifference:
		var hostFound = false
		if sortToAnySpecies:# or !checkHostFirst: #wip not sure
			#Compare with all queens and find the most similar one
			var difference = maxSpeciesDifference
			for s2 in species.values():
				if !checkHostFirst or s != s2: #entire line is redundant but maybe adds some speed maybe
					var comparison = compare(newGenome, s2.queen)
					if comparison < difference:
						difference = comparison
						hostSpecie = s2
						hostFound = true
		else:
			#Check if any children are compatible hosts
			for child in s.children:
				if species.has(child) and compare(newGenome, species[child].queen) <= maxSpeciesDifference:
					hostSpecie = species[child]
					hostFound = true
					break
		#if no host is found create a new species
		if hostFound == false:
			#only create new species if the original was successful enough (using speciesvalues because its sorted)
			var percentile = float(speciesValues.find(s)+1) / speciesValues.size() # >0 to 1
			if percentile > disallowOffspringPercent: #if successful fitness
				hostSpecie = createSpecies(newGenome, s.id)
				if transferStalenessToOffspring:
					hostSpecie.staleness = s.staleness
				if transferRecordFitnessToOffspring:
					hostSpecie.recordFitness = s.recordFitness
			else: #if unsuccessful fitness, leave it in the original
				hostSpecie = s
	#add new genome to its species
	hostSpecie.genomes.push_back(newGenome)
			
func createSpecies(queen = null, parent = null):
	var s = Specie.new()
	s.id = speciesCount
	speciesCount += 1
	if queen != null:
		s.queen = queen
		s.lastGenQueen = queen
	if parent != null:
		s.parent = parent
		species[parent].children.push_back(s.id)
	species[s.id] = s
	return s
					
func pickSemiRandomGenome(genomes, totalGenomeFitness = null, fExponent = genomeSelectionExponent, rExponent = rankSelectionExponent):
	#Fitness selection
	if genomeRankSelection == false:
		if totalGenomeFitness == null:
			totalGenomeFitness = totalFitness(genomes, fExponent)
		var rand = randi()%int(totalGenomeFitness)
		var runningFitnessTotal = 0
		for g in genomes:
			runningFitnessTotal += pow(g.fitness, fExponent)+1
			if rand < runningFitnessTotal:
				return g
	#Rank selection
	elif genomeRankSelection == true:
		var totalRank = 0
		for i in range(genomes.size()):
			totalRank += pow(i+1, rExponent)
		var rand = randi()%int(totalRank)
		var runningRankTotal = 0
		for i in range(genomes.size()):
			runningRankTotal += pow(i+1, rExponent)
			if rand < runningRankTotal:
				return genomes[i]
	
func totalFitness(array, exponent = 1):
	var totalFitness = 0 #FIX FOR 0 FITNESS
	for s in array:
		totalFitness += pow(s.fitness, exponent)+1
	return totalFitness
	
		
#Selects a random mutation on the genome
func mutate(genome):
	var total = mutateChance()
	var rand = randi()%total
	if rand < mutateAllWeightsChance:
		genome.mutateAllWeights(weightAdjust, weightExponent) #consider doing percentages (at the cost of switching between positive and negative)
	else:
		var randWeight = genome.calcWeight(1, weightExponent, initialWeight)
		if rand < mutateAxonChance + mutateAllWeightsChance:
			if null == genome.mutateAxon(axonDB, randWeight):#int(randi()%2*2-1))#, rand_range(-initialWeight, initialWeight))
				genome.mutateWeight(true, randWeight)
		elif rand < mutateNeuronChance + mutateAxonChance + mutateAllWeightsChance:
			genome.mutateNeuron(axonDB, neuronDB, randWeight)#int(randi()%2*2-1))#rand_range(-initialWeight, initialWeight))
		elif rand < mutateWeightChance + mutateNeuronChance + mutateAxonChance + mutateAllWeightsChance:
			genome.mutateWeight(true, randWeight)
		else: #mutateManyWeightsChance
			genome.mutateManyWeights(true, manyWeightsPercentage, 1, weightExponent, initialWeight)
		
func totalChance():
	return mutateChance() + crossoverChance()
func mutateChance():
	return mutateWeightChance + mutateNeuronChance + mutateAxonChance + mutateAllWeightsChance + mutateManyWeightsChance
func crossoverChance():
	return crossoverChance + copyAllCrossoverChance
	
#Copies half of shared weights from g2 into g1 (modifies g1 directly)
func crossover(g1, g2, copyAxons = false, copyNeurons = false, adjustNeurons = false):
	var genes = findSharedGenes(g2.neuralNet.axons, g1.neuralNet.axons)
	var sharedAxons = genes[0]
	var success = false
	#Randomly use weights from either genomes shared axons
	for a in sharedAxons:
		if randi()%2 == 0:
			g1.neuralNet.axons[a].weight = g2.neuralNet.axons[a].weight
			success = true
	if copyAxons:
		if copyNeurons:
			var exclusiveNeurons = findSharedGenes(g2.neuralNet.neurons, g1.neuralNet.neurons)[1]
			if exclusiveNeurons.size() != 0:
				success = true
				#Store new neurons
				var newNeurons = []
				for nid in exclusiveNeurons:
					var neuron = g2.neuralNet.neurons[nid].duplicate()
					neuron.to = []
					neuron.from = []
					newNeurons.push_back(neuron)
#					g1.neuralNet.addNeuron(neuron)
				#Adjust neurons
				if adjustNeurons:
					#sort new neurons by layer
					var values = []
					for n in newNeurons: 
						values.push_back(n)
					quickSort(newNeurons, funcref(self,"sortByLayer"))
					#from low layer to high, find highest from layer, and become it+1
					for n in newNeurons:
						for axonid in g2.neuralNet.neurons[n.id].from:
							var axon = g2.neuralNet.axons[axonid]
							var fromNeuron
							if g1.neuralNet.neurons.has(axon.from):
								fromNeuron = g1.neuralNet.neurons[axon.from]
							#if g1 doesnt have the neuron then we need to find it in the new neurons
							else:
								for n2 in newNeurons:
									if n2.id == axon.from:
										fromNeuron = n2
										break
							if fromNeuron.layer >= n.layer:
								n.layer = fromNeuron.layer+1
#								g1.neuralNet.setLayerOfNeuron(n, fromNeuron.layer+1)
					#find highest layer
#					var highestLayer = g1.neuralNet.layerCount-1
#					for n in neurons:
#						var neuron = g1.neuralNet.neurons[n]
#						if neuron.layer > highestLayer:
#							highestLayer = neuron.layer
#					g1.neuralNet.updateLayerCount(highestLayer)

				#After sufficient calculations, we can add the neuron
				for n in newNeurons:
					#Make sure outputs are at a high enough layer
					var diff = n.layer -(g1.neuralNet.layers.size()-1)
					if diff >= 0:
						for i in range(diff+1): #WIP IF WE DO THIS MANUALLY IT WONT BE AS EXPENSIVE
							g1.pushOutputs()
					g1.neuralNet.addNeuron(n)
				
		#Copy axons
		if genes[1].size() != 0:
			success = true
			#copy axons, checking if the layers match. no pushing is done
			for axonid in genes[1]:
				var g2axon = g2.neuralNet.axons[axonid]
				if g1.neuralNet.neurons.has(g2axon.from) and g1.neuralNet.neurons.has(g2axon.to):
					var fromNeuron = g1.neuralNet.neurons[g2axon.from]
					var toNeuron = g1.neuralNet.neurons[g2axon.to]
					if fromNeuron.layer < toNeuron.layer:
						g1.neuralNet.addAxon(g2axon.duplicate())
					else:
						#consider not doing this
						if fromNeuron.layer == toNeuron.layer:
							g1.neuralNet.addAxon(g2axon.duplicate())
							g1.pushLayersFrom(toNeuron)
		
	#if nothing was changed
	if not success:
		return null
	if copyAxons == false:
		g1.lastMutation = 6
	else:
		g1.lastMutation = 7
	return g1

func quickSort(array, sortFunc = funcref(self,"sortBySelf"), sortTheseToo = [], from = 0, to = array.size()-1):
	if to-from <= 0:
		return
	var pivot = to
	var low = to-1
	var high = from
	while true:
		#low needs to find a number lower than pivot
		while !sortFunc.call_func(array[pivot], array[low]) and low != -1:
			low -= 1
		#high needs to find a number higher than pivot
		while !sortFunc.call_func(array[high], array[pivot]) and high != pivot:
			high += 1
		if high > low: #if we are done
			swapArrayPositions(array, high, pivot)
			for array2 in sortTheseToo:
				swapArrayPositions(array2, from, to)
			quickSort(array, sortFunc, sortTheseToo, from, high-1)
			quickSort(array, sortFunc, sortTheseToo, high+1, to)
			return
		else:
			swapArrayPositions(array, low, high)
			for array2 in sortTheseToo:
				swapArrayPositions(array2, from, to)
			low -= 1
			high += 1
func sortBySelf(a, b):
	if a > b:
		return true
	return false
func sortByFitness(a, b):
	if a.fitness > b.fitness:
		return true
	return false
func sortByLayer(a, b):
	if a.layer > b.layer:
		return true
	return false
func swapArrayPositions(array, pos1, pos2):
	var temp = array[pos1]
	array[pos1] = array[pos2]
	array[pos2] = temp
	

#Returns a percentage of compatibility (genome1 should be more fit)
func compare(g1, g2):
	var axons1 = g1.neuralNet.axons
	var axons2 = g2.neuralNet.axons
	#var genes = findAllGenes(g1, g2)
	var genes = findSharedGenes(axons1, axons2)
	genes.push_back(findSharedGenes(axons2, axons1)[1])
	var totalGenes = genes[0].size() + genes[1].size() + genes[2].size() #THE PAPER SAYS TOTAL GENES OF THE MORE FIT GENOME, NOT BOTH
	var geneDifference = 1 - (genes[0].size()/totalGenes) #eg: 7/25
	var weightDifference = 0
	if genes[0].size() != 0:
		for i in genes[0]:
			weightDifference += abs(axons1[i].weight - axons2[i].weight)
		weightDifference /= genes[0].size()
	return geneDifference*geneDifMult + weightDifference*weightDifMult
	
#includes disabled (run in reverse for both exclusives)
func findSharedGenes(genes1, genes2):
	var shared = []
	var g1exclusive = []
	for id in genes1:
		if genes2.has(id):# or g2.neuralNet.disabled.has(axon.id):
			shared.push_back(id)
		else:
			g1exclusive.push_back(id)
#	for axon in g1.neuralNet.disabled:
#		if g2.neuralNet.disabled.has(axon.id) or g2.neuralNet.axons.has(axon.id):
#			shared.push_back(axon.id)
#		else:
#			g1exclusive.push_back(axon.id)
	return [shared, g1exclusive]
	
#excludes disabled, requires genes to be ordered by id (NEEDS TO BE DONE REQUIRES COMPUTATION)
func findAllGenes(g1, g2):
	var shared = []
	var g1exclusive = []
	var g2exclusive = []
	var i1 = 0
	var i2 = 0
	var axons1 = g1.neuralNet.axons.values()
	var axons2 = g2.neuralNet.axons.values()
	while(true):
		#Sort genes into arrays
		if axons1[i1].id == axons2[i2].id:
			shared.push_back(axons1[i1].id)
			i1 += 1
			i2 += 1
		elif axons1[i1].id < axons2[i2].id:
			g1exclusive.push_back(axons1[i1].id)
			i1 += 1
		else:
			g2exclusive.push_back(axons2[i2].id)
			i2 += 1
		#Prevent out of bounds
		if axons1.size() == i1:
			while(axons2.size() != i2):
				g2exclusive.push_back(axons2[i2].id)
				i2 += 1
			break
		elif axons2.size() == i2:
			while(axons1.size() != i1):
				g1exclusive.push_back(axons1[i1].id)
				i1 += 1
			break
	return [shared, g1exclusive, g2exclusive]
	
func timePassed(startTime, endTime = OS.get_datetime()):
	var secondsPassed = secondsPassed(startTime, endTime)
	var seconds = secondsPassed%60
	var minutes = int(secondsPassed/60)%60
	var hours = int(secondsPassed/(60*60))%24
	var days = int(secondsPassed/(60*60*24))
	return {"day":days, "hour":hours, "minute":minutes, "second":seconds}
	
func secondsPassed(startTime, endTime = OS.get_datetime()):
	var startSeconds = startTime["day"]*24*60*60 + startTime["hour"]*60*60 + startTime["minute"]*60 + startTime["second"]
	var endSeconds = endTime["day"]*24*60*60 + endTime["hour"]*60*60 + endTime["minute"]*60 + endTime["second"]
	return endSeconds - startSeconds
	
func timeToString(time):
	var string = ""
	if time["day"] != 0:
		string += "Day:%s "%[time["day"]]
	if time["hour"] != 0:
		string += "Hour:%s "%[time["hour"]]
	if time["minute"] != 0:
		string += "Min:%s "%[time["minute"]]
	string += "Sec:%s "%[time["second"]]
	return string
	
	
	
	
	
	
	