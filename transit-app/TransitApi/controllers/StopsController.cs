using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TransitApi.Data;

namespace TransitApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StopsController : ControllerBase
{
    private readonly AppDbContext _context;

    public StopsController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet("search")]
    public async Task<IActionResult> SearchStops([FromQuery] string query)
    {
        if (string.IsNullOrWhiteSpace(query)) return Ok(new List<object>());

        // 1. Find all stops matching the text
        var rawStops = await _context.Stops
            .Where(s => s.Name.ToLower().Contains(query.ToLower()))
            .ToListAsync();

        // 2. Loop them into "One Big Station" by grouping them by their Parent ID
        var groupedStops = rawStops
            .GroupBy(s => !string.IsNullOrEmpty(s.ParentStation) ? s.ParentStation : s.Id)
            .Select(group => 
            {
                // Find the Parent row, or fallback to the first child if the GTFS data is broken
                var mainStop = group.FirstOrDefault(s => s.LocationType == 1) ?? group.First();
                
                return new 
                {
                    StationId = mainStop.Id,
                    StationName = mainStop.Name,
                    // Optional: Send the available platforms to the frontend just so you can see them!
                    AvailablePlatforms = group.Select(g => g.PlatformCode).Where(p => !string.IsNullOrEmpty(p)).Distinct()
                };
            })
            .ToList();

        return Ok(groupedStops);
    }
}