using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TransitApi.Data;

namespace TransitApi.Controllers;


[ApiController]
[Route("api/[controller]")]

public class TripsController : ControllerBase
{
    private readonly AppDbContext _context;
    public TripsController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet("{tripId}/pattern")]
    public async Task<IActionResult> GetStoppingPattern(string tripId)
    {
        var pattern = await _context.StopTime
            .Where(st => st.TripId == tripId)
            .OrderBy(st => st.StopSequence)
            .Join(_context.Stops, 
                st => st.StopId, 
                s => s.Id, 
                (st, s) => new { 
                    st.StopSequence, 
                    StationName = s.Name, 
                    st.ArrivalTime 
                })
            .ToListAsync();

        return Ok(pattern);
    }
}