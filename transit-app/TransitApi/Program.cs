using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.EntityFrameworkCore;
using TransitApi.Data;

// ─────────────────────────────────────────────
// CREATE BUILDER
// ─────────────────────────────────────────────
var builder = WebApplication.CreateBuilder(args);

// ✅ Railway port binding (MUST be before Build)
var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";
builder.WebHost.ConfigureKestrel(options =>
{
    options.ListenAnyIP(int.Parse(port));
});

// ─────────────────────────────────────────────
// SERVICES (ALL must be before Build)
// ─────────────────────────────────────────────
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader());
});

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlite("Data Source=transit.db"));

// ─────────────────────────────────────────────
// BUILD APP (locks services)
// ─────────────────────────────────────────────
var app = builder.Build();

// ─────────────────────────────────────────────
// MIDDLEWARE
// ─────────────────────────────────────────────
app.UseCors("AllowAll");

// ─────────────────────────────────────────────
// DATABASE INIT
// ─────────────────────────────────────────────
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();
}

// ─────────────────────────────────────────────
// LOAD GTFS DATA
// ─────────────────────────────────────────────
var contentRoot = builder.Environment.ContentRootPath;
var gtfsPath = Path.Combine(contentRoot, "Data", "gtfs", "static", "stops.txt");

if (!File.Exists(gtfsPath))
{
    var parentDir = Directory.GetParent(contentRoot)?.FullName;
    if (parentDir != null)
    {
        gtfsPath = Path.Combine(parentDir, "Data", "gtfs", "static", "stops.txt");
    }
}

var stops = File.Exists(gtfsPath)
    ? GtfsParser.LoadStops(gtfsPath)
    : new List<Stop>();

// ─────────────────────────────────────────────
// API ENDPOINTS
// ─────────────────────────────────────────────

// All stops
app.MapGet("/api/stops", () => Results.Ok(stops));

// Search stops
app.MapGet("/api/stops/search", (string? q) =>
{
    if (string.IsNullOrWhiteSpace(q))
        return Results.Ok(stops);

    return Results.Ok(
        stops.Where(s => s.Name.Contains(q, StringComparison.OrdinalIgnoreCase))
    );
});

// Favorites
app.MapGet("/api/favorites/{deviceId}", async (string deviceId, AppDbContext db) =>
    await db.Favorites.Where(f => f.UserDeviceId == deviceId).ToListAsync());

app.MapPost("/api/favorites", async (Favorite fav, AppDbContext db) =>
{
    db.Favorites.Add(fav);
    await db.SaveChangesAsync();
    return Results.Created($"/api/favorites/{fav.Id}", fav);
});

// ─────────────────────────────────────────────
// RUN APP
// ─────────────────────────────────────────────
app.Run();

// ─────────────────────────────────────────────
// TYPES
// ─────────────────────────────────────────────
record StationDto(
    string Id,
    string Name,
    string Group,
    List<string> Lines
);