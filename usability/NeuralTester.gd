extends Node

var NEATGD = preload("NEAT.gd")
var neat = NEATGD.new()

var trainingOutputs = [[1,0,0,0,0,0,0,0,0],[0,1,0,0,0,0,0,0,0],[0,0,1,0,0,0,0,0,0],[0,0,0,1,0,0,0,0,0],[0,0,0,0,1,0,0,0,0],[0,0,0,0,0,1,0,0,0],[0,0,0,0,0,0,1,0,0],[0,0,0,0,0,0,0,1,0],[0,0,0,0,0,0,0,0,1]]
var trainingInputs = [[1,0,0,0],[0,1,0,0],[1,1,0,0],[0,0,1,0],[1,0,1,0],[0,1,1,0],[1,1,1,0],[0,0,0,1],[1,0,0,1]]
#var trainingInputs = [[1,0,0,0,0,0,0,0,0],[0,1,0,0,0,0,0,0,0],[0,0,1,0,0,0,0,0,0],[0,0,0,1,0,0,0,0,0],[0,0,0,0,1,0,0,0,0],[0,0,0,0,0,1,0,0,0],[0,0,0,0,0,0,1,0,0],[0,0,0,0,0,0,0,1,0],[0,0,0,0,0,0,0,0,1]]
#var trainingOutputs = [[1,0,0,0],[0,1,0,0],[1,1,0,0],[0,0,1,0],[1,0,1,0],[0,1,1,0],[1,1,1,0],[0,0,0,1],[1,0,0,1]]
var generations = 100000
var secondsToTermination = 6000000

func _ready():
	var time = OS.get_time()
	neat.create(trainingInputs[0].size(), trainingOutputs[0].size())
	generations /= neat.population
	neat.maxStaleness = 25
		
	while(secondsPassed(time) < secondsToTermination):
		for s in neat.species.values():
			for g in s.genomes:
				
				var fitness = 0
				#test the networks
				for i in range(trainingInputs.size()):
					var output = g.neuralNet.feed(trainingInputs[i])
					if output.size() == 0:
						print("testing start")
						for l in g.neuralNet.layers:
							print(l)
						print("end")
					fitness += compare(output, trainingOutputs[i])
				g.fitness = fitness
				
		neat.endGeneration()
		print("%s/%s seconds passed"%[secondsPassed(time), secondsToTermination])
		if neat.nextGeneration() == -1:
			break
			
	#test the networks
	var best = neat.bestSpeciesAllTime.queen		
	for axon in best.neuralNet.axons.values():
		print(str(axon.id) +": w:"+ str(axon.weight) + " f:" + str(axon.from) +" t:"+ str(axon.to))
	for i in range(trainingInputs.size()):
		var output = best.neuralNet.feed(trainingInputs[i])
		print(str(i+1)+": "+str(compare(output, trainingOutputs[i])))#+":"+array2str(trainingInputs[i]))
		print("result:"+formatArray(output))
		print("actual:"+formatArray(trainingOutputs[i]))
	print("Final fitness:%s"%best.fitness)
	print("Mutations: "+array2str(neat.recordMutations))
	get_node("NNDrawer").create(best.neuralNet)

func compare(output, expected):
	var total = 0
	for i in range(output.size()):
		total += abs(output[i]-expected[i])
	#return output.size()-total
	total/output.size()
	total += 1
	return (10000/trainingOutputs.size())/total
	
func array2str(array):
	var string = "[%s" % array[0]
	for i in range(1, array.size()):
		string += ",%s" % array[i]
	string += "]"
	return string
	
func formatArray(array):
	var string = "[%5.2f" % array[0]
	for i in range(1, array.size()):
		string += ",%5.2f" % array[i]
	string += " ]"
	return string
	
func timePassed(startTime, endTime = OS.get_time()):
	var secondsPassed = secondsPassed(startTime, endTime)
	var seconds = secondsPassed%60
	var minutes = int(secondsPassed/60)%60
	var hours = int(secondsPassed/(60*60))
	return {"hour":hours, "minute":minutes, "second":seconds}
	
func secondsPassed(startTime, endTime = OS.get_time()):
	var startSeconds = startTime["hour"]*60*60 + startTime["minute"]*60 + startTime["second"]
	var endSeconds = endTime["hour"]*60*60 + endTime["minute"]*60 + endTime["second"]
	return endSeconds - startSeconds
	
	