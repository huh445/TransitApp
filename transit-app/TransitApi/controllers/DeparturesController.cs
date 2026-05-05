using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TransitApi.Data;
using TransitApi.Models;

namespace TransitApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DeparturesController : ControllerBase
{
    private readonly AppDbContext _context;

    public DeparturesController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet("favorites/{deviceId}")]
    public async Task<IActionResult> GetDeparturesForFavorites(string deviceId)
    {
        // 1. Get the user's saved stations
        var favorites = await _context.Favorites
            .Where(f => f.UserDeviceId == deviceId)
            .ToListAsync();

        if (!favorites.Any())
        {
            return Ok(new List<object>()); // Return empty if no favorites
        }

        var results = new List<object>();

        // 2. Aggregate departures for each saved station
        foreach (var fav in favorites)
        {
            // TODO: Replace this mock with an actual call to the PTV API or your GTFS memory cache
            var stationDepartures = new
            {
                StationName = fav.StationName,
                StationId = fav.StationId,
                Departures = new[]
                {
                    new { Line = "Frankston", Destination = "Flinders Street", ScheduledTime = DateTime.UtcNow.AddMinutes(4), IsRealtime = true },
                    new { Line = "Frankston", Destination = "Flinders Street", ScheduledTime = DateTime.UtcNow.AddMinutes(12), IsRealtime = true }
                }
            };

            results.Add(stationDepartures);
        }

        // 3. Return the consolidated payload
        return Ok(results);
    }
}