using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

// ─────────────────────────────────────────────
// TOP-LEVEL EXECUTION CODE (MUST COME FIRST)
// ─────────────────────────────────────────────

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
});

var app = builder.Build();

app.UseCors("AllowAll");

var gtfsPath = Path.Combine(AppContext.BaseDirectory, "Data", "gtfs", "static", "stops.txt");

var stops = GtfsParser.LoadStops(gtfsPath);

app.MapGet("/api/stops", () => Results.Ok(stops));

app.MapGet("/api/stops/search", (string? q) =>
{
    if (string.IsNullOrWhiteSpace(q))
        return Results.Ok(stops);

    return Results.Ok(
        stops.Where(s => s.Name.Contains(q, StringComparison.OrdinalIgnoreCase))
    );
});

app.Run("http://0.0.0.0:5241");


// ─────────────────────────────────────────────
// TYPES (MUST BE AT THE BOTTOM)
// ─────────────────────────────────────────────

record StationDto(
    string Id,
    string Name,
    string Group,
    List<string> Lines
);