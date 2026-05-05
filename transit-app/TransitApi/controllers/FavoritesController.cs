using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TransitApi.Data;
using TransitApi.Models;

namespace TransitApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class FavoritesController : ControllerBase
{
    private readonly AppDbContext _context;

    public FavoritesController(AppDbContext context)
    {
        _context = context;
    }

    [HttpGet("{deviceId}")]
    public async Task<ActionResult<IEnumerable<Favorite>>> GetFavorites(string deviceId)
    {
        return await _context.Favorites.Where(f => f.UserDeviceId == deviceId).ToListAsync();
    }
    
[HttpPost]
public async Task<ActionResult<Favorite>> PostFavorite(Favorite favorite)
{
    // Sanitize the inputs by removing double and single quotes
    if (!string.IsNullOrEmpty(favorite.StationName))
    {
        favorite.StationName = favorite.StationName.Replace("\"", "").Replace("'", "");
    }

    if (!string.IsNullOrEmpty(favorite.StationId))
    {
        favorite.StationId = favorite.StationId.Replace("\"", "").Replace("'", "");
    }

    _context.Favorites.Add(favorite);
    await _context.SaveChangesAsync();
    
    return Ok(favorite);
}

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteFavorite(int id)
    {
        var favorite = await _context.Favorites.FindAsync(id);
        if (favorite == null) return NotFound();

        _context.Favorites.Remove(favorite);
        await _context.SaveChangesAsync();
        return NoContent();
    }
}