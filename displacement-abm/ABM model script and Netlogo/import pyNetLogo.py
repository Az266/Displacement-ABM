import pyNetLogo
print("✅ pyNetLogo is installed and ready!")
import pandas as pd
import matplotlib.pyplot as plt

# Start NetLogo in headless mode
netlogo = pyNetLogo.NetLogoLink(gui=False)

# Use filename only (model file must be in same folder)
netlogo.load_model("flood-abm-clean-rebuild.nlogo")

# Settings
flood_levels = [0.2, 0.4, 0.6, 0.8, 1.0]
ticks = 104  # Number of ticks to run the model for each flood intensity
results = []

for level in flood_levels:
    print(f"Running model for flood intensity = {level}")
    
    netlogo.command("setup")
    netlogo.command(f"set slider-flood-intensity {level}")
    netlogo.command("reset-ticks")
    
    max_displaced = 0
    max_flooded_2plus = 0
    max_cumulative_displacement = 0

    for _ in range(ticks):
        netlogo.command("go")
        max_displaced = max(max_displaced, netlogo.report("percentage-displaced"))
        max_flooded_2plus = max(max_flooded_2plus, netlogo.report("count turtles with [times-flooded >= 2]"))
        max_cumulative_displacement = max(max_cumulative_displacement, netlogo.report("sum [times-flooded] of turtles"))

    final_displaced = netlogo.report("count turtles with [displaced?]")
    final_avg_wealth = netlogo.report("average-wealth")

    results.append({
        "flood_intensity": level,
        "max_%_displaced": max_displaced,
        "max_flooded_2plus": max_flooded_2plus,
        "final_displaced": final_displaced,
        "final_average_wealth": final_avg_wealth,
        "max_cumulative_displacement": max_cumulative_displacement
    })

# Create a DataFrame
df = pd.DataFrame(results)
print(df)
df.to_csv("flood_abm_results.csv", index=False)

# === 📊 Plotting ===
plt.figure(figsize=(10, 6))

# 1. Max % Displaced
plt.subplot(2, 2, 1)
plt.plot(df["flood_intensity"], df["max_%_displaced"], marker='o')
plt.title("Max % Displaced")
plt.xlabel("Flood Intensity")
plt.ylabel("% Displaced")

# 2. Max Flooded 2+ Times
plt.subplot(2, 2, 2)
plt.plot(df["flood_intensity"], df["max_flooded_2plus"], marker='o', color='orange')
plt.title("Max Flooded 2+ Times")
plt.xlabel("Flood Intensity")
plt.ylabel("Turtles")

# 3. Final Displaced Count
plt.subplot(2, 2, 3)
plt.plot(df["flood_intensity"], df["final_displaced"], marker='o', color='red')
plt.title("Final Displaced Count")
plt.xlabel("Flood Intensity")
plt.ylabel("Turtles")

# 4. Final Average Wealth
plt.subplot(2, 2, 4)
plt.plot(df["flood_intensity"], df["final_average_wealth"], marker='o', color='green')
plt.title("Final Average Wealth")
plt.xlabel("Flood Intensity")
plt.ylabel("BDT")

plt.tight_layout()
plt.savefig("flood_abm_graphs.png")
plt.show()
