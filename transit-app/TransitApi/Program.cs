using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.EntityFrameworkCore;
using TransitApi.Data;

// ─────────────────────────────────────────────
// CREATE BUILDER
// ─────────────────────────────────────────────
var builder = WebApplication.CreateBuilder(args);

var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";

builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

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

var dbPath = Path.Combine(AppContext.BaseDirectory, "transit.db");
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlite($"Data Source={dbPath}"));

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
var baseDir = AppContext.BaseDirectory;
var contentRoot = builder.Environment.ContentRootPath;

var gtfsPath = new[]
{
    Path.Combine(baseDir, "Data", "gtfs", "static", "stops.txt"),
    Path.Combine(contentRoot, "Data", "gtfs", "static", "stops.txt"),
    Path.Combine(Directory.GetParent(contentRoot)?.FullName ?? "", "Data", "gtfs", "static", "stops.txt")
}
.FirstOrDefault(File.Exists);

var stops = gtfsPath != null
    ? GtfsParser.LoadStops(gtfsPath)
    : new List<Stop>();

// ─────────────────────────────────────────────
// API ENDPOINTS
// ─────────────────────────────────────────────

// Debug (remove after confirming Railway works)
app.MapGet("/api/debug", () => new {
    StopsLoaded = stops.Count,
    GtfsPathUsed = gtfsPath ?? "NOT FOUND",
    BaseDir = AppContext.BaseDirectory,
    ContentRoot = contentRoot,
    FilesInBaseDir = Directory.Exists(Path.Combine(AppContext.BaseDirectory, "Data"))
        ? Directory.GetFiles(Path.Combine(AppContext.BaseDirectory, "Data"), "*.txt", SearchOption.AllDirectories)
        : Array.Empty<string>()
});

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