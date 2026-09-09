# Quantifying Climate-Induced Displacement: An Agent-Based Modeling Approach

Agent-Based Model (ABM) simulating the dynamics of flood-induced displacements and household economic attrition in response to recurrent flooding. 

This project combines Python with a NetLogo-based simulation to explore resilience and adaptive behaviour under climate stress. This end-to-end pipeline transforms real-world coordinates into a simulated environment to evaluate climate adaptation strategies for vulnerable populations

Tech stack : Python (Pandas, NumPy, OSMnx, Shapely)| NetLogo Simulation Modelling |Geospatial Analysis 

## 🚀 Core Features
> - Built a 50 km² spatial ABM with real-world elevation, roads, rainfall & household agents
> - Agents with wealth, displacement state, flood history, and relocation logic 
> - Captures temporary vs. permanent displacement 
> -  Exports time-series data (displacement %, cumulative displacement, wealth trajectories, Turtles flooded 2+:  repeat flood counts)
> - Quantifies displacement dynamics across intensities (0.2 to 1.0)
---

Simulation Screenshot:

Here's the NetLogo interface during a run:
![Flood ABM Simulation](./ABM%20model%20script%20and%20Netlogo/simulation.gif)

—
—

## Project Overview:

Built full pipeline for this project:
1. **Geospatial Data Pipeline (Python-script_1.py):**
   - **Process:** Developed a Python pipeline generating a 50 km² terrain grid (~20,000 points) with elevation, OSM roads/buildings and rainfall data.
   - **Outputs:** Produced a formatted CSV files: abm_base_grid.csv, osm_buildings.csv, osm_ shelters.csv.
2. **Agent-Based Model- NetLogo (FinalNetLogoCompleted.nlogo):**
   - **Process:** Developed  heterogeneous household agents with dynamic attributes: wealth, displacement statuses (stay, return, displace), times flooded and decision-making logic for temporary vs permanent relocation
   - **Output:** Exported time-series data on displacement rates, wealth trajectories and flood recurrence.
3. **Post-Simulation analytics:**
   - Results extractions, data wrangling (Pandas, NumPy) and CSV exports of time-series simulation data.
4. **Quantitative Scenario Analysis:**
   - **Process:** Analysed displacement patterns across five flood intensity scenarios (0.2 to 1.0).



## Getting started:
**Requirements:** 
- NetLogo 6.x [NetLogo 6.x](https://ccl.northwestern.edu/netlogo/6.4.0/)
- Python 
- Install python dependencies  
- pip install pandas numpy matplotlib osmnx shapely

**2. Run the simulation**

     1. Open **FinalNetlogocompleted.nlogo** in NetLogo
     2. Click the **Setup** button to  inistialse the model.
     3. Adjust the model parameters (flood intensity, floods/year, aid amount/delay)
     4. Click the **`Go`** button to run the simulation.
     5. Export results (CSV)



## Results and conclusion:
### Simulation results:
The agent-based model was run across multiple flood intensity scenarios. 
 
  ![Flood ABM Simulation](./ABM%20model%20script%20and%20Netlogo/simulation2.png)

### Key Insights & Conclusion:

The model revealed a non-linear relationship between flood intensity and long-term displacement
- At **low intensity (0.2)** displacement remained minimal (3.3%) but households experienced economic stagnation, identifying a population undergoing **"silent suffering"**.
- At **moderate intensities (0.6)**, instability was most persistent, a population "perpetually stressed" but not shocked enough to trigger major adaptive changes. 
- At **high intensities (1.0)**, displacement was initially severe (52%), but stronger wealth recovery (22,096) when supported by aid: **“Crisis & Recovery”**.

—
The model emphasises that the time and design of aid interventions has a significant impact on resilience, underscoring the need for strategic resource allocation to reducing long-term displacement. 

## Data Sources

- Map data © [OpenStreetMap](https://www.openstreetmap.org/), [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), licensed under the [Open Database License (ODbL)](https://opendatacommons.org/licenses/odbl/1-0/).
- Elevation data from the [Open-Elevation API](https://open-elevation.com/).
- Additional geospatial data retrieved via the [Overpass API](https://overpass-api.de/).
 


