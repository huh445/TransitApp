using Microsoft.EntityFrameworkCore;

namespace TransitApi.Data;

public class Favorite
{
    public int Id {get; set;}
    public string UserDeviceId {get; set;} = string.Empty;
    public string StationId {get; set;} = string.Empty;
    public string StationName {get; set;} = string.Empty;
    public string DestinationStationId {get; set;} = string.Empty;
}

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }
    public DbSet<Favorite> Favorites => Set<Favorite>();
}