using Microsoft.EntityFrameworkCore;
using TransitApi.Models;

namespace TransitApi.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }
    public DbSet<Favorite> Favorites => Set<Favorite>();
}