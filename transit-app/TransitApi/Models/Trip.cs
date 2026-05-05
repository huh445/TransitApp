public class Trip
{
    public string TripId { get; set; } // Unique ID from GTFS

    public string RouteId { get; set; } // Links to the "Line" (e.g., Pakenham)
    
    public string ServiceId { get; set; } // Links to the schedule (Weekday/Weekend)

    public string TripHeadsign { get; set; } // This is your "Destination Name"
    
    public int DirectionId { get; set; } // 0 for outbound, 1 for inbound (or vice versa)
}