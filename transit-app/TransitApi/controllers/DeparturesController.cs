using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using TransitApi.Data;
using TransitRealtime;
using ProtoBuf; // <-- Required for Serializer.Deserialize

namespace TransitApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DeparturesController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IMemoryCache _cache;
    
    private const string GtfsRealtimeUrl = "https://opendata.transport.vic.gov.au/dataset/2d9a7228-5b81-40d3-8075-ae7a3da42198/resource/0010d606-47bf-4abb-a04f-63add63a4d23/download/gtfsr_metro_train_trip_updates.openapi.json";

    public DeparturesController(AppDbContext context, IHttpClientFactory httpClientFactory, IMemoryCache cache)
    {
        _context = context;
        _httpClientFactory = httpClientFactory;
        _cache = cache;
    }

    [HttpGet("favorites/{deviceId}")]
    public async Task<IActionResult> GetDeparturesForFavorites(string deviceId)
    {
        var favorites = await _context.Favorites
            .Where(f => f.UserDeviceId == deviceId)
            .ToListAsync();

        if (!favorites.Any())
        {
            return Ok(new List<object>());
        }

        if (!_cache.TryGetValue("GtfsTripUpdates", out FeedMessage? feed) || feed == null)
        {
            var client = _httpClientFactory.CreateClient();
            var response = await client.GetAsync(GtfsRealtimeUrl);
            response.EnsureSuccessStatusCode();

            await using var stream = await response.Content.ReadAsStreamAsync();
            
            // FIX 1: Use protobuf-net Serializer instead of Parser
            feed = Serializer.Deserialize<FeedMessage>(stream);

            if (feed != null)
            {
                _cache.Set("GtfsTripUpdates", feed, TimeSpan.FromSeconds(30));
            }
        }

        var results = new List<object>();

        // Safety check in case the feed couldn't be parsed
        if (feed == null) return Ok(results); 

        foreach (var fav in favorites)
        {
            var stationDepartures = new List<object>();

            foreach (var entity in feed.Entities.Where(e => e.TripUpdate != null))
            {
                var tripUpdate = entity.TripUpdate;
                
                // FIX 2: Added the 's' to StopTimeUpdates
                var stopUpdate = tripUpdate.StopTimeUpdates
                    .FirstOrDefault(stu => stu.StopId == fav.StationId);

                if (stopUpdate != null && stopUpdate.Departure != null)
                {
                    // Some GTFS-R feeds use ulong for Time, cast to long to be safe
                    long posixSeconds = (long)stopUpdate.Departure.Time;
                    var scheduledTime = DateTimeOffset.FromUnixTimeSeconds(posixSeconds).UtcDateTime;

                    if (scheduledTime > DateTime.UtcNow)
                    {
                        stationDepartures.Add(new
                        {
                            Line = tripUpdate.Trip?.RouteId ?? "Unknown", 
                            Destination = "Check Timetable", 
                            ScheduledTime = scheduledTime,
                            Platform = "1", 
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