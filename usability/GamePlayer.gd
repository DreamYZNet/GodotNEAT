extends KinematicBody2D

#NEURAL PLAYER
var inputs = 4
var outputs = 1
var alterGenome = true
var scene #set it as the player scene

var genome
var fitness = 0
var fitnessRecord = []
	
func _ready():
	inputs = 0
	outputs = 0
#	scene = load(".tscn")
	
func _physics_process(delta):
#	processNetwork()
	pass
		
func processNetwork(delta = 0):
#	var output = genome.neuralNet.feed()
	pass
	
#Calculate the fitness for this run
func updateFitness():
#	if alterGenome:
#		genome.fitness += fitness
	pass
	
func setColor(r, g, b, a = 1):
	$Polygon2D.color = Color(r,g,b,a)

func getDistanceTo(obj):
	return abs((obj.position - self.position).length())