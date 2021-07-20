data =XLSX.readxlsx("data.xlsx")
#=
source_data = readxlsheet("data.xlsx","Source_ESDMI")
sink_data = readxlsheet("data.xlsx","Sink_2")
cost_data = readxlsheet("data.xlsx", "Cost")
=#

source_data = data["Source_ESDMI"][:]
sink_data = data["Sink_2"][:]
cost_data = data["Cost"][:]

sources = [string(source_data[i,3]) for i in 2:size(source_data,1)]
sinks = [string(sink_data[i,2]) for i in 2:size(sink_data,1)]
sink_type = unique(sink_data[2:end,1])

# New sets
domestic_sites = [string(sink_data[i,2]) for i in 2:size(sink_data,1) if sink_data[i,1] == "Inland"]
domestic_EOR_sites = [string(sink_data[i,2]) for i in 2:size(sink_data,1) if sink_data[i,6] == 1]
domestic_non_EOR_sites = [string(sink_data[i,2]) for i in 2:size(sink_data,1) if sink_data[i,6] == 0 && sink_data[i,1] == "Inland"]



set_type_sink_dict = Dict([sink_data[i,1],sink_data[i,2]] => 1 for i in 2:size(sink_data,1))
set_domestic_EOR_dict = Dict([sink_data[i,2]] => 1 for i in 2:size(sink_data,1) if sink_data[i,6] == 1)

param_source_lat = Dict([source_data[i,3] => source_data[i,4] for i in 2:size(source_data,1)])
param_source_long = Dict([source_data[i,3] => source_data[i,5] for i in 2:size(source_data,1)])
param_source_region = Dict([source_data[i,3] => source_data[i,1] for i in 2:size(source_data,1)])
param_source_fuel = Dict([source_data[i,3] => source_data[i,2] for i in 2:size(source_data,1)])


param_sink_lat = Dict([sink_data[i,2] => sink_data[i,3] for i in 2:size(sink_data,1)])
param_sink_long = Dict([sink_data[i,2] => sink_data[i,4] for i in 2:size(sink_data,1)])
param_sink_region = Dict(sink_data[i,2] => sink_data[i,7] for i in 2:size(sink_data,1))


param_source_sink_dist = Dict()
for s in sources
    for k in sinks
            if !haskey(set_type_sink_dict,["Offshore",k])
                param_source_sink_dist[s,k] = haversine((param_source_long[s],param_source_lat[s]), (param_sink_long[k], param_sink_lat[k]), 6372.8)
            end
    end
end

for k in sinks
    for l in sinks
        if haskey(set_type_sink_dict,["Hub",k]) && haskey(set_type_sink_dict,["Offshore",l])
            param_source_sink_dist[k,l] = haversine((param_sink_long[k],param_sink_lat[k]), (param_sink_long[l], param_sink_lat[l]), 6372.8)
        end
    end
end

source_sink_dist = DataFrame(source = String[], Sink = String[], Distance_km = Float64[])


param_source_size = Dict([source_data[i,3] => source_data[i,6] for i in 2:size(source_data,1)])
param_sink_limit = Dict([sink_data[i,2] => sink_data[i,5] for i in 2:size(sink_data,1)])

param_capture_cost = Dict([source_data[i,3] => source_data[i,8] for i in 2:size(source_data,1)])
param_transport_cost = Dict([source_data[i,3] => source_data[i,10] for i in 2:size(source_data,1)])

#transportation cost per tonne CO2 per km = .18 from APEN paper; .01 from the review survey
#unit_transport_cost_dict = Dict()
#unit_transport_cost_dict["Inland"] = 0.01

transport_cost_offshore_dict = Dict([[cost_data[i,1],cost_data[i,2]] => cost_data[i,4] for i in 2:size(cost_data,1)])

unit_utilization_price_dict = Dict()
unit_utilization_price_dict["EOR"] = 5

#capture_cost = 46 # $/ton CO2
storage_cost = 15 # $/ton CO2
oil_per_ton_CO2 = 0.25 # ton of oils/ton of CO2
Oil_price = 328.5 # $/ton of oil = 45 $ per barrel. 1 ton = 7.3 barrels
CO2_price = 15 # $/ton
cost_sharing_factor = 0.7
