using System;
using System.IO;

namespace TransitApp.Utilities
{
    public static class GtfsLoader
    {
        // 1. The Single Source of Truth for the folder path
        private static string GetFilePath(string fileName)
        {
            return Path.Combine(
                AppContext.BaseDirectory,
                "Data",
                "gtfs",
                "static",
                fileName
            );
        }

        // 2. The Path Resolvers
        public static string GetStopsPath()
        {
            return GetFilePath("stops.txt");
        }

        public static string GetTripsPath()
        {
            return GetFilePath("trips.txt");
        }

        // 3. The File Loaders
        public static string[] LoadStops()
        {
            var path = GetStopsPath();
            return File.ReadAllLines(path);
        }

        public static string[] LoadTrips()
        {
            var path = GetTripsPath();
            return File.ReadAllLines(path);
        }
    }
}