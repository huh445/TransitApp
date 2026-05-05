using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using TransitApi.Data;
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

    public async Task<List<object>> GetDeparturesForDeviceAsync(string deviceId)
    {
        var results = new List<object>();

        // 1. Fetch user's saved favorites
        var favorites = await _context.Favorites
            .Where(f => f.UserDeviceId == deviceId)
            .ToListAsync();

        if (!favorites.Any()) return results;

        // 2. Fetch all child stops/platforms for the favorite stations
        var favoriteStationIds = favorites.Select(f => f.StationId).ToList();

        var childStops = await _context.Stops
            .Where(s => favoriteStationIds.Contains(s.ParentStation) || favoriteStationIds.Contains(s.Id))
            .ToListAsync();

        // Map which Stop IDs (platforms) belong to which Favorite Station (Parent) for instant lookup
        var validStopsForFavorite = favorites.ToDictionary(
            fav => fav.StationId,
            fav => childStops
                .Where(cs => cs.ParentStation == fav.StationId || cs.Id == fav.StationId)
                .Select(cs => cs.Id)
                .ToHashSet()
        );

        // 3. Fetch or retrieve the live GTFS feed from the cache
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
                // Cache for 30 seconds to prevent rate-limiting and improve performance
                _cache.Set("GtfsTripUpdates", feed, TimeSpan.FromSeconds(30));
            }
        }

        if (feed == null) return results;

        // 4. Pre-load all relevant static trips to avoid the N+1 database problem
        var allTripIds = feed.Entities
            .Where(e => e.TripUpdate?.Trip?.TripId != null)
            .Select(e => e.TripUpdate.Trip.TripId)
            .Distinct()
            .ToList();

        var tripLookup = await _context.Trips
            .Where(t => allTripIds.Contains(t.TripId))
            .ToDictionaryAsync(t => t.TripId);

        // 5. Process the departures for each favorite station
        foreach (var fav in favorites)
        {
            var stationDepartures = new List<object>();
            var validStopIds = validStopsForFavorite[fav.StationId];

            foreach (var entity in feed.Entities.Where(e => e.TripUpdate != null))
            {
                var tripUpdate = entity.TripUpdate;
                
                // Match if the train is stopping at ANY of the valid child platforms
                var stopUpdate = tripUpdate.StopTimeUpdates
                    .FirstOrDefault(stu => validStopIds.Contains(stu.StopId));

                if (stopUpdate != null && stopUpdate.Departure != null)
                {
                    long posixSeconds = (long)stopUpdate.Departure.Time;
                    var scheduledTime = DateTimeOffset.FromUnixTimeSeconds(posixSeconds).UtcDateTime;

                    if (scheduledTime > DateTime.UtcNow)
                    {
                        // Instantly map the headsign from memory
                        tripLookup.TryGetValue(tripUpdate.Trip.TripId, out var tripData);

                        // Get the actual platform code from our pre-loaded child stops
                        var actualStop = childStops.FirstOrDefault(cs => cs.Id == stopUpdate.StopId);
                        string platform = !string.IsNullOrWhiteSpace(actualStop?.PlatformCode) 
                            ? actualStop.PlatformCode 
                            : stopUpdate.StopSequence.ToString() ?? "1";

                        stationDepartures.Add(new
                        {
                            Line = tripData?.RouteId ?? tripUpdate.Trip?.RouteId ?? "Unknown",
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
                StationName = fav.StationName,
                StationId = fav.StationId,
                Departures = stationDepartures.OrderBy(d => ((dynamic)d).ScheduledTime).Take(5)
            });
        }

        return results;
    }
}