using Microsoft.EntityFrameworkCore;
using TransitApi.Models;

namespace TransitApi.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }
    
    // If you have a Stop model, add it here too
    public DbSet<Favorite> Favorites => Set<Favorite>();
}