

// HttpGet("{tripId}/pattern")]
// public async Task<IActionResult> GetStoppingPattern(string tripId)
// {
//     var pattern = await _context.StopTimes
//         .Where(st => st.TripId == tripId)
//         .OrderBy(st => st.StopSequence)
//         .Join(_context.Stops, 
//             st => st.StopId, 
//             s => s.Id, 
//             (st, s) => new { 
//                 st.StopSequence, 
//                 StationName = s.Name, 
//                 st.ArrivalTime 
//             })
//         .ToListAsync();

//     return Ok(pattern);
// }