using Microsoft.AspNetCore.Mvc;
using TransitApi.Services;

namespace TransitApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DeparturesController : ControllerBase
{
    private readonly IDeparturesService _departuresService;

    // We only inject the Service now. The controller doesn't need to know about the Database or the Cache.
    public DeparturesController(IDeparturesService departuresService)
    {
        _departuresService = departuresService;
    }

    [HttpGet("favorites/{deviceId}")]
    public async Task<IActionResult> GetDeparturesForFavorites(string deviceId)
    {
        // The controller simply asks the service for the data, and returns it.
        var results = await _departuresService.GetDeparturesForDeviceAsync(deviceId);
        
        return Ok(results);
    }
}