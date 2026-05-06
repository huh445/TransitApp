public class StopTime
{
    public int Id { get; set; } // Auto-increment PK
    public string TripId { get; set; } = string.Empty;
    public string StopId { get; set; } = string.Empty;
    public int StopSequence { get; set; }
    public string ArrivalTime { get; set; } = string.Empty;
}