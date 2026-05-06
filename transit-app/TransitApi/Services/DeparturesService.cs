using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using TransitApi.Data;
using TransitApi.Models; // Ensure this matches where your Favorite class is
using TransitRealtime;
using ProtoBuf;

namespace TransitApi.Services;

public class DeparturesService : IDeparturesService
{
    private readonly AppDbContext _context;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IMemoryCache _cache;
    
    private const string GtfsRealtimeUrl = "https://api.opendata.transport.vic.gov.au/opendata/public-transport/gtfs/realtime/v1/metro/trip-updates";

    public DeparturesService(AppDbContext context, IHttpClientFactory httpClientFactory, IMemoryCache cache)
    {
        _context = context;
        _httpClientFactory = httpClientFactory;
        _cache = cache;
    }

    // --- PUBLIC METHOD 1: For the React Native Favorites Tab ---
    public async Task<List<object>> GetDeparturesForDeviceAsync(string deviceId)
    {
        var favorites = await _context.Favorites
            .Where(f => f.UserDeviceId == deviceId)
            .ToListAsync();

        if (!favorites.Any()) return new List<object>();

        return await ProcessDeparturesAsync(favorites);
    }

    // --- PUBLIC METHOD 2: For Direct Testing & Single Station Views ---
    public async Task<object?> GetDeparturesForStationAsync(string stationId)
    {
        // 1. Defeat the invisible whitespace bug
        var cleanId = stationId.Trim();
        // Check if the ID matches exactly, or if it matches when spaces are stripped
        var station = await _context.Stops.FirstOrDefaultAsync(s => s.Id == cleanId);
        
        if (station == null) 
        {
            // Now we know for a FACT it isn't in the DB
            return new { Error = $"Literally could not find ID '{cleanId}' in the Stops table." };
        }

        var dummyFavoriteList = new List<Favorite>
        {
            new Favorite { StationId = station.Id, StationName = station.Name }
        };

        var results = await ProcessDeparturesAsync(dummyFavoriteList);
        var finalResult = results.FirstOrDefault();
        
        // 2. Defeat the Null Trap
        if (finalResult == null)
        {
            return new 
            { 
                StationName = station.Name, 
                StationId = station.Id, 
                Departures = new List<object>(),
                DebugMessage = "SUCCESS: Station found in DB, but no trains matched in the live feed or cache right now."
            };
        }
        return finalResult;
    }


    // --- THE CORE ENGINE (Private) ---
    private async Task<List<object>> ProcessDeparturesAsync(List<Favorite> stationsToProcess)
    {
        var results = new List<object>();

        // 1. Cached Family Tree Dictionary
        if (!_cache.TryGetValue("StationPlatformCache", out Dictionary<string, Dictionary<string, string>>? stationPlatformCache) || stationPlatformCache == null)
        {
            var allStops = await _context.Stops.ToListAsync();
            
            stationPlatformCache = allStops
                .GroupBy(s => !string.IsNullOrEmpty(s.ParentStation) ? s.ParentStation : s.Id)
                .ToDictionary(
                    group => group.Key, 
                    group => group.ToDictionary(
                        s => s.Id, 
                        s => s.PlatformCode ?? "" 
                    )
                );

            _cache.Set("StationPlatformCache", stationPlatformCache, TimeSpan.FromHours(24));
        }

        // 2. Fetch or retrieve the live GTFS feed
        if (!_cache.TryGetValue("GtfsTripUpdates", out FeedMessage? feed) || feed == null)
        {
            var client = _httpClientFactory.CreateClient();
            client.DefaultRequestHeaders.Add("KeyId", "f1be977e-232e-4e58-888e-ba9ad550c798");
            client.DefaultRequestHeaders.Add("accept", "*/*");

            var response = await client.GetAsync(GtfsRealtimeUrl);
            response.EnsureSuccessStatusCode();

            await using var stream = await response.Content.ReadAsStreamAsync();
            feed = Serializer.Deserialize<FeedMessage>(stream);

            if (feed != null)
            {
                _cache.Set("GtfsTripUpdates", feed, TimeSpan.FromSeconds(30));
            }
        }

        if (feed == null) return results;

        // 3. Pre-load static trips
        var allTripIds = feed.Entities
            .Where(e => e.TripUpdate?.Trip?.TripId != null)
            .Select(e => e.TripUpdate.Trip.TripId)
            .Distinct()
            .ToList();

        var tripLookup = await _context.Trips
            .Where(t => allTripIds.Contains(t.TripId))
            .ToDictionaryAsync(t => t.TripId);

        // 4. Process the departures using memory dictionary
        foreach (var reqStation in stationsToProcess)
        {
            var stationDepartures = new List<object>();
            
            if (!stationPlatformCache.TryGetValue(reqStation.StationId, out var childPlatforms)) continue;

            foreach (var entity in feed.Entities.Where(e => e.TripUpdate != null))
            {
                var tripUpdate = entity.TripUpdate;
                
                var stopUpdate = tripUpdate.StopTimeUpdates
                    .FirstOrDefault(stu => childPlatforms.ContainsKey(stu.StopId));

                if (stopUpdate != null && stopUpdate.Departure != null)
                {
                    long posixSeconds = (long)stopUpdate.Departure.Time;
                    var scheduledTime = DateTimeOffset.FromUnixTimeSeconds(posixSeconds).UtcDateTime;

                    if (scheduledTime > DateTime.UtcNow)
                    {
                        tripLookup.TryGetValue(tripUpdate.Trip.TripId, out var tripData);

                        string actualPlatformCode = childPlatforms[stopUpdate.StopId];
                        string platform = !string.IsNullOrWhiteSpace(actualPlatformCode) 
                            ? actualPlatformCode 
                            : stopUpdate.StopSequence.ToString() ?? "1";

                        stationDepartures.Add(new
                        {
                            Line = tripData?.RouteId ?? tripUpdate.Trip?.RouteId ?? "Unknown",
                            TripId = tripData?.TripId ?? "TripId Unknown",
                            Destination = tripData?.TripHeadsign ?? "Check Timetable",
                            ScheduledTime = scheduledTime,
                            Platform = platform,
                            IsRealtime = true
                        });
                    }
                }
            }

            results.Add(new
            {
                StationName = reqStation.StationName,
                StationId = reqStation.StationId,
                Departures = stationDepartures.OrderBy(d => ((dynamic)d).ScheduledTime).ToList()
            });
        }

        return results;
    }
}