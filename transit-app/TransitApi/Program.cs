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

app.Run();


// ─────────────────────────────────────────────
// TYPES (MUST BE AT THE BOTTOM)
// ─────────────────────────────────────────────

record StationDto(
    string Id,
    string Name,
    string Group,
    List<string> Lines
);