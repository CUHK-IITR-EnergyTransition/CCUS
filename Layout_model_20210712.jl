mitigation_curve_df = DataFrame(matched = Float64[], EOR_price = Float64[], Shipped_Mt = Float64[], Domestic_EOR_Mt = Float64[], Domestic_other_Mt = Float64[], Avg_Cost = Float64[], MAC = Float64[])
matched_df = DataFrame(Cost_sharing = Float64[], matched = Float64[], Oil_Price_per_ton = Float64[], Carbon_Price_per_ton = Float64[], Objective_value = Float64[])


#for  unit_utilization_price_dict["EOR"] = 22.5
        # 0 : 2.5 : 25
#for cost_sharing_factor = 0.1 : .1 : .6
for cost_sharing_factor = 0.3

     for Oil_price = 292 : 73/4 : 511

         for CO2_price = 20 : 2 : 40

             for matched = 1000 : 100 : 57800

#for mitigated = 1000 : 100 : 57800

#Layout = Model(optimizer_with_attributes(Gurobi.Optimizer, "TimeLimit" => 3600))

Layout = Model(with_optimizer(Gurobi.Optimizer))

@variable(Layout,Matched_Domestic[i in sources, j in domestic_sites] >= 0)
@variable(Layout,Matched_Terminal[i in sources, k in CO2_shipping_terminals] >= 0)
@variable(Layout,Matched_Overseas[k in CO2_shipping_terminals, l in overseas_sites] >= 0)

#=
@variable(Layout,transport_Inland[s in sources, k in sinks; !haskey(set_type_sink_dict,["Offshore",k])] >= 0)
@variable(Layout,transport_Offshore[k in sinks, l in sinks; haskey(set_type_sink_dict,["Hub",k]) && haskey(set_type_sink_dict,["Offshore",l]) ] >= 0)

=#

@constraint(Layout,source_distribution[i in sources],
                   sum(Matched_Domestic[i,j] for j in domestic_sites) + sum(Matched_Terminal[i,k] for k in CO2_shipping_terminals) <= param_source_size[i])

@constraint(Layout,sink_accumulation_Inland[j in domestic_sites],
                   sum(Matched_Domestic[i,j] for i in sources) <= param_sink_limit[j])

@constraint(Layout,sink_accumulation_Offshore[l in overseas_sites],
                    sum(Matched_Overseas[k,l] for k in CO2_shipping_terminals) <= param_sink_limit[l])

@constraint(Layout,terminal_in_out_balance[k in CO2_shipping_terminals],
                    sum(Matched_Terminal[i,k] for i in sources) == sum(Matched_Overseas[k,l] for l in overseas_sites))

@constraint(Layout, matched_con,
                sum(Matched_Domestic[i,j] for i in sources, j in domestic_sites) + sum(Matched_Terminal[i,k] for i in sources, k in CO2_shipping_terminals) >= matched)


#=
@constraint(Layout,source_distribution[s in sources],
                   sum(transport_Inland[s,k] for k in sinks if !haskey(set_type_sink_dict,["Offshore",k])) <= param_source_size[s])

@constraint(Layout,sink_accumulation_Inland[k in sinks; !haskey(set_type_sink_dict,["Offshore",k])],
                     sum(transport_Inland[s,k] for s in sources) <= param_sink_limit[k])

@constraint(Layout,sink_accumulation_Offshore[k in sinks; haskey(set_type_sink_dict,["Offshore",k])],
                    sum(transport_Offshore[h,k] for h in sinks
                    if haskey(set_type_sink_dict,["Hub",h])) <= param_sink_limit[k])

@constraint(Layout,hub_in_out_balance[ h in sinks; haskey(set_type_sink_dict,["Hub",h])],
                    sum(transport_Inland[s,h] for s in sources) == sum(transport_Offshore[h,k] for k in sinks if haskey(set_type_sink_dict,["Offshore",k])))

@constraint(Layout, mitigation,
                sum(transport_Inland[s,k] for s in sources, k in sinks if !haskey(set_type_sink_dict,["Offshore",k])) >= mitigated)
=#

#= scope 1
@objective(Layout, Min, sum(param_capture_cost[i]*Matched_Domestic[i,j] for i in sources, j in domestic_sites)
                        + sum(param_capture_cost[i]*Matched_Terminal[i,k] for i in sources, k in CO2_shipping_terminals) # Capture cost
                        + sum(param_transport_cost[i]*Matched_Domestic[i,j]*param_source_sink_dist[i,j] for i in sources, j in domestic_sites)
                        + sum(param_transport_cost[i]*Matched_Terminal[i,k]*param_source_sink_dist[i,k] for i in sources, k in CO2_shipping_terminals) # Inland tranport cost from source to sink and terminal
                        + sum(param_shipping_cost[[k,l]]*Matched_Overseas[k,l] for k in CO2_shipping_terminals, l in overseas_sites) # Shipping cost
                        + storage_cost*sum(Matched_Domestic[i,j_2] for i in sources, j_2 in domestic_non_EOR_sites)  # Inland stroage cost
                        - unit_CO2_sales_revenue*(sum(Matched_Domestic[i,j_1] for i in sources,j_1 in domestic_EOR_sites)+
                                                 sum(Matched_Overseas[k,l] for k in CO2_shipping_terminals, l in overseas_sites)))# CO2 price for domestic storage both EOR and non EOR
