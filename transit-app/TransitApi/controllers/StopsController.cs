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

    // 2. THE NUCLEAR OPTION: Group by the actual human-readable name!
    var groupedStops = rawStops
        .GroupBy(s => s.Name.Trim()) 
        .Select(group => 
        {
            // OrderByDescending puts LocationType 1 (Parents) at the top of the group.
            // We grab the first one to serve as our "Main" ID for this station name.
            var mainStop = group.OrderByDescending(s => s.LocationType).First();
            
            return new 
            {
                StationId = mainStop.Id,
                StationName = mainStop.Name,
                // Collect all available platforms from the squashed duplicates
                AvailablePlatforms = group.Select(g => g.PlatformCode)
                                          .Where(p => !string.IsNullOrWhiteSpace(p))
                                          .Distinct()
                                          .OrderBy(p => p)
                                          .ToList()
            };
        })
        .OrderBy(s => s.StationName) // Sort alphabetically for a clean UI
        .Take(20) // Prevent the frontend from lagging if they just search "Station"
        .ToList();

    return Ok(groupedStops);
}
}