using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.EntityFrameworkCore;
using TransitApi.Data;
using TransitApi.Models;
using TransitApi.Controllers;

// ─────────────────────────────────────────────
// CREATE BUILDER
// ─────────────────────────────────────────────
var builder = WebApplication.CreateBuilder(args);

var port = Environment.GetEnvironmentVariable("PORT") ?? "8080";

builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

// ─────────────────────────────────────────────
// SERVICES (ALL must be before Build)
// ─────────────────────────────────────────────
builder.Services.AddControllers();
builder.Services.AddHttpClient();
builder.Services.AddMemoryCache();

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
app.MapControllers();

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
    Path.Combine(baseDir, "Data", "gtfs", "static"),
    Path.Combine(contentRoot, "Data", "gtfs", "static"),
    Path.Combine(Directory.GetParent(contentRoot)?.FullName ?? "", "Data", "gtfs", "static")
}
.FirstOrDefault(Directory.Exists);

var stops = gtfsPath != null
    ? GtfsParser.LoadStops(Path.Combine(gtfsPath, "stops.txt"))
    : new List<Stop>();

var trips = gtfsPath != null
    ? GtfsParser.LoadTrips(Path.Combine(gtfsPath, "trips.txt"))
    : new List<Trip>();

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