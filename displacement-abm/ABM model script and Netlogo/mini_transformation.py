import pandas as pd

# Load your current CSV
df = pd.read_csv("abm_combined_dataset.csv")

# Force conversion: is_water to string "true"/"false"
df["is_water"] = df["is_water"].apply(lambda x: "true" if str(x).lower() in ["1", "true", "True"] else "false")

# Keep only required columns (in correct order)
columns = ["latitude", "longitude", "elevation", "rainfall_mm", "is_water"]
df = df[columns]

# Save cleaned version
df.to_csv("abm_base_grid_clean.csv", index=False)

print("✅ Cleaned and saved: abm_base_grid_clean.csv")


print(df['latitude'].min(), df['latitude'].max())
print(df['longitude'].min(), df['longitude'].max())