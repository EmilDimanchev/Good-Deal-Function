using JuMP
using Gurobi
include("./load_inputs.jl")


# ~~~~
# Load inputs
# ~~~

inputs_path = "./Inputs/Inputs_4days_4scen"
settings = Dict{String, Any}()
settings["Demand risk flag"] = false
settings["Fuel risk flag"] = false

# Load data
inputs = load_input_data(inputs_path, settings)

# Settings
# Data
cost_inv = inputs["Investment costs"]
cost_var = inputs["Variable costs"]
demand = inputs["Demand"]
availability = inputs["Generation availability"]

# Stochasticities
P = inputs["Demand scenario probabilities"]
P_f = inputs["Fuel price scenario probabilities"]

# Representative periods
n_periods = inputs["Number of representative periods"]
t_weights = inputs["Period weights"]

# ~~~
# Build model
# ~~~

# Sharpe ratio
A = 1.22
# Price cap
price_cap = 2000

# Model
gep = Model(Gurobi.Optimizer)

# Sets
T = inputs["Number of periods"]
S = size(P)[1] # number of demand scenarios
F = size(P_f)[1] # number of fuel cost scenarios
G = inputs["Number of generation resources"]

# ~~~
# Model formulation
# ~~~

# Contract
@variable(gep, w_0)
# Auxiliary good deal variable
@variable(gep, η[s in 1:S, f in 1:F] >= 0)
# Generation
@variable(gep, g[r in 1:G, t in 1:T, s in 1:S, f in 1:F] >= 0)
# Capacity
@variable(gep, x[r in 1:G] >= 0) # Capacity, MW
# Non-served energy
@variable(gep, y[t in 1:T, s in 1:S, f in 1:F] >= 0) # $/MWh

# Capacity limit on generation
@constraint(gep, capacity_limit[r in 1:G, t in 1:T, s in 1:S, f in 1:F], x[r]*availability[t,r] >= g[r,t,s,f])

# Power balance constraint
@constraint(gep, power_balance[t in 1:T, s in 1:S, f in 1:F], sum(g[r,t,s,f] for r in 1:G) + y[t,s,f] - demand[t,s] == 0)

# Define second-stage (operating) costs
@expression(gep, op_cost[s in 1:S, f in 1:F], sum(t_weights[t]*g[r,t,s,f]*cost_var[r,f] for r in 1:G, t in 1:T) + sum(t_weights[t]*price_cap*y[t,s,f] for t in 1:T))

# Good Deal constraint
@constraint(gep, good_deal[s in 1:S, f in 1:F], 1.02*w_0 + η[s,f] >= op_cost[s,f])

# ~~~
# Objective function
# ~~~ 

# Cone
@variable(gep, z >= 0)
@expression(gep, p_eta[s in 1:S], sqrt(P[s])*η[s])
@constraint(gep, [z; p_eta] in SecondOrderCone())


@objective(gep, Min, sum(cost_inv[r]*x[r] for r in 1:G) + w_0 + A*z)

# Solve
optimize!(gep)

# Write outputs
output = Dict{String, Any}()

output["Capacity"] = value.(x)
output["Load shedding"] = value.(y)
output["Generation"] = value.(g)
output["Objective function value"] = objective_value(gep)


