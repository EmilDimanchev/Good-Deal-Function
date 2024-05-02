using CSV
using DataFrames

function load_input_data(inputs_path, settings)

    # Collect data here
    inputs = Dict{String, Any}()

    if Sys.isunix()
        sep = "/"
    elseif Sys.iswindows()
        sep = "\U005c"
    end

    # Input parameters
    period_weights_input = CSV.read(string(inputs_path,sep,"Representative_period_weights.csv"), DataFrame, header=true)
    # Technologies
    resources_input = CSV.read(string(inputs_path,sep,"Resources.csv"), DataFrame, header=true)
    inputs["Generation resources"] = resources_input[1:end,1]
    inputs["Number of generation resources"] = size(resources_input)[1]    
    # Costs
    var_cost_input = CSV.read(string(inputs_path,sep,"Variable_cost.csv"), DataFrame, header=true)
    inputs["Investment costs"] = round.(resources_input[1:end,"Investment cost"],digits=2) # $/MW-year
    # Availability
    resource_avail_input = CSV.read(string(inputs_path,sep,"Resources_availability.csv"), DataFrame, header=true)
    inputs["Generation availability"] = round.(Matrix(resource_avail_input[:, 2:end]),digits=2)
    
    # ~~~
    # Stochastic parameters
    # ~~~
    
    probabilities_input_demand = CSV.read(string(inputs_path,sep,"Scenario_probabilities_demand.csv"), DataFrame, header=true)
    probabilities_input_fuel = CSV.read(string(inputs_path,sep,"Scenario_probabilities_fuel.csv"), DataFrame, header=true)

    # Demand
    if settings["Demand risk flag"]
        demand_input = CSV.read(string(inputs_path,sep,"Demand.csv"), DataFrame, header=true)
        inputs["Demand"] = round.(Array(demand_input[:,3:end]),digits=1)
        inputs["Demand scenario probabilities"] = Array(probabilities_input_demand[probabilities_input_demand[!,:Uncertainty] .== "Demand",2:end][1,:])
    else
        demand_input = CSV.read(string(inputs_path,sep,"Demand.csv"), DataFrame, header=true, select=["Time_index", "Demand-base"])
        inputs["Demand"] = round.(Array(demand_input[:,2]),digits=1)
        inputs["Demand scenario probabilities"] = [1]
    end
    time_index = demand_input[:,1]
    inputs["Time index"] = time_index

    # Fuel price
    if settings["Fuel risk flag"]
        # Variable cost in $/MWh
        inputs["Variable costs"] = Array(var_cost_input[1:end, 3:end])
        inputs["Fuel price scenario probabilities"] = Array(probabilities_input_fuel[probabilities_input_fuel[!,:Uncertainty] .== "Fuel",2:end][1,:])
    else
        inputs["Variable costs"] = Array(var_cost_input[1:end, 2]) # $/MWh
        inputs["Fuel price scenario probabilities"] = [1]
    end

    # Variable costs 
    inputs["Variable costs"] = Array(var_cost_input[1:end, 2]) # $/MWh
    
    # Representative period weights
    T_length = size(demand_input)[1]
    n_periods = size(period_weights_input)[1]
    t_weights = zeros(T_length)
    period_length = Integer(T_length/n_periods)
    first_periods = collect(1:period_length:T_length) 
    last_periods = collect(period_length:period_length:T_length)
    for i in 1:n_periods
        t_weights[first_periods[i]:last_periods[i]] .= period_weights_input[!,"Weight"][i]/period_length
    end
    inputs["Period weights"] = t_weights
    inputs["Number of periods"] = T_length
    inputs["Number of representative periods"] = n_periods

    return inputs
end

