using System.Globalization;
using Microsoft.AspNetCore.StaticAssets;

public static class GtfsParser
{
    public static List<Stop> LoadStops(string path)
    {
        var lines = File.ReadAllLines(path);
        var header = lines[0].Split(',');

        int idIndex = Array.IndexOf(header, "stop_id");
        int nameIndex = Array.IndexOf(header, "stop_name");
        int latIndex = Array.IndexOf(header, "stop_lat");
        int lonIndex = Array.IndexOf(header, "stop_lon");

        double ParseDouble(string s) =>
            double.Parse(s.Trim('"'), CultureInfo.InvariantCulture);

        var stops = new List<Stop>();

        for (int i = 1; i < lines.Length; i++)
        {
            var parts = lines[i].Split(',');

            stops.Add(new Stop
            {
                Id = parts[idIndex],
                Name = parts[nameIndex],
                Lat = ParseDouble(parts[latIndex]),
                Lon = ParseDouble(parts[lonIndex])
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
            DirectionId = int.Parse(parts[directionIdIndex].Trim('"')),
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