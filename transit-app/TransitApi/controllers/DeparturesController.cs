using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using TransitApi.Data;
using TransitRealtime; 
using ProtoBuf; 

namespace TransitApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DeparturesController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IMemoryCache _cache;
    
    private const string GtfsRealtimeUrl = "https://api.opendata.transport.vic.gov.au/opendata/public-transport/gtfs/realtime/v1/metro/trip-updates";

    public DeparturesController(AppDbContext context, IHttpClientFactory httpClientFactory, IMemoryCache cache)
    {
        _context = context;
        _httpClientFactory = httpClientFactory;
        _cache = cache;
    }

    [HttpGet("favorites/{deviceId}")]
    public async Task<IActionResult> GetDeparturesForFavorites(string deviceId)
    {
        // 1. Fetch user's saved favorites
        var favorites = await _context.Favorites
            .Where(f => f.UserDeviceId == deviceId)
            .ToListAsync();

        if (!favorites.Any())
        {
            return Ok(new List<object>());
        }

        // 2. Fetch or retrieve the live GTFS feed from the cache
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

        var results = new List<object>();
        if (feed == null) return Ok(results); 

        // 3. Pre-load all relevant static trips to avoid the N+1 database problem
        var allTripIds = feed.Entities
            .Where(e => e.TripUpdate?.Trip?.TripId != null)
            .Select(e => e.TripUpdate.Trip.TripId)
            .Distinct()
            .ToList();

        var tripLookup = await _context.Trips
            .Where(t => allTripIds.Contains(t.TripId))
            .ToDictionaryAsync(t => t.TripId);

        // 4. Process the departures for each favorite station
        foreach (var fav in favorites)
        {
            var stationDepartures = new List<object>();

            foreach (var entity in feed.Entities.Where(e => e.TripUpdate != null))
            {
                var tripUpdate = entity.TripUpdate;
                var stopUpdate = tripUpdate.StopTimeUpdates
                    .FirstOrDefault(stu => stu.StopId == fav.StationId);

                if (stopUpdate != null && stopUpdate.Departure != null)
                {
                    long posixSeconds = (long)stopUpdate.Departure.Time;
                    var scheduledTime = DateTimeOffset.FromUnixTimeSeconds(posixSeconds).UtcDateTime;

                    if (scheduledTime > DateTime.UtcNow)
                    {
                        // Instantly map the headsign from memory
                        tripLookup.TryGetValue(tripUpdate.Trip.TripId, out var tripData);

                        stationDepartures.Add(new
                        {
                            Line = tripData?.RouteId ?? tripUpdate.Trip?.RouteId ?? "Unknown",
                            Destination = tripData?.TripHeadsign ?? "Check Timetable",
                            ScheduledTime = scheduledTime,
                            Platform = stopUpdate.StopSequence.ToString() ?? "1",
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

        return Ok(results);
    }
}