=#
# scope 2
@objective(Layout, Min, sum(param_capture_cost[i]*Matched_Domestic[i,j] for i in sources, j in domestic_sites)
                        + sum(param_capture_cost[i]*Matched_Terminal[i,k] for i in sources, k in CO2_shipping_terminals) # Capture cost
                        + sum(param_transport_cost[i]*Matched_Domestic[i,j]*param_source_sink_dist[i,j] for i in sources, j in domestic_sites)
                        + sum(param_transport_cost[i]*Matched_Terminal[i,k]*param_source_sink_dist[i,k] for i in sources, k in CO2_shipping_terminals) # Inland tranport cost from source to sink and terminal
                        + sum(param_shipping_cost[[k,l]]*Matched_Overseas[k,l] for k in CO2_shipping_terminals, l in overseas_sites) # Shipping cost
                        + storage_cost*sum(Matched_Domestic[i,j] for i in sources, j in domestic_sites) # Domestic storage cost
                        - Oil_price*oil_per_ton_CO2*sum(Matched_Domestic[i,j_1] for i in sources, j_1 in domestic_EOR_sites) # Domestic oil revenue
                        - cost_sharing_factor*(Oil_price*oil_per_ton_CO2-storage_cost)*sum(Matched_Terminal[i,k] for i in sources, k in CO2_shipping_terminals) # Overseas oil revenue
                        - CO2_price*(sum(Matched_Domestic[i,j] for i in sources, j in domestic_sites)
                                    + sum(Matched_Terminal[i,k] for i in sources, k in CO2_shipping_terminals))) # Carbon revenue
#
#= Scope 2
@objective(Layout, Min, sum(transport_Inland[s,k]*param_capture_cost[s] for s in sources, k in sinks # Capture cost
                        if !haskey(set_type_sink_dict,["Offshore",k])) +
                        sum(transport_Inland[s,k]*storage_cost # Inland stroage cost
                        for s in sources, k in sinks
                        if haskey(set_type_sink_dict,["Inland",k])) -
                        sum(transport_Inland[s,k]*CO2_price # CO2 price for domestic storage both EOR and non EOR
                        for s in sources, k in sinks
                        if haskey(set_type_sink_dict,["Inland",k])) -
                        sum(transport_Inland[s,k]*oil_per_ton_CO2*Oil_price # Oil price from domestic EOR
                        for s in sources, k in sinks
                        if haskey(set_type_sink_dict,["Inland",k]) && haskey(set_domestic_EOR_dict,[k])) +
                        sum( param_transport_cost[s]*transport_Inland[s,k]*param_source_sink_dist[s,k] # Inland tranport cost from source to sink and terminal
                        for s in sources, k in sinks
                        if !haskey(set_type_sink_dict,["Offshore",k])) +
                        sum(transport_Offshore[k,l]*transport_cost_offshore_dict[[k,l]] for k in sinks, l in sinks # Offshore transportation cost
                        if haskey(set_type_sink_dict,["Hub",k]) && haskey(set_type_sink_dict,["Offshore",l])) +
                        cost_sharing_factor*(sum(transport_Offshore[k,l]*storage_cost for k in sinks, l in sinks # Offshore storage cost
                        if haskey(set_type_sink_dict,["Hub",k]) && haskey(set_type_sink_dict,["Offshore",l]))-
                        sum(transport_Offshore[k,l]*oil_per_ton_CO2*Oil_price for k in sinks, l in sinks # Offshore oil price
                        if haskey(set_type_sink_dict,["Hub",k]) && haskey(set_type_sink_dict,["Offshore",l]))) -
                        sum(transport_Offshore[k,l]* CO2_price for k in sinks, l in sinks # Offshore CO2 price
                        if haskey(set_type_sink_dict,["Hub",k]) && haskey(set_type_sink_dict,["Offshore",l])))
=#

optimize!(Layout)

Shipped = value(sum(Matched_Terminal[i,k] for i in sources, k in CO2_shipping_terminals))
EOR_domestic = value(sum(Matched_Domestic[i,j_1] for i in sources, j_1 in domestic_EOR_sites))
Inland_others = value(sum(Matched_Domestic[i,j_2] for i in sources, j_2 in domestic_non_EOR_sites))
marginal_abatement_cost = dual(matched_con)

