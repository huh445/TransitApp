using System.Globalization;

public static class GtfsParser
{
    public static List<Stop> LoadStops(string path)
    {
        var lines = File.ReadAllLines(path);
        var header = lines[0].Split(",");
        

        int idIndex = Array.IndexOf(header, "stop_id");
        int nameIndex = Array.IndexOf(header, "stop_name");
        int latIndex = Array.IndexOf(header, "stop_lat");
        int lonIndex = Array.IndexOf(header, "stop_lon");

        var stops = new List<Stop>();

        for (int i = 1; i < lines.Length; i++)
        {
            var parts = lines[i].Split(",");

            stops.Add(new Stop
            {
                Id = parts[idIndex],
                Name = parts[nameIndex],
                Lat = double.Parse(parts[latIndex], CultureInfo.InvariantCulture),
                Lon = double.Parse(parts[lonIndex], CultureInfo.InvariantCulture)
            });
        }

        return stops;
    }
}