namespace TransitApi.Models;

public class Favorite
{
    public int Id { get; set; }
    public string UserDeviceId { get; set; } = string.Empty;
    public string StationId { get; set; } = string.Empty;
    public string StationName { get; set; } = string.Empty;
    public string DestinationStationId { get; set; } = "none";
}