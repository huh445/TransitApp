using System.Globalization;
using TransitApi.Models;
using Microsoft.AspNetCore.StaticAssets;
public static class GtfsParser
{
    public static List<Stop> LoadStops(string path)
    {
        var stops = new List<Stop>();
        var lines = File.ReadLines(path).ToList();
        if (lines.Count == 0) return stops;

        var header = SplitCsvLine(lines[0]);

        int idIndex = Array.IndexOf(header, "stop_id");
        int nameIndex = Array.IndexOf(header, "stop_name");
        int latIndex = Array.IndexOf(header, "stop_lat");
        int lonIndex = Array.IndexOf(header, "stop_lon");
        int locationTypeIndex = Array.IndexOf(header, "location_type");
        int parentStationIndex = Array.IndexOf(header, "parent_station");
        int platformCodeIndex = Array.IndexOf(header, "platform_code");

        for (int i = 1; i < lines.Count; i++)
        {
            var parts = SplitCsvLine(lines[i]);
            if (parts.Length <= Math.Max(idIndex, nameIndex)) continue;
            stops.Add(new Stop
            {
                Id = parts[idIndex].Trim('"'),
                Name = parts[nameIndex].Trim('"'),
                Lat = double.Parse(parts[latIndex].Trim('"'), CultureInfo.InvariantCulture),
                Lon = double.Parse(parts[lonIndex].Trim('"'), CultureInfo.InvariantCulture),
                
                LocationType = locationTypeIndex != -1 && int.TryParse(parts[locationTypeIndex].Trim('"'), out int locType) ? locType : 0,                            
                ParentStation = parentStationIndex != -1 ? parts[parentStationIndex].Trim('"') : "",
                PlatformCode = platformCodeIndex != -1 ? parts[platformCodeIndex].Trim('"') : ""
            });
        }

        return stops;
    }

public static List<Trip> LoadTrips(string path)
{
    var trips = new List<Trip>();
    // Using ReadLines is better for memory than ReadAllLines for large GTFS files
    var lines = File.ReadLines(path).ToList(); 
    if (lines.Count == 0) return trips;

    var header = SplitCsvLine(lines[0]);

    int tripIdIndex = Array.IndexOf(header, "trip_id");
    int routeIdIndex = Array.IndexOf(header, "route_id");
    int serviceIdIndex = Array.IndexOf(header, "service_id");
    int headsignIndex = Array.IndexOf(header, "trip_headsign");
    int directionIdIndex = Array.IndexOf(header, "direction_id");

    for (int i = 1; i < lines.Count; i++)
    {
        var parts = SplitCsvLine(lines[i]);
        if (parts.Length <= Math.Max(tripIdIndex, headsignIndex)) continue;

        trips.Add(new Trip
        {
            TripId = parts[tripIdIndex].Trim('"'),
            RouteId = parts[routeIdIndex].Trim('"'),
            ServiceId = parts[serviceIdIndex].Trim('"'),
            TripHeadsign = parts[headsignIndex].Trim('"'),
            
            // THE FIX: Safely parse the direction, defaulting to 0 if the field is empty
            DirectionId = directionIdIndex != -1 && int.TryParse(parts[directionIdIndex].Trim('"'), out int dirId) ? dirId : 0,
        });
    }

    return trips;
}

    // Helper to handle commas inside quotes
    private static string[] SplitCsvLine(string line)
    {
        return System.Text.RegularExpressions.Regex.Split(line, ",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)");
    }
}