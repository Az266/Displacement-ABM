import osmnx as ox
import geopandas as gpd
import pandas as pd
import numpy as np
import requests
import time
import overpy
from shapely.geometry import Polygon, LineString, Point
from math import sqrt, cos, radians

center_lat = 25.090856448492858
center_lon = 91.98183390329902
area_km2 = 50
target_points = 20000


side_km = sqrt(area_km2)
deg_per_km_lat = 1 / 111
deg_per_km_lon = 1 / (111 * cos(radians(center_lat)))
lat_range = (side_km / 2) * deg_per_km_lat
lon_range = (side_km / 2) * deg_per_km_lon

min_lat = center_lat - lat_range
max_lat = center_lat + lat_range
min_lon = center_lon - lon_range
max_lon = center_lon + lon_range


n_side = int(sqrt(target_points))
lat_vals = np.linspace(min_lat, max_lat, n_side)
lon_vals = np.linspace(min_lon, max_lon, n_side)
grid_points = [(lat, lon) for lat in lat_vals for lon in lon_vals]

df = pd.DataFrame(grid_points, columns=["latitude", "longitude"])


def fetch_elevations_batch(locations):
    url = "https://api.open-elevation.com/api/v1/lookup"
    response = requests.post(url, json={"locations": locations})
    if response.status_code == 200:
        return [entry['elevation'] for entry in response.json()['results']]
    else:
        print("Elevation API error:", response.text)
        return [None] * len(locations)

print("🔼 Fetching elevation...")
batch_size = 100
elevations = []
for i in range(0, len(df), batch_size):
    batch = df.iloc[i:i + batch_size]
    locations = batch[["latitude", "longitude"]].to_dict(orient="records")
    print(f" Elevation batch {i // batch_size + 1}")
    elevations.extend(fetch_elevations_batch(locations))
    time.sleep(1)

df["elevation"] = elevations


df["rainfall_mm"] = np.random.normal(loc=50, scale=10, size=len(df))


print("🌊 Fetching water areas...")
api = overpy.Overpass()
query = f"""
[out:json][timeout:25];
(
  way["natural"="water"]({min_lat},{min_lon},{max_lat},{max_lon});
  way["waterway"="riverbank"]({min_lat},{min_lon},{max_lat},{max_lon});
  way["landuse"="reservoir"]({min_lat},{min_lon},{max_lat},{max_lon});
  relation["natural"="water"]({min_lat},{min_lon},{max_lat},{max_lon});
);
out body;
>;
out skel qt;
"""
result = api.query(query)

def way_to_polygon(way):
    try:
        coords = [(float(node.lat), float(node.lon)) for node in way.nodes]
        if coords[0] != coords[-1]:
            coords.append(coords[0])
        return Polygon([(lon, lat) for lat, lon in coords])
    except:
        return None

water_polygons = [way_to_polygon(way) for way in result.ways]
water_polygons = [poly for poly in water_polygons if poly and poly.is_valid]

gdf_grid = gpd.GeoDataFrame(df, geometry=gpd.points_from_xy(df.longitude, df.latitude), crs="EPSG:4326")
df["is_water"] = False
for poly in water_polygons:
    df.loc[gdf_grid.geometry.within(poly), "is_water"] = True


def save_gdf_as_csv(gdf, filename):
    gdf = gdf.copy()
    gdf["latitude"] = gdf.geometry.y
    gdf["longitude"] = gdf.geometry.x
    gdf[["latitude", "longitude"]].to_csv(filename, index=False)
    print(f"✅ Saved CSV: {filename}")

def save_linestrings_as_csv(gdf, filename):
    rows = []
    for line in gdf.geometry:
        if line.geom_type == "LineString":
            for coord in line.coords:
                rows.append({"latitude": coord[1], "longitude": coord[0]})
    pd.DataFrame(rows).to_csv(filename, index=False)
    print(f"✅ Saved LineString CSV: {filename}")


try:
    buildings = ox.geometries_from_bbox(max_lat, min_lat, max_lon, min_lon, tags={"building": True})
    if not buildings.empty:
        buildings = buildings[buildings.geometry.type == "Point"].copy()
        buildings[["geometry"]].to_file("osm_buildings.geojson", driver="GeoJSON")
        save_gdf_as_csv(buildings[["geometry"]], "osm_buildings.csv")
    else:
        raise ValueError("Empty OSM result")
except:
    fallback_bld = df[df["is_water"] == False].sample(n=200)
    synthetic_bld = gpd.GeoDataFrame(fallback_bld, geometry=gpd.points_from_xy(fallback_bld.longitude, fallback_bld.latitude), crs="EPSG:4326")
    save_gdf_as_csv(synthetic_bld, "osm_buildings.csv")


try:
    G = ox.graph_from_bbox(max_lat, min_lat, max_lon, min_lon, network_type="drive")
    gdf_roads = ox.graph_to_gdfs(G, nodes=False, edges=True)
    gdf_roads.to_file("osm_roads.geojson", driver="GeoJSON")
    save_linestrings_as_csv(gdf_roads, "osm_roads.csv")
except:
    lat_samples = np.linspace(min_lat, max_lat, 10)
    lon_samples = np.linspace(min_lon, max_lon, 10)
    lines = []
    for lat in lat_samples:
        lines.append(LineString([(min_lon, lat), (max_lon, lat)]))
    for lon in lon_samples:
        lines.append(LineString([(lon, min_lat), (lon, max_lat)]))
    synthetic_roads = gpd.GeoDataFrame(geometry=lines, crs="EPSG:4326")
    save_linestrings_as_csv(synthetic_roads, "osm_roads.csv")


try:
    shelters = ox.geometries_from_bbox(max_lat, min_lat, max_lon, min_lon, tags={"amenity": ["school", "hospital", "shelter"]})
    if not shelters.empty:
        shelters = shelters[shelters.geometry.type == "Point"].copy()
        shelters[["geometry"]].to_file("osm_shelters.geojson", driver="GeoJSON")
        save_gdf_as_csv(shelters[["geometry"]], "osm_shelters.csv")
    else:
        raise ValueError("Empty OSM result")
except:
    fallback_shel = df[df["is_water"] == False].sample(n=8)
    synthetic_shel = gpd.GeoDataFrame(fallback_shel, geometry=gpd.points_from_xy(fallback_shel.longitude, fallback_shel.latitude), crs="EPSG:4326")
    save_gdf_as_csv(synthetic_shel, "osm_shelters.csv")


buildings = pd.read_csv("osm_buildings.csv")
shelters = pd.read_csv("osm_shelters.csv")
roads = pd.read_csv("osm_roads.csv")


from scipy.spatial import cKDTree

def add_proximity_flag(df_main, df_ref, col_name, radius=0.001):
    tree = cKDTree(df_ref[["latitude", "longitude"]])
    dist, _ = tree.query(df_main[["latitude", "longitude"]], distance_upper_bound=radius)
    df_main[col_name] = dist != np.inf
    return df_main

df = add_proximity_flag(df, buildings, "has_building")
df = add_proximity_flag(df, shelters, "has_shelter")
df = add_proximity_flag(df, roads, "near_road")

df.to_csv("abm_full.csv", index=False)
print("✅ Final CSV saved: abm_full.csv")
