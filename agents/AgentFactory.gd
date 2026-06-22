extends Node
class_name AgentFactory

func create_agent(id: String) -> Agent:
	var data = AgentData.new()
	data.id = id
	
	var agent = Agent.new()
	agent.initialize(data)
	
	return agent
