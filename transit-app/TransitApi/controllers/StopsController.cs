using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TransitApi.Data;
using TransitApi.Models;

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

    // GET: /api/stops
    [HttpGet]
    public async Task<IActionResult> GetAllStops()
    {
        var allData = await _context.Stops.ToListAsync();
        return Ok(CleanAndGroupStops(allData));
    }

    // GET: /api/stops/search?query=flagstaff
    [HttpGet("search")]
    public async Task<IActionResult> SearchStops([FromQuery] string query)
    {
        if (string.IsNullOrWhiteSpace(query)) return Ok(new List<object>());

        var matches = await _context.Stops
            .Where(s => s.Name.ToLower().Contains(query.ToLower()))
            .ToListAsync();

        return Ok(CleanAndGroupStops(matches));
    }

    // --- PRIVATE HELPER: The "Nuclear Option" Logic ---
    private List<object> CleanAndGroupStops(List<Stop> rawList)
    {
        return rawList
            .GroupBy(s => s.Name.Trim()) 
            .Select(group => 
            {
                // Prioritize the Parent Station (LocationType 1) as the main record
                var mainStop = group.OrderByDescending(s => s.LocationType).First();
                
                return new 
                {
                    StationId = mainStop.Id,
                    StationName = mainStop.Name,
                    // Collect unique platforms for this station name
                    AvailablePlatforms = group.Select(g => g.PlatformCode)
                                              .Where(p => !string.IsNullOrWhiteSpace(p))
                                              .Distinct()
                                              .OrderBy(p => p)
                                              .ToList()
                };
            })
            .OrderBy(s => s.StationName)
            .Cast<object>()
            .ToList();
    }
}