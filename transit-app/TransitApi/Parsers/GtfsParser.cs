using System.Globalization;
using TransitApi.Models;
using Microsoft.AspNetCore.StaticAssets;
public static class GtfsParser
{
    public static List<Stop> LoadStops(string path)
    {
        var rawStops = new List<Stop>();
        var lines = File.ReadLines(path).ToList();
        if (lines.Count == 0) return rawStops;

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

            // --- THE RAIL FILTER ---
            string stopId = parts[idIndex].Trim('"');
            
            // This ensures we ONLY capture Melbourne rail stations and platforms
            if (!stopId.StartsWith("vic:rail:")) continue;

            rawStops.Add(new Stop
            {
                Id = stopId,
                Name = parts[nameIndex].Trim('"'),
                Lat = double.Parse(parts[latIndex].Trim('"'), CultureInfo.InvariantCulture),
                Lon = double.Parse(parts[lonIndex].Trim('"'), CultureInfo.InvariantCulture),
                LocationType = locationTypeIndex != -1 && int.TryParse(parts[locationTypeIndex].Trim('"'), out int locType) ? locType : 0,
                ParentStation = parentStationIndex != -1 ? parts[parentStationIndex].Trim('"') : "",
                PlatformCode = platformCodeIndex != -1 ? parts[platformCodeIndex].Trim('"') : ""
            });
        }

        // --- THE HIERARCHY PHASE (Remains the same, but now only processes Rail) ---
        var cleanedStops = new List<Stop>();

        // 1. Identify all official Parent Stations (LocationType = 1)
        var parentStations = rawStops
            .Where(s => s.LocationType == 1 && !string.IsNullOrEmpty(s.Id))
            .GroupBy(s => s.Id) 
            .Select(g => g.First())
            .ToList();

        var validParentIds = parentStations.Select(p => p.Id).ToHashSet();

        // 2. Identify all valid Child Platforms (LocationType = 0) linked to a Rail Parent
        var childPlatforms = rawStops
            .Where(s => s.LocationType == 0 && validParentIds.Contains(s.ParentStation))
            .GroupBy(s => s.Id)
            .Select(g => g.First())
            .ToList();

        // 3. Keep standalone stops (LocationType = 0) with no parent
        var standaloneStops = rawStops
            .Where(s => s.LocationType == 0 && string.IsNullOrEmpty(s.ParentStation))
            .GroupBy(s => s.Id)
            .Select(g => g.First())
            .ToList();

        cleanedStops.AddRange(parentStations);
        cleanedStops.AddRange(childPlatforms);
        cleanedStops.AddRange(standaloneStops);

        return cleanedStops;
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

    public static void LoadStopTimeStreaming(string path, TransitApi.Data.AppDbContext context)
    {
        // 1. Check if file exists
        if (!File.Exists(path)) return;

        using var reader = new StreamReader(path);
        string? headerLine = reader.ReadLine();
        if (headerLine == null) return;

        var header = SplitCsvLine(headerLine);
        int tripIdIndex = Array.IndexOf(header, "trip_id");
        int stopIdIndex = Array.IndexOf(header, "stop_id");
        int stopSequenceIndex = Array.IndexOf(header, "stop_sequence");
        int arrivalTimeIndex = Array.IndexOf(header, "arrival_time");

        var buffer = new List<StopTime>();
        int totalCount = 0;

        Console.WriteLine("Streaming stop_times.txt to database...");

        while (!reader.EndOfStream)
        {
            var line = reader.ReadLine();
            if (string.IsNullOrWhiteSpace(line)) continue;

            var parts = SplitCsvLine(line);
            if (parts.Length <= Math.Max(tripIdIndex, stopSequenceIndex)) continue;

            buffer.Add(new StopTime
            {
                TripId = parts[tripIdIndex].Trim('"'),
                StopId = parts[stopIdIndex].Trim('"'),
                StopSequence = int.TryParse(parts[stopSequenceIndex].Trim('"'), out int seq) ? seq : 0,
                ArrivalTime = parts[arrivalTimeIndex].Trim('"')
            });

            // 2. The Secret Sauce: Batch Saving
            // We save every 10,000 rows so we don't blow up the RAM
            if (buffer.Count >= 10000)
            {
                context.StopTime.AddRange(buffer);
                context.SaveChanges();
                totalCount += buffer.Count;
                buffer.Clear();
                Console.WriteLine($"Seeded {totalCount} stop times...");
            }
        }

        // Save the final remaining rows
        if (buffer.Count > 0)
        {
            context.StopTime.AddRange(buffer);
            context.SaveChanges();
            totalCount += buffer.Count;
        }

        Console.WriteLine($"✅ Successfully finished seeding {totalCount} total stop times.");
    }

    // Helper to handle commas inside quotes
    private static string[] SplitCsvLine(string line)
    {
        return System.Text.RegularExpressions.Regex.Split(line, ",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)");
    }
}