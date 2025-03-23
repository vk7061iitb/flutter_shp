# Flutter ShapeFile Plotter
A Flutter application that reads and plots `shapefiles` on a map using the flutter_map package.

## Overview
This project is designed to parse shapefiles (which are binary files) and convert them into a format that can be rendered on a map. Since flutter_map and similar packages do not support shapefiles directly, this app acts as an intermediate layer to read, process, and visualize geographic data.

## Features
- Read and parse shapefiles (.shp)
- Convert shapefile data into a format compatible with flutter_map
- Render geographic data dynamically on an interactive map
- Acts as a foundation for a larger project aimed at developing a Dart package for shapefile-to-GeoJSON conversion

## Future Scope
- This project serves as a stepping stone towards building a Dart package that can:
- Convert shapefiles to GeoJSON or other widely used geospatial formats
- Provide an efficient API for handling shapefiles in Flutter apps
- Offer compatibility with multiple map-rendering libraries