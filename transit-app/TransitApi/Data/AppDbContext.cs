using Microsoft.EntityFrameworkCore;
using TransitApi.Models; // Ensure this matches your Trip class namespace

namespace TransitApi.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<Favorite> Favorites { get; set; }
    public DbSet<Stop> Stops { get; set; }
    
    // Add this line to fix the compiler error:
    public DbSet<Trip> Trips { get; set; } 

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Ensure TripId is treated as the Primary Key
        modelBuilder.Entity<Trip>().HasKey(t => t.TripId);
        base.OnModelCreating(modelBuilder);
    }
}