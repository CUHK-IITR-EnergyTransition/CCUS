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

Layout = Model(with_optimizer(Gurobi.Optimizer))

@variable(Layout,Matched_Domestic[i in sources, j in domestic_sites] >= 0)
@variable(Layout,Matched_Terminal[i in sources, k in CO2_shipping_terminals] >= 0)
@variable(Layout,Matched_Overseas[k in CO2_shipping_terminals, l in overseas_sites] >= 0)

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

optimize!(Layout)

Shipped = value(sum(Matched_Terminal[i,k] for i in sources, k in CO2_shipping_terminals))
EOR_domestic = value(sum(Matched_Domestic[i,j_1] for i in sources, j_1 in domestic_EOR_sites))
Inland_others = value(sum(Matched_Domestic[i,j_2] for i in sources, j_2 in domestic_non_EOR_sites))
marginal_abatement_cost = dual(matched_con)

push!(matched_df,(cost_sharing_factor,matched,Oil_price,CO2_price, objective_value(Layout)))

#Scope 1
push!(mitigation_curve_df,(matched,unit_CO2_sales_revenue,Shipped, EOR_domestic, Inland_others,
    objective_value(Layout)/matched, marginal_abatement_cost))
end
end
end
end
