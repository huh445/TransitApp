using System.ComponentModel.DataAnnotations;

namespace TransitApi.Models;

public class Stop
{
    public string Id { get; set; }
    public string Name { get; set; }
    public double Lat { get; set; }
    public double Lon { get; set; }
    public int LocationType { get; set; } 
    public string ParentStation { get; set; } 
    public string PlatformCode { get; set; } 
}