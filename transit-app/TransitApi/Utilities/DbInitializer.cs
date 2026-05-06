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
            context.Database.EnsureDeleted(); 
            context.Database.EnsureCreated(); 

            // 2. FILE PATHS
            var stopsPath = GtfsLoader.GetStopsPath();
            var tripsPath = GtfsLoader.GetTripsPath();
            // ✅ FIXED: Now pointing to the correct file
            var stopTimePath = GtfsLoader.GetStopTimePath(); 

            if (!File.Exists(stopsPath) || !File.Exists(tripsPath) || !File.Exists(stopTimePath))
            {
                throw new FileNotFoundException("GTFS static files missing. Check your Data/gtfs/static folder.");
            }

            // 3. PARSING & SEEDING
            Console.WriteLine("Parsing Stops and Trips...");
            var parsedStops = GtfsParser.LoadStops(stopsPath);
            var parsedTrips = GtfsParser.LoadTrips(tripsPath);
            
            context.Stops.AddRange(parsedStops);
            context.Trips.AddRange(parsedTrips);
            context.SaveChanges(); // Save these first to keep things clean

            // 4. STREAMING STOP TIMES
            // We use the streaming method here because this file is 1M+ rows
            GtfsParser.LoadStopTimeStreaming(stopTimePath, context);
            
            Console.WriteLine("--- Initialization Complete ---");
        }
        catch (Exception ex)
        {
            Console.WriteLine("❌ CRITICAL ERROR DURING DB INITIALIZATION:");
            Console.WriteLine(ex.Message);
            Console.WriteLine(ex.StackTrace); // Added this so you can see exactly where it fails
        }
    }
}