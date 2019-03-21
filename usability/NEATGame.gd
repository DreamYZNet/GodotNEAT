extends Node

export(int) var secondsToTermination = 1
export(int) var playCountPerGen = 5
export(int) var population = 100

onready var playersNode = get_node("/root/Game/Objects/Players")
onready var objectsToUpdate = get_node("/root/Game/Objects/Update").get_children()
onready var drawNN = get_node("/root/Game/NNDrawer")
var neat = preload("NEAT.gd").new()
var playerScene

var players = []
var timePassed = 0
var playCountInGen = 0
var pickLowestFitness = true # false: we add together. true = we pick the lowest

func _ready():
	neat.population = population
	neat.maxStaleness = 25
	neat.startingFitness = 0
	#neat.maxGenomeAmount = 15
	#temporarily use sample player
	var samplePlayer = playersNode.get_children()[0]
	playerScene = samplePlayer.scene
	neat.create(samplePlayer.inputs, samplePlayer.outputs)
	#we remove from tree to void processes, because queue_free isnt instant
	samplePlayer.get_parent().remove_child(samplePlayer)
	samplePlayer.queue_free()
	
	recreatePlayers()
	drawNN.create(neat.bestSpeciesLastGen.lastGenQueen.neuralNet)
	
func _physics_process(delta):
	drawNN.update()
	#Use an allotted time for each "game"
	timePassed += delta
	if secondsToTermination != 0 and timePassed >= secondsToTermination or playersNode.get_child_count() == 0:
		timePassed = 0
		#Update fitnesses
		for p in players:
			if p.alterGenome:
				p.updateFitness()
				p.fitnessRecord.append(p.fitness)
				p.fitness = 0
		#Allow playing game multiple times
		playCountInGen += 1
		if playCountPerGen == playCountInGen:
			playCountInGen = 0
			finalizeFitnesses()
			nextGeneration()
		remakeStage()

func finalizeFitnesses():
	for p in players:
		if p.alterGenome:
			if pickLowestFitness:
				p.fitness = p.fitnessRecord[0]
				for i in range(1, p.fitnessRecord.size()):
					p.fitness = min(p.fitnessRecord[i], p.fitness)
			else:#average
				for f in p.fitnessRecord:
					p.fitness += f
				p.fitness /= float(p.fitnessRecord.size())
			p.genome.fitness = p.fitness
		
func nextGeneration():
	neat.endGeneration()
	if neat.nextGeneration() == -1:
		gameOver()
	drawNN.create(neat.bestSpeciesLastGen.lastGenQueen.neuralNet)
	updateLabels()
		
func updateLabels():
	get_node("/root/Game/GenerationLabel").text = "Generation: %s"%[neat.generation]
	get_node("/root/Game/FitnessLabel").text = "Fitness: %s /%s"%[stepify(neat.bestSpeciesLastGen.fitnessLastGen,0.1), stepify(neat.bestSpeciesAllTime.fitnessAllTime,0.1)]
	get_node("/root/Game/SpecieIDLabel").text = "Specie ID: %s"%[neat.bestSpeciesLastGen.id]
		
func remakeStage():
	for o in objectsToUpdate:
		if o.has_method("nextGeneration"):
			o.nextGeneration()
	recreatePlayers()
	
		
func gameOver():
	get_tree().paused = true
	results()
	
func recreatePlayers():
	clearPlayers()
	createPlayers()
	
func createPlayers():
	for s in neat.species.values():
		for g in s.genomes:
			addPlayer(g)
	var lastQueen = addPlayer(neat.bestSpeciesLastGen.lastGenQueen)
	lastQueen.alterGenome = false
	lastQueen.setColor(.7,0,.7)
	var bestAllTime = addPlayer(neat.bestSpeciesAllTime.queen)
	bestAllTime.alterGenome = false
	bestAllTime.setColor(.7,.5,0)
	
func addPlayer(g):
	var player = playerScene.instance()
	player.genome = g
	players.push_back(player)
	playersNode.add_child(player)
	return player
	
func clearPlayers():
	for c in players:
		c.queue_free()
	players = []
#	for c in playersNode.get_children():
#		c.queue_free()
	
func results():
	print(" ")
	print("Results: (best species)")
	var best = neat.bestSpecies.queen
	for axon in best.neuralNet.axons.values():
		print(str(axon.id) +": w:"+ str(axon.weight) + " f:" + str(axon.from) +" t:"+ str(axon.to))
	print("Final fitness:%s"%best.fitness)
	print("Mutations: "+str(neat.recordMutations))
	
func secondsPassed(startTime, endTime = OS.get_time()):
	var startSeconds = startTime["hour"]*60*60 + startTime["minute"]*60 + startTime["second"]
	var endSeconds = endTime["hour"]*60*60 + endTime["minute"]*60 + endTime["second"]
	return endSeconds - startSeconds
	
func _input(event):
	if event is InputEventKey:
		if event.pressed:
			if OS.get_scancode_string(event.scancode) == "Enter":
				if gameSpeed() == 0:
					gameSpeed(1)
				else:
					gameSpeed(0)
					results()
			if OS.get_scancode_string(event.scancode) == "Space":
				results()
			if event.scancode == KEY_0:
				gameSpeed(1)
			if event.scancode == KEY_EQUAL:
				gameSpeed(gameSpeed()+0.2)
			if event.scancode == KEY_MINUS:
				gameSpeed(gameSpeed()-0.2)
			if event.scancode == KEY_S:
				gameSpeed(1000)
			if event.scancode == KEY_V:
				get_node("/root/Game").visible = !get_node("/root/Game").visible
			if event.scancode == KEY_9:
				ips(ips()*2)
			if event.scancode == KEY_8:
				ips(ips()/2)
			if event.scancode == KEY_7:
				ips(defaultIPS)
	
var defaultIPS = Engine.iterations_per_second
var currentIPS = float(defaultIPS)
func incGameSpeed(speed):
	gameSpeed(gameSpeed()+speed)
func gameSpeed(speed = null):
	if speed != null:
		print("Game speed: "+str(speed))
		Engine.time_scale = speed
		Engine.iterations_per_second = max(speed,1)*currentIPS
	return Engine.time_scale
func ips(ips = null):
	if ips != null:
		print("Iterations per second: " + str(ips))
		currentIPS = float(ips)
		Engine.iterations_per_second = max(Engine.time_scale,1)*currentIPS
	return currentIPS


#
#	#troubleshooting
#	var species = neat.species.values()
#	for s in range(species.size()):
#		for g in range(species[s].genomes.size()):
#			#if species[s].genomes[g].fitness > 5000:
#			for s2 in range(species.size()):
#				for g2 in range(species[s2].genomes.size()):
#					if species[s].genomes[g] == species[s2].genomes[g2]:
#						if !(s == s2 and g == g2):
#							print("s1:%s g1:%s s2:%s g2:%s"%[s,g,s2,g2])
#							print(species[s].id)
#							print(species[s].genomes[g].fitness)
#							print(species[s].genomes.size())


func printLayer(layer):
	var array = []
	for n in layer:
		array.append(n.value)
	print(array)