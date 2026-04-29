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

var contentRoot = builder.Environment.ContentRootPath;
var gtfsPath = Path.Combine(contentRoot, "Data", "gtfs", "static", "stops.txt");

if (!File.Exists(gtfsPath))
{
    // If running from /app/out, the Data folder might be in /app
    var parentDir = Directory.GetParent(contentRoot)?.FullName;
    if (parentDir != null)
    {
        gtfsPath = Path.Combine(parentDir, "Data", "gtfs", "static", "stops.txt");
    }
}

var stops = File.Exists(gtfsPath) 
    ? GtfsParser.LoadStops(gtfsPath) 
    : new List<Stop>();

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

var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";

app.Run($"http://0.0.0.0:{port}");


// ─────────────────────────────────────────────
// TYPES
// ─────────────────────────────────────────────

record StationDto(
    string Id,
    string Name,
    string Group,
    List<string> Lines
);