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
        // We group EVERYTHING so the main list is also duplicate-free
        return Ok(FormatStops(allData));
    }

    // GET: /api/stops/search?query=flagstaff
    [HttpGet("search")]
    public async Task<IActionResult> SearchStops([FromQuery] string query)
    {
        if (string.IsNullOrWhiteSpace(query)) return Ok(new List<object>());

        var matches = await _context.Stops
            .Where(s => s.Name.ToLower().Contains(query.ToLower()))
            .ToListAsync();

        return Ok(FormatStops(matches));
    }

    // --- THE UNIFIER ---
    // This forces all outputs to use lowercase 'id' and 'name'
    private List<object> FormatStops(List<Stop> rawList)
    {
        return rawList
            .GroupBy(s => s.Name.Trim()) 
            .Select(group => 
            {
                var mainStop = group.OrderByDescending(s => s.LocationType).First();
                
                return new 
                {
                    id = mainStop.Id,    // Lowercase to match your Station interface
                    name = mainStop.Name, // Lowercase to match your Station interface
                    availablePlatforms = group.Select(g => g.PlatformCode)
                                              .Where(p => !string.IsNullOrWhiteSpace(p))
                                              .Distinct()
                                              .OrderBy(p => p)
                                              .ToList()
                };
            })
            .OrderBy(s => s.name)
            .Cast<object>()
            .ToList();
    }
}