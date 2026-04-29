using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.EntityFrameworkCore;
using TransitApi.Data;
using Microsoft.AspNetCore.Mvc.Routing;


// Create Builder
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
});

// Initialise Database
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlite("Data Source=transit.db"));

var app = builder.Build();
app.UseCors("AllowAll");

// Create Database
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();
}

var gtfsPath = Path.Combine(AppContext.BaseDirectory, "Data", "gtfs", "static", "stops.txt");

var stops = GtfsParser.LoadStops(gtfsPath);

// Api Endpoints
app.MapGet("/api/stops", () => Results.Ok(stops));

app.MapGet("/api/stops/search", (string? q) =>
{
    if (string.IsNullOrWhiteSpace(q))
        return Results.Ok(stops);

    return Results.Ok(
        stops.Where(s => s.Name.Contains(q, StringComparison.OrdinalIgnoreCase))
    );
});

// Favorite Api Endpoints
app.MapGet("/api/favorites/{deviceId}", async (string deviceId, AppDbContext db) =>
    await db.Favorites.Where(f => f.UserDeviceId == deviceId).ToListAsync());

app.MapPost("/api/favorites", async (Favorite fav, AppDbContext db) =>
{
    db.Favorites.Add(fav);
    await db.SaveChangesAsync();
    return Results.Created($"/api/favorites/{fav.Id}", fav);
});

// Replace app.Run("http://0.0.0.0:5241"); with:
var port = Environment.GetEnvironmentVariable("PORT") ?? "5241";
app.Run($"http://0.0.0.0:{port}");


// ─────────────────────────────────────────────
// TYPES (MUST BE AT THE BOTTOM)
// ─────────────────────────────────────────────

record StationDto(
    string Id,
    string Name,
    string Group,
    List<string> Lines
);