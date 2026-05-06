using Microsoft.EntityFrameworkCore;
using TransitApi.Data;
using TransitApp.Utilities;

namespace TransitApi.Data;

public static class DbInitializer
{
    public static void Initialize(IApplicationBuilder app)
    {
        using var scope = app.ApplicationServices.CreateScope();
        var services = scope.ServiceProvider;
        
        try
        {
            var context = services.GetRequiredService<AppDbContext>();

            Console.WriteLine("--- Starting Database Initialization ---");

            // 1. THE NUCLEAR RESET
            // Ensuring a fresh start for every deployment
            context.Database.EnsureDeleted(); 
            context.Database.EnsureCreated(); 

            // 2. THE SEEDER
            Console.WriteLine("Database cleared. Parsing GTFS data...");
            
            var stopsPath = GtfsLoader.GetStopsPath();
            var tripsPath = GtfsLoader.GetTripsPath();

            // Verify files exist before crashing
            if (!File.Exists(stopsPath) || !File.Exists(tripsPath))
            {
                throw new FileNotFoundException("GTFS static files missing from the expected directory.");
            }

            var parsedStops = GtfsParser.LoadStops(stopsPath);
            var parsedTrips = GtfsParser.LoadTrips(tripsPath);
            
            context.Stops.AddRange(parsedStops);
            context.Trips.AddRange(parsedTrips);
            
            context.SaveChanges();
            
            Console.WriteLine($"✅ Successfully seeded {parsedStops.Count} stops.");
            Console.WriteLine($"✅ Successfully seeded {parsedTrips.Count} trips.");
            Console.WriteLine("--- Initialization Complete ---");
        }
        catch (Exception ex)
        {
            Console.WriteLine("❌ CRITICAL ERROR DURING DB INITIALIZATION:");
            Console.WriteLine(ex.Message);
            // Optionally: throw; // Re-throw if you want the app to fail to start entirely
        }
    }
}