push!(matched_df,(cost_sharing_factor,matched,Oil_price,CO2_price, objective_value(Layout)))

#Scope 1
push!(mitigation_curve_df,(matched,unit_CO2_sales_revenue,Shipped, EOR_domestic, Inland_others,
    objective_value(Layout)/matched, marginal_abatement_cost))

#=
shipped = value(sum(transport_Offshore[k,l] for k in sinks, l in sinks
                if haskey(set_type_sink_dict,["Hub",k]) && haskey(set_type_sink_dict,["Offshore",l])))
EOR_domestic = value(sum(transport_Inland[s,k] for s in sources, k in sinks
                if haskey(set_domestic_EOR_dict,[k])))
Inland_others = value(sum(transport_Inland[s,k] for s in sources, k in sinks
                if haskey(set_type_sink_dict,["Inland",k]) && !haskey(set_domestic_EOR_dict,[k])))
marginal_abatement_cost = dual(mitigation)

push!(matched,(cost_sharing_factor,mitigated,Oil_price,CO2_price,
    objective_value(Layout)))

#=push!(mitigation_curve,(mitigated,unit_utilization_price_dict["EOR"],shipped, EOR_domestic, Inland_others,
    objective_value(Layout)/mitigated, marginal_abatement_cost))
=#

=#
end
end
end
end

XLSX.writetable("mitigation_curve_STPS_3.xlsx", collect(DataFrames.eachcol(mitigation_curve_df)), DataFrames.names(mitigation_curve_df))
XLSX.writetable("matched.xlsx", collect(DataFrames.eachcol(matched_df)), DataFrames.names(matched_df))


objective_value(Layout)

result_Inland_EOR = DataFrame(Region = String[], Fuel = String[], Source = String[], Region_sink = String[], Sink = String[], Quantity_Mt = Float64[], Distance_km = Float64[], Lat = Float64[], Long = Float64[])
result_Inland_hub = DataFrame(Region = String[], Fuel = String[], Source = String[],Region_sink = String[], Sink = String[], Quantity_Mt = Float64[], Distance_km = Float64[], Capture_cost = Float64[],
                            Transportation_cost = Float64[], Lat = Float64[], Long = Float64[])
result_Inland_sink = DataFrame(Region = String[], Fuel = String[], Source = String[], Region_sink = String[], Sink = String[], Quantity_Mt = Float64[], Distance_km = Float64[], Lat = Float64[], Long = Float64[])
result_Offshore = DataFrame(Source = String[], Sink = String[], Quantity_Mt = Float64[], Distance_km = Float64[])

for s in sources, k in sinks
    if  haskey(set_domestic_EOR_dict,[k])
        if value(transport_Inland[s,k]) > 0
                push!(result_Inland_EOR,(param_source_region[s], param_source_fuel[s],s,param_sink_region[k], k,value(transport_Inland[s,k]),param_source_sink_dist[s,k], param_source_lat[s], param_source_long[s]))
        end
    end
end

for s in sources, k in sinks
    if haskey(set_type_sink_dict,["Hub",k])
        if value(transport_Inland[s,k]) > 0
                push!(result_Inland_hub,(param_source_region[s], param_source_fuel[s], s, param_sink_region[k], k,value(transport_Inland[s,k]),param_source_sink_dist[s,k], param_capture_cost[s],
                param_transport_cost[s], param_source_lat[s], param_source_long[s]))
        end
    end
end

for s in sources, k in sinks
    if haskey(set_type_sink_dict,["Inland",k]) && !haskey(set_domestic_EOR_dict,[k])
        if value(transport_Inland[s,k]) > 0
                push!(result_Inland_sink,(param_source_region[s], param_source_fuel[s], s, param_sink_region[k], k,value(transport_Inland[s,k]),param_source_sink_dist[s,k], param_source_lat[s], param_source_long[s]))
        end
    end
end


for h in sinks, k in sinks
    if haskey(set_type_sink_dict,["Hub",h]) && haskey(set_type_sink_dict,["Offshore",k])
        if value(transport_Offshore[h,k]) > 0
            push!(result_Offshore,(h,k,value(transport_Offshore[h,k]),param_source_sink_dist[h,k]))
        end
    end
end




XLSX.writetable("result_Inland_EOR.xlsx", collect(DataFrames.eachcol(result_Inland_EOR)), DataFrames.names(result_Inland_EOR))
XLSX.writetable("result_Inland_hub.xlsx", collect(DataFrames.eachcol(result_Inland_hub)), DataFrames.names(result_Inland_hub))
XLSX.writetable("result_Inland_sink.xlsx", collect(DataFrames.eachcol(result_Inland_sink)), DataFrames.names(result_Inland_sink))
XLSX.writetable("result_Offshore.xlsx", collect(DataFrames.eachcol(result_Offshore)), DataFrames.names(result_Offshore))
