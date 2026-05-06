using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.EntityFrameworkCore;
using TransitApi.Data;
using TransitApi.Models;
using TransitApi.Controllers;
using TransitApi.Services;
using TransitApp.Utilities; // Added this so it can find your GtfsLoader

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
builder.Services.AddScoped<IDeparturesService, DeparturesService>();
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
// This one line replaces that whole block of code
DbInitializer.Initialize(app);

app.Run();