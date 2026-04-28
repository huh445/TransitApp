using System;
using System.IO;

namespace TransitApp.Utilities
{
    public static class GtfsLoader
    {
        public static string GetStopsPath()
        {
            return Path.Combine(
                AppContext.BaseDirectory,
                "Data",
                "gtfs",
                "static",
                "stops.txt"
            );
        }

        public static string[] LoadStops()
        {
            var path = GetStopsPath();
            return File.ReadAllLines(path);
        }
    }
}