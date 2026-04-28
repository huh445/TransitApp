using System.Globalization;

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